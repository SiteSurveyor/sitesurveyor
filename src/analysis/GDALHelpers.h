#ifndef GDALHELPERS_H
#define GDALHELPERS_H

#include <gdal_priv.h>
#include <gdal_utils.h>
#include <geos_c.h>
#include <vector>
#include <cstdlib>

namespace GDALHelpers {

/**
 * @brief RAII wrapper for GDALDataset handles
 * Automatically closes dataset on destruction
 */
class DatasetGuard {
public:
    explicit DatasetGuard(GDALDatasetH dataset = nullptr) : m_dataset(dataset) {}
    
    ~DatasetGuard() {
        if (m_dataset) {
            GDALClose(m_dataset);
        }
    }
    
    // Non-copyable
    DatasetGuard(const DatasetGuard&) = delete;
    DatasetGuard& operator=(const DatasetGuard&) = delete;
    
    // Movable
    DatasetGuard(DatasetGuard&& other) noexcept : m_dataset(other.m_dataset) {
        other.m_dataset = nullptr;
    }
    
    DatasetGuard& operator=(DatasetGuard&& other) noexcept {
        if (this != &other) {
            if (m_dataset) {
                GDALClose(m_dataset);
            }
            m_dataset = other.m_dataset;
            other.m_dataset = nullptr;
        }
        return *this;
    }
    
    GDALDatasetH get() const { return m_dataset; }
    GDALDatasetH* ptr() { return &m_dataset; }
    operator bool() const { return m_dataset != nullptr; }
    
    GDALDatasetH release() {
        GDALDatasetH temp = m_dataset;
        m_dataset = nullptr;
        return temp;
    }
    
private:
    GDALDatasetH m_dataset;
};

/**
 * @brief RAII wrapper for GDALGridOptions
 * Automatically frees options on destruction
 */
class GridOptionsGuard {
public:
    explicit GridOptionsGuard(GDALGridOptions* options = nullptr) : m_options(options) {}
    
    ~GridOptionsGuard() {
        if (m_options) {
            GDALGridOptionsFree(m_options);
        }
    }
    
    GridOptionsGuard(const GridOptionsGuard&) = delete;
    GridOptionsGuard& operator=(const GridOptionsGuard&) = delete;
    
    GridOptionsGuard(GridOptionsGuard&& other) noexcept : m_options(other.m_options) {
        other.m_options = nullptr;
    }
    
    GridOptionsGuard& operator=(GridOptionsGuard&& other) noexcept {
        if (this != &other) {
            if (m_options) {
                GDALGridOptionsFree(m_options);
            }
            m_options = other.m_options;
            other.m_options = nullptr;
        }
        return *this;
    }
    
    GDALGridOptions* get() const { return m_options; }
    operator bool() const { return m_options != nullptr; }
    
private:
    GDALGridOptions* m_options;
};

/**
 * @brief RAII wrapper for GEOS geometry handles
 * Automatically destroys geometry on destruction
 */
class GeometryGuard {
public:
    explicit GeometryGuard(GEOSGeometry* geom = nullptr) : m_geom(geom) {}
    
    ~GeometryGuard() {
        if (m_geom) {
            GEOSGeom_destroy(m_geom);
        }
    }
    
    GeometryGuard(const GeometryGuard&) = delete;
    GeometryGuard& operator=(const GeometryGuard&) = delete;
    
    GeometryGuard(GeometryGuard&& other) noexcept : m_geom(other.m_geom) {
        other.m_geom = nullptr;
    }
    
    GeometryGuard& operator=(GeometryGuard&& other) noexcept {
        if (this != &other) {
            if (m_geom) {
                GEOSGeom_destroy(m_geom);
            }
            m_geom = other.m_geom;
            other.m_geom = nullptr;
        }
        return *this;
    }
    
    GEOSGeometry* get() const { return m_geom; }
    GEOSGeometry** ptr() { return &m_geom; }
    operator bool() const { return m_geom != nullptr; }
    
    GEOSGeometry* release() {
        GEOSGeometry* temp = m_geom;
        m_geom = nullptr;
        return temp;
    }
    
private:
    GEOSGeometry* m_geom;
};

/**
 * @brief RAII wrapper for GEOS prepared geometry
 */
class PreparedGeometryGuard {
public:
    explicit PreparedGeometryGuard(const GEOSPreparedGeometry* geom = nullptr) 
        : m_geom(geom) {}
    
    ~PreparedGeometryGuard() {
        if (m_geom) {
            GEOSPreparedGeom_destroy(m_geom);
        }
    }
    
    PreparedGeometryGuard(const PreparedGeometryGuard&) = delete;
    PreparedGeometryGuard& operator=(const PreparedGeometryGuard&) = delete;
    
    const GEOSPreparedGeometry* get() const { return m_geom; }
    operator bool() const { return m_geom != nullptr; }
    
private:
    const GEOSPreparedGeometry* m_geom;
};

/**
 * @brief RAII wrapper for char** arrays used in GDAL
 * Automatically frees all allocated strings
 */
class CStringArrayGuard {
public:
    CStringArrayGuard() = default;
    
    ~CStringArrayGuard() {
        for (char* str : m_strings) {
            free(str);
        }
    }
    
    CStringArrayGuard(const CStringArrayGuard&) = delete;
    CStringArrayGuard& operator=(const CStringArrayGuard&) = delete;
    
    void add(const char* str) {
        m_strings.push_back(strdup(str));
    }
    
    void add(const QString& str) {
        m_strings.push_back(strdup(str.toUtf8().constData()));
    }
    
    char** data() {
        // Add null terminator if not already present
        if (m_strings.empty() || m_strings.back() != nullptr) {
            m_strings.push_back(nullptr);
        }
        return m_strings.data();
    }
    
    size_t size() const {
        // Don't count the null terminator
        return m_strings.empty() ? 0 : m_strings.size() - 1;
    }
    
private:
    std::vector<char*> m_strings;
};

/**
 * @brief RAII wrapper for CPL memory allocations
 */
template<typename T>
class CPLMemoryGuard {
public:
    explicit CPLMemoryGuard(T* ptr = nullptr) : m_ptr(ptr) {}
    
    ~CPLMemoryGuard() {
        if (m_ptr) {
            CPLFree(m_ptr);
        }
    }
    
    CPLMemoryGuard(const CPLMemoryGuard&) = delete;
    CPLMemoryGuard& operator=(const CPLMemoryGuard&) = delete;
    
    CPLMemoryGuard(CPLMemoryGuard&& other) noexcept : m_ptr(other.m_ptr) {
        other.m_ptr = nullptr;
    }
    
    CPLMemoryGuard& operator=(CPLMemoryGuard&& other) noexcept {
        if (this != &other) {
            if (m_ptr) {
                CPLFree(m_ptr);
            }
            m_ptr = other.m_ptr;
            other.m_ptr = nullptr;
        }
        return *this;
    }
    
    T* get() const { return m_ptr; }
    T** ptr() { return &m_ptr; }
    operator bool() const { return m_ptr != nullptr; }
    
    T* release() {
        T* temp = m_ptr;
        m_ptr = nullptr;
        return temp;
    }
    
    // Array access
    T& operator[](size_t index) { return m_ptr[index]; }
    const T& operator[](size_t index) const { return m_ptr[index]; }
    
private:
    T* m_ptr;
};

} // namespace GDALHelpers

#endif // GDALHELPERS_H
