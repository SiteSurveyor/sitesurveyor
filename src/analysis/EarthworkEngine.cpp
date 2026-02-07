#include "EarthworkEngine.h"
#include "DTMGenerator.h"
#include "TINProcessor.h"
#include "VolumeCalculator.h"
#include "MeshExporter.h"
#include <gdal_priv.h>
#include <proj.h>
#include <geos_c.h>
#include <QStandardPaths>
#include <QProcess>
#include <QFileInfo>
#include <QDebug>
#include <QUuid>

// GEOS Message Handlers
void geosNotice(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    char buf[1024];
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    qDebug() << "GEOS Notice:" << buf;
}

void geosError(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    char buf[1024];
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    qCritical() << "GEOS Error:" << buf;
}

EarthworkEngine::EarthworkEngine(QObject *parent) 
    : QObject(parent)
    , m_isProcessing(false)
    , m_progress(0)
    , m_dtmGenerator(new DTMGenerator(this))
    , m_tinProcessor(new TINProcessor(this))
    , m_volumeCalculator(new VolumeCalculator(this))
    , m_meshExporter(new MeshExporter(this))
{
    initGEOS(geosNotice, geosError);
    GDALAllRegister();
    QString tempDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    QString uuid = QUuid::createUuid().toString(QUuid::Id128);
    m_dtmPath = tempDir + QString("/dtm_%1.tif").arg(uuid);
    PJ_INFO info = proj_info();
    qDebug() << "EarthworkEngine initialized. GDAL:" << GDALVersionInfo("RELEASE_NAME")
             << "| PROJ:" << info.version
             << "| GEOS:" << GEOSversion();
}

EarthworkEngine::~EarthworkEngine()
{
    finishGEOS();
}

void EarthworkEngine::setError(const QString &error)
{
    m_lastError = error;
    emit errorChanged();
    emit errorOccurred(error);
}

void EarthworkEngine::setProcessing(bool processing)
{
    if (m_isProcessing != processing) {
        m_isProcessing = processing;
        emit processingChanged();
    }
}

void EarthworkEngine::setProgress(int value)
{
    if (m_progress != value) {
        m_progress = value;
        emit progressChanged(value);
    }
}

void EarthworkEngine::generateDTM(const QVariantList &points, double pixelSize)
{
    setProcessing(true);
    setProgress(0);

    QString error;
    bool success = m_dtmGenerator->generate(points, pixelSize, m_dtmPath, error,
        [this](int prog) {
            setProgress(prog);
        });

    setProcessing(false);

    if (!success) {
        setError(error);
        qWarning() << "DTM generation failed:" << error;
    } else {
        setProgress(100);
    }
}

QVariantList EarthworkEngine::generateContours(double interval)
{
    QString error;
    QVariantList contours = m_dtmGenerator->generateContours(m_dtmPath, interval, error);
    
    if (contours.isEmpty() && !error.isEmpty()) {
        setError(error);
    }
    
    return contours;
}

QVariantMap EarthworkEngine::getDTMData()
{
    QString error;
    QVariantMap data = m_dtmGenerator->getData(m_dtmPath, error);
    
    if (data.isEmpty() && !error.isEmpty()) {
        setError(error);
    }
    
    return data;
}

QVariantMap EarthworkEngine::generate3DMesh(double verticalScale)
{
    QString error;
    QVariantMap dtmData = m_dtmGenerator->getData(m_dtmPath, error);
    
    if (dtmData.isEmpty()) {
        setError(error.isEmpty() ? "DTM data not available" : error);
        return QVariantMap();
    }
    
    QVariantMap mesh = m_meshExporter->generate3DMesh(dtmData, verticalScale, error);
    
    if (mesh.isEmpty() && !error.isEmpty()) {
        setError(error);
    }
    
    return mesh;
}

bool EarthworkEngine::exportDTMasOBJ(const QString &filePath, double verticalScale)
{
    QString error;
    QVariantMap dtmData = m_dtmGenerator->getData(m_dtmPath, error);
    
    if (dtmData.isEmpty()) {
        setError(error.isEmpty() ? "DTM data not available" : error);
        return false;
    }
    
    bool success = m_meshExporter->exportAsOBJ(dtmData, filePath, verticalScale, error);
    
    if (!success) {
        setError(error);
    }
    
    return success;
}

