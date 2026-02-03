# SiteSurveyor Feature Enhancement Roadmap

## Summary

This document outlines planned feature enhancements for SiteSurveyor based on the refactoring improvements. Features are prioritized by user impact and implementation complexity.

---

## ✅ Completed Features

### Phase 1: Core Refactoring (DONE)
- ✅ **Modular Architecture** - Split EarthworkEngine into 5 components
- ✅ **RAII Memory Management** - Eliminated memory leaks
- ✅ **Error Handling** - Q_PROPERTY states with QML propagation
- ✅ **Progress Indicators** - Real-time DTM generation progress (0-100%)
- ✅ **QML Error UI** - ErrorBanner and ProcessingOverlay components

### Phase 2: Coordinate Transformation (IN PROGRESS)
- ✅ **CoordinateTransformer Class** - PROJ-based coordinate conversions
- 🔨 **QML Dialog** - User-friendly conversion interface (next)

---

## 🚀 High Priority Features

### 1. Coordinate Transformation UI
**Status**: Foundation complete, UI pending  
**Impact**: High - Users frequently need Lo29 ↔ WGS84 conversions  
**Complexity**: Low

**What's Done**:
- ✅ `CoordinateTransformer.h/cpp` created with PROJ integration
- ✅ Supports: WGS84, Lo29, Lo31, UTM 35S/36S
- ✅ Q_INVOKABLE methods for QML

**Next Steps**:
1. Create `CoordinateConverterDialog.qml`
2. Add to main menu: Tools → Coordinate Converter
3. Expose CoordinateTransformer to QML in main.cpp
4. Add keyboard shortcut (Ctrl+T)

**Example Usage**:
```qml
Dialog {
    id: coordConverter
    TextField { id: eastingInput; placeholderText: "Easting (Y)" }
    TextField { id: northingInput; placeholderText: "Northing (X)" }
    Button {
        text: "Convert to WGS84"
        onClicked: {
            var result = CoordTransform.lo29ToWgs84(
                parseFloat(eastingInput.text),
                parseFloat(northingInput.text),
                0
            )
            if (result.success) {
                latText.text = result.latitude.toFixed(8)
                lonText.text = result.longitude.toFixed(8)
            }
        }
    }
}
```

---

### 2. Traverse Misclose Calculation
**Status**: Not started  
**Impact**: High - Critical for survey validation  
**Complexity**: Medium

**Implementation**:
1. Add method to DatabaseManager:
   ```cpp
   Q_INVOKABLE QVariantMap calculateTraverseMisclose(int traverseId);
   ```

2. Calculate:
   - Angular misclose
   - Linear misclose  
   - Precision ratio (1:N)
   - Distribute corrections (Bowditch adjustment)

3. Add to TraversingPage.qml:
   - "Check Misclose" button
   - Display results dialog with:
     * Linear misclose (meters)
     * Angular misclose (seconds)
     * Precision (1:XXXX)
     * Pass/Fail indicator

**Formula**:
```
Linear Misclose = √(ΣΔE² + ΣΔN²)
Precision = Total Distance / Linear Misclose
Angular Misclose = |(Σ interior angles) - (n-2)×180°|
```

---

### 3. Automated Database Backup
**Status**: Not started  
**Impact**: High - Data protection  
**Complexity**: Low

**Implementation**:
1. Add to DatabaseManager:
   ```cpp
   Q_INVOKABLE bool createBackup(const QString &reason);
   Q_INVOKABLE QString getBackupPath();
   ```

2. Auto-backup before:
   - Delete project
   - Clear all data
   - Import large CSV (>1000 points)
   - Database schema changes

3. Store backups in:
   ```
   ~/SiteSurveyor/backups/
   sitesurveyor_20260203_133045.db
   sitesurveyor_20260203_140521.db
   ```

4. Keep last 10 backups, delete older

**UI Addition**:
- Settings → Database → Backups
- List recent backups
- "Restore from Backup" button

---

### 4. Recent Projects List
**Status**: Not started  
**Impact**: Medium - Workflow improvement  
**Complexity**: Low

**Implementation**:
1. Track last access time in projects table:
   ```sql
   ALTER TABLE projects ADD COLUMN last_accessed TEXT;
   ```

2. Update on project load:
   ```cpp
   bool DatabaseManager::loadProject(int projectId) {
       // existing code...
       updateProjectAccessTime(projectId);
   }
   ```

3. Add to ProjectManagementView.qml:
   ```qml
   Rectangle {
       // "Recent Projects" section
       ListView {
           model: Database.getRecentProjects(5)
           delegate: ProjectCard {
               onClicked: Database.loadProject(model.id)
           }
       }
   }
   ```

---

## 📊 Medium Priority Features

### 5. Undo/Redo System
**Status**: Design phase  
**Impact**: High - User experience  
**Complexity**: High

**Architecture**:
```cpp
class CommandStack {
    QUndoStack *m_stack;
    
    // Commands
    AddPointCommand
    DeletePointCommand
    ModifyPointCommand
    DeleteProjectCommand
}
```

**Challenges**:
- Database transactions for undo
- Memory overhead for large operations
- Undo traverse computations

