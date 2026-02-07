#ifndef DATABASEMANAGER_H
#define DATABASEMANAGER_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QSqlDatabase>

#ifdef WITH_SPATIALITE
#include <sqlite3.h>
#include <spatialite.h>
#endif

/**
 * @brief DatabaseManager - Handles SpatiaLite database operations for offline storage
 *
 * Provides functionality for:
 * - Project management
 * - Survey points storage with spatial indexing
 * - Personnel management
 * - Instruments management
 * - Traverses and observations
 */
class DatabaseManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY connectionChanged)
    Q_PROPERTY(QString currentProject READ currentProject NOTIFY projectChanged)
    Q_PROPERTY(QString currentDiscipline READ currentDiscipline NOTIFY disciplineChanged)
    Q_PROPERTY(QString databasePath READ databasePath NOTIFY databasePathChanged)

public:
    explicit DatabaseManager(QObject *parent = nullptr);
    ~DatabaseManager();

    // Database connection
    Q_INVOKABLE bool openDatabase(const QString &path);
    Q_INVOKABLE void closeDatabase();
    Q_INVOKABLE bool isConnected() const;
    Q_INVOKABLE QString databasePath() const;
    Q_INVOKABLE QString defaultDatabasePath() const;
    void setDefaultDatabasePath(const QString &path);
    Q_INVOKABLE bool changeDatabasePath(const QString &newPath);
    Q_INVOKABLE QString browseForDatabase();
    Q_INVOKABLE QString browseForNewDatabase();

    // Project management
    Q_INVOKABLE bool createProject(const QString &name, const QString &description,
                                    const QString &discipline,
                                    double centerY, double centerX, int srid = 4326);
    Q_INVOKABLE QVariantList getProjects(const QString &discipline = QString());
    Q_INVOKABLE QVariantList getRecentProjects(int limit = 5);
    Q_INVOKABLE bool loadProject(int projectId);
    Q_INVOKABLE bool deleteProject(int projectId);
    Q_INVOKABLE bool deleteProjects(const QVariantList &projectIds);
    Q_INVOKABLE bool updateProjectStatus(int projectId, const QString &status);
    Q_INVOKABLE bool updateProject(int projectId, const QString &name, const QString &description, double centerY, double centerX);
    Q_INVOKABLE int getPointCountForProject(int projectId);
    Q_INVOKABLE QString currentProject() const;
    Q_INVOKABLE QVariantMap currentProjectDetails() const;
    Q_INVOKABLE QString currentDiscipline() const;
    Q_INVOKABLE void setCurrentDiscipline(const QString &discipline);

    // Survey Points
    Q_INVOKABLE int addPoint(const QString &name, double x, double y, double z,
                              const QString &code = QString(), const QString &description = QString());
    Q_INVOKABLE bool updatePoint(int pointId, double x, double y, double z,
                                  const QString &code = QString(), const QString &description = QString());
    Q_INVOKABLE bool deletePoint(int pointId);
    Q_INVOKABLE QVariantList getPoints();
    Q_INVOKABLE QVariantMap getPoint(int pointId);
    Q_INVOKABLE QVariantList getPointsInBounds(double minX, double minY, double maxX, double maxY);

    // Personnel
    Q_INVOKABLE bool addPersonnel(const QString &name, const QString &role,
                                   const QString &status, const QString &phone = QString());
    Q_INVOKABLE bool updatePersonnel(int id, const QString &name, const QString &role,
                                      const QString &status, const QString &phone = QString());
    Q_INVOKABLE bool deletePersonnel(int id);
    Q_INVOKABLE QVariantList getPersonnel();

    // Instruments
    Q_INVOKABLE bool addInstrument(const QString &name, const QString &type,
                                    const QString &serial, const QString &status);
    Q_INVOKABLE bool updateInstrument(int id, const QString &name, const QString &type,
                                       const QString &serial, const QString &status);
    Q_INVOKABLE bool deleteInstrument(int id);
    Q_INVOKABLE QVariantList getInstruments();

    // Traverses
    Q_INVOKABLE int createTraverse(const QString &name, const QString &type);
    Q_INVOKABLE bool addTraverseObservation(int traverseId, int fromPointId, int toPointId,
                                             double horizontalAngle, double verticalAngle,
                                             double slopeDistance);
    Q_INVOKABLE QVariantList getTraverses();
    Q_INVOKABLE QVariantList getTraverseObservations(int traverseId);

    // Levelling
    Q_INVOKABLE int createLevelLine(const QString &name, const QString &description, double startRl, const QString &method);
    Q_INVOKABLE bool updateLevelLine(int id, const QString &name, const QString &description, double startRl, const QString &method, const QString &status);
    Q_INVOKABLE bool deleteLevelLine(int id);
    Q_INVOKABLE QVariantList getLevelLines();
    Q_INVOKABLE bool addLevelObservation(int lineId, const QString &station, double bs, double is, double fs,
                                          double rise, double fall, double hpc, double rl, const QString &remarks,
                                          double distance = 0.0, double adjRl = 0.0);
    Q_INVOKABLE bool updateLevelObservation(int id, const QString &station, double bs, double is, double fs,
                                             double rise, double fall, double hpc, double rl, const QString &remarks,
                                             double distance = 0.0, double adjRl = 0.0);
    Q_INVOKABLE bool deleteLevelObservation(int id);
    Q_INVOKABLE QVariantList getLevelObservations(int lineId);

    // Spatial queries (SpatiaLite specific)
    Q_INVOKABLE double calculateDistance(int pointId1, int pointId2);
    Q_INVOKABLE double calculateArea(const QVariantList &pointIds);
    Q_INVOKABLE QVariantList getPointsWithinRadius(double centerX, double centerY, double radiusMeters);

    // Export/Import
    Q_INVOKABLE bool exportToCSV(const QString &filePath);
    Q_INVOKABLE bool importFromCSV(const QString &filePath);
    
    // Database Backup/Restore
    Q_INVOKABLE bool createBackup(const QString &reason = QString());
    Q_INVOKABLE QString getBackupDirectory() const;
    Q_INVOKABLE QVariantList listBackups();
    Q_INVOKABLE bool restoreFromBackup(const QString &backupPath);
    Q_INVOKABLE bool deleteOldBackups(int keepCount = 10);

signals:
    void connectionChanged();
    void projectChanged();
    void disciplineChanged();
    void pointsChanged();
    void personnelChanged();
    void instrumentsChanged();
    void traversesChanged();
    void errorOccurred(const QString &error);
    void databasePathChanged();

private:
    bool initSpatialite();
    bool createTables();
    void runMigrations();
    bool executeSql(const QString &sql);
    QVariantList executeQuery(const QString &sql);

    QSqlDatabase m_db;
    QString m_dbPath;
    QString m_defaultDbPath;
    int m_currentProjectId;
    QString m_currentProjectName;
    QString m_currentDiscipline;
    bool m_spatialiteLoaded;

#ifdef WITH_SPATIALITE
    void *m_spatialiteCache;
#endif
};

#endif // DATABASEMANAGER_H