bool EarthworkEngine::openInQGIS(const QString &filePath)
{
    if (filePath.isEmpty()) {
        setError("No file path provided for QGIS");
        return false;
    }

    QFileInfo fileInfo(filePath);
    if (!fileInfo.exists()) {
        setError(QString("File does not exist: %1").arg(filePath));
        return false;
    }

    qDebug() << "Launching QGIS with:" << filePath;

    QProcess *process = new QProcess(this);
    process->setProgram("qgis");
    process->setArguments({filePath});

    bool started = process->startDetached();

    if (!started) {
        setError("Failed to launch QGIS - make sure QGIS is installed");
        return false;
    }

    return true;
}

QVariantList EarthworkEngine::createBuffer(const QVariantList &points, double distance)
{
    QVariantList result;
    if (points.size() < 3) return result;

    // Convert QVariantList to GEOS Coordinates
    GEOSCoordSequence* seq = GEOSCoordSeq_create(points.size() + 1, 2);

    for (int i = 0; i < points.size(); ++i) {
        QPointF p = points[i].toPointF();
        GEOSCoordSeq_setX(seq, i, p.x());
        GEOSCoordSeq_setY(seq, i, p.y());
    }
    
    // Close the ring
    QPointF p0 = points[0].toPointF();
    GEOSCoordSeq_setX(seq, points.size(), p0.x());
    GEOSCoordSeq_setY(seq, points.size(), p0.y());

    // Create Polygon
    GEOSGeometry* ring = GEOSGeom_createLinearRing(seq);
    if (!ring) {
        setError("Failed to create GEOS linear ring");
        GEOSCoordSeq_destroy(seq);
        return result;
    }

    GEOSGeometry* poly = GEOSGeom_createPolygon(ring, nullptr, 0);
    if (!poly) {
        setError("Failed to create GEOS polygon");
        return result;
    }

    // Create Buffer
    GEOSGeometry* buffered = GEOSBuffer(poly, distance, 8);

    if (buffered) {
        const GEOSGeometry* rawResult = buffered;
        if (GEOSGeomTypeId(buffered) == GEOS_MULTIPOLYGON) {
            rawResult = GEOSGetGeometryN(buffered, 0);
        }

        const GEOSGeometry* shell = GEOSGetExteriorRing(rawResult);
        if (shell) {
            const GEOSCoordSequence* resSeq = GEOSGeom_getCoordSeq(shell);
            unsigned int size;
            GEOSCoordSeq_getSize(resSeq, &size);

            for (unsigned int i = 0; i < size; ++i) {
                double x, y;
                GEOSCoordSeq_getX(resSeq, i, &x);
                GEOSCoordSeq_getY(resSeq, i, &y);
                result.append(QPointF(x, y));
            }
        }
        GEOSGeom_destroy(buffered);
    }

    GEOSGeom_destroy(poly);
    return result;
}

QVariantMap EarthworkEngine::calculateVolume(double baseElevation, const QVariantList &points, const QString &engine)
{
    Q_UNUSED(engine);
    
    QString error;
    QVariantMap result = m_volumeCalculator->calculateGrid(m_dtmPath, baseElevation, points, error);
    
    if (result["area"].toDouble() == 0.0 && !error.isEmpty()) {
        setError(error);
    }
    
    return result;
}

QVariantMap EarthworkEngine::generateTIN(const QVariantList &points)
{
    QString error;
    QVariantMap result = m_tinProcessor->generate(points, error);
    
    if (!result["success"].toBool() && !error.isEmpty()) {
        setError(error);
    }
    
    return result;
}

QVariantMap EarthworkEngine::calculateVolumeTIN(double baseElevation, const QVariantList &boundaryPolygon)
{
    QString error;
    QVariantMap result = m_volumeCalculator->calculateTIN(m_tinProcessor.data(), 
                                                           baseElevation, 
                                                           boundaryPolygon, 
                                                           error);
    
    if (result["area"].toDouble() == 0.0 && !error.isEmpty()) {
        setError(error);
    }
    
    return result;
}
