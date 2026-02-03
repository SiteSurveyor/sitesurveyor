#include "EarthworkEngine.h"
#include <gdal_priv.h>
#include <gdal_utils.h>
#include <gdal.h>
#include <ogr_spatialref.h>
#include <gdal_alg.h>
#include <proj.h>
#include <geos_c.h>
#include <cmath>
#include <QDir>
#include <QStandardPaths>
#include <QFile>
#include <QTextStream>
#include <QVector3D>
#include <QProcess>
#include <QFileInfo>

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

EarthworkEngine::EarthworkEngine(QObject *parent) : QObject(parent)
{
    initGEOS(geosNotice, geosError);
    GDALAllRegister();
    QString tempDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    m_dtmPath = tempDir + "/dtm.tif";
    PJ_INFO info = proj_info();
    qDebug() << "EarthworkEngine initialized. GDAL:" << GDALVersionInfo("RELEASE_NAME")
             << "| PROJ:" << info.version
             << "| GEOS:" << GEOSversion();
}

EarthworkEngine::~EarthworkEngine()
{
    finishGEOS();
}

void EarthworkEngine::generateDTM(const QVariantList &points, double pixelSize)
{
    if (points.isEmpty()) {
        qWarning() << "Cannot generate DTM: No points provided. Please import CSV data first.";
        return;
    }

    qDebug() << "Generating DTM with " << points.size() << " points";

    // 1. Create a temporary CSV file for the points (GDALGrid can ingest CSV)
    // Format: X,Y,Z
    QString tempCsvPath = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/points.csv";
    QFile csvFile(tempCsvPath);
    if (csvFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&csvFile);
        out << "X,Y,Z\n"; // Header

        double minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;

        for (const QVariant &v : points) {
            QVariantMap pt = v.toMap();
            double x = pt["x"].toDouble();
            double y = pt["y"].toDouble();
            double z = pt["z"].toDouble();

            out << QString::number(x, 'f', 6) << ","
                << QString::number(y, 'f', 6) << ","
                << QString::number(z, 'f', 6) << "\n";

            if(x < minX) minX = x;
            if(x > maxX) maxX = x;
            if(y < minY) minY = y;
            if(y > maxY) maxY = y;
        }
        csvFile.close();

        // Add margin
        double margin = 5.0;
        minX -= margin; maxX += margin;
        minY -= margin; maxY += margin;

        // 2. Configure GDAL Grid options
        // Store QByteArray to keep data alive during GDAL operations
        QByteArray outputPathBytes = m_dtmPath.toUtf8();
        const char *pszOutput = outputPathBytes.constData();

        // Input VRT (virtual dataset for CSV) to define geometry columns
        QString vrtPath = tempCsvPath + ".vrt";
        QFile vrtFile(vrtPath);
        if(vrtFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream vout(&vrtFile);
            vout << "<OGRVRTDataSource>\n"
                 << "    <OGRVRTLayer name=\"points\">\n"
                 << "        <SrcDataSource>" << tempCsvPath << "</SrcDataSource>\n"
                 << "        <GeometryType>wkbPoint</GeometryType>\n"
                 << "        <GeometryField encoding=\"PointFromColumns\" x=\"X\" y=\"Y\" z=\"Z\"/>\n"
                 << "    </OGRVRTLayer>\n"
                 << "</OGRVRTDataSource>\n";
            vrtFile.close();
        }

        // Open Source
        QByteArray vrtPathBytes = vrtPath.toUtf8();
        GDALDatasetH hSrcDS = GDALOpenEx(vrtPathBytes.constData(), GDAL_OF_VECTOR, nullptr, nullptr, nullptr);
        if(!hSrcDS) {
            qWarning() << "Failed to open point source for DTM generation";
            return;
        }

        // Grid Options
        // We use Inverse Distance Weighting as default
        // Format: GTiff
        // Size: Calculated
        int nXSize = (int)((maxX - minX) / pixelSize);
        int nYSize = (int)((maxY - minY) / pixelSize);
        if (nXSize <= 0) nXSize = 1;
        if (nYSize <= 0) nYSize = 1;

        QString outSizeOps = QString("-outsize %1 %2").arg(nXSize).arg(nYSize);
        QString txeOps = QString("-txe %1 %2").arg(minX).arg(maxX);
        QString tyeOps = QString("-tye %1 %2").arg(minY).arg(maxY); // MinY MaxY? standard is min max
        QString formatOps = "-of GTiff";
        QString algoOps = "-a invdist:power=2.0:smoothing=1.0:radius1=0.0:radius2=0.0:angle=0.0:max_points=0:min_points=0:nodata=-9999";
        QString zField = "-zfield Z";

        // Construc argv list
        // Note: C API expects char* array
        std::vector<char*> args;
        args.push_back(strdup("-outsize")); args.push_back(strdup(QString::number(nXSize).toUtf8().data())); args.push_back(strdup(QString::number(nYSize).toUtf8().data()));
        args.push_back(strdup("-txe")); args.push_back(strdup(QString::number(minX, 'f', 6).toUtf8().data())); args.push_back(strdup(QString::number(maxX, 'f', 6).toUtf8().data()));
        args.push_back(strdup("-tye")); args.push_back(strdup(QString::number(minY, 'f', 6).toUtf8().data())); args.push_back(strdup(QString::number(maxY, 'f', 6).toUtf8().data()));
        args.push_back(strdup("-of")); args.push_back(strdup("GTiff"));
        args.push_back(strdup("-a")); args.push_back(strdup("invdist:power=2.0:smoothing=1.0:nodata=-9999"));
        args.push_back(strdup("-zfield")); args.push_back(strdup("Z"));
        args.push_back(nullptr);

        GDALGridOptions *psOptions = GDALGridOptionsNew(args.data(), nullptr);
        if (psOptions) {
            GDALDatasetH hDstDS = GDALGrid(pszOutput, hSrcDS, psOptions, nullptr);
            if (hDstDS) {
                GDALClose(hDstDS);
                qDebug() << "DTM Generated successfully at:" << m_dtmPath;
            } else {
                qWarning() << "GDALGrid failed.";
            }
            GDALGridOptionsFree(psOptions);
        }

        GDALClose(hSrcDS);
        // Free args
         for(size_t k=0; k<args.size()-1; ++k) free(args[k]);
    }
}

