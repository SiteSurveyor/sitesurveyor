#include "DatabaseManager.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QSqlRecord>
#include <QSqlDriver>
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QDateTime>
#include <QStandardPaths>
#include <QDir>
#include <QFileInfo>
#include <QSettings>

namespace {
bool tableExists(QSqlDatabase &db, const QString &tableName)
{
    QSqlQuery query(db);
    query.prepare("SELECT 1 FROM sqlite_master WHERE type='table' AND name = :name");
    query.bindValue(":name", tableName);
    if (!query.exec()) {
        qWarning() << "Failed to check for table" << tableName << ":" << query.lastError().text();
        return false;
    }

    return query.next();
}

bool columnExists(QSqlDatabase &db, const QString &tableName, const QString &columnName)
{
    QSqlQuery query(db);
    if (!query.exec(QString("PRAGMA table_info('%1')").arg(tableName))) {
        qWarning() << "Failed to read table info for" << tableName << ":" << query.lastError().text();
        return false;
    }

    while (query.next()) {
        if (query.value(1).toString() == columnName) {
            return true;
        }
    }

    return false;
}

bool geometryColumnRegistered(QSqlDatabase &db, const QString &tableName, const QString &columnName)
{
    if (!tableExists(db, "geometry_columns")) {
        return false;
    }

    QSqlQuery query(db);
    query.prepare(R"(
        SELECT 1
        FROM geometry_columns
        WHERE f_table_name = :table AND f_geometry_column = :column
    )");
    query.bindValue(":table", tableName);
    query.bindValue(":column", columnName);
    if (!query.exec()) {
        qWarning() << "Failed to check geometry_columns for" << tableName << columnName << ":"
                   << query.lastError().text();
        return false;
    }

    return query.next();
}

bool spatialIndexExists(QSqlDatabase &db, const QString &tableName, const QString &columnName)
{
    QSqlQuery query(db);
    if (query.exec(QString("SELECT CheckSpatialIndex('%1', '%2')").arg(tableName, columnName))
        && query.next()) {
        return query.value(0).toInt() == 1;
    }

    const QString rtreeName = QString("idx_%1_%2").arg(tableName, columnName);
    return tableExists(db, rtreeName);
}
} // namespace

DatabaseManager::DatabaseManager(QObject *parent)
    : QObject(parent)
    , m_currentProjectId(-1)
    , m_spatialiteLoaded(false)
#ifdef WITH_SPATIALITE
    , m_spatialiteCache(nullptr)
#endif
{
}

DatabaseManager::~DatabaseManager()
{
    closeDatabase();
}

bool DatabaseManager::openDatabase(const QString &path)
{
    if (m_db.isOpen()) {
        closeDatabase();
    }

    m_dbPath = path;

    // Ensure directory exists
    QFileInfo fileInfo(path);
    QDir dir = fileInfo.absoluteDir();
    if (!dir.exists()) {
        dir.mkpath(".");
    }

    m_db = QSqlDatabase::addDatabase("QSQLITE", "spatialite_connection");
    m_db.setDatabaseName(path);

    if (!m_db.open()) {
        emit errorOccurred(tr("Failed to open database: %1").arg(m_db.lastError().text()));
        return false;
    }

    // Initialize SpatiaLite extension
    if (!initSpatialite()) {
        qWarning() << "SpatiaLite extension not loaded, using basic SQLite";
    }

    // Create tables if they don't exist
    if (!createTables()) {
        emit errorOccurred(tr("Failed to create database tables"));
        closeDatabase();
        return false;
    }

    emit connectionChanged();
    return true;
}

void DatabaseManager::closeDatabase()
{
    QString connectionName = m_db.connectionName();
    if (m_db.isOpen()) {
        m_db.close();
    }

#ifdef WITH_SPATIALITE
    if (m_spatialiteCache) {
        spatialite_cleanup_ex(m_spatialiteCache);
        m_spatialiteCache = nullptr;
    }
#endif

    m_currentProjectId = -1;
    m_currentProjectName.clear();
    m_spatialiteLoaded = false;
    m_db = QSqlDatabase();
    if (!connectionName.isEmpty()) {
        QSqlDatabase::removeDatabase(connectionName);
    }
    emit connectionChanged();
}

bool DatabaseManager::isConnected() const
{
    return m_db.isOpen();
}

QString DatabaseManager::databasePath() const
{
    return m_dbPath;
}

QString DatabaseManager::defaultDatabasePath() const
{
    return m_defaultDbPath;
}

void DatabaseManager::setDefaultDatabasePath(const QString &path)
{
    m_defaultDbPath = path;
}

bool DatabaseManager::changeDatabasePath(const QString &newPath)
{
    if (newPath.isEmpty()) {
        return false;
    }

    // Close current database
    closeDatabase();

    // Open new database
    if (openDatabase(newPath)) {
        // Save to settings
        QSettings settings;
        settings.setValue("database/path", newPath);
        emit databasePathChanged();
        return true;
    }

    // If failed, try to reopen the previous database
    if (!m_dbPath.isEmpty()) {
        openDatabase(m_dbPath);
    }

    return false;
}

QString DatabaseManager::browseForDatabase()
{
    // File dialog handled in QML - return home path as default
    return QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
}

QString DatabaseManager::browseForNewDatabase()
{
    // File dialog handled in QML - return suggested path
    return QStandardPaths::writableLocation(QStandardPaths::HomeLocation) + "/sitesurveyor.db";
}

bool DatabaseManager::initSpatialite()
{
#ifdef WITH_SPATIALITE
    m_spatialiteCache = spatialite_alloc_connection();
    if (!m_spatialiteCache) {
        qWarning() << "SpatiaLite cache allocation failed";
        return false;
    }

    sqlite3 *sqliteHandle = nullptr;
    const QVariant driverHandle = m_db.driver()->handle();
    if (driverHandle.isValid() && QString(driverHandle.typeName()) == "sqlite3*") {
        sqliteHandle = *static_cast<sqlite3 *const *>(driverHandle.data());
    }

    QSqlQuery query(m_db);

    if (sqliteHandle) {
        spatialite_init_ex(sqliteHandle, m_spatialiteCache, 0);
    } else {
        qWarning() << "SpatiaLite init failed: unable to access sqlite3 handle";
        return false;
    }

    if (!query.exec("SELECT spatialite_version()")) {
        qWarning() << "SpatiaLite init failed:" << query.lastError().text();
        return false;
    }
    const bool hasSpatialRefSys = tableExists(m_db, "spatial_ref_sys");
    const bool hasGeometryColumns = tableExists(m_db, "geometry_columns");
    if (!hasSpatialRefSys || !hasGeometryColumns) {
        if (!query.exec("SELECT InitSpatialMetaData(1)")) {
            qWarning() << "InitSpatialMetaData failed:" << query.lastError().text();
            return false;
        }
    }

    m_spatialiteLoaded = true;
    qDebug() << "SpatiaLite initialized successfully";
    return true;
#else
    qDebug() << "SpatiaLite support not compiled in";
    return false;
#endif
}

