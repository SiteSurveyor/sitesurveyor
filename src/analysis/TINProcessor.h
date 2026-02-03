#ifndef TINPROCESSOR_H
#define TINPROCESSOR_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

/**
 * @brief Handles Triangulated Irregular Network (TIN) operations
 * 
 * Provides functionality for:
 * - Generating TIN from point clouds using Delaunay triangulation (GEOS)
 * - Storing and retrieving TIN vertex and triangle data
 */
class TINProcessor : public QObject
{
    Q_OBJECT

public:
    explicit TINProcessor(QObject *parent = nullptr);
    ~TINProcessor();

    /**
     * @brief Generate TIN from survey points using Delaunay triangulation
     * @param points List of point maps with x, y, z keys
     * @param errorOut Output parameter for error message
     * @return Map with success, vertexCount, triangleCount, vertices, triangles
     */
    QVariantMap generate(const QVariantList &points, QString &errorOut);

    /**
     * @brief Get stored TIN vertices
     * @return List of vertex maps with x, y, z keys
     */
    QVariantList getVertices() const { return m_vertices; }

    /**
     * @brief Get stored TIN triangle indices
     * @return Flattened list of vertex indices [v0, v1, v2, v0, v1, v2, ...]
     */
    QVariantList getTriangles() const { return m_triangles; }

    /**
     * @brief Check if TIN data is available
     */
    bool hasData() const { return !m_vertices.isEmpty() && !m_triangles.isEmpty(); }

    /**
     * @brief Clear stored TIN data
     */
    void clear();

private:
    QVariantList m_vertices;    // Stored TIN vertices [{x, y, z}, ...]
    QVariantList m_triangles;   // Stored TIN triangles as flat index list [i0, i1, i2, ...]
};

#endif // TINPROCESSOR_H