QVariantList EarthworkEngine::generateContours(double interval)
{
    qDebug() << "Generating Contours with interval:" << interval;
    QVariantList results;

    // Open DTM
    GDALDatasetH hSrcDS = GDALOpen(m_dtmPath.toUtf8().constData(), GA_ReadOnly);
    if (!hSrcDS) {
         qWarning() << "Failed to open DTM for contours. Please generate DTM first (Earthwork -> Generate DTM).";
         qWarning() << "Expected DTM path:" << m_dtmPath;
         return results;
    }

    GDALRasterBandH hBand = GDALGetRasterBand(hSrcDS, 1);

    // Create memory datasource for contours
    GDALDriverH hDriver = GDALGetDriverByName("Memory");
    GDALDatasetH hDstDS = GDALCreate(hDriver, "", 0, 0, 0, GDT_Unknown, nullptr);

    // We need OGR datasource actually for contours
    // "Memory" driver in OGR
    OGRSFDriverH hOgrDriver = OGRGetDriverByName("Memory");
    OGRDataSourceH hOgrDS = OGR_Dr_CreateDataSource(hOgrDriver, "contour_mem", nullptr);

    OGRSpatialReferenceH hSRS = nullptr; // TODO set from DTM if available
    OGRLayerH hLayer = OGR_DS_CreateLayer(hOgrDS, "contours", hSRS, wkbLineString, nullptr);

    OGRFieldDefnH hFieldDefn = OGR_Fld_Create("Elevation", OFTReal);
    OGR_L_CreateField(hLayer, hFieldDefn, TRUE);
    OGR_Fld_Destroy(hFieldDefn);

    // Generate
    // GDALContourGenerate(hBand, interval, 0.0, 0, nullptr, FALSE, 0.0, hLayer, 0, 1, nullptr, nullptr);
    // Note: Parameter list might vary by version.
    // double contourInterval, double contourBase, int nFixedLevelCount, double *padfFixedLevels, int bUseNoData, double dfNoDataValue, OGRLayerH hLayer, int iIDField, int iElevField

    CPLErr err = GDALContourGenerate(hBand, interval, 0.0, 0, nullptr, FALSE, -9999.0, hLayer, -1, 0, nullptr, nullptr);

    if (err == CE_None) {
        // Read features back to QVariantList
        OGR_L_ResetReading(hLayer);
        OGRFeatureH hFeat;
        while( (hFeat = OGR_L_GetNextFeature(hLayer)) != nullptr ) {
            double elev = OGR_F_GetFieldAsDouble(hFeat, 0);
            OGRGeometryH hGeom = OGR_F_GetGeometryRef(hFeat);

            if (hGeom != nullptr && wkbFlatten(OGR_G_GetGeometryType(hGeom)) == wkbLineString) {
                QVariantList linePoints;
                int pointCount = OGR_G_GetPointCount(hGeom);
                for(int i=0; i<pointCount; ++i) {
                     double x = OGR_G_GetX(hGeom, i);
                     double y = OGR_G_GetY(hGeom, i);
                     QVariantMap pt;
                     pt["x"] = x; pt["y"] = y;
                     linePoints.append(pt);
                }

                QVariantMap contourLine;
                contourLine["elevation"] = elev;
                contourLine["points"] = linePoints;
                results.append(contourLine);
            }
            OGR_F_Destroy(hFeat);
        }
        qDebug() << "Generated " << results.size() << " contour lines";
    } else {
        qWarning() << "GDALContourGenerate failed error:" << err;
    }

    OGR_DS_Destroy(hOgrDS);
    GDALClose(hSrcDS);

    return results;
}

