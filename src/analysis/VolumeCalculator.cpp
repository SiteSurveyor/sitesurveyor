#include "VolumeCalculator.h"
#include "TINProcessor.h"
#include "GDALHelpers.h"
#include <gdal_priv.h>
#include <geos_c.h>
#include <QDebug>
#include <cmath>

using namespace GDALHelpers;

VolumeCalculator::VolumeCalculator(QObject *parent)
    : QObject(parent)
{
}

VolumeCalculator::~VolumeCalculator() = default;

void* VolumeCalculator::createBoundaryGeometry(const QVariantList &points, QString &errorOut)
{
    if (points.size() < 3) {
        return nullptr;
    }

    GEOSGeometry** pointGeoms = new GEOSGeometry*[points.size()];
    for (int i = 0; i < points.size(); ++i) {
        QVariantMap m = points[i].toMap();
        GEOSCoordSequence* s = GEOSCoordSeq_create(1, 2);
        GEOSCoordSeq_setX(s, 0, m["x"].toDouble());
        GEOSCoordSeq_setY(s, 0, m["y"].toDouble());
        pointGeoms[i] = GEOSGeom_createPoint(s);
    }

    GEOSGeometry* collection = GEOSGeom_createCollection(GEOS_MULTIPOINT, pointGeoms, points.size());
    delete[] pointGeoms;

    if (!collection) {
        errorOut = "Failed to create point collection for boundary";
        return nullptr;
    }

    GEOSGeometry* hull = GEOSConvexHull(collection);
    GEOSGeom_destroy(collection);

    return hull;
}

QVariantMap VolumeCalculator::calculateGrid(const QString &dtmPath,
                                           double baseElevation,
                                           const QVariantList &maskPoints,
                                           QString &errorOut)
{
    QVariantMap result;
    result["cut"] = 0.0;
    result["fill"] = 0.0;
    result["net"] = 0.0;
    result["area"] = 0.0;

    // Create boundary geometry if mask points provided
    GeometryGuard boundary;
    const GEOSPreparedGeometry* prepBoundaryPtr = nullptr;

    if (maskPoints.size() >= 3) {
        GEOSGeometry* boundaryGeom = static_cast<GEOSGeometry*>(createBoundaryGeometry(maskPoints, errorOut));
        if (boundaryGeom) {
            boundary = GeometryGuard(boundaryGeom);
            prepBoundaryPtr = GEOSPrepare(boundaryGeom);
        }
    }
    PreparedGeometryGuard prepBoundary(prepBoundaryPtr);

    qDebug() << "Calculating volume with boundary mask:" << (boundary ? "Yes" : "No");

    // Open DTM
    DatasetGuard dataset(GDALOpen(dtmPath.toUtf8().constData(), GA_ReadOnly));
    if (!dataset) {
        errorOut = QString("Failed to open DTM for volume calculation: %1").arg(dtmPath);
        return result;
    }

    // Get raster band
    GDALRasterBandH hBand = GDALGetRasterBand(dataset.get(), 1);
    if (!hBand) {
        errorOut = "Failed to get raster band for volume calculation";
        return result;
    }

    double adfGeoTransform[6];
    if (GDALGetGeoTransform(dataset.get(), adfGeoTransform) != CE_None) {
        errorOut = "Failed to get geotransform from DTM";
        return result;
    }

    int width = GDALGetRasterBandXSize(hBand);
    int height = GDALGetRasterBandYSize(hBand);

    // Transform parameters
    double originX = adfGeoTransform[0];
    double pixelWidth = adfGeoTransform[1];
    double param2 = adfGeoTransform[2];
    double originY = adfGeoTransform[3];
    double param4 = adfGeoTransform[4];
    double pixelHeight = adfGeoTransform[5];

    double pixelArea = std::abs(pixelWidth * pixelHeight);

    // Read raster data
    CPLMemoryGuard<float> scanline((float*)CPLMalloc(sizeof(float) * width * height));
    if (!scanline) {
        errorOut = "Failed to allocate memory for DTM data";
        return result;
    }

    if (GDALRasterIO(hBand, GF_Read, 0, 0, width, height,
                     scanline.get(), width, height, GDT_Float32, 0, 0) != CE_None) {
        errorOut = "Failed to read DTM raster data";
        return result;
    }

    double cut = 0.0;
    double fill = 0.0;
    double totalArea = 0.0;

    for (int row = 0; row < height; row++) {
        for (int col = 0; col < width; col++) {
            int idx = row * width + col;
            float elev = scanline[idx];

            if (elev == -9999.0f) continue; // Skip nodata

            // Compute world coordinates
            double worldX = originX + col * pixelWidth + row * param2;
            double worldY = originY + col * param4 + row * pixelHeight;

            // Check if point is inside boundary mask
            bool include = true;
            if (prepBoundary) {
                GEOSCoordSequence* s = GEOSCoordSeq_create(1, 2);
                GEOSCoordSeq_setX(s, 0, worldX);
                GEOSCoordSeq_setY(s, 0, worldY);
                GeometryGuard pGeom(GEOSGeom_createPoint(s));

                if (!GEOSPreparedIntersects(prepBoundary.get(), pGeom.get())) {
                    include = false;
                }
            }

            if (include) {
                double diff = elev - baseElevation;
                if (diff > 0) {
                    cut += diff * pixelArea;
                } else {
                    fill += std::abs(diff) * pixelArea;
                }
                totalArea += pixelArea;
            }
        }
    }

    result["cut"] = cut;
    result["fill"] = fill;
    result["net"] = cut - fill;
    result["area"] = totalArea;

    qDebug() << "Volume (grid-based): Cut=" << cut << "Fill=" << fill << "Area=" << totalArea;

    return result;
}

