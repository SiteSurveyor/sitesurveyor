#include "CoordinateTransformer.h"
#include <proj.h>
#include <QDebug>

CoordinateTransformer::CoordinateTransformer(QObject *parent)
    : QObject(parent)
{
    initializeSupportedCRS();
}

CoordinateTransformer::~CoordinateTransformer() = default;

void CoordinateTransformer::initializeSupportedCRS()
{
    m_supportedCRS = {
        {"WGS 84", 4326, "Geographic coordinates (latitude/longitude)"},
        {"Lo29 (Harare)", 22289, "Zimbabwe Transverse Mercator - Lo29"},
        {"Lo31 (Beitbridge)", 22291, "Zimbabwe Transverse Mercator - Lo31"},
        {"UTM Zone 35S", 32735, "Universal Transverse Mercator Zone 35 South"},
        {"UTM Zone 36S", 32736, "Universal Transverse Mercator Zone 36 South"}
    };
}

QVariantMap CoordinateTransformer::transform(double x, double y, double z,
                                            int fromEPSG, int toEPSG)
{
    QVariantMap result;
    result["success"] = false;
    
    if (!isValidEPSG(fromEPSG)) {
        result["error"] = QString("Invalid source EPSG code: %1").arg(fromEPSG);
        emit transformationFailed(result["error"].toString());
        return result;
    }
    
    if (!isValidEPSG(toEPSG)) {
        result["error"] = QString("Invalid target EPSG code: %1").arg(toEPSG);
        emit transformationFailed(result["error"].toString());
        return result;
    }
    
    // Create PROJ transformation context
    PJ_CONTEXT *ctx = proj_context_create();
    
    // Create transformation string
    QString fromCRS = QString("EPSG:%1").arg(fromEPSG);
    QString toCRS = QString("EPSG:%1").arg(toEPSG);
    
    PJ *P = proj_create_crs_to_crs(
        ctx,
        fromCRS.toUtf8().constData(),
        toCRS.toUtf8().constData(),
        nullptr
    );
    
    if (!P) {
        result["error"] = QString("Failed to create transformation from EPSG:%1 to EPSG:%2")
                         .arg(fromEPSG).arg(toEPSG);
        proj_context_destroy(ctx);
        emit transformationFailed(result["error"].toString());
        return result;
    }
    
    // Normalize for input/output (important for degree/radian handling)
    PJ *P_norm = proj_normalize_for_visualization(ctx, P);
    if (!P_norm) {
        result["error"] = "Failed to normalize transformation";
        proj_destroy(P);
        proj_context_destroy(ctx);
        emit transformationFailed(result["error"].toString());
        return result;
    }
    
    // Perform transformation
    PJ_COORD coord_in, coord_out;
    coord_in = proj_coord(x, y, z, 0);
    coord_out = proj_trans(P_norm, PJ_FWD, coord_in);
    
    // Check for transformation errors
    int err = proj_errno(P_norm);
    if (err) {
        result["error"] = QString("Transformation failed: %1").arg(proj_errno_string(err));
        proj_destroy(P_norm);
        proj_destroy(P);
        proj_context_destroy(ctx);
        emit transformationFailed(result["error"].toString());
        return result;
    }
    
    // Cleanup
    proj_destroy(P_norm);
    proj_destroy(P);
    proj_context_destroy(ctx);
    
    // Return results
    result["success"] = true;
    result["x"] = coord_out.xyz.x;
    result["y"] = coord_out.xyz.y;
    result["z"] = coord_out.xyz.z;
    
    qDebug() << "Transformed" << x << y << z 
             << "from EPSG:" << fromEPSG 
             << "to EPSG:" << toEPSG 
             << "→" << coord_out.xyz.x << coord_out.xyz.y << coord_out.xyz.z;
    
    return result;
}

QVariantMap CoordinateTransformer::lo29ToWgs84(double easting, double northing, double elevation)
{
    // Lo29: easting is Y, northing is X (negative for southern hemisphere)
    QVariantMap result = transform(easting, northing, elevation, 22289, 4326);
    
    if (result["success"].toBool()) {
        // Rename for clarity
        result["latitude"] = result["y"];
        result["longitude"] = result["x"];
        result["elevation"] = result["z"];
        result.remove("x");
        result.remove("y");
        result.remove("z");
    }
    
    return result;
}

QVariantMap CoordinateTransformer::wgs84ToLo29(double latitude, double longitude, double elevation)
{
    QVariantMap result = transform(longitude, latitude, elevation, 4326, 22289);
    
    if (result["success"].toBool()) {
        // Rename for clarity
        result["easting"] = result["x"];
        result["northing"] = result["y"];
        result["elevation"] = result["z"];
        result.remove("x");
        result.remove("y");
        result.remove("z");
    }
    
    return result;
}

QVariantList CoordinateTransformer::getSupportedCRS()
{
    QVariantList list;
    
    for (const CRSInfo &crs : m_supportedCRS) {
        QVariantMap item;
        item["name"] = crs.name;
        item["epsg"] = crs.epsg;
        item["description"] = crs.description;
        list.append(item);
    }
    
    return list;
}

bool CoordinateTransformer::isValidEPSG(int epsg)
{
    for (const CRSInfo &crs : m_supportedCRS) {
        if (crs.epsg == epsg) {
            return true;
        }
    }
    return false;
}
