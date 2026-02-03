#include "MeshExporter.h"
#include <QFile>
#include <QTextStream>
#include <QDebug>
#include <QVector>
#include <cmath>

MeshExporter::MeshExporter(QObject *parent)
    : QObject(parent)
{
}

MeshExporter::~MeshExporter() = default;

QVector3D MeshExporter::getElevationColor(float elevation, float minElev, float maxElev)
{
    if (elevation == -9999.0f) {
        return QVector3D(0.5, 0.5, 0.5);  // Gray for nodata
    }

    float elevRange = maxElev - minElev;
    if (elevRange <= 0) {
        return QVector3D(0.5, 0.5, 0.5);
    }

    float normalized = (elevation - minElev) / elevRange;
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
}

QVariantMap MeshExporter::generate3DMesh(const QVariantMap &dtmData,
                                        double verticalScale,
                                        QString &errorOut)
{
    QVariantMap result;

    if (dtmData.isEmpty() || dtmData["width"].toInt() == 0) {
        errorOut = "DTM data is empty or invalid";
        return result;
    }

    int width = dtmData["width"].toInt();
    int height = dtmData["height"].toInt();
    QVariantList data = dtmData["data"].toList();
    double minElev = dtmData["minElev"].toDouble();
    double maxElev = dtmData["maxElev"].toDouble();
    double pixelWidth = dtmData["pixelWidth"].toDouble();
    double pixelHeight = qAbs(dtmData["pixelHeight"].toDouble());

    if (data.size() != width * height) {
        errorOut = QString("Data size mismatch: expected %1, got %2")
                   .arg(width * height).arg(data.size());
        return result;
    }

    qDebug() << "Generating 3D mesh from DTM:" << width << "x" << height;

    // Generate vertices
    QVariantList vertices;
    QVariantList normals;
    QVariantList colors;

    // Normalize to centered coordinates
    double centerX = width * pixelWidth / 2.0;
    double centerY = height * pixelHeight / 2.0;

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
            QVector3D color = getElevationColor(elev, minElev, maxElev);
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
    result["maxElev"] = maxElev;
    result["width"] = width;
    result["height"] = height;

    qDebug() << "3D mesh generated:" << vertices.size() / 3 << "vertices," << indices.size() / 3 << "triangles";

    return result;
}

bool MeshExporter::exportAsOBJ(const QVariantMap &dtmData,
                              const QString &filePath,
                              double verticalScale,
                              QString &errorOut)
{
    if (dtmData.isEmpty() || dtmData["width"].toInt() == 0) {
        errorOut = "DTM data is empty or invalid";
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
        errorOut = QString("Failed to open file for writing: %1").arg(filePath);
        return false;
    }

    QTextStream out(&file);

    // Write OBJ header
    out << "# Wavefront OBJ file\n";
    out << "# Generated by SiteSurveyor - DTM Export\n";
    out << "# Vertices: " << (width * height) << "\n";
    out << "# Elevation range: " << minElev << "m - " << maxElev << "m\n";
    out << "# Vertical scale: " << verticalScale << "x\n\n";

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
            QVector3D color = getElevationColor(elev, minElev, maxElev);

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