bool DatabaseManager::createTables()
{
    QStringList statements;

    // Projects table - use center_lat/center_lon for backwards compatibility
    statements << R"(
        CREATE TABLE IF NOT EXISTS projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            discipline TEXT NOT NULL,
            center_lat REAL,
            center_lon REAL,
            srid INTEGER DEFAULT 4326,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            last_accessed TEXT
        )
    )";

    // Survey Points table
    statements << R"(
        CREATE TABLE IF NOT EXISTS survey_points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            x REAL NOT NULL,
            y REAL NOT NULL,
            z REAL DEFAULT 0,
            code TEXT,
            description TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
        )
    )";


    // Personnel table
    statements << R"(
        CREATE TABLE IF NOT EXISTS personnel (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER,
            name TEXT NOT NULL,
            role TEXT,
            status TEXT DEFAULT 'Off Duty',
            phone TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL
        )
    )";

    // Instruments table
    statements << R"(
        CREATE TABLE IF NOT EXISTS instruments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT,
            serial_number TEXT,
            status TEXT DEFAULT 'Available',
            last_calibration TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    )";

    // Traverses table
    statements << R"(
        CREATE TABLE IF NOT EXISTS traverses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            type TEXT DEFAULT 'Open',
            status TEXT DEFAULT 'In Progress',
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
        )
    )";

    // Traverse Observations table
    statements << R"(
        CREATE TABLE IF NOT EXISTS traverse_observations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            traverse_id INTEGER NOT NULL,
            from_point_id INTEGER,
            to_point_id INTEGER,
            horizontal_angle REAL,
            vertical_angle REAL,
            slope_distance REAL,
            horizontal_distance REAL,
            height_difference REAL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (traverse_id) REFERENCES traverses(id) ON DELETE CASCADE,
            FOREIGN KEY (from_point_id) REFERENCES survey_points(id),
            FOREIGN KEY (to_point_id) REFERENCES survey_points(id)
        )
    )";

    // Level Lines table
    statements << R"(
        CREATE TABLE IF NOT EXISTS level_lines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            start_rl REAL DEFAULT 0.0,
            method TEXT DEFAULT 'RiseFall',
            status TEXT DEFAULT 'In Progress',
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
        )
    )";

    // Level Observations table
    statements << R"(
        CREATE TABLE IF NOT EXISTS level_observations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            line_id INTEGER NOT NULL,
            station TEXT,
            bs REAL,
            is_reading REAL,
            fs REAL,
            rise REAL,
            fall REAL,
            hpc REAL,
            rl REAL,
            remarks TEXT,
            distance REAL DEFAULT 0.0,
            adj_rl REAL DEFAULT 0.0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (line_id) REFERENCES level_lines(id) ON DELETE CASCADE
        )
    )";

    // Execute all statements
    for (const QString &sql : statements) {
        QSqlQuery query(m_db);
        if (!query.exec(sql)) {
            // Ignore errors for spatial columns that might already exist
            if (!query.lastError().text().contains("already exists")) {
                qWarning() << "SQL Error:" << query.lastError().text() << "for:" << sql;
            }
        }
    }

    if (m_spatialiteLoaded) {
        bool hasGeomColumn = columnExists(m_db, "survey_points", "geom");
        bool hasGeomMetadata = geometryColumnRegistered(m_db, "survey_points", "geom");
        if (!hasGeomColumn) {
            QSqlQuery geomQuery(m_db);
            if (!geomQuery.exec(R"(
                SELECT AddGeometryColumn('survey_points', 'geom', 4326, 'POINT', 'XYZ', 1)
            )")) {
                qWarning() << "Failed to add geometry column:" << geomQuery.lastError().text();
            }
            hasGeomColumn = columnExists(m_db, "survey_points", "geom");
            hasGeomMetadata = geometryColumnRegistered(m_db, "survey_points", "geom");
        } else if (!hasGeomMetadata) {
            QSqlQuery recoverQuery(m_db);
            if (!recoverQuery.exec(R"(
                SELECT RecoverGeometryColumn('survey_points', 'geom', 4326, 'POINT', 'XYZ')
            )")) {
                qWarning() << "Failed to recover geometry column metadata:"
                           << recoverQuery.lastError().text();
            }
            hasGeomMetadata = geometryColumnRegistered(m_db, "survey_points", "geom");
        }

        if (hasGeomColumn && hasGeomMetadata) {
            if (!spatialIndexExists(m_db, "survey_points", "geom")) {
                QSqlQuery indexQuery(m_db);
                if (!indexQuery.exec(R"(
                    SELECT CreateSpatialIndex('survey_points', 'geom')
                )")) {
                    qWarning() << "Failed to create spatial index:" << indexQuery.lastError().text();
                }
            }
        }
    }

    // Run migrations for existing databases
    runMigrations();

    return true;
}

