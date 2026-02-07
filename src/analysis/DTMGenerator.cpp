#include "DTMGenerator.h"
#include "GDALHelpers.h"
#include <gdal_priv.h>
#include <gdal_utils.h>
#include <gdal_alg.h>
#include <ogr_spatialref.h>
#include <QFile>
#include <QTextStream>
#include <QDebug>
#include <QUuid>
#include <QStandardPaths>
#include <QFileInfo>

using namespace GDALHelpers;

DTMGenerator::DTMGenerator(QObject *parent)
    : QObject(parent)
{
}

DTMGenerator::~DTMGenerator() = default;

bool DTMGenerator::validatePoints(const QVariantList &points, QString &errorOut)
{
    if (points.isEmpty()) {
        errorOut = "No points provided for DTM generation";
        return false;
    }

    if (points.size() < 3) {
        errorOut = QString("Insufficient points: %1 (minimum 3 required)").arg(points.size());
        return false;
    }

    // Validate first point structure
    QVariantMap firstPoint = points[0].toMap();
    if (!firstPoint.contains("x") || !firstPoint.contains("y") || !firstPoint.contains("z")) {
        errorOut = "Points must contain x, y, and z coordinates";
        return false;
    }

    return true;
}

bool DTMGenerator::createVRTFile(const QString &csvPath, const QString &vrtPath, QString &errorOut)
{
    QFile vrtFile(vrtPath);
    if (!vrtFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        errorOut = QString("Failed to create VRT file: %1").arg(vrtPath);
        return false;
    }

    QString layerName = QFileInfo(csvPath).completeBaseName();

    QTextStream out(&vrtFile);
    out << "<OGRVRTDataSource>\n"
        << "    <OGRVRTLayer name=\"points\">\n"
        << "        <SrcDataSource>" << csvPath << "</SrcDataSource>\n"
        << "        <SrcLayer>" << layerName << "</SrcLayer>\n"
        << "        <GeometryType>wkbPoint</GeometryType>\n"
        << "        <GeometryField encoding=\"PointFromColumns\" x=\"X\" y=\"Y\" z=\"Z\"/>\n"
        << "    </OGRVRTLayer>\n"
        << "</OGRVRTDataSource>\n";

    vrtFile.close();
    return true;
}

