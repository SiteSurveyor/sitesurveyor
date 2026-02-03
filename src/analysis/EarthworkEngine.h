#ifndef EARTHWORKENGINE_H
#define EARTHWORKENGINE_H

#include <QObject>
#include <QVariantList>
#include <QDebug>

class EarthworkEngine : public QObject
{
    Q_OBJECT
public:
    explicit EarthworkEngine(QObject *parent = nullptr);
    ~EarthworkEngine();

    Q_INVOKABLE void generateDTM(const QVariantList &points, double pixelSize);
    Q_INVOKABLE QVariantList generateContours(double interval);
    Q_INVOKABLE QVariantMap getDTMData();  // Returns DTM raster data for visualization
    Q_INVOKABLE QVariantMap generate3DMesh(double verticalScale = 1.0);  // Generate 3D mesh for terrain
    Q_INVOKABLE bool exportDTMasOBJ(const QString &filePath, double verticalScale = 1.5);  // Export DTM as OBJ file
    Q_INVOKABLE bool openInQGIS(const QString &filePath);  // Open DTM in QGIS
    Q_INVOKABLE QVariantList createBuffer(const QVariantList &points, double distance); // Generate buffered geometry using GEOS
    Q_INVOKABLE QVariantMap calculateVolume(double baseElevation, const QVariantList &points, const QString &engine = "gdal"); // Calculate Cut/Fill Volume masked by points

    // TIN-based methods
    Q_INVOKABLE QVariantMap generateTIN(const QVariantList &points); // Generate TIN from points (Delaunay triangulation)
    Q_INVOKABLE QVariantMap calculateVolumeTIN(double baseElevation, const QVariantList &boundaryPolygon = QVariantList()); // Calculate volume using TIN prism method

private:
    QString m_dtmPath;
    QVariantList m_tinVertices;    // Stored TIN vertices
    QVariantList m_tinTriangles;   // Stored TIN triangles (indices)
};

#endif // EARTHWORKENGINE_H