void DatabaseManager::runMigrations()
{
    // Migration 1: Add phone column to personnel table if it doesn't exist
    {
        QSqlQuery checkQuery(m_db);
        checkQuery.exec("PRAGMA table_info(personnel)");

        bool hasPhoneColumn = false;
        while (checkQuery.next()) {
            if (checkQuery.value(1).toString() == "phone") {
                hasPhoneColumn = true;
                break;
            }
        }

        if (!hasPhoneColumn) {
            QSqlQuery alterQuery(m_db);
            if (alterQuery.exec("ALTER TABLE personnel ADD COLUMN phone TEXT")) {
                qDebug() << "Migration: Added phone column to personnel table";
            } else {
                qWarning() << "Migration failed: Could not add phone column:" << alterQuery.lastError().text();
            }
        }
    }

    // Migration 2: Add distance and adj_rl columns to level_observations table if they don't exist
    {
        QSqlQuery checkQuery(m_db);
        checkQuery.exec("PRAGMA table_info(level_observations)");

        bool hasDistanceColumn = false;
        bool hasAdjRlColumn = false;

        while (checkQuery.next()) {
            QString colName = checkQuery.value(1).toString();
            if (colName == "distance") hasDistanceColumn = true;
            if (colName == "adj_rl") hasAdjRlColumn = true;
        }

        if (!hasDistanceColumn) {
            QSqlQuery alterQuery(m_db);
            if (alterQuery.exec("ALTER TABLE level_observations ADD COLUMN distance REAL DEFAULT 0.0")) {
                qDebug() << "Migration: Added distance column to level_observations table";
            } else {
                qWarning() << "Migration failed: Could not add distance column:" << alterQuery.lastError().text();
            }
        }

        if (!hasAdjRlColumn) {
            QSqlQuery alterQuery(m_db);
            if (alterQuery.exec("ALTER TABLE level_observations ADD COLUMN adj_rl REAL DEFAULT 0.0")) {
                qDebug() << "Migration: Added adj_rl column to level_observations table";
            } else {
                qWarning() << "Migration failed: Could not add adj_rl column:" << alterQuery.lastError().text();
            }
        }
    }

    // Migration 3: Add status column to projects table if it doesn't exist
    {
        QSqlQuery checkQuery(m_db);
        checkQuery.exec("PRAGMA table_info(projects)");

        bool hasStatusColumn = false;
        while (checkQuery.next()) {
            if (checkQuery.value(1).toString() == "status") {
                hasStatusColumn = true;
                break;
            }
        }

        if (!hasStatusColumn) {
            QSqlQuery alterQuery(m_db);
            if (alterQuery.exec("ALTER TABLE projects ADD COLUMN status TEXT DEFAULT 'Active'")) {
                qDebug() << "Migration: Added status column to projects table";
            } else {
                qWarning() << "Migration failed: Could not add status column:" << alterQuery.lastError().text();
            }
        }
    }
}

// Project management
bool DatabaseManager::createProject(const QString &name, const QString &description,
                                     const QString &discipline,
                                     double centerY, double centerX, int srid)
{
    QSqlQuery query(m_db);
    query.prepare(R"(
        INSERT INTO projects (name, description, discipline, center_lat, center_lon, srid)
        VALUES (:name, :description, :discipline, :y, :x, :srid)
    )");
    query.bindValue(":name", name);
    query.bindValue(":description", description);
    query.bindValue(":discipline", discipline);
    query.bindValue(":y", centerY);
    query.bindValue(":x", centerX);
    query.bindValue(":srid", srid);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to create project: %1").arg(query.lastError().text()));
        qDebug() << "SQL Error:" << query.lastError().text();
        return false;
    }

    return true;
}

QVariantList DatabaseManager::getProjects(const QString &discipline)
{
    QVariantList projects;
    QSqlQuery query(m_db);

    QString sql = R"(
        SELECT p.id, p.name, p.description, p.discipline, p.center_lat, p.center_lon, 
               p.srid, p.created_at, p.updated_at, COALESCE(p.status, 'Active') as status,
               (SELECT COUNT(*) FROM survey_points sp WHERE sp.project_id = p.id) as point_count
        FROM projects p
    )";

    if (discipline.isEmpty()) {
        sql += " ORDER BY p.updated_at DESC";
        if (!query.exec(sql)) {
            qWarning() << "getProjects query failed:" << query.lastError().text();
            return projects;
        }
    } else {
        sql += " WHERE p.discipline = :discipline ORDER BY p.updated_at DESC";
        query.prepare(sql);
        query.bindValue(":discipline", discipline);
        if (!query.exec()) {
            qWarning() << "getProjects query failed:" << query.lastError().text();
            qWarning() << "Discipline was:" << discipline;
            return projects;
        }
    }

    while (query.next()) {
        QVariantMap project;
        project["id"] = query.value(0);
        project["name"] = query.value(1);
        project["description"] = query.value(2);
        project["discipline"] = query.value(3);
        project["centerY"] = query.value(4);
        project["centerX"] = query.value(5);
        project["srid"] = query.value(6);
        project["createdAt"] = query.value(7);
        project["lastAccessed"] = query.value(8);  // Actually updated_at
        project["status"] = query.value(9);
        project["pointCount"] = query.value(10);
        projects.append(project);
    }

    qDebug() << "getProjects returning" << projects.count() << "projects for discipline:" << discipline;
    return projects;
}

QVariantList DatabaseManager::getRecentProjects(int limit)
{
    QVariantList projects;
    QSqlQuery query(m_db);
    
    query.prepare(R"(
        SELECT id, name, description, discipline, center_lat, center_lon, srid, created_at, last_accessed
        FROM projects
        WHERE last_accessed IS NOT NULL
        ORDER BY last_accessed DESC
        LIMIT :limit
    )");
    query.bindValue(":limit", limit);
    
    if (!query.exec()) {
        qWarning() << "Failed to get recent projects:" << query.lastError().text();
        return projects;
    }
    
    while (query.next()) {
        QVariantMap project;
        project["id"] = query.value(0);
        project["name"] = query.value(1);
        project["description"] = query.value(2);
        project["discipline"] = query.value(3);
        project["centerY"] = query.value(4);
        project["centerX"] = query.value(5);
        project["srid"] = query.value(6);
        project["createdAt"] = query.value(7);
        project["lastAccessed"] = query.value(8);
        projects.append(project);
    }
    
    return projects;
}

bool DatabaseManager::deleteProject(int projectId)
{
    // Create backup before deletion
    createBackup("before_delete_project");
    
    QSqlQuery query(m_db);
    query.prepare("DELETE FROM projects WHERE id = :id");
    query.bindValue(":id", projectId);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to delete project: %1").arg(query.lastError().text()));
        return false;
    }

    if (m_currentProjectId == projectId) {
        m_currentProjectId = -1;
        m_currentProjectName.clear();
        emit projectChanged();
    }

    return true;
}

bool DatabaseManager::deleteProjects(const QVariantList &projectIds)
{
    if (projectIds.isEmpty()) {
        return true;
    }

    // Create backup before bulk deletion
    createBackup("before_bulk_delete");
    
    m_db.transaction();
    
    QSqlQuery query(m_db);
    query.prepare("DELETE FROM projects WHERE id = :id");
    
    for (const QVariant &idVar : projectIds) {
        int projectId = idVar.toInt();
        query.bindValue(":id", projectId);
        
        if (!query.exec()) {
            m_db.rollback();
            emit errorOccurred(tr("Failed to delete projects: %1").arg(query.lastError().text()));
            return false;
        }
        
        if (m_currentProjectId == projectId) {
            m_currentProjectId = -1;
            m_currentProjectName.clear();
        }
    }
    
    m_db.commit();
    emit projectChanged();
    return true;
}

