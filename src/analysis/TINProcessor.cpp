#include "TINProcessor.h"
#include "GDALHelpers.h"
#include <geos_c.h>
#include <QDebug>
#include <cmath>

using namespace GDALHelpers;

TINProcessor::TINProcessor(QObject *parent)
    : QObject(parent)
{
}

TINProcessor::~TINProcessor() = default;

void TINProcessor::clear()
{
    m_vertices.clear();
    m_triangles.clear();
}

QVariantMap TINProcessor::generate(const QVariantList &points, QString &errorOut)
{
    QVariantMap result;
    result["success"] = false;
    
    clear();
    
    if (points.size() < 3) {
        errorOut = QString("TIN requires at least 3 points (provided: %1)").arg(points.size());
        return result;
    }
    
    qDebug() << "Generating TIN from" << points.size() << "points...";
    
    // Create GEOS MultiPoint for Delaunay triangulation
    std::vector<GeometryGuard> pointGeoms;
    pointGeoms.reserve(points.size());
    
    GEOSGeometry** rawPointGeoms = new GEOSGeometry*[points.size()];
    
    for (int i = 0; i < points.size(); ++i) {
        QVariantMap m = points[i].toMap();
        
        if (!m.contains("x") || !m.contains("y") || !m.contains("z")) {
            errorOut = QString("Point %1 missing x, y, or z coordinate").arg(i);
            delete[] rawPointGeoms;
            return result;
        }
        
        GEOSCoordSequence* s = GEOSCoordSeq_create(1, 3); // 3D coordinates
        GEOSCoordSeq_setX(s, 0, m["x"].toDouble());
        GEOSCoordSeq_setY(s, 0, m["y"].toDouble());
        GEOSCoordSeq_setZ(s, 0, m["z"].toDouble());
        
        GEOSGeometry* pointGeom = GEOSGeom_createPoint(s);
        if (!pointGeom) {
            errorOut = QString("Failed to create GEOS point geometry at index %1").arg(i);
            delete[] rawPointGeoms;
            return result;
        }
        
        rawPointGeoms[i] = pointGeom;
        
        // Store vertices
        QVariantMap vertex;
        vertex["x"] = m["x"].toDouble();
        vertex["y"] = m["y"].toDouble();
        vertex["z"] = m["z"].toDouble();
        m_vertices.append(vertex);
    }
    
    // Create collection
    GEOSGeometry* collection = GEOSGeom_createCollection(GEOS_MULTIPOINT, rawPointGeoms, points.size());
    delete[] rawPointGeoms; // Ownership transferred to collection
    
    if (!collection) {
        errorOut = "Failed to create point collection for TIN";
        clear();
        return result;
    }
    
    GeometryGuard collectionGuard(collection);
    
    // Perform Delaunay triangulation
    GEOSGeometry* triangles = GEOSDelaunayTriangulation(collection, 0.0, 0); // 0 = return triangles (not edges)
    
    if (!triangles) {
        errorOut = "Delaunay triangulation failed";
        clear();
        return result;
    }
    
    GeometryGuard trianglesGuard(triangles);
    
    int numTriangles = GEOSGetNumGeometries(triangles);
    qDebug() << "TIN generated:" << numTriangles << "triangles";
    
    if (numTriangles == 0) {
        errorOut = "Delaunay triangulation produced no triangles";
        clear();
        return result;
    }
    
    // Extract triangles - store as point indices
    // For each triangle, find matching vertices in m_vertices
    for (int t = 0; t < numTriangles; ++t) {
        const GEOSGeometry* tri = GEOSGetGeometryN(triangles, t);
        if (!tri) continue;
        
        const GEOSGeometry* ring = GEOSGetExteriorRing(tri);
        if (!ring) continue;
        
        const GEOSCoordSequence* seq = GEOSGeom_getCoordSeq(ring);
        if (!seq) continue;
        
        QVariantList triIndices;
        unsigned int numCoords;
        GEOSCoordSeq_getSize(seq, &numCoords);
        
        // Triangle has 4 coords (closed ring), we need first 3
        for (unsigned int c = 0; c < 3 && c < numCoords; ++c) {
            double x, y;
            GEOSCoordSeq_getX(seq, c, &x);
            GEOSCoordSeq_getY(seq, c, &y);
            
            // Find matching vertex index
            bool found = false;
            for (int v = 0; v < m_vertices.size(); ++v) {
                QVariantMap vert = m_vertices[v].toMap();
                if (std::abs(vert["x"].toDouble() - x) < 0.001 &&
                    std::abs(vert["y"].toDouble() - y) < 0.001) {
                    triIndices.append(v);
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                qWarning() << "Could not find matching vertex for triangle" << t << "coord" << c;
            }
        }
        
        if (triIndices.size() == 3) {
            m_triangles.append(triIndices[0]);
            m_triangles.append(triIndices[1]);
            m_triangles.append(triIndices[2]);
        }
    }
    
    result["success"] = true;
    result["vertexCount"] = m_vertices.size();
    result["triangleCount"] = m_triangles.size() / 3;
    result["vertices"] = m_vertices;
    result["triangles"] = m_triangles; // 1D list [v0, v1, v2, v0, v1, v2...]
    
    qDebug() << "TIN complete:" << m_vertices.size() << "vertices," << m_triangles.size() / 3 << "triangles";
    
    return result;
}
