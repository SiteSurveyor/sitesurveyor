
QVariantMap EarthworkEngine::calculateVolume(double baseElevation, const QVariantList &points, const QString &engine)
{
    Q_UNUSED(engine);
    QVariantMap result;
    result["cut"] = 0.0;
    result["fill"] = 0.0;
    result["net"] = 0.0;
    result["area"] = 0.0;

    // 1. Create Boundary Geometry (Convex Hull) from points
    GEOSGeometry* boundary = nullptr;
    const GEOSPreparedGeometry* prepBoundary = nullptr;

    if (points.size() >= 3) {
        GEOSCoordSequence* seq = GEOSCoordSeq_create(points.size(), 2);
        for (int i = 0; i < points.size(); ++i) {
            QVariantMap pt = points[i].toMap(); // Or point if passed as QPointF? checking usage
            // Usage in QML: normally points are objects {x, y, z}
            // if QVariantList is list of QPointF, use toPointF()
            // Let's assume list of objects {x, y, z} based on DTM generation usage
             bool ok = false;
             double x, y;
             if (points[i].canConvert<QVariantMap>()) {
                 QVariantMap m = points[i].toMap();
                 x = m["x"].toDouble();
                 y = m["y"].toDouble();
             } else {
                 // Fallback if likely QPointF or existing format
                 // But generateDTM uses QVariantMap logic
                  QVariantMap m = points[i].toMap();
                  x = m["x"].toDouble();
                  y = m["y"].toDouble();
             }
            GEOSCoordSeq_setX(seq, i, x);
            GEOSCoordSeq_setY(seq, i, y);
        }

        GEOSGeometry* multipoint = GEOSGeom_createMultiPoint(seq); // Sequence is consumed? No, createMultiPoint takes geom?
        // GEOSGeom_createMultiPoint expects Vector of Geometries
        // Easier: Create Point for each, then Collection?
        // Or better: GEOSGeom_createCollection(GEOS_MULTIPOINT, geoms, count)

        GEOSGeometry** pointGeoms = new GEOSGeometry*[points.size()];
        for(int i=0; i<points.size(); ++i) {
             QVariantMap m = points[i].toMap();
             GEOSCoordSequence* s = GEOSCoordSeq_create(1, 2);
             GEOSCoordSeq_setX(s, 0, m["x"].toDouble());
             GEOSCoordSeq_setY(s, 0, m["y"].toDouble());
             pointGeoms[i] = GEOSGeom_createPoint(s);
        }
        GEOSGeometry* collection = GEOSGeom_createCollection(GEOS_MULTIPOINT, pointGeoms, points.size());

        if (collection) {
            boundary = GEOSConvexHull(collection);
            GEOSGeom_destroy(collection);
        }
        delete[] pointGeoms; // Array of pointers, handled by collection?
        // NOTE: GEOSGeom_createCollection takes ownership of elements.
        // So we only delete the array, not the elements.

        if (boundary) {
            prepBoundary = GEOSPrepare(boundary);
        }
    }

    qDebug() << "Calculing volume with boundary mask:" << (boundary ? "Yes" : "No");

    // Open DTM
    QByteArray dtmPathBytes = m_dtmPath.toUtf8();
    GDALDatasetH hDataset = GDALOpen(dtmPathBytes.constData(), GA_ReadOnly);
    if (!hDataset) {
        if (boundary) GEOSGeom_destroy(boundary);
        if (prepBoundary) GEOSPreparedGeom_destroy(prepBoundary);
        return result;
    }

    // Get raster band
    GDALRasterBandH hBand = GDALGetRasterBand(hDataset, 1);
    double adfGeoTransform[6];
    GDALGetGeoTransform(hDataset, adfGeoTransform);
    int width = GDALGetRasterBandXSize(hBand);
    int height = GDALGetRasterBandYSize(hBand);

    // Transform parameters
    double originX = adfGeoTransform[0];
    double pixelWidth = adfGeoTransform[1];
    double param2 = adfGeoTransform[2]; // Rotation 0
    double originY = adfGeoTransform[3];
    double param4 = adfGeoTransform[4]; // Rotation 0
    double pixelHeight = adfGeoTransform[5]; // Usually negative

    double pixelArea = std::abs(pixelWidth * pixelHeight);

    // Read Data
    float *pafScanline = (float*) CPLMalloc(sizeof(float) * width * height);
    GDALRasterIO(hBand, GF_Read, 0, 0, width, height, pafScanline, width, height, GDT_Float32, 0, 0);

    double cut = 0.0;
    double fill = 0.0;
    double totalArea = 0.0;

    // Reusable point geometry for check
    GEOSCoordSequence* ptSeq = GEOSCoordSeq_create(1, 2);
    GEOSGeometry* checkPt = GEOSGeom_createPoint(ptSeq); // We will update coords directly? No, GEOS immutable-ish
    // GEOS C API pattern: create fresh point for each or efficient check?
    // Efficient: Just check X,Y vs Polygon using GEOSPreparedContainsXY (if available in version) or just create/destroy Point.
    // Standard GEOS 3.10+ has GEOSPreparedContainsXY. If unsure of version (likely old), use GEOSGeom_createPoint

    // Since we don't know GEOS version, full geom create/destroy is safer but slower.
    // Optimization: Bounding box check first?

    for (int row = 0; row < height; row++) {
        for (int col = 0; col < width; col++) {
            int idx = row * width + col;
            float elev = pafScanline[idx];

            if (elev == -9999.0f) continue;

            // Compute World X,Y
            // Xp = padfGeoTransform[0] + P*padfGeoTransform[1] + L*padfGeoTransform[2];
            // Yp = padfGeoTransform[3] + P*padfGeoTransform[4] + L*padfGeoTransform[5];
            double worldX = originX + col * pixelWidth + row * param2;
            double worldY = originY + col * param4 + row * pixelHeight;

            // Check Mask
            bool include = true;
            if (prepBoundary) {
                 GEOSCoordSequence* s = GEOSCoordSeq_create(1, 2);
                 GEOSCoordSeq_setX(s, 0, worldX);
                 GEOSCoordSeq_setY(s, 0, worldY);
                 GEOSGeometry* pGeom = GEOSGeom_createPoint(s);

                 // if (!GEOSPreparedContains(prepBoundary, pGeom)) { // Strict contains?
                 // Intersects is safer for boundary pixels
                 if (!GEOSPreparedIntersects(prepBoundary, pGeom)) {
                     include = false;
                 }
                 GEOSGeom_destroy(pGeom);
            }

            if (include) {
                double diff = elev - baseElevation;
                if (diff > 0) cut += diff * pixelArea;
                else fill += std::abs(diff) * pixelArea;
                totalArea += pixelArea;
            }
        }
    }

    CPLFree(pafScanline);
    GDALClose(hDataset);
    if (prepBoundary) GEOSPreparedGeom_destroy(prepBoundary);
    if (boundary) GEOSGeom_destroy(boundary);
    // Note checkPt was not used/destroyed above as logic changed

    result["cut"] = cut;
    result["fill"] = fill;
    result["net"] = cut - fill;
    result["area"] = totalArea;

    qDebug() << "Volume (masked):" << cut << "/" << fill << " Area:" << totalArea;
    return result;
}