bool DatabaseManager::updateProjectStatus(int projectId, const QString &status)
{
    QSqlQuery query(m_db);
    query.prepare("UPDATE projects SET status = :status, updated_at = :timestamp WHERE id = :id");
    query.bindValue(":status", status);
    query.bindValue(":timestamp", QDateTime::currentDateTime().toString(Qt::ISODate));
    query.bindValue(":id", projectId);
    
    if (!query.exec()) {
        emit errorOccurred(tr("Failed to update project status: %1").arg(query.lastError().text()));
        return false;
    }
    
    emit projectChanged();
    return true;
}

bool DatabaseManager::updateProject(int projectId, const QString &name, const QString &description, double centerY, double centerX)
{
    QSqlQuery query(m_db);
    query.prepare(R"(
        UPDATE projects 
        SET name = :name, 
            description = :description, 
            center_lat = :y, 
            center_lon = :x,
            updated_at = :timestamp 
        WHERE id = :id
    )");
    query.bindValue(":name", name);
    query.bindValue(":description", description);
    query.bindValue(":y", centerY);
    query.bindValue(":x", centerX);
    query.bindValue(":timestamp", QDateTime::currentDateTime().toString(Qt::ISODate));
    query.bindValue(":id", projectId);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to update project: %1").arg(query.lastError().text()));
        return false;
    }

    if (m_currentProjectId == projectId) {
        m_currentProjectName = name;
        emit projectChanged();
    } else {
        emit projectChanged();
    }

    return true;
}

int DatabaseManager::getPointCountForProject(int projectId)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT COUNT(*) FROM survey_points WHERE project_id = :id");
    query.bindValue(":id", projectId);
    
    if (query.exec() && query.next()) {
        return query.value(0).toInt();
    }
    
    return 0;
}

QString DatabaseManager::currentDiscipline() const
{
    return m_currentDiscipline;
}

void DatabaseManager::setCurrentDiscipline(const QString &discipline)
{
    if (m_currentDiscipline != discipline) {
        m_currentDiscipline = discipline;
        emit disciplineChanged();
    }
}

bool DatabaseManager::loadProject(int projectId)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT name FROM projects WHERE id = :id");
    query.bindValue(":id", projectId);

    if (query.exec() && query.next()) {
        m_currentProjectId = projectId;
        m_currentProjectName = query.value(0).toString();
        
        // Update last accessed time
        QSqlQuery updateQuery(m_db);
        updateQuery.prepare("UPDATE projects SET last_accessed = :timestamp WHERE id = :id");
        updateQuery.bindValue(":timestamp", QDateTime::currentDateTime().toString(Qt::ISODate));
        updateQuery.bindValue(":id", projectId);
        updateQuery.exec();
        
        emit projectChanged();
        emit pointsChanged();
        emit personnelChanged();
        emit traversesChanged();
        return true;
    }

    emit errorOccurred(tr("Project not found"));
    return false;
}

QString DatabaseManager::currentProject() const
{
    return m_currentProjectName;
}

QVariantMap DatabaseManager::currentProjectDetails() const
{
    QVariantMap details;

    if (m_currentProjectId < 0) {
        return details;
    }

    QSqlQuery query(m_db);
    query.prepare(R"(
        SELECT id, name, description, discipline, center_lat, center_lon, srid, created_at
        FROM projects WHERE id = :id
    )");
    query.bindValue(":id", m_currentProjectId);

    if (query.exec() && query.next()) {
        details["id"] = query.value("id");
        details["name"] = query.value("name");
        details["description"] = query.value("description");
        details["discipline"] = query.value("discipline");
        details["centerY"] = query.value("center_lat");  // Map to centerY for QML
        details["centerX"] = query.value("center_lon");  // Map to centerX for QML
        details["srid"] = query.value("srid");
        details["createdAt"] = query.value("created_at");
    }

    return details;
}

// Survey Points
int DatabaseManager::addPoint(const QString &name, double x, double y, double z,
                                const QString &code, const QString &description)
{
    if (m_currentProjectId < 0) {
        emit errorOccurred(tr("No project loaded"));
        return 0;
    }

    QSqlQuery query(m_db);

    if (m_spatialiteLoaded) {
        query.prepare(R"(
            INSERT INTO survey_points (project_id, name, x, y, z, code, description, geom)
            VALUES (:project_id, :name, :x, :y, :z, :code, :desc, MakePointZ(:x, :y, :z, 4326))
        )");
    } else {
        query.prepare(R"(
            INSERT INTO survey_points (project_id, name, x, y, z, code, description)
            VALUES (:project_id, :name, :x, :y, :z, :code, :desc)
        )");
    }

    query.bindValue(":project_id", m_currentProjectId);
    query.bindValue(":name", name);
    query.bindValue(":x", x);
    query.bindValue(":y", y);
    query.bindValue(":z", z);
    query.bindValue(":code", code);
    query.bindValue(":desc", description);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to add point: %1").arg(query.lastError().text()));
        return 0;
    }

    emit pointsChanged();
    return query.lastInsertId().toInt();
}

bool DatabaseManager::updatePoint(int pointId, double x, double y, double z,
                                   const QString &code, const QString &description)
{
    QSqlQuery query(m_db);

    if (m_spatialiteLoaded) {
        query.prepare(R"(
            UPDATE survey_points
            SET x = :x, y = :y, z = :z, code = :code, description = :desc,
                geom = MakePointZ(:x, :y, :z, 4326)
            WHERE id = :id
        )");
    } else {
        query.prepare(R"(
            UPDATE survey_points
            SET x = :x, y = :y, z = :z, code = :code, description = :desc
            WHERE id = :id
        )");
    }

    query.bindValue(":id", pointId);
    query.bindValue(":x", x);
    query.bindValue(":y", y);
    query.bindValue(":z", z);
    query.bindValue(":code", code);
    query.bindValue(":desc", description);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to update point: %1").arg(query.lastError().text()));
        return false;
    }

    emit pointsChanged();
    return true;
}

bool DatabaseManager::deletePoint(int pointId)
{
    QSqlQuery query(m_db);
    query.prepare("DELETE FROM survey_points WHERE id = :id");
    query.bindValue(":id", pointId);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to delete point: %1").arg(query.lastError().text()));
        return false;
    }

    emit pointsChanged();
    return true;
}

