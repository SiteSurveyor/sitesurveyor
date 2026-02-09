#ifndef DTMGENERATOR_H
#define DTMGENERATOR_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <functional>

/**
 * @brief Handles Digital Terrain Model generation and operations
 * 
 * Provides functionality for:
 * - Generating DTM from point clouds using GDAL Grid interpolation
 * - Retrieving DTM raster data for visualization
 * - Generating contour lines at specified intervals
 */
class DTMGenerator : public QObject
{
    Q_OBJECT

public:
    using ProgressCallback = std::function<void(int)>;

    explicit DTMGenerator(QObject *parent = nullptr);
    ~DTMGenerator();

    /**
     * @brief Generate DTM from survey points
     * @param points List of point maps with x, y, z keys
     * @param pixelSize Grid resolution in ground units
     * @param outputPath Path where DTM will be saved
     * @param errorOut Output parameter for error message
     * @param progressCallback Optional callback for progress updates (0-100)
     * @return true on success, false on failure
     */
    bool generate(const QVariantList &points, 
                  double pixelSize,
                  const QString &outputPath,
                  QString &errorOut,
                  ProgressCallback progressCallback = nullptr);

    /**
     * @brief Get DTM raster data for visualization
     * @param dtmPath Path to DTM file
     * @param errorOut Output parameter for error message
     * @return Map containing width, height, data, minElev, maxElev, geotransform params
     */
    QVariantMap getData(const QString &dtmPath, QString &errorOut);

    /**
     * @brief Generate contour lines from DTM
     * @param dtmPath Path to DTM file
     * @param interval Contour interval in elevation units
     * @param errorOut Output parameter for error message
     * @return List of contour line maps with elevation and points
     */
    QVariantList generateContours(const QString &dtmPath, 
                                   double interval,
                                   QString &errorOut);

private:
    bool createVRTFile(const QString &csvPath, const QString &vrtPath, QString &errorOut);
    bool validatePoints(const QVariantList &points, QString &errorOut);
};

#endif // DTMGENERATOR_H