**Phased Approach**:
1. Phase 1: Undo point edits only
2. Phase 2: Undo delete operations
3. Phase 3: Undo computations

---

### 6. Keyboard Shortcuts
**Status**: Not started  
**Impact**: Medium - Power user productivity  
**Complexity**: Low

**Shortcuts to Add**:
```qml
Shortcut {
    sequence: "Ctrl+S"
    onActivated: saveCurrentWork()
}
Shortcut {
    sequence: "Ctrl+Z"
    onActivated: undoLastAction()
}
Shortcut {
    sequence: "Ctrl+Shift+Z"
    onActivated: redoLastAction()
}
Shortcut {
    sequence: "Ctrl+I"
    onActivated: importCSVDialog.open()
}
Shortcut {
    sequence: "Ctrl+T"
    onActivated: coordConverterDialog.open()
}
Shortcut {
    sequence: "Ctrl+D"
    onActivated: generateDTMDialog.open()
}
Shortcut {
    sequence: "Ctrl+P"
    onActivated: addPointDialog.open()
}
Shortcut {
    sequence: "F1"
    onActivated: helpDialog.open()
}
```

---

## 🔬 Advanced Features (Future)

### 7. End-Area Volume Method
**Status**: Planned  
**Complexity**: Medium

Add to VolumeCalculator:
```cpp
QVariantMap calculateVolumeEndArea(
    const QVariantList &crossSections,
    double stationInterval
);
```

Useful for: Roads, pipelines, linear earthworks

---

### 8. Cross-Section Generation
**Status**: Planned  
**Complexity**: Medium

```cpp
QVariantList generateCrossSections(
    const QVariantList &alignment,  // Centerline
    double spacing,                  // Station interval
    double width                     // Cross-section width
);
```

Returns: List of cross-sections with elevations

---

### 9. Point Cloud Support (LAS/LAZ)
**Status**: Research phase  
**Complexity**: High

**Libraries**:
- libLAS or PDAL for LAS/LAZ reading
- Octree spatial indexing for rendering
- Level-of-detail (LOD) for large clouds

**Features**:
- Import LAS/LAZ files
- Classify points (ground, vegetation, building)
- Generate DTM from ground points
- 3D visualization with color by elevation/intensity

---

### 10. Data Validation Framework
**Status**: Planned  
**Complexity**: Medium

**Validations**:
```cpp
class DataValidator {
    bool validateTraverseClosures();
    bool checkDuplicatePoints(double tolerance);
    bool validateElevations(double minZ, double maxZ);
    bool checkCoordinateRange(int epsg);
    QVariantList findOutliers(double threshold);
}
```

**UI**:
- Tools → Validate Data
- Show validation report
- Auto-fix common issues

---

## 📋 Implementation Priority Matrix

| Feature | Impact | Complexity | Priority | Status |
|---------|--------|------------|----------|--------|
| Coordinate Transform UI | High | Low | 🔥 P0 | In Progress |
| Recent Projects | Medium | Low | 🔥 P0 | Not Started |
| Database Backup | High | Low | 🔥 P0 | Not Started |
| Keyboard Shortcuts | Medium | Low | ⭐ P1 | Not Started |
| Traverse Misclose | High | Medium | ⭐ P1 | Not Started |
| Undo/Redo System | High | High | ⭐ P1 | Design |
| End-Area Volumes | Medium | Medium | 📌 P2 | Planned |
| Cross-Sections | Medium | Medium | 📌 P2 | Planned |
| Data Validation | Medium | Medium | 📌 P2 | Planned |
| Point Cloud Support | Low | High | 📌 P3 | Research |

---

## 🎯 Recommended Implementation Order

### Sprint 1 (Week 1)
1. ✅ Complete CoordinateConverter Dialog
2. ✅ Add Recent Projects list
3. ✅ Implement Database Backup

### Sprint 2 (Week 2)
4. ✅ Add Keyboard Shortcuts
5. ✅ Implement Traverse Misclose calculation
6. ✅ Add validation UI

### Sprint 3 (Week 3-4)
7. ✅ Design Undo/Redo architecture
8. ✅ Implement Phase 1 (point edits)
9. ✅ Add End-Area volume method

---

## 📝 Notes

- Focus on **quick wins** (low complexity, high impact) first
- Build **foundational systems** (undo/redo) before complex features
- Maintain **backward compatibility** with existing QML
- Keep **documentation** up-to-date
- Add **unit tests** for all new features

---

## 🤝 Contribution Guidelines

When implementing features from this roadmap:

1. Create feature branch: `feature/coordinate-transform-ui`
2. Follow existing code style (clang-format, clang-tidy)
3. Add inline documentation
4. Update this roadmap with status
5. Create PR with:
   - Description of changes
   - Screenshots (for UI features)
   - Test results
   - Co-Authored-By: Warp <agent@warp.dev>

---

## 📚 References

- [PROJ Documentation](https://proj.org/en/stable/)
- [Qt Undo Framework](https://doc.qt.io/qt-6/qundo.html)
- [PDAL Point Cloud Library](https://pdal.io/)
- Surveying Computations: Wolf & Ghilani (7th Ed.)

---

**Last Updated**: 2026-02-03  
**Version**: 1.0  
**Maintainer**: Development Team