QVariantList DatabaseManager::getPoints()
{
    QVariantList points;

    if (m_currentProjectId < 0) return points;

    QSqlQuery query(m_db);
    query.prepare("SELECT id, name, x, y, z, code, description FROM survey_points WHERE project_id = :pid ORDER BY name");
    query.bindValue(":pid", m_currentProjectId);
    query.exec();

    while (query.next()) {
        QVariantMap point;
        point["id"] = query.value(0);
        point["name"] = query.value(1);
        point["x"] = query.value(2);
        point["y"] = query.value(3);
        point["z"] = query.value(4);
        point["code"] = query.value(5);
        point["description"] = query.value(6);
        points.append(point);
    }

    return points;
}

QVariantMap DatabaseManager::getPoint(int pointId)
{
    QVariantMap point;
    QSqlQuery query(m_db);
    query.prepare("SELECT id, name, x, y, z, code, description FROM survey_points WHERE id = :id");
    query.bindValue(":id", pointId);

    if (query.exec() && query.next()) {
        point["id"] = query.value(0);
        point["name"] = query.value(1);
        point["x"] = query.value(2);
        point["y"] = query.value(3);
        point["z"] = query.value(4);
        point["code"] = query.value(5);
        point["description"] = query.value(6);
    }

    return point;
}

QVariantList DatabaseManager::getPointsInBounds(double minX, double minY, double maxX, double maxY)
{
    QVariantList points;

    if (m_currentProjectId < 0) return points;

    QSqlQuery query(m_db);

    if (m_spatialiteLoaded) {
        query.prepare(R"(
            SELECT id, name, x, y, z, code, description
            FROM survey_points
            WHERE project_id = :pid
              AND MbrWithin(geom, BuildMbr(:minX, :minY, :maxX, :maxY, 4326))
        )");
    } else {
        query.prepare(R"(
            SELECT id, name, x, y, z, code, description
            FROM survey_points
            WHERE project_id = :pid
              AND x BETWEEN :minX AND :maxX
              AND y BETWEEN :minY AND :maxY
        )");
    }

    query.bindValue(":pid", m_currentProjectId);
    query.bindValue(":minX", minX);
    query.bindValue(":minY", minY);
    query.bindValue(":maxX", maxX);
    query.bindValue(":maxY", maxY);
    query.exec();

    while (query.next()) {
        QVariantMap point;
        point["id"] = query.value(0);
        point["name"] = query.value(1);
        point["x"] = query.value(2);
        point["y"] = query.value(3);
        point["z"] = query.value(4);
        point["code"] = query.value(5);
        point["description"] = query.value(6);
        points.append(point);
    }

    return points;
}

// Personnel
bool DatabaseManager::addPersonnel(const QString &name, const QString &role,
                                    const QString &status, const QString &phone)
{
    QSqlQuery query(m_db);
    query.prepare(R"(
        INSERT INTO personnel (project_id, name, role, status, phone)
        VALUES (:pid, :name, :role, :status, :phone)
    )");
    query.bindValue(":pid", m_currentProjectId > 0 ? m_currentProjectId : QVariant());
    query.bindValue(":name", name);
    query.bindValue(":role", role);
    query.bindValue(":status", status);
    query.bindValue(":phone", phone);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to add personnel: %1").arg(query.lastError().text()));
        return false;
    }

    emit personnelChanged();
    return true;
}

bool DatabaseManager::updatePersonnel(int id, const QString &name, const QString &role,
                                       const QString &status, const QString &phone)
{
    QSqlQuery query(m_db);
    query.prepare("UPDATE personnel SET name = :name, role = :role, status = :status, phone = :phone WHERE id = :id");
    query.bindValue(":id", id);
    query.bindValue(":name", name);
    query.bindValue(":role", role);
    query.bindValue(":status", status);
    query.bindValue(":phone", phone);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to update personnel: %1").arg(query.lastError().text()));
        return false;
    }

    emit personnelChanged();
    return true;
}

bool DatabaseManager::deletePersonnel(int id)
{
    QSqlQuery query(m_db);
    query.prepare("DELETE FROM personnel WHERE id = :id");
    query.bindValue(":id", id);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to delete personnel: %1").arg(query.lastError().text()));
        return false;
    }

    emit personnelChanged();
    return true;
}

QVariantList DatabaseManager::getPersonnel()
{
    QVariantList personnel;
    QSqlQuery query(m_db);
    query.exec("SELECT id, name, role, status, phone FROM personnel ORDER BY name");

    while (query.next()) {
        QVariantMap person;
        person["id"] = query.value(0);
        person["name"] = query.value(1);
        person["role"] = query.value(2);
        person["status"] = query.value(3);
        person["phone"] = query.value(4);
        personnel.append(person);
    }

    return personnel;
}

// Instruments
bool DatabaseManager::addInstrument(const QString &name, const QString &type,
                                     const QString &serial, const QString &status)
{
    QSqlQuery query(m_db);
    query.prepare(R"(
        INSERT INTO instruments (name, type, serial_number, status)
        VALUES (:name, :type, :serial, :status)
    )");
    query.bindValue(":name", name);
    query.bindValue(":type", type);
    query.bindValue(":serial", serial);
    query.bindValue(":status", status);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to add instrument: %1").arg(query.lastError().text()));
        return false;
    }

    emit instrumentsChanged();
    return true;
}

bool DatabaseManager::updateInstrument(int id, const QString &name, const QString &type,
                                        const QString &serial, const QString &status)
{
    QSqlQuery query(m_db);
    query.prepare("UPDATE instruments SET name = :name, type = :type, serial_number = :serial, status = :status WHERE id = :id");
    query.bindValue(":id", id);
    query.bindValue(":name", name);
    query.bindValue(":type", type);
    query.bindValue(":serial", serial);
    query.bindValue(":status", status);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to update instrument: %1").arg(query.lastError().text()));
        return false;
    }

    emit instrumentsChanged();
    return true;
}

bool DatabaseManager::deleteInstrument(int id)
{
    QSqlQuery query(m_db);
    query.prepare("DELETE FROM instruments WHERE id = :id");
    query.bindValue(":id", id);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to delete instrument: %1").arg(query.lastError().text()));
        return false;
    }

    emit instrumentsChanged();
    return true;
}

QVariantList DatabaseManager::getInstruments()
{
    QVariantList instruments;
    QSqlQuery query(m_db);
    query.exec("SELECT id, name, type, serial_number, status FROM instruments ORDER BY name");

    while (query.next()) {
        QVariantMap instrument;
        instrument["id"] = query.value(0);
        instrument["name"] = query.value(1);
        instrument["type"] = query.value(2);
        instrument["serial"] = query.value(3);
        instrument["status"] = query.value(4);
        instruments.append(instrument);
    }

    return instruments;
}

