#ifndef MESHEXPORTER_H
#define MESHEXPORTER_H

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QVector3D>

/**
 * @brief Handles 3D mesh generation and export from DTM data
 * 
 * Provides functionality for:
 * - Generating 3D mesh with vertices, normals, colors, indices
 * - Exporting DTM as Wavefront OBJ format
 * - Elevation-based color mapping
 */
class MeshExporter : public QObject
{
    Q_OBJECT

public:
    explicit MeshExporter(QObject *parent = nullptr);
    ~MeshExporter();

    /**
     * @brief Generate 3D mesh from DTM data
     * @param dtmData Map containing width, height, data, minElev, maxElev, pixel sizes
     * @param verticalScale Vertical exaggeration factor
     * @param errorOut Output parameter for error message
     * @return Map with vertices, normals, colors, indices arrays
     */
    QVariantMap generate3DMesh(const QVariantMap &dtmData,
                              double verticalScale,
                              QString &errorOut);

    /**
     * @brief Export DTM as Wavefront OBJ file
     * @param dtmData Map containing DTM raster data
     * @param filePath Output OBJ file path
     * @param verticalScale Vertical exaggeration factor
     * @param errorOut Output parameter for error message
     * @return true on success, false on failure
     */
    bool exportAsOBJ(const QVariantMap &dtmData,
                    const QString &filePath,
                    double verticalScale,
                    QString &errorOut);

private:
    // Helper to calculate elevation-based color
    QVector3D getElevationColor(float elevation, float minElev, float maxElev);
};

#endif // MESHEXPORTER_H
