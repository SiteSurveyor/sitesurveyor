#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include <QStandardPaths>
#include <QDir>
#include <QSettings>

#include "database/DatabaseManager.h"
#include "cloud/CloudSyncManager.h"

#include "analysis/EarthworkEngine.h"
#include "utilities/CoordinateTransformer.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("SiteSurveyor");
    app.setOrganizationName("Geomatics");

    // Initialize database manager
    DatabaseManager dbManager;

    // Load saved database path from settings, or use default
    QSettings settings;
    QString defaultDataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(defaultDataPath);
    QString defaultDbPath = defaultDataPath + "/sitesurveyor.db";

    QString dbPath = settings.value("database/path", defaultDbPath).toString();
    if (dbPath.isEmpty()) {
        dbPath = defaultDbPath;
    }

    // Store the default path for reference
    dbManager.setDefaultDatabasePath(defaultDbPath);

    // Open database
    if (!dbManager.openDatabase(dbPath)) {
        qWarning() << "Failed to open database at:" << dbPath;
        // Try default path as fallback
        if (dbPath != defaultDbPath && dbManager.openDatabase(defaultDbPath)) {
            qDebug() << "Opened default database at:" << defaultDbPath;
            settings.setValue("database/path", defaultDbPath);
        }
    } else {
        qDebug() << "Database opened at:" << dbPath;
    }

    qputenv("QML_XHR_ALLOW_FILE_READ", "1");
    // Initialize backend objects before engine to ensure proper destruction order
    EarthworkEngine earthwork;
    CoordinateTransformer coordTransform;
    CloudSyncManager cloudSync(&dbManager);

    QQmlApplicationEngine engine;

    // Expose objects to QML
    engine.rootContext()->setContextProperty("Database", &dbManager);
    engine.rootContext()->setContextProperty("Earthwork", &earthwork);
    engine.rootContext()->setContextProperty("CoordTransform", &coordTransform);
    engine.rootContext()->setContextProperty("CloudSync", &cloudSync);

    const QUrl url(QStringLiteral("qrc:/qml/Main.qml"));

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    engine.load(url);

    return app.exec();
}