// Traverses
int DatabaseManager::createTraverse(const QString &name, const QString &type)
{
    if (m_currentProjectId < 0) {
        emit errorOccurred(tr("No project loaded"));
        return -1;
    }

    QSqlQuery query(m_db);
    query.prepare(R"(
        INSERT INTO traverses (project_id, name, type)
        VALUES (:pid, :name, :type)
    )");
    query.bindValue(":pid", m_currentProjectId);
    query.bindValue(":name", name);
    query.bindValue(":type", type);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to create traverse: %1").arg(query.lastError().text()));
        return -1;
    }

    emit traversesChanged();
    return query.lastInsertId().toInt();
}

bool DatabaseManager::addTraverseObservation(int traverseId, int fromPointId, int toPointId,
                                              double horizontalAngle, double verticalAngle,
                                              double slopeDistance)
{
    // Calculate horizontal distance and height difference
    double vertAngleRad = verticalAngle * M_PI / 180.0;
    double horizontalDistance = slopeDistance * cos(vertAngleRad);
    double heightDifference = slopeDistance * sin(vertAngleRad);

    QSqlQuery query(m_db);
    query.prepare(R"(
        INSERT INTO traverse_observations
        (traverse_id, from_point_id, to_point_id, horizontal_angle, vertical_angle,
         slope_distance, horizontal_distance, height_difference)
        VALUES (:tid, :from, :to, :ha, :va, :sd, :hd, :dh)
    )");
    query.bindValue(":tid", traverseId);
    query.bindValue(":from", fromPointId);
    query.bindValue(":to", toPointId);
    query.bindValue(":ha", horizontalAngle);
    query.bindValue(":va", verticalAngle);
    query.bindValue(":sd", slopeDistance);
    query.bindValue(":hd", horizontalDistance);
    query.bindValue(":dh", heightDifference);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to add observation: %1").arg(query.lastError().text()));
        return false;
    }

    return true;
}

QVariantList DatabaseManager::getTraverses()
{
    QVariantList traverses;

    if (m_currentProjectId < 0) return traverses;

    QSqlQuery query(m_db);
    query.prepare("SELECT id, name, type, status FROM traverses WHERE project_id = :pid ORDER BY created_at DESC");
    query.bindValue(":pid", m_currentProjectId);
    query.exec();

    while (query.next()) {
        QVariantMap traverse;
        traverse["id"] = query.value(0);
        traverse["name"] = query.value(1);
        traverse["type"] = query.value(2);
        traverse["status"] = query.value(3);
        traverses.append(traverse);
    }

    return traverses;
}

QVariantList DatabaseManager::getTraverseObservations(int traverseId)
{
    QVariantList observations;
    QSqlQuery query(m_db);
    query.prepare(R"(
        SELECT o.id, o.horizontal_angle, o.vertical_angle, o.slope_distance,
               o.horizontal_distance, o.height_difference,
               p1.name as from_name, p2.name as to_name
        FROM traverse_observations o
        LEFT JOIN survey_points p1 ON o.from_point_id = p1.id
        LEFT JOIN survey_points p2 ON o.to_point_id = p2.id
        WHERE o.traverse_id = :tid
        ORDER BY o.id
    )");
    query.bindValue(":tid", traverseId);
    query.exec();

    while (query.next()) {
        QVariantMap obs;
        obs["id"] = query.value(0);
        obs["horizontalAngle"] = query.value(1);
        obs["verticalAngle"] = query.value(2);
        obs["slopeDistance"] = query.value(3);
        obs["horizontalDistance"] = query.value(4);
        obs["heightDifference"] = query.value(5);
        obs["fromPoint"] = query.value(6);
        obs["toPoint"] = query.value(7);
        observations.append(obs);
    }

    return observations;
}

// Levelling
int DatabaseManager::createLevelLine(const QString &name, const QString &description, double startRl, const QString &method)
{
    if (m_currentProjectId < 0) {
        emit errorOccurred(tr("No project loaded"));
        return -1;
    }

    QSqlQuery query(m_db);
    query.prepare(R"(
        INSERT INTO level_lines (project_id, name, description, start_rl, method)
        VALUES (:pid, :name, :desc, :startRl, :method)
    )");
    query.bindValue(":pid", m_currentProjectId);
    query.bindValue(":name", name);
    query.bindValue(":desc", description);
    query.bindValue(":startRl", startRl);
    query.bindValue(":method", method);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to create level line: %1").arg(query.lastError().text()));
        return -1;
    }

    return query.lastInsertId().toInt();
}

bool DatabaseManager::updateLevelLine(int id, const QString &name, const QString &description, double startRl, const QString &method, const QString &status)
{
    QSqlQuery query(m_db);
    query.prepare(R"(
        UPDATE level_lines
        SET name = :name, description = :desc, start_rl = :startRl, method = :method, status = :status
        WHERE id = :id
    )");
    query.bindValue(":id", id);
    query.bindValue(":name", name);
    query.bindValue(":desc", description);
    query.bindValue(":startRl", startRl);
    query.bindValue(":method", method);
    query.bindValue(":status", status);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to update level line: %1").arg(query.lastError().text()));
        return false;
    }

    return true;
}

bool DatabaseManager::deleteLevelLine(int id)
{
    QSqlQuery query(m_db);
    query.prepare("DELETE FROM level_lines WHERE id = :id");
    query.bindValue(":id", id);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to delete level line: %1").arg(query.lastError().text()));
        return false;
    }

    return true;
}

QVariantList DatabaseManager::getLevelLines()
{
    QVariantList lines;

    if (m_currentProjectId < 0) return lines;

    QSqlQuery query(m_db);
    query.prepare("SELECT id, name, description, start_rl, method, status, created_at FROM level_lines WHERE project_id = :pid ORDER BY created_at DESC");
    query.bindValue(":pid", m_currentProjectId);
    query.exec();

    while (query.next()) {
        QVariantMap line;
        line["id"] = query.value(0);
        line["name"] = query.value(1);
        line["description"] = query.value(2);
        line["startRl"] = query.value(3);
        line["method"] = query.value(4);
        line["status"] = query.value(5);
        line["createdAt"] = query.value(6);
        lines.append(line);
    }

    return lines;
}