QVariantMap VolumeCalculator::calculateTIN(TINProcessor *tinProcessor,
                                          double baseElevation,
                                          const QVariantList &boundaryPolygon,
                                          QString &errorOut)
{
    QVariantMap result;
    result["cut"] = 0.0;
    result["fill"] = 0.0;
    result["net"] = 0.0;
    result["area"] = 0.0;
    result["method"] = "TIN";

    if (!tinProcessor) {
        errorOut = "TIN processor is null";
        return result;
    }

    if (!tinProcessor->hasData()) {
        errorOut = "TIN not generated. Call generateTIN first.";
        return result;
    }

    QVariantList vertices = tinProcessor->getVertices();
    QVariantList triangles = tinProcessor->getTriangles();

    // Create boundary geometry if provided
    GeometryGuard boundary;
    const GEOSPreparedGeometry* prepBoundaryPtr = nullptr;

    if (boundaryPolygon.size() >= 3) {
        GEOSCoordSequence* seq = GEOSCoordSeq_create(boundaryPolygon.size() + 1, 2);
        for (int i = 0; i < boundaryPolygon.size(); ++i) {
            QVariantMap pt = boundaryPolygon[i].toMap();
            GEOSCoordSeq_setX(seq, i, pt["x"].toDouble());
            GEOSCoordSeq_setY(seq, i, pt["y"].toDouble());
        }
        // Close the ring
        QVariantMap first = boundaryPolygon[0].toMap();
        GEOSCoordSeq_setX(seq, boundaryPolygon.size(), first["x"].toDouble());
        GEOSCoordSeq_setY(seq, boundaryPolygon.size(), first["y"].toDouble());

        GEOSGeometry* ring = GEOSGeom_createLinearRing(seq);
        if (ring) {
            GEOSGeometry* poly = GEOSGeom_createPolygon(ring, nullptr, 0);
            if (poly) {
                boundary = GeometryGuard(poly);
                prepBoundaryPtr = GEOSPrepare(poly);
            }
        }
    }
    PreparedGeometryGuard prepBoundary(prepBoundaryPtr);

    qDebug() << "Calculating TIN volume with" << triangles.size() / 3 << "triangles, base:" << baseElevation;

    double cut = 0.0;
    double fill = 0.0;
    double totalArea = 0.0;

    // Process each triangle (stride of 3)
    for (int t = 0; t < triangles.size(); t += 3) {
        if (t + 2 >= triangles.size()) break;

        int i0 = triangles[t].toInt();
        int i1 = triangles[t + 1].toInt();
        int i2 = triangles[t + 2].toInt();

        if (i0 >= vertices.size() || i1 >= vertices.size() || i2 >= vertices.size()) {
            continue;
        }

        QVariantMap v0 = vertices[i0].toMap();
        QVariantMap v1 = vertices[i1].toMap();
        QVariantMap v2 = vertices[i2].toMap();

        double x0 = v0["x"].toDouble(), y0 = v0["y"].toDouble(), z0 = v0["z"].toDouble();
        double x1 = v1["x"].toDouble(), y1 = v1["y"].toDouble(), z1 = v1["z"].toDouble();
        double x2 = v2["x"].toDouble(), y2 = v2["y"].toDouble(), z2 = v2["z"].toDouble();

        // Check if triangle centroid is inside boundary
        if (prepBoundary) {
            double cx = (x0 + x1 + x2) / 3.0;
            double cy = (y0 + y1 + y2) / 3.0;

            GEOSCoordSequence* ps = GEOSCoordSeq_create(1, 2);
            GEOSCoordSeq_setX(ps, 0, cx);
            GEOSCoordSeq_setY(ps, 0, cy);
            GeometryGuard pt(GEOSGeom_createPoint(ps));

            if (!GEOSPreparedIntersects(prepBoundary.get(), pt.get())) {
                continue; // Skip triangles outside boundary
            }
        }

        // Calculate triangle area using cross product
        double ax = x1 - x0, ay = y1 - y0;
        double bx = x2 - x0, by = y2 - y0;
        double area = std::abs(ax * by - ay * bx) / 2.0;

        // Average elevation of triangle
        double avgElev = (z0 + z1 + z2) / 3.0;

        // Prism volume = area × height difference
        double heightDiff = avgElev - baseElevation;
        double prismVolume = area * std::abs(heightDiff);

        if (heightDiff > 0) {
            cut += prismVolume;
        } else {
            fill += prismVolume;
        }

        totalArea += area;
    }

    result["cut"] = cut;
    result["fill"] = fill;
    result["net"] = cut - fill;
    result["area"] = totalArea;

    qDebug() << "TIN Volume: Cut=" << cut << "Fill=" << fill << "Area=" << totalArea;

    return result;
}