QVariantMap EarthworkEngine::getDTMData()
{
    QVariantMap result;

    // Open DTM
    QByteArray dtmPathBytes = m_dtmPath.toUtf8();
    GDALDatasetH hDataset = GDALOpen(dtmPathBytes.constData(), GA_ReadOnly);
    if (!hDataset) {
        qWarning() << "Failed to open DTM for visualization:" << m_dtmPath;
        return result;
    }

    // Get raster band
    GDALRasterBandH hBand = GDALGetRasterBand(hDataset, 1);
    if (!hBand) {
        qWarning() << "Failed to get DTM raster band";
        GDALClose(hDataset);
        return result;
    }

    // Get dimensions
    int width = GDALGetRasterBandXSize(hBand);
    int height = GDALGetRasterBandYSize(hBand);

    // Get geotransform for coordinate mapping
    double adfGeoTransform[6];
    GDALGetGeoTransform(hDataset, adfGeoTransform);

    // Read the entire raster (for small DTMs this is fine)
    // For large DTMs, you might want to downsample
    float *pafScanline = (float*) CPLMalloc(sizeof(float) * width * height);
    CPLErr err = GDALRasterIO(hBand, GF_Read, 0, 0, width, height,
                               pafScanline, width, height, GDT_Float32, 0, 0);

    if (err != CE_None) {
        qWarning() << "Failed to read DTM raster data";
        CPLFree(pafScanline);
        GDALClose(hDataset);
        return result;
    }

    // Find min/max elevation for color scaling
    float minElev = pafScanline[0];
    float maxElev = pafScanline[0];
    for (int i = 0; i < width * height; i++) {
        if (pafScanline[i] != -9999.0f) {  // Skip nodata
            if (pafScanline[i] < minElev) minElev = pafScanline[i];
            if (pafScanline[i] > maxElev) maxElev = pafScanline[i];
        }
    }

    // Convert to QVariantList for QML
    QVariantList dataList;
    for (int i = 0; i < width * height; i++) {
        dataList.append(pafScanline[i]);
    }

    result["width"] = width;
    result["height"] = height;
    result["data"] = dataList;
    result["minElev"] = minElev;
    result["maxElev"] = maxElev;
    result["originX"] = adfGeoTransform[0];
    result["originY"] = adfGeoTransform[3];
    result["pixelWidth"] = adfGeoTransform[1];
    result["pixelHeight"] = adfGeoTransform[5];

    CPLFree(pafScanline);
    GDALClose(hDataset);

    qDebug() << "DTM data retrieved:" << width << "x" << height
             << "Elevation range:" << minElev << "-" << maxElev;

    return result;
}


