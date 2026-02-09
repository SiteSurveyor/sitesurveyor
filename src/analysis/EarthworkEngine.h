#ifndef EARTHWORKENGINE_H
#define EARTHWORKENGINE_H

#include <QObject>
#include <QVariantList>
#include <QDebug>
#include <QScopedPointer>

// Forward declarations
class DTMGenerator;
class TINProcessor;
class VolumeCalculator;
class MeshExporter;

/**
 * @brief Facade for earthwork analysis operations
 * 
 * Coordinates DTM, TIN, volume, and mesh export components
 * Provides QML interface with error handling and progress feedback
 */
class EarthworkEngine : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString lastError READ lastError NOTIFY errorChanged)
    Q_PROPERTY(bool isProcessing READ isProcessing NOTIFY processingChanged)
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)

public:
    explicit EarthworkEngine(QObject *parent = nullptr);
    ~EarthworkEngine();

    // Q_INVOKABLE methods for QML
    Q_INVOKABLE void generateDTM(const QVariantList &points, double pixelSize);
    Q_INVOKABLE QVariantList generateContours(double interval);
    Q_INVOKABLE QVariantMap getDTMData();
    Q_INVOKABLE QVariantMap generate3DMesh(double verticalScale = 1.0);
    Q_INVOKABLE bool exportDTMasOBJ(const QString &filePath, double verticalScale = 1.5);
    Q_INVOKABLE bool openInQGIS(const QString &filePath);
    Q_INVOKABLE QVariantList createBuffer(const QVariantList &points, double distance);
    Q_INVOKABLE QVariantMap calculateVolume(double baseElevation, const QVariantList &points, const QString &engine = "gdal");
    
    // TIN-based methods
    Q_INVOKABLE QVariantMap generateTIN(const QVariantList &points);
    Q_INVOKABLE QVariantMap calculateVolumeTIN(double baseElevation, const QVariantList &boundaryPolygon = QVariantList());

    // Property getters
    QString lastError() const { return m_lastError; }
    bool isProcessing() const { return m_isProcessing; }
    int progress() const { return m_progress; }

signals:
    void errorOccurred(const QString &error);
    void errorChanged();
    void processingChanged();
    void progressChanged(int value);

private:
    void setError(const QString &error);
    void setProcessing(bool processing);
    void setProgress(int value);

    QString m_dtmPath;
    QString m_lastError;
    bool m_isProcessing;
    int m_progress;

    // Component instances
    QScopedPointer<DTMGenerator> m_dtmGenerator;
    QScopedPointer<TINProcessor> m_tinProcessor;
    QScopedPointer<VolumeCalculator> m_volumeCalculator;
    QScopedPointer<MeshExporter> m_meshExporter;
};

#endif // EARTHWORKENGINE_H
