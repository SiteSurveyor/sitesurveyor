#ifndef VOLUMECALCULATOR_H
#define VOLUMECALCULATOR_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class TINProcessor;

/**
 * @brief Handles earthwork volume calculations
 * 
 * Provides functionality for:
 * - Grid-based volume calculation from DTM
 * - TIN-based prism method volume calculation
 * - Cut/fill analysis with boundary masking
 */
class VolumeCalculator : public QObject
{
    Q_OBJECT

public:
    explicit VolumeCalculator(QObject *parent = nullptr);
    ~VolumeCalculator();

    /**
     * @brief Calculate volume using grid-based method from DTM
     * @param dtmPath Path to DTM raster file
     * @param baseElevation Reference elevation for cut/fill
     * @param maskPoints Optional boundary polygon points for masking
     * @param errorOut Output parameter for error message
     * @return Map with cut, fill, net, area values
     */
    QVariantMap calculateGrid(const QString &dtmPath,
                              double baseElevation,
                              const QVariantList &maskPoints,
                              QString &errorOut);

    /**
     * @brief Calculate volume using TIN prism method
     * @param tinProcessor TIN processor with generated triangulation
     * @param baseElevation Reference elevation for cut/fill
     * @param boundaryPolygon Optional boundary polygon for clipping
     * @param errorOut Output parameter for error message
     * @return Map with cut, fill, net, area values
     */
    QVariantMap calculateTIN(TINProcessor *tinProcessor,
                            double baseElevation,
                            const QVariantList &boundaryPolygon,
                            QString &errorOut);

private:
    // Helper to create boundary geometry from points
    void* createBoundaryGeometry(const QVariantList &points, QString &errorOut);
};

#endif // VOLUMECALCULATOR_H