QVariantMap EarthworkEngine::generate3DMesh(double verticalScale)
{
    QVariantMap result;

    // Get DTM data first
    QVariantMap dtmData = getDTMData();
    if (dtmData.isEmpty() || dtmData["width"].toInt() == 0) {
        qWarning() << "Cannot generate 3D mesh: DTM data not available";
        return result;
    }

    int width = dtmData["width"].toInt();
    int height = dtmData["height"].toInt();
    QVariantList data = dtmData["data"].toList();
    double minElev = dtmData["minElev"].toDouble();
    double maxElev = dtmData["maxElev"].toDouble();
    double pixelWidth = dtmData["pixelWidth"].toDouble();
    double pixelHeight = qAbs(dtmData["pixelHeight"].toDouble());

    qDebug() << "Generating 3D mesh from DTM:" << width << "x" << height;

    // Generate vertices
    QVariantList vertices;
    QVariantList normals;
    QVariantList colors;

    // Normalize to centered coordinates
    double centerX = width * pixelWidth / 2.0;
    double centerY = height * pixelHeight / 2.0;
    double elevRange = maxElev - minElev;

    // Helper function to get elevation color
    auto getElevationColor = [minElev, elevRange](float elev) -> QVector3D {
        if (elev == -9999.0f) return QVector3D(0.5, 0.5, 0.5);  // Gray for nodata

        float normalized = (elev - minElev) / elevRange;
        float r, g, b;

        if (normalized < 0.25f) {
            float t = normalized * 4.0f;
            r = 0; g = t; b = 1.0f;
        } else if (normalized < 0.5f) {
            float t = (normalized - 0.25f) * 4.0f;
            r = 0; g = 1.0f; b = 1.0f - t;
        } else if (normalized < 0.75f) {
            float t = (normalized - 0.5f) * 4.0f;
            r = t; g = 1.0f; b = 0;
        } else {
            float t = (normalized - 0.75f) * 4.0f;
            r = 1.0f; g = 1.0f - t; b = 0;
        }

        return QVector3D(r, g, b);
    };

    // Create vertex grid
    for (int row = 0; row < height; row++) {
        for (int col = 0; col < width; col++) {
            int idx = row * width + col;
            float elev = data[idx].toFloat();

            // Vertex position (centered and scaled)
            float x = (col * pixelWidth - centerX);
            float z = (row * pixelHeight - centerY);
            float y = (elev == -9999.0f ? minElev : elev) * verticalScale;

            vertices.append(x);
            vertices.append(y);
            vertices.append(z);

            // Color
            QVector3D color = getElevationColor(elev);
            colors.append(color.x());
            colors.append(color.y());
            colors.append(color.z());

            // Normals (will calculate properly later)
            normals.append(0.0f);
            normals.append(1.0f);
            normals.append(0.0f);
        }
    }

    // Generate indices for triangle mesh
    QVariantList indices;
    for (int row = 0; row < height - 1; row++) {
        for (int col = 0; col < width - 1; col++) {
            int topLeft = row * width + col;
            int topRight = topLeft + 1;
            int bottomLeft = (row + 1) * width + col;
            int bottomRight = bottomLeft + 1;

            // First triangle
            indices.append(topLeft);
            indices.append(bottomLeft);
            indices.append(topRight);

            // Second triangle
            indices.append(topRight);
            indices.append(bottomLeft);
            indices.append(bottomRight);
        }
    }

    // Calculate proper normals
    QVector<QVector3D> normalVectors(width * height, QVector3D(0, 0, 0));

    for (int i = 0; i < indices.size(); i += 3) {
        int i0 = indices[i].toInt();
        int i1 = indices[i + 1].toInt();
        int i2 = indices[i + 2].toInt();

        QVector3D v0(vertices[i0 * 3].toFloat(), vertices[i0 * 3 + 1].toFloat(), vertices[i0 * 3 + 2].toFloat());
        QVector3D v1(vertices[i1 * 3].toFloat(), vertices[i1 * 3 + 1].toFloat(), vertices[i1 * 3 + 2].toFloat());
        QVector3D v2(vertices[i2 * 3].toFloat(), vertices[i2 * 3 + 1].toFloat(), vertices[i2 * 3 + 2].toFloat());

        QVector3D normal = QVector3D::crossProduct(v1 - v0, v2 - v0).normalized();

        normalVectors[i0] += normal;
        normalVectors[i1] += normal;
        normalVectors[i2] += normal;
    }

    // Normalize and write back
    for (int i = 0; i < normalVectors.size(); i++) {
        QVector3D n = normalVectors[i].normalized();
        normals[i * 3] = n.x();
        normals[i * 3 + 1] = n.y();
        normals[i * 3 + 2] = n.z();
    }

    result["vertices"] = vertices;
    result["normals"] = normals;
    result["colors"] = colors;
    result["indices"] = indices;
    result["vertexCount"] = width * height;
    result["indexCount"] = indices.size();
    result["minElev"] = minElev;
    result["maxElev"] = maxElev;  // Fixed: removed space before maxElev
    result["width"] = width;
    result["height"] = height;

    qDebug() << "3D mesh generated:" << vertices.size() / 3 << "vertices," << indices.size() / 3 << "triangles";

    return result;
}