bool DTMGenerator::generate(const QVariantList &points,
                           double pixelSize,
                           const QString &outputPath,
                           QString &errorOut,
                           ProgressCallback progressCallback)
{
    // Validate input
    if (!validatePoints(points, errorOut)) {
        return false;
    }

    if (pixelSize <= 0) {
        errorOut = QString("Invalid pixel size: %1 (must be > 0)").arg(pixelSize);
        return false;
    }



    if (progressCallback) progressCallback(10);

    qDebug() << "Generating DTM with" << points.size() << "points, pixel size:" << pixelSize;

    // Create unique temporary CSV file
    QString tempDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    QString uniqueId = QUuid::createUuid().toString(QUuid::Id128);
    QString tempCsvPath = tempDir + QString("/dtm_pts_%1.csv").arg(uniqueId);
    
    QFile csvFile(tempCsvPath);
    if (!csvFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        errorOut = QString("Failed to create temporary CSV file: %1").arg(tempCsvPath);
        return false;
    }

    QTextStream out(&csvFile);
    out << "X,Y,Z\n";

    double minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;

    for (const QVariant &v : points) {
        QVariantMap pt = v.toMap();
        double x = pt["x"].toDouble();
        double y = pt["y"].toDouble();
        double z = pt["z"].toDouble();

        out << QString::number(x, 'f', 6) << ","
            << QString::number(y, 'f', 6) << ","
            << QString::number(z, 'f', 6) << "\n";

        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
    }
    csvFile.close();

    if (progressCallback) progressCallback(30);

    // Add margin
    double margin = 5.0;
    minX -= margin; maxX += margin;
    minY -= margin; maxY += margin;

    // Create VRT file
    QString vrtPath = tempCsvPath + ".vrt";
    if (!createVRTFile(tempCsvPath, vrtPath, errorOut)) {
        QFile::remove(tempCsvPath); // Cleanup CSV if VRT fails
        return false;
    }

    if (progressCallback) progressCallback(40);

    // Open source dataset using RAII guard
    DatasetGuard srcDataset(GDALOpenEx(vrtPath.toUtf8().constData(),
                                       GDAL_OF_VECTOR, nullptr, nullptr, nullptr));
    if (!srcDataset) {
        errorOut = "Failed to open point source for DTM generation";
        QFile::remove(tempCsvPath);
        QFile::remove(vrtPath);
        return false;
    }

    // Calculate grid dimensions
    int nXSize = static_cast<int>((maxX - minX) / pixelSize);
    int nYSize = static_cast<int>((maxY - minY) / pixelSize);
    if (nXSize <= 0) nXSize = 1;
    if (nYSize <= 0) nYSize = 1;

    if (progressCallback) progressCallback(50);

    // Build GDAL Grid arguments using RAII guard
    CStringArrayGuard args;
    args.add("-outsize");
    args.add(QString::number(nXSize));
    args.add(QString::number(nYSize));
    args.add("-txe");
    args.add(QString::number(minX, 'f', 6));
    args.add(QString::number(maxX, 'f', 6));
    args.add("-tye");
    args.add(QString::number(minY, 'f', 6));
    args.add(QString::number(maxY, 'f', 6));
    args.add("-of");
    args.add("GTiff");
    args.add("-a");
    args.add("invdist:power=2.0:smoothing=1.0:nodata=-9999");
    args.add("-zfield");
    args.add("Z");

    if (progressCallback) progressCallback(60);

    // Create grid options using RAII guard
    GridOptionsGuard gridOptions(GDALGridOptionsNew(args.data(), nullptr));
    if (!gridOptions) {
        errorOut = "Failed to create GDAL grid options";
        QFile::remove(tempCsvPath);
        QFile::remove(vrtPath);
        return false;
    }

    if (progressCallback) progressCallback(70);

    // Generate DTM using RAII guard for output dataset
    DatasetGuard dstDataset(GDALGrid(outputPath.toUtf8().constData(),
                                    srcDataset.get(),
                                    gridOptions.get(),
                                    nullptr));

    if (!dstDataset) {
        errorOut = "GDAL Grid failed to generate DTM";
        QFile::remove(tempCsvPath);
        QFile::remove(vrtPath);
        return false;
    }

    if (progressCallback) progressCallback(100);

    qDebug() << "DTM generated successfully:" << outputPath;
    qDebug() << "  Grid size:" << nXSize << "x" << nYSize;
    qDebug() << "  Bounds: [" << minX << "," << minY << "] to [" << maxX << "," << maxY << "]";

    // Cleanup temporary files
    QFile::remove(tempCsvPath);
    QFile::remove(vrtPath);

    return true;
}