bool DatabaseManager::addLevelObservation(int lineId, const QString &station, double bs, double is, double fs,
                                          double rise, double fall, double hpc, double rl, const QString &remarks,
                                          double distance, double adjRl)
{
    QSqlQuery query(m_db);
    query.prepare(R"(
        INSERT INTO level_observations (line_id, station, bs, is_reading, fs, rise, fall, hpc, rl, remarks, distance, adj_rl)
        VALUES (:lineId, :station, :bs, :is, :fs, :rise, :fall, :hpc, :rl, :remarks, :dist, :adjRl)
    )");
    query.bindValue(":lineId", lineId);
    query.bindValue(":station", station);
    query.bindValue(":bs", bs);
    query.bindValue(":is", is);
    query.bindValue(":fs", fs);
    query.bindValue(":rise", rise);
    query.bindValue(":fall", fall);
    query.bindValue(":hpc", hpc);
    query.bindValue(":rl", rl);
    query.bindValue(":remarks", remarks);
    query.bindValue(":dist", distance);
    query.bindValue(":adjRl", adjRl);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to add level observation: %1").arg(query.lastError().text()));
        return false;
    }

    return true;
}

bool DatabaseManager::updateLevelObservation(int id, const QString &station, double bs, double is, double fs,
                                             double rise, double fall, double hpc, double rl, const QString &remarks,
                                             double distance, double adjRl)
{
    QSqlQuery query(m_db);
    query.prepare(R"(
        UPDATE level_observations
        SET station = :station, bs = :bs, is_reading = :is, fs = :fs,
            rise = :rise, fall = :fall, hpc = :hpc, rl = :rl, remarks = :remarks,
            distance = :dist, adj_rl = :adjRl
        WHERE id = :id
    )");
    query.bindValue(":id", id);
    query.bindValue(":station", station);
    query.bindValue(":bs", bs);
    query.bindValue(":is", is);
    query.bindValue(":fs", fs);
    query.bindValue(":rise", rise);
    query.bindValue(":fall", fall);
    query.bindValue(":hpc", hpc);
    query.bindValue(":rl", rl);
    query.bindValue(":remarks", remarks);
    query.bindValue(":dist", distance);
    query.bindValue(":adjRl", adjRl);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to update observation: %1").arg(query.lastError().text()));
        return false;
    }

    return true;
}

bool DatabaseManager::deleteLevelObservation(int id)
{
    QSqlQuery query(m_db);
    query.prepare("DELETE FROM level_observations WHERE id = :id");
    query.bindValue(":id", id);

    if (!query.exec()) {
        emit errorOccurred(tr("Failed to delete observation: %1").arg(query.lastError().text()));
        return false;
    }

    return true;
}

QVariantList DatabaseManager::getLevelObservations(int lineId)
{
    QVariantList observations;
    QSqlQuery query(m_db);
    query.prepare("SELECT id, station, bs, is_reading, fs, rise, fall, hpc, rl, remarks, distance, adj_rl FROM level_observations WHERE line_id = :lid ORDER BY id");
    query.bindValue(":lid", lineId);
    query.exec();

    while (query.next()) {
        QVariantMap obs;
        obs["id"] = query.value(0);
        obs["station"] = query.value(1);
        obs["bs"] = query.value(2);
        obs["is"] = query.value(3);
        obs["fs"] = query.value(4);
        obs["rise"] = query.value(5);
        obs["fall"] = query.value(6);
        obs["hpc"] = query.value(7);
        obs["rl"] = query.value(8);
        obs["remarks"] = query.value(9);
        obs["distance"] = query.value(10);
        obs["adjRl"] = query.value(11);
        observations.append(obs);
    }

    return observations;
}

// Spatial queries
double DatabaseManager::calculateDistance(int pointId1, int pointId2)
{
    if (!m_spatialiteLoaded) {
        // Fallback to simple calculation
        QVariantMap p1 = getPoint(pointId1);
        QVariantMap p2 = getPoint(pointId2);

        if (p1.isEmpty() || p2.isEmpty()) return -1;

        double dx = p2["x"].toDouble() - p1["x"].toDouble();
        double dy = p2["y"].toDouble() - p1["y"].toDouble();
        double dz = p2["z"].toDouble() - p1["z"].toDouble();

        return sqrt(dx*dx + dy*dy + dz*dz);
    }

    QSqlQuery query(m_db);
    query.prepare(R"(
        SELECT ST_Distance(
            (SELECT geom FROM survey_points WHERE id = :id1),
            (SELECT geom FROM survey_points WHERE id = :id2),
            1
        )
    )");
    query.bindValue(":id1", pointId1);
    query.bindValue(":id2", pointId2);

    if (query.exec() && query.next()) {
        return query.value(0).toDouble();
    }

    return -1;
}

double DatabaseManager::calculateArea(const QVariantList &pointIds)
{
    if (pointIds.size() < 3) return 0;

    if (!m_spatialiteLoaded) {
        // Simple polygon area calculation (shoelace formula)
        double area = 0;
        for (int i = 0; i < pointIds.size(); i++) {
            QVariantMap p1 = getPoint(pointIds[i].toInt());
            QVariantMap p2 = getPoint(pointIds[(i + 1) % pointIds.size()].toInt());

            area += p1["x"].toDouble() * p2["y"].toDouble();
            area -= p2["x"].toDouble() * p1["y"].toDouble();
        }
        return fabs(area) / 2.0;
    }

    // Build polygon WKT
    QString wkt = "POLYGON((";
    for (int i = 0; i <= pointIds.size(); i++) {
        QVariantMap p = getPoint(pointIds[i % pointIds.size()].toInt());
        if (i > 0) wkt += ", ";
        wkt += QString("%1 %2").arg(p["x"].toDouble()).arg(p["y"].toDouble());
    }
    wkt += "))";

    QSqlQuery query(m_db);
    query.prepare("SELECT ST_Area(GeomFromText(:wkt, 4326), 1)");
    query.bindValue(":wkt", wkt);

    if (query.exec() && query.next()) {
        return query.value(0).toDouble();
    }

    return 0;
}