bool EarthworkEngine::exportDTMasOBJ(const QString &filePath, double verticalScale)
{
    // Get DTM data
    QVariantMap dtmData = getDTMData();
    if (dtmData.isEmpty() || dtmData["width"].toInt() == 0) {
        qWarning() << "Cannot export OBJ: DTM data not available";
        return false;
    }

    int width = dtmData["width"].toInt();
    int height = dtmData["height"].toInt();
    QVariantList data = dtmData["data"].toList();
    double minElev = dtmData["minElev"].toDouble();
    double maxElev = dtmData["maxElev"].toDouble();
    double pixelWidth = dtmData["pixelWidth"].toDouble();
    double pixelHeight = qAbs(dtmData["pixelHeight"].toDouble());

    qDebug() << "Exporting DTM as OBJ:" << width << "x" << height << "to" << filePath;

    // Open output file
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "Failed to open file for writing:" << filePath;
        return false;
    }

    QTextStream out(&file);

    // Write OBJ header
    out << "# Wavefront OBJ file\n";
    out << "# Generated by SiteSurveyor - DTM Export\n";
    out << "# Vertices: " << (width * height) << "\n";
    out << "# Elevation range: " << minElev << "m - " << maxElev << "m\n";
    out << "# Vertical scale: " << verticalScale << "x\n\n";

    // Helper function for elevation color
    auto getElevationColor = [minElev, maxElev](float elev) -> QVector3D {
        if (elev == -9999.0f) return QVector3D(0.5, 0.5, 0.5);

        float normalized = (elev - minElev) / (maxElev - minElev);
        float r, g, b;

        if (normalized < 0.25f) {
            float t = normalized * 4.0f;
            r = 0; g = t; b = 1.0f;
        } else if (normalized < 0.5f) {
            float t = (normalized - 0.25f) * 4.0f;
            r = 0; g = 1.0f; b = 1.0f - t;
        } else if (normalized < 0.75f) {
            float t = (normalized - 0.5f) * 4.0f;
            r = t; g = 1.0f; b = 0;
        } else {
            float t = (normalized - 0.75f) * 4.0f;
            r = 1.0f; g = 1.0f - t; b = 0;
        }

        return QVector3D(r, g, b);
    };

    // Center coordinates
    double centerX = width * pixelWidth / 2.0;
    double centerY = height * pixelHeight / 2.0;

    // Write vertices
    out << "# Vertices\n";
    for (int row = 0; row < height; row++) {
        for (int col = 0; col < width; col++) {
            int idx = row * width + col;
            float elev = data[idx].toFloat();

            float x = (col * pixelWidth - centerX);
            float z = -(row * pixelHeight - centerY);  // Negate for proper orientation
            float y = (elev == -9999.0f ? minElev : elev) * verticalScale;

            // Get color for this vertex
            QVector3D color = getElevationColor(elev);

            // Write vertex with color (vx vy vz r g b)
            out << "v " << QString::number(x, 'f', 3) << " "
                << QString::number(y, 'f', 3) << " "
                << QString::number(z, 'f', 3) << " "
                << QString::number(color.x(), 'f', 3) << " "
                << QString::number(color.y(), 'f', 3) << " "
                << QString::number(color.z(), 'f', 3) << "\n";
        }
    }

    out << "\n# Faces\n";

    // Write faces (triangles)
    for (int row = 0; row < height - 1; row++) {
        for (int col = 0; col < width - 1; col++) {
            // OBJ indices are 1-based
            int topLeft = row * width + col + 1;
            int topRight = topLeft + 1;
            int bottomLeft = (row + 1) * width + col + 1;
            int bottomRight = bottomLeft + 1;

            // First triangle (counter-clockwise winding)
            out << "f " << topLeft << " " << bottomLeft << " " << topRight << "\n";

            // Second triangle
            out << "f " << topRight << " " << bottomLeft << " " << bottomRight << "\n";
        }
    }

    file.close();

    int triangleCount = (width - 1) * (height - 1) * 2;
    qDebug() << "OBJ export successful:" << (width * height) << "vertices," << triangleCount << "triangles";
    qDebug() << "File saved to:" << filePath;

    return true;
}

