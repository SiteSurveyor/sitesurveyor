#ifndef COORDINATETRANSFORMER_H
#define COORDINATETRANSFORMER_H

#include <QObject>
#include <QString>
#include <QVariantMap>

/**
 * @brief Utility for coordinate transformations between different CRS
 * 
 * Supports transformations between:
 * - Lo29 (EPSG:22289) - Zimbabwe Transverse Mercator
 * - WGS84 (EPSG:4326) - Geographic coordinates
 * - UTM zones
 * 
 * Uses PROJ library for accurate transformations
 */
class CoordinateTransformer : public QObject
{
    Q_OBJECT
    
public:
    explicit CoordinateTransformer(QObject *parent = nullptr);
    ~CoordinateTransformer();
    
    /**
     * @brief Transform coordinates from one CRS to another
     * @param x X coordinate (or longitude)
     * @param y Y coordinate (or latitude)
     * @param z Z coordinate (elevation)
     * @param fromEPSG Source EPSG code
     * @param toEPSG Target EPSG code
     * @return Map with transformed coordinates {x, y, z, success, error}
     */
    Q_INVOKABLE QVariantMap transform(double x, double y, double z,
                                      int fromEPSG, int toEPSG);
    
    /**
     * @brief Convert Lo29 to WGS84
     * @param easting Lo29 easting (Y)
     * @param northing Lo29 northing (X, negative for southern hemisphere)
     * @param elevation Elevation
     * @return Map with {latitude, longitude, elevation, success, error}
     */
    Q_INVOKABLE QVariantMap lo29ToWgs84(double easting, double northing, double elevation = 0.0);
    
    /**
     * @brief Convert WGS84 to Lo29
     * @param latitude Latitude in decimal degrees
     * @param longitude Longitude in decimal degrees
     * @param elevation Elevation
     * @return Map with {easting, northing, elevation, success, error}
     */
    Q_INVOKABLE QVariantMap wgs84ToLo29(double latitude, double longitude, double elevation = 0.0);
    
    /**
     * @brief Get list of supported coordinate systems
     * @return List of CRS with name and EPSG code
     */
    Q_INVOKABLE QVariantList getSupportedCRS();
    
    /**
     * @brief Validate EPSG code
     * @param epsg EPSG code to validate
     * @return true if valid and supported
     */
    Q_INVOKABLE bool isValidEPSG(int epsg);
    
signals:
    void transformationFailed(const QString &error);
    
private:
    struct CRSInfo {
        QString name;
        int epsg;
        QString description;
    };
    
    QList<CRSInfo> m_supportedCRS;
    void initializeSupportedCRS();
};

#endif // COORDINATETRANSFORMER_H