QVariantList DatabaseManager::getPointsWithinRadius(double centerX, double centerY, double radiusMeters)
{
    QVariantList points;

    if (m_currentProjectId < 0) return points;

    QSqlQuery query(m_db);

    if (m_spatialiteLoaded) {
        query.prepare(R"(
            SELECT id, name, x, y, z, code, description
            FROM survey_points
            WHERE project_id = :pid
              AND ST_Distance(geom, MakePoint(:cx, :cy, 4326), 1) <= :radius
        )");
    } else {
        // Approximate with bounding box (not accurate for large distances)
        double approxDegrees = radiusMeters / 111000.0;
        query.prepare(R"(
            SELECT id, name, x, y, z, code, description
            FROM survey_points
            WHERE project_id = :pid
              AND x BETWEEN :minX AND :maxX
              AND y BETWEEN :minY AND :maxY
        )");
        query.bindValue(":minX", centerX - approxDegrees);
        query.bindValue(":maxX", centerX + approxDegrees);
        query.bindValue(":minY", centerY - approxDegrees);
        query.bindValue(":maxY", centerY + approxDegrees);
    }

    query.bindValue(":pid", m_currentProjectId);
    query.bindValue(":cx", centerX);
    query.bindValue(":cy", centerY);
    query.bindValue(":radius", radiusMeters);
    query.exec();

    while (query.next()) {
        QVariantMap point;
        point["id"] = query.value(0);
        point["name"] = query.value(1);
        point["x"] = query.value(2);
        point["y"] = query.value(3);
        point["z"] = query.value(4);
        point["code"] = query.value(5);
        point["description"] = query.value(6);
        points.append(point);
    }

    return points;
}

// Export/Import
bool DatabaseManager::exportToCSV(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        emit errorOccurred(tr("Failed to open file for writing"));
        return false;
    }

    QTextStream out(&file);
    out << "Name,X,Y,Z,Code,Description\n";

    QVariantList points = getPoints();
    for (const QVariant &pt : points) {
        QVariantMap p = pt.toMap();
        out << QString("\"%1\",%2,%3,%4,\"%5\",\"%6\"\n")
               .arg(p["name"].toString())
               .arg(p["x"].toDouble(), 0, 'f', 6)
               .arg(p["y"].toDouble(), 0, 'f', 6)
               .arg(p["z"].toDouble(), 0, 'f', 3)
               .arg(p["code"].toString())
               .arg(p["description"].toString());
    }

    file.close();
    return true;
}

bool DatabaseManager::importFromCSV(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit errorOccurred(tr("Failed to open file for reading"));
        return false;
    }

    QTextStream in(&file);
    QString header = in.readLine(); // Skip header

    while (!in.atEnd()) {
        QString line = in.readLine();
        QStringList parts = line.split(',');

        if (parts.size() >= 4) {
            QString name = parts[0].remove('"');
            double x = parts[1].toDouble();
            double y = parts[2].toDouble();
            double z = parts[3].toDouble();
            QString code = parts.size() > 4 ? parts[4].remove('"') : "";
            QString desc = parts.size() > 5 ? parts[5].remove('"') : "";

            addPoint(name, x, y, z, code, desc);
        }
    }

    file.close();
    return true;
}

// Database Backup/Restore
bool DatabaseManager::createBackup(const QString &reason)
{
    if (m_dbPath.isEmpty() || !m_db.isOpen()) {
        emit errorOccurred(tr("No database is currently open"));
        return false;
    }
    
    // Create backup directory
    QString backupDir = getBackupDirectory();
    QDir dir;
    if (!dir.exists(backupDir)) {
        if (!dir.mkpath(backupDir)) {
            emit errorOccurred(tr("Failed to create backup directory"));
            return false;
        }
    }
    
    // Generate backup filename with timestamp
    QString timestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
    QString reasonCopy = reason;
    QString reasonSuffix = reason.isEmpty() ? "" : "_" + reasonCopy.replace(" ", "_");
    QString backupFileName = QString("sitesurveyor_%1%2.db").arg(timestamp).arg(reasonSuffix);
    QString backupPath = backupDir + "/" + backupFileName;
    
    // Close database temporarily to copy file
    QString originalPath = m_dbPath;
    m_db.close();
    
    // Copy database file
    bool success = QFile::copy(originalPath, backupPath);
    
    // Reopen database
    m_db.setDatabaseName(originalPath);
    if (!m_db.open()) {
        emit errorOccurred(tr("Failed to reopen database after backup"));
        return false;
    }
    
    if (!success) {
        emit errorOccurred(tr("Failed to create backup file"));
        return false;
    }
    
    qDebug() << "Database backed up to:" << backupPath;
    
    // Clean up old backups
    deleteOldBackups(10);
    
    return true;
}

QString DatabaseManager::getBackupDirectory() const
{
    QString dataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return dataPath + "/backups";
}

QVariantList DatabaseManager::listBackups()
{
    QVariantList backups;
    QString backupDir = getBackupDirectory();
    
    QDir dir(backupDir);
    if (!dir.exists()) {
        return backups;
    }
    
    // Get all .db files sorted by modification time (newest first)
    QFileInfoList fileList = dir.entryInfoList(QStringList() << "*.db", QDir::Files, QDir::Time);
    
    for (const QFileInfo &fileInfo : fileList) {
        QVariantMap backup;
        backup["path"] = fileInfo.absoluteFilePath();
        backup["name"] = fileInfo.fileName();
        backup["size"] = fileInfo.size();
        backup["created"] = fileInfo.lastModified().toString(Qt::ISODate);
        backups.append(backup);
    }
    
    return backups;
}

bool DatabaseManager::restoreFromBackup(const QString &backupPath)
{
    if (!QFile::exists(backupPath)) {
        emit errorOccurred(tr("Backup file does not exist"));
        return false;
    }
    
    // Create a safety backup of current database before restoring
    createBackup("before_restore");
    
    QString originalPath = m_dbPath;
    closeDatabase();
    
    // Remove current database
    QFile::remove(originalPath);
    
    // Copy backup to current location
    bool success = QFile::copy(backupPath, originalPath);
    
    if (!success) {
        emit errorOccurred(tr("Failed to restore from backup"));
        return false;
    }
    
    // Reopen database
    if (!openDatabase(originalPath)) {
        emit errorOccurred(tr("Failed to open restored database"));
        return false;
    }
    
    qDebug() << "Database restored from:" << backupPath;
    return true;
}

bool DatabaseManager::deleteOldBackups(int keepCount)
{
    QString backupDir = getBackupDirectory();
    QDir dir(backupDir);
    
    if (!dir.exists()) {
        return true;
    }
    
    // Get all .db files sorted by modification time (newest first)
    QFileInfoList fileList = dir.entryInfoList(QStringList() << "*.db", QDir::Files, QDir::Time);
    
    // Delete files beyond keepCount
    for (int i = keepCount; i < fileList.size(); ++i) {
        QFile::remove(fileList[i].absoluteFilePath());
        qDebug() << "Deleted old backup:" << fileList[i].fileName();
    }
    
    return true;
}