bool EarthworkEngine::openInQGIS(const QString &filePath)
{
    if (filePath.isEmpty()) {
        qWarning() << "No file path provided for QGIS";
        return false;
    }

    QFileInfo fileInfo(filePath);
    if (!fileInfo.exists()) {
        qWarning() << "File does not exist:" << filePath;
        return false;
    }

    qDebug() << "Launching QGIS with:" << filePath;

    QProcess *process = new QProcess(this);
    process->setProgram("qgis");
    process->setArguments({filePath});

    bool started = process->startDetached();

    if (started) {
        qDebug() << "QGIS launched successfully";
        return true;
    } else {
        qWarning() << "Failed to launch QGIS - make sure QGIS is installed: sudo apt install qgis";
        return false;
    }
}

QVariantList EarthworkEngine::createBuffer(const QVariantList &points, double distance)
{
    QVariantList result;
    if (points.size() < 3) return result;

    // Convert QVariantList to GEOS Coordinates
    GEOSCoordSequence* seq = GEOSCoordSeq_create(points.size() + 1, 2); // +1 to close ring

    for (int i = 0; i < points.size(); ++i) {
        QPointF p = points[i].toPointF();
        GEOSCoordSeq_setX(seq, i, p.x());
        GEOSCoordSeq_setY(seq, i, p.y());
    }
    // Close the ring
    QPointF p0 = points[0].toPointF();
    GEOSCoordSeq_setX(seq, points.size(), p0.x());
    GEOSCoordSeq_setY(seq, points.size(), p0.y());

    // Create Polygon (LinearRing -> Polygon)
    GEOSGeometry* ring = GEOSGeom_createLinearRing(seq);
    if (!ring) {
        qCritical() << "Failed to create GEOS linear ring";
        GEOSCoordSeq_destroy(seq);
        return result;
    }

    GEOSGeometry* poly = GEOSGeom_createPolygon(ring, nullptr, 0);

    if (!poly) {
        qCritical() << "Failed to create GEOS polygon";
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
    QVariantMap result;
    result["cut"] = 0.0;
    result["fill"] = 0.0;
    result["net"] = 0.0;
    result["area"] = 0.0;

    // 1. Create Boundary Geometry (Convex Hull) from points
    GEOSGeometry* boundary = nullptr;
    const GEOSPreparedGeometry* prepBoundary = nullptr;

    if (points.size() >= 3) {
        // Create GEOS geometries
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
        delete[] pointGeoms;

        if (boundary) {
            prepBoundary = GEOSPrepare(boundary);
        }
    }

    qDebug() << "Calculing volume with boundary mask:" << (boundary ? "Yes" : "No");

    // Open DTM
    QByteArray dtmPathBytes = m_dtmPath.toUtf8();
    GDALDatasetH hDataset = GDALOpen(dtmPathBytes.constData(), GA_ReadOnly);
    if (!hDataset) {
        if (prepBoundary) GEOSPreparedGeom_destroy(prepBoundary);
        if (boundary) GEOSGeom_destroy(boundary);
        qWarning() << "Failed to open DTM for volume calculation";
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
    double param2 = adfGeoTransform[2];
    double originY = adfGeoTransform[3];
    double param4 = adfGeoTransform[4];
    double pixelHeight = adfGeoTransform[5];

    double pixelArea = std::abs(pixelWidth * pixelHeight);

    // Read Data
    float *pafScanline = (float*) CPLMalloc(sizeof(float) * width * height);
    if (GDALRasterIO(hBand, GF_Read, 0, 0, width, height, pafScanline, width, height, GDT_Float32, 0, 0) != CE_None) {
         CPLFree(pafScanline);
         GDALClose(hDataset);
         if (prepBoundary) GEOSPreparedGeom_destroy(prepBoundary);
         if (boundary) GEOSGeom_destroy(boundary);
         return result;
    }

    double cut = 0.0;
    double fill = 0.0;
    double totalArea = 0.0;

    for (int row = 0; row < height; row++) {
        for (int col = 0; col < width; col++) {
            int idx = row * width + col;
            float elev = pafScanline[idx];

            if (elev == -9999.0f) continue;

            // Compute World X,Y
            double worldX = originX + col * pixelWidth + row * param2;
            double worldY = originY + col * param4 + row * pixelHeight;

            // Check Mask
            bool include = true;
            if (prepBoundary) {
                 GEOSCoordSequence* s = GEOSCoordSeq_create(1, 2);
                 GEOSCoordSeq_setX(s, 0, worldX);
                 GEOSCoordSeq_setY(s, 0, worldY);
                 GEOSGeometry* pGeom = GEOSGeom_createPoint(s);

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

    result["cut"] = cut;
    result["fill"] = fill;
    result["net"] = cut - fill;
    result["area"] = totalArea;

    qDebug() << "Volume (masked):" << cut << "/" << fill << " Area:" << totalArea;
    return result;
}

// ============ TIN-BASED METHODS ============

QVariantMap EarthworkEngine::generateTIN(const QVariantList &points)
{
    QVariantMap result;
    result["success"] = false;
    m_tinVertices.clear();
    m_tinTriangles.clear();

    if (points.size() < 3) {
        qWarning() << "TIN requires at least 3 points";
        return result;
    }

    qDebug() << "Generating TIN from" << points.size() << "points...";

    // Create GEOS MultiPoint for Delaunay triangulation
    GEOSGeometry** pointGeoms = new GEOSGeometry*[points.size()];
    for (int i = 0; i < points.size(); ++i) {
        QVariantMap m = points[i].toMap();
        GEOSCoordSequence* s = GEOSCoordSeq_create(1, 3); // 3D coordinates
        GEOSCoordSeq_setX(s, 0, m["x"].toDouble());
        GEOSCoordSeq_setY(s, 0, m["y"].toDouble());
        GEOSCoordSeq_setZ(s, 0, m["z"].toDouble());
        pointGeoms[i] = GEOSGeom_createPoint(s);

        // Store vertices
        QVariantMap vertex;
        vertex["x"] = m["x"].toDouble();
        vertex["y"] = m["y"].toDouble();
        vertex["z"] = m["z"].toDouble();
        m_tinVertices.append(vertex);
    }

    GEOSGeometry* collection = GEOSGeom_createCollection(GEOS_MULTIPOINT, pointGeoms, points.size());
    delete[] pointGeoms;

    if (!collection) {
        qWarning() << "Failed to create point collection for TIN";
        return result;
    }

    // Perform Delaunay triangulation
    GEOSGeometry* triangles = GEOSDelaunayTriangulation(collection, 0.0, 0); // 0 = return triangles (not edges)
    GEOSGeom_destroy(collection);

    if (!triangles) {
        qWarning() << "Delaunay triangulation failed";
        return result;
    }

    int numTriangles = GEOSGetNumGeometries(triangles);
    qDebug() << "TIN generated:" << numTriangles << "triangles";

    // Extract triangles - store as point indices
    // For each triangle, find matching vertices in m_tinVertices
    for (int t = 0; t < numTriangles; ++t) {
        const GEOSGeometry* tri = GEOSGetGeometryN(triangles, t);
        const GEOSGeometry* ring = GEOSGetExteriorRing(tri);
        const GEOSCoordSequence* seq = GEOSGeom_getCoordSeq(ring);

        QVariantList triIndices;
        unsigned int numCoords;
        GEOSCoordSeq_getSize(seq, &numCoords);

        // Triangle has 4 coords (closed ring), we need first 3
        for (unsigned int c = 0; c < 3 && c < numCoords; ++c) {
            double x, y;
            GEOSCoordSeq_getX(seq, c, &x);
            GEOSCoordSeq_getY(seq, c, &y);

            // Find matching vertex index
            for (int v = 0; v < m_tinVertices.size(); ++v) {
                QVariantMap vert = m_tinVertices[v].toMap();
                if (std::abs(vert["x"].toDouble() - x) < 0.001 &&
                    std::abs(vert["y"].toDouble() - y) < 0.001) {
                    triIndices.append(v);
                    break;
                }
            }
        }

        if (triIndices.size() == 3) {
            m_tinTriangles.append(triIndices[0]);
            m_tinTriangles.append(triIndices[1]);
            m_tinTriangles.append(triIndices[2]);
        }
    }

    GEOSGeom_destroy(triangles);

    result["success"] = true;
    result["vertexCount"] = m_tinVertices.size();
    result["triangleCount"] = m_tinTriangles.size() / 3;
    result["vertices"] = m_tinVertices;
    result["triangles"] = m_tinTriangles; // Now 1D list [v0, v1, v2, v0, v1, v2...]

    qDebug() << "TIN complete:" << m_tinVertices.size() << "vertices," << m_tinTriangles.size() / 3 << "triangles";
    return result;
}

QVariantMap EarthworkEngine::calculateVolumeTIN(double baseElevation, const QVariantList &boundaryPolygon)
{
    QVariantMap result;
    result["cut"] = 0.0;
    result["fill"] = 0.0;
    result["net"] = 0.0;
    result["area"] = 0.0;
    result["method"] = "TIN";

    if (m_tinVertices.isEmpty() || m_tinTriangles.isEmpty()) {
        qWarning() << "TIN not generated. Call generateTIN first.";
        return result;
    }

    // Build boundary geometry for clipping (if provided)
    GEOSGeometry* boundary = nullptr;
    const GEOSPreparedGeometry* prepBoundary = nullptr;

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
            boundary = GEOSGeom_createPolygon(ring, nullptr, 0);
            if (boundary) {
                prepBoundary = GEOSPrepare(boundary);
            }
        }
    }

    qDebug() << "Calculating TIN volume with" << m_tinTriangles.size() << "triangles, base:" << baseElevation;

    double cut = 0.0;
    double fill = 0.0;
    double totalArea = 0.0;

    // Process each triangle (stride of 3)
    for (int t = 0; t < m_tinTriangles.size(); t += 3) {
        if (t + 2 >= m_tinTriangles.size()) break;

        // Flattened list access - no nested variants issues!
        int i0 = m_tinTriangles[t].toInt();
        int i1 = m_tinTriangles[t+1].toInt();
        int i2 = m_tinTriangles[t+2].toInt();

        if (t == 0) {
            qDebug() << "First triangle indices:" << i0 << i1 << i2;
        }

        if (i0 >= m_tinVertices.size() || i1 >= m_tinVertices.size() || i2 >= m_tinVertices.size())
            continue;

        QVariantMap v0 = m_tinVertices[i0].toMap();
        QVariantMap v1 = m_tinVertices[i1].toMap();
        QVariantMap v2 = m_tinVertices[i2].toMap();

        double x0 = v0["x"].toDouble(), y0 = v0["y"].toDouble(), z0 = v0["z"].toDouble();
        double x1 = v1["x"].toDouble(), y1 = v1["y"].toDouble(), z1 = v1["z"].toDouble();
        double x2 = v2["x"].toDouble(), y2 = v2["y"].toDouble(), z2 = v2["z"].toDouble();

        // Check if triangle centroid is inside boundary (if defined)
        if (prepBoundary) {
            double cx = (x0 + x1 + x2) / 3.0;
            double cy = (y0 + y1 + y2) / 3.0;

            GEOSCoordSequence* ps = GEOSCoordSeq_create(1, 2);
            GEOSCoordSeq_setX(ps, 0, cx);
            GEOSCoordSeq_setY(ps, 0, cy);
            GEOSGeometry* pt = GEOSGeom_createPoint(ps);

            if (!GEOSPreparedIntersects(prepBoundary, pt)) {
                GEOSGeom_destroy(pt);
                continue; // Skip triangles outside boundary
            }
            GEOSGeom_destroy(pt);
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

    if (prepBoundary) GEOSPreparedGeom_destroy(prepBoundary);
    if (boundary) GEOSGeom_destroy(boundary);

    result["cut"] = cut;
    result["fill"] = fill;
    result["net"] = cut - fill;
    result["area"] = totalArea;

    qDebug() << "TIN Volume: Cut=" << cut << "Fill=" << fill << "Area=" << totalArea;
    return result;
}