QVariantMap DTMGenerator::getData(const QString &dtmPath, QString &errorOut)
{
    QVariantMap result;

    // Open DTM using RAII guard
    DatasetGuard dataset(GDALOpen(dtmPath.toUtf8().constData(), GA_ReadOnly));
    if (!dataset) {
        errorOut = QString("Failed to open DTM: %1").arg(dtmPath);
        return result;
    }

    // Get raster band
    GDALRasterBandH hBand = GDALGetRasterBand(dataset.get(), 1);
    if (!hBand) {
        errorOut = "Failed to get DTM raster band";
        return result;
    }

    // Get dimensions
    int width = GDALGetRasterBandXSize(hBand);
    int height = GDALGetRasterBandYSize(hBand);

    // Get geotransform
    double adfGeoTransform[6];
    if (GDALGetGeoTransform(dataset.get(), adfGeoTransform) != CE_None) {
        errorOut = "Failed to get DTM geotransform";
        return result;
    }

    // Read raster data using RAII guard
    CPLMemoryGuard<float> scanline((float*)CPLMalloc(sizeof(float) * width * height));
    if (!scanline) {
        errorOut = "Failed to allocate memory for DTM data";
        return result;
    }

    CPLErr err = GDALRasterIO(hBand, GF_Read, 0, 0, width, height,
                              scanline.get(), width, height, GDT_Float32, 0, 0);
    if (err != CE_None) {
        errorOut = "Failed to read DTM raster data";
        return result;
    }

    // Find min/max elevation
    float minElev = scanline[0];
    float maxElev = scanline[0];
    for (int i = 0; i < width * height; i++) {
        if (scanline[i] != -9999.0f) {  // Skip nodata
            if (scanline[i] < minElev) minElev = scanline[i];
            if (scanline[i] > maxElev) maxElev = scanline[i];
        }
    }

    // Convert to QVariantList
    QVariantList dataList;
    dataList.reserve(width * height);
    for (int i = 0; i < width * height; i++) {
        dataList.append(scanline[i]);
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

    qDebug() << "DTM data retrieved:" << width << "x" << height
             << "Elevation range:" << minElev << "-" << maxElev;

    return result;
}

QVariantList DTMGenerator::generateContours(const QString &dtmPath,
                                           double interval,
                                           QString &errorOut)
{
    QVariantList results;

    if (interval <= 0) {
        errorOut = QString("Invalid contour interval: %1 (must be > 0)").arg(interval);
        return results;
    }

    // Open DTM using RAII guard
    DatasetGuard dataset(GDALOpen(dtmPath.toUtf8().constData(), GA_ReadOnly));
    if (!dataset) {
        errorOut = QString("Failed to open DTM for contours: %1").arg(dtmPath);
        return results;
    }

    GDALRasterBandH hBand = GDALGetRasterBand(dataset.get(), 1);
    if (!hBand) {
        errorOut = "Failed to get raster band for contours";
        return results;
    }

    // Create memory datasource for contours
    OGRSFDriverH hOgrDriver = OGRGetDriverByName("Memory");
    OGRDataSourceH hOgrDS = OGR_Dr_CreateDataSource(hOgrDriver, "contour_mem", nullptr);
    if (!hOgrDS) {
        errorOut = "Failed to create memory datasource for contours";
        return results;
    }

    OGRSpatialReferenceH hSRS = nullptr;
    OGRLayerH hLayer = OGR_DS_CreateLayer(hOgrDS, "contours", hSRS, wkbLineString, nullptr);
    if (!hLayer) {
        errorOut = "Failed to create contour layer";
        OGR_DS_Destroy(hOgrDS);
        return results;
    }

    OGRFieldDefnH hFieldDefn = OGR_Fld_Create("Elevation", OFTReal);
    OGR_L_CreateField(hLayer, hFieldDefn, TRUE);
    OGR_Fld_Destroy(hFieldDefn);

    // Generate contours
    CPLErr err = GDALContourGenerate(hBand, interval, 0.0, 0, nullptr,
                                     FALSE, -9999.0, hLayer, -1, 0,
                                     nullptr, nullptr);

    if (err != CE_None) {
        errorOut = QString("GDAL contour generation failed (code: %1)").arg(err);
        OGR_DS_Destroy(hOgrDS);
        return results;
    }

    // Extract contours
    OGR_L_ResetReading(hLayer);
    OGRFeatureH hFeat;
    while ((hFeat = OGR_L_GetNextFeature(hLayer)) != nullptr) {
        double elev = OGR_F_GetFieldAsDouble(hFeat, 0);
        OGRGeometryH hGeom = OGR_F_GetGeometryRef(hFeat);

        if (hGeom != nullptr && wkbFlatten(OGR_G_GetGeometryType(hGeom)) == wkbLineString) {
            QVariantList linePoints;
            int pointCount = OGR_G_GetPointCount(hGeom);

            for (int i = 0; i < pointCount; ++i) {
                QVariantMap pt;
                pt["x"] = OGR_G_GetX(hGeom, i);
                pt["y"] = OGR_G_GetY(hGeom, i);
                linePoints.append(pt);
            }

            QVariantMap contourLine;
            contourLine["elevation"] = elev;
            contourLine["points"] = linePoints;
            results.append(contourLine);
        }

        OGR_F_Destroy(hFeat);
    }

    OGR_DS_Destroy(hOgrDS);

    qDebug() << "Generated" << results.size() << "contour lines at" << interval << "interval";

    return results;
}
