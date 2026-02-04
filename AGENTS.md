# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

SiteSurveyor is a Qt6/QML desktop application for geomatics and surveying professionals. It supports multiple surveying disciplines (Engineering, Mining, Geodetic, Cadastral, Topographic, Remote Sensing) with offline-first data storage using SpatiaLite and GIS analysis capabilities via GDAL/GEOS/PROJ.

## Build Commands

```bash
# Quick start (installs deps + builds)
./scripts/quickstart.sh

# Configure with CMake presets
cmake --preset linux-debug    # or linux-release, macos-debug, windows-debug

# Build
cmake --build build/linux-debug --parallel

# Run (Linux)
./build/linux-debug/SiteSurveyor

# Run (macOS)
open build/macos-debug/SiteSurveyor.app
```

### Dependencies

Linux (Debian/Ubuntu):
```bash
sudo apt install cmake ninja-build qt6-base-dev qt6-declarative-dev libqt6quick3d6-dev \
  libgdal-dev libgeos-dev libproj-dev libsqlite3-dev libspatialite-dev
```

## Linting and Formatting

```bash
# Install pre-commit hooks
pip install pre-commit && pre-commit install

# Run all checks
pre-commit run --all-files

# Format C++ only
clang-format -i src/**/*.cpp src/**/*.h

# Format CMake files
cmake-format -i CMakeLists.txt
```

The project uses:
- **clang-format** (v17): LLVM-based style, 120 char line limit, 4-space indent
- **clang-tidy**: Qt-style naming (CamelCase classes, camelBack functions, `m_` prefix for private members)

## Architecture

### C++ Backend (`src/`)

Three QObjects are exposed to QML via `rootContext()`:

1. **Database** (`DatabaseManager`) - SpatiaLite storage for projects, survey points, personnel, instruments, traverses, and levelling data. Supports spatial queries and CSV import/export.

2. **Earthwork** (`EarthworkEngine`) - Facade for GIS analysis:
   - `src/analysis/DTMGenerator` - Digital Terrain Model creation using GDAL Grid (IDW interpolation)
   - `src/analysis/TINProcessor` - Delaunay triangulation via GEOS
   - `src/analysis/VolumeCalculator` - Cut/fill calculations (grid and TIN-prism methods)
   - `src/analysis/MeshExporter` - 3D mesh generation and OBJ export

3. **CoordTransform** (`CoordinateTransformer`) - CRS transformations via PROJ (supports Lo29/EPSG:22289 ↔ WGS84)

### RAII Memory Management

GDAL/GEOS C API resources use RAII guards in `src/analysis/GDALHelpers.h`:
- `DatasetGuard`, `GridOptionsGuard`, `GeometryGuard`, `PreparedGeometryGuard`, `CStringArrayGuard`, `CPLMemoryGuard<T>`

### QML Frontend (`resources/qml/`)

Navigation uses a `StackView` in `Main.qml`. Key views:
- `DisciplineSelectionView` → `ProjectManagementView` → discipline-specific dashboard
- Engineering discipline has full implementation: `pages/engineering/EngineeringDashboard.qml`
- Reusable components in `components/` (DTM3DViewer, ErrorBanner, ProcessingOverlay, MapPicker, etc.)

### Error Handling Pattern

Backend components return errors via `QString& errorOut` parameters. EarthworkEngine exposes errors to QML via:
```cpp
Q_PROPERTY(QString lastError READ lastError NOTIFY errorChanged)
signal void errorOccurred(const QString &error);
```

QML should connect to `errorOccurred` signal to display errors to users.

## Key Files

- `CMakeLists.txt` - Build configuration, lists all source files
- `CMakePresets.json` - Build presets for all platforms
- `.clang-format` / `.clang-tidy` - Code style configuration
- `resources/qml.qrc` - Qt resource file listing all QML files
- `appwrite.config.json` - Backend service configuration (if using cloud features)

## CI/CD

GitHub Actions workflow in `.github/workflows/release.yml`:
- Builds Linux AppImage (bundles GDAL/GEOS/PROJ data files)
- Builds Windows ZIP with vcpkg dependencies
- Triggered on `main` pushes and version tags (`v*`)
