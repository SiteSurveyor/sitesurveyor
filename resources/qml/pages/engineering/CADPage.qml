import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Qt.labs.platform as Platform
import "../../components"

Window {
    id: root
    width: 1400
    height: 900
    visible: false
    title: "CAD Mode - SiteSurveyor"

    // Dark theme color palette
    property color bgColor: "#1E1E1E"          // Dark background
    property color accentColor: "#5B7C99"      // Steel blue accent
    property color textPrimary: "#E8E8E8"      // Light grey text
    property color textSecondary: "#B0B0B0"    // Medium grey text
    property color charcoalBg: "#2C3E50"       // Charcoal elements
    property color darkCardBg: "#252525"       // Dark card background
    property color canvasBg: "#2A2A2A"         // Canvas background
    property color gridColor: "#3A3A3A"        // Grid lines

    // Imported points data
    property var importedPoints: ListModel {}
    property string csvContentCache: ""
    property real canvasOffsetX: 0
    property real canvasOffsetY: 0
    property real canvasScale: 1.0

    // Tool selection
    property int selectedTool: 0  // 0=Select, 1=Pan, 2=Zoom, etc.

    onSelectedToolChanged: {
        if (selectedTool === 1) canvasMouseArea.cursorShape = Qt.OpenHandCursor
        else if (selectedTool === 2) canvasMouseArea.cursorShape = Qt.SizeAllCursor
        else canvasMouseArea.cursorShape = Qt.CrossCursor

        // Cancel active drafts when switching tools (completed measurements/shapes remain until cleared)
        if (selectedTool !== 10) drawingState = { active: false }
        if (selectedTool !== 11) measurePoints = []
        if (selectedTool !== 6) polylineDraftPoints = []
        if (selectedTool !== 7) polygonDraftPoints = []
        if (selectedTool !== 12) boundaryDraftPoints = []

        if (pointsCanvas) pointsCanvas.requestPaint()
    }
    // Mouse drag state
    property real lastMouseX: 0
    property real lastMouseY: 0
    property int selectedPointIndex: -1  // -1 means no selection
    property var selectedPoints: []  // Array of selected point indices
    property var measurePoints: []   // Array of points for active area measurement

    property var polylineDraftPoints: [] // Active polyline points (draft)
    property var polygonDraftPoints: []  // Active polygon points (draft)
    property var boundaryDraftPoints: [] // Active boundary points (draft)

    property var drawnShapes: []  // Array of {type, points, color, ...}

    // Undo/redo for geometry edits (drawnShapes + boundaryPolygon)
    property var undoStack: []
    property var redoStack: []
    property int maxUndoStates: 30

    function cloneValue(value) {
        try {
            return JSON.parse(JSON.stringify(value))
        } catch (e) {
            return value
        }
    }

    function pushUndoState() {
        var snapshot = {
            drawnShapes: cloneValue(drawnShapes) || [],
            boundaryPolygon: cloneValue(boundaryPolygon) || []
        }

        var stack = undoStack ? undoStack.slice() : []
        stack.push(snapshot)
        if (stack.length > maxUndoStates) stack.shift()
        undoStack = stack
        redoStack = []
    }

    function restoreSnapshot(snapshot) {
        if (!snapshot) return
        drawnShapes = snapshot.drawnShapes || []
        boundaryPolygon = snapshot.boundaryPolygon || []
        if (pointsCanvas) pointsCanvas.requestPaint()
    }

    function undo() {
        if (!undoStack || undoStack.length === 0) return
        var current = {
            drawnShapes: cloneValue(drawnShapes) || [],
            boundaryPolygon: cloneValue(boundaryPolygon) || []
        }
        var stack = undoStack.slice()
        var prev = stack.pop()
        undoStack = stack

        var redo = redoStack ? redoStack.slice() : []
        redo.push(current)
        if (redo.length > maxUndoStates) redo.shift()
        redoStack = redo

        restoreSnapshot(prev)
    }

    function redo() {
        if (!redoStack || redoStack.length === 0) return
        var current = {
            drawnShapes: cloneValue(drawnShapes) || [],
            boundaryPolygon: cloneValue(boundaryPolygon) || []
        }
        var redo = redoStack.slice()
        var next = redo.pop()
        redoStack = redo

        var stack = undoStack ? undoStack.slice() : []
        stack.push(current)
        if (stack.length > maxUndoStates) stack.shift()
        undoStack = stack

        restoreSnapshot(next)
    }
    property var contourLines: [] // Array of {elevation, points}
    property var dtmData: null    // DTM raster data for visualization
    property var tinData: null    // TIN mesh data for visualization
    property bool showDTM: true   // Toggle DTM visualization
    property bool showTIN: true   // Toggle TIN visualization
    property bool showContours: true // Toggle Contours visualization
    property bool showGrid: true  // Toggle Grid
    property bool showPointLabels: true // Toggle point labels
    property string gridMode: "Auto" // "Auto" or "Manual"
    property real manualGridSpacing: 10.0 // Manual spacing in meters
    property bool snapEnabled: true // Toggle Object Snapping
    property bool isBulkImporting: false // Flag for bulk import operations
    property var drawingState: ({ active: false, startX: 0, startY: 0, currentX: 0, currentY: 0 })
    property var boundaryPolygon: [] // User-defined boundary polygon for volume calculation

    // CRS Properties
    property int selectedCRS: 0
    property string customEpsg: ""
    property var crsList: [
        { name: "Lo29 (Harare)", epsg: 22289 },
        { name: "Lo31 (Beitbridge)", epsg: 22291 },
        { name: "WGS 84", epsg: 4326 },
        { name: "UTM Zone 36S", epsg: 32736 }
    ]

    // Drawing Settings (AutoCAD-style)
    property int crosshairSize: 5
    property int pickboxSize: 5
    property int snapMarkerSize: 10
    property var currentSnapPos: null  // Current snap target position {x, y} in world coordinates
    property bool showSnapIndicator: false  // Whether to show the snap indicator
    property var lineTypeNames: ["Continuous", "Dashed", "Center", "Hidden"]
    property string currentLineType: "Continuous"
    property real lineTypeScale: 1.0

    // Coordinate system properties
    property real fitScale: 1.0
    property real fitOffsetX: 0
    property real fitOffsetY: 0

    // Status Bar Properties
    property real cursorX: 0
    property real cursorY: 0

    // Command Console Properties
    property int commandHistoryLimit: 120
    property var commandInputHistory: []
    property int commandInputHistoryIndex: -1
    property bool commandConsoleCollapsed: false
    property int commandConsoleWidth: 460
    property int commandConsoleExpandedHeight: 150
    property int commandConsoleCollapsedHeight: 30

    ListModel {
        id: commandHistoryModel
    }

    function appendCommandHistory(line, kind) {
        commandHistoryModel.append({ line: line, kind: kind || "info" })
        if (commandHistoryModel.count > commandHistoryLimit) {
            commandHistoryModel.remove(0, commandHistoryModel.count - commandHistoryLimit)
        }
        Qt.callLater(function() {
            if (commandHistoryView) commandHistoryView.positionViewAtEnd()
        })
    }

    function clearCommandHistory() {
        commandHistoryModel.clear()
        appendCommandHistory("Command console cleared.", "info")
    }

    function executeCommand(raw) {
        var input = (raw || "").trim()
        if (input.length === 0) return

        appendCommandHistory("Command: " + input, "prompt")

        var inputHistory = commandInputHistory ? commandInputHistory.slice() : []
        inputHistory.push(input)
        commandInputHistory = inputHistory
        commandInputHistoryIndex = inputHistory.length

        var parts = input.split(/\s+/)
        var cmd = parts[0].toUpperCase()
        var args = parts.slice(1).join(" ").toUpperCase()

        function setTool(id, label) {
            selectedTool = id
            if (id === 10 || id === 11) {
                measurePoints = []
                drawingState = { active: false }
            }
            appendCommandHistory(label + " tool active.", "info")
        }

        function reportToggle(label, enabled) {
            appendCommandHistory(label + " " + (enabled ? "ON" : "OFF") + ".", "info")
        }

        switch (cmd) {
        case "L":
        case "LINE":
            setTool(3, "Line")
            return
        case "C":
        case "CIRCLE":
            setTool(4, "Circle")
            return
        case "R":
        case "RECT":
        case "RECTANGLE":
            setTool(5, "Rectangle")
            return
        case "P":
        case "PLINE":
        case "POLYLINE":
            setTool(6, "Polyline")
            return
        case "O":
        case "POLY":
        case "POLYGON":
            setTool(7, "Polygon")
            return
        case "B":
        case "BOUNDARY":
            setTool(12, "Boundary")
            return
        case "D":
        case "DIST":
        case "DISTANCE":
            setTool(10, "Measure Distance")
            return
        case "A":
        case "AREA":
            setTool(11, "Measure Area")
            return
        case "H":
        case "PAN":
            setTool(1, "Pan")
            return
        case "SELECT":
        case "V":
            setTool(0, "Select")
            return
        case "ZOOM":
        case "Z":
            if (args === "" || args === "EXTENTS" || args === "E" || args === "FIT") {
                recalculateBounds()
                appendCommandHistory("Zoom extents.", "info")
                return
            }
            if (args === "IN") {
                handleToolClick({action: "zoomIn"})
                appendCommandHistory("Zoom in.", "info")
                return
            }
            if (args === "OUT") {
                handleToolClick({action: "zoomOut"})
                appendCommandHistory("Zoom out.", "info")
                return
            }
            appendCommandHistory("Zoom options: IN, OUT, EXTENTS", "info")
            return
        case "ZOOMIN":
            handleToolClick({action: "zoomIn"})
            appendCommandHistory("Zoom in.", "info")
            return
        case "ZOOMOUT":
            handleToolClick({action: "zoomOut"})
            appendCommandHistory("Zoom out.", "info")
            return
        case "FIT":
        case "ZE":
        case "ZOOMEXTENTS":
            recalculateBounds()
            appendCommandHistory("Zoom extents.", "info")
            return
        case "GRID":
            if (args === "ON") showGrid = true
            else if (args === "OFF") showGrid = false
            else showGrid = !showGrid
            pointsCanvas.requestPaint()
            reportToggle("Grid", showGrid)
            return
        case "SNAP":
            if (args === "ON") snapEnabled = true
            else if (args === "OFF") snapEnabled = false
            else snapEnabled = !snapEnabled
            reportToggle("Snap", snapEnabled)
            return
        case "LABELS":
        case "LABEL":
            if (args === "ON") showPointLabels = true
            else if (args === "OFF") showPointLabels = false
            else showPointLabels = !showPointLabels
            pointsCanvas.requestPaint()
            reportToggle("Labels", showPointLabels)
            return
        case "COGO":
            openCogoFromSelection()
            appendCommandHistory("COGO opened.", "info")
            return
        case "POINTS":
        case "POINTMANAGER":
            openPointManager()
            appendCommandHistory("Point Manager opened.", "info")
            return
        case "ADDPOINT":
        case "ADDPT":
            selectedTool = 30
            addPointDialog.clearFields()
            addPointDialog.open()
            appendCommandHistory("Add Point dialog opened.", "info")
            return
        case "IMPORT":
            csvFileDialog.open()
            appendCommandHistory("Import CSV opened.", "info")
            return
        case "EXPORT":
            if (importedPoints.count > 0) {
                exportCsvDialog.open()
                appendCommandHistory("Export CSV opened.", "info")
            } else {
                appendCommandHistory("No points to export.", "error")
            }
            return
        case "CRS":
            crsDialog.open()
            appendCommandHistory("CRS settings opened.", "info")
            return
        case "OPTIONS":
            optionsDialog.open()
            appendCommandHistory("CAD options opened.", "info")
            return
        case "DTM":
            if (importedPoints.count === 0) {
                appendCommandHistory("Import points before generating a DTM.", "error")
                return
            }
            dtmDialog.open()
            appendCommandHistory("DTM dialog opened.", "info")
            return
        case "CONTOURS":
        case "CONT":
            if (!dtmData) {
                appendCommandHistory("Generate a DTM before contours.", "error")
                return
            }
            contourDialog.open()
            appendCommandHistory("Contours dialog opened.", "info")
            return
        case "TIN":
            generateTIN()
            appendCommandHistory("Generating TIN...", "info")
            return
        case "VOLUME":
        case "VOL":
            volumeDialog.open()
            appendCommandHistory("Volume dialog opened.", "info")
            return
        case "OBJ":
        case "EXPORTOBJ":
            if (!dtmData) {
                appendCommandHistory("Generate a DTM before exporting OBJ.", "error")
                return
            }
            exportDTMObj()
            appendCommandHistory("Exporting OBJ...", "info")
            return
        case "UNDO":
        case "U":
            if (undoStack && undoStack.length > 0) {
                undo()
                appendCommandHistory("Undo.", "info")
            } else {
                appendCommandHistory("Nothing to undo.", "error")
            }
            return
        case "REDO":
            if (redoStack && redoStack.length > 0) {
                redo()
                appendCommandHistory("Redo.", "info")
            } else {
                appendCommandHistory("Nothing to redo.", "error")
            }
            return
        case "CLEAR":
            clearTransientStates(true, true)
            appendCommandHistory("Cleared drawings and measurements.", "info")
            return
        case "HELP":
        case "?":
            appendCommandHistory("Draw: LINE, CIRCLE, RECT, PLINE, POLYGON, BOUNDARY", "info")
            appendCommandHistory("Survey: DIST, AREA, COGO, ADDPOINT, POINTS", "info")
            appendCommandHistory("Earthwork: DTM, CONTOURS, TIN, VOLUME, OBJ", "info")
            appendCommandHistory("View: ZOOM, FIT, GRID, SNAP, LABELS", "info")
            appendCommandHistory("File/Settings: IMPORT, EXPORT, CRS, OPTIONS", "info")
            appendCommandHistory("Edit: UNDO, REDO, CLEAR", "info")
            return
        default:
            appendCommandHistory("Unknown command: " + input, "error")
            return
        }
    }

    function toolNameForId(id) {
        switch (id) {
        case 0: return "Select"
        case 1: return "Pan"
        case 2: return "Zoom In"
        case 20: return "Zoom Out"
        case 21: return "Zoom Origin"
        case 22: return "Zoom Extents"
        case 23: return "Point Manager"
        case 3: return "Line"
        case 4: return "Circle"
        case 5: return "Rectangle"
        case 6: return "Polyline"
        case 7: return "Polygon"
        case 12: return "Boundary"
        case 10: return "Measure Distance"
        case 11: return "Measure Area"
        case 30: return "Add Point"
        default: return "Unknown"
        }
    }

    property string currentToolName: toolNameForId(selectedTool)
    // Processing overlay control (avoid splash on CAD entry)
    property bool processingOverlayEnabled: false
    property string processingOverlayMessage: "Processing..."
    // Overlay for topbar menus (ensures dropdowns render above canvas)
    Item {
        id: menuOverlay
        anchors.fill: parent
        z: 10000
    }

    // Tool models for sidebar organization
    property var navTools: [
        {id: 0, icon: "\uf245", name: "Select", tooltip: "Select Tool (V)"},
        {id: 1, icon: "\uf256", name: "Pan", tooltip: "Pan Tool (H)"},
        {action: "zoomIn", icon: "\uf00e", name: "Zoom+", tooltip: "Zoom In"},
        {action: "zoomOut", icon: "\uf010", name: "Zoom-", tooltip: "Zoom Out"},
        {action: "fit", icon: "\uf31e", name: "Fit", tooltip: "Zoom Extents (Fit All)"},
        {action: "origin", icon: "\uf015", name: "Origin", tooltip: "Zoom to Origin (0,0)"}
    ]
    property var drawTools: [
        {id: 3, icon: "\uf068", name: "Line", tooltip: "Line (L)"},
        {id: 4, icon: "\uf111", name: "Circle", tooltip: "Circle (C)"},
        {id: 5, icon: "\uf0c8", name: "Rect", tooltip: "Rectangle (R)"},
        {id: 6, icon: "\uf5a9", name: "Pline", tooltip: "Polyline (P)"},
        {id: 7, icon: "\uf5ee", name: "Poly", tooltip: "Polygon (O)"},
        {id: 12, icon: "\uf5ee", name: "Bound", tooltip: "Boundary (B)"}
    ]
    property var surveyTools: [
        {id: 10, icon: "\uf547", name: "Dist", tooltip: "Measure Distance (D)"},
        {id: 11, icon: "\uf5cb", name: "Area", tooltip: "Measure Area (A)"},
        {action: "cogo", icon: "\uf1de", name: "COGO", tooltip: "Bearing/Distance COGO"},
        {action: "addPoint", icon: "\uf3c5", name: "Add Pt", tooltip: "Add Control Point"},
        {action: "pointManager", icon: "\uf0ae", name: "Points", tooltip: "Point Manager"},
        {action: "buffer", icon: "\uf5ee", name: "Buffer", tooltip: "Create Buffer"}
    ]
    property var earthworkTools: [
        {action: "dtm", icon: "\uf5fd", name: "DTM", tooltip: "Generate DTM"},
        {action: "contours", icon: "\uf5ee", name: "Cont", tooltip: "Generate Contours"},
        {action: "tin", icon: "\uf1b2", name: "TIN", tooltip: "Generate TIN"},
        {action: "volume", icon: "\uf547", name: "Vol", tooltip: "Calculate Volume"},
        {action: "exportObj", icon: "\uf56d", name: "OBJ", tooltip: "Export DTM OBJ"}
    ]
    property var displayTools: [
        {action: "gridSettings", icon: "\uf009", name: "Grid", tooltip: "Grid Settings"},
        {action: "crs", icon: "\uf0ac", name: "CRS", tooltip: "Coordinate System"},
        {action: "options", icon: "\uf013", name: "Opts", tooltip: "CAD Options"}
    ]
    property var dataTools: [
        {action: "import", icon: "\uf56f", name: "Import", tooltip: "Import CSV Points"},
        {action: "export", icon: "\uf560", name: "Export", tooltip: "Export CSV Points"}
    ]

    property var commandQuickList: [
        { label: "LINE", command: "LINE", tooltip: "Line (L)" },
        { label: "CIRCLE", command: "CIRCLE", tooltip: "Circle (C)" },
        { label: "RECT", command: "RECT", tooltip: "Rectangle (R)" },
        { label: "PLINE", command: "PLINE", tooltip: "Polyline (P)" },
        { label: "POLY", command: "POLYGON", tooltip: "Polygon (O)" },
        { label: "BOUND", command: "BOUNDARY", tooltip: "Boundary (B)" },
        { separator: true },
        { label: "DIST", command: "DIST", tooltip: "Measure Distance (D)" },
        { label: "AREA", command: "AREA", tooltip: "Measure Area (A)" },
        { label: "COGO", command: "COGO", tooltip: "COGO" },
        { label: "ADDPT", command: "ADDPOINT", tooltip: "Add Control Point" },
        { label: "POINTS", command: "POINTS", tooltip: "Point Manager" },
        { separator: true },
        { label: "DTM", command: "DTM", tooltip: "Generate DTM" },
        { label: "CONT", command: "CONTOURS", tooltip: "Generate Contours" },
        { label: "TIN", command: "TIN", tooltip: "Generate TIN" },
        { label: "VOL", command: "VOLUME", tooltip: "Volume" },
        { label: "OBJ", command: "EXPORTOBJ", tooltip: "Export OBJ" },
        { separator: true },
        { label: "ZOOM+", command: "ZOOMIN", tooltip: "Zoom In" },
        { label: "ZOOM-", command: "ZOOMOUT", tooltip: "Zoom Out" },
        { label: "FIT", command: "FIT", tooltip: "Zoom Extents" },
        { label: "GRID", command: "GRID", tooltip: "Toggle Grid" },
        { label: "SNAP", command: "SNAP", tooltip: "Toggle Snap" },
        { label: "LABELS", command: "LABELS", tooltip: "Toggle Labels" },
        { separator: true },
        { label: "IMPORT", command: "IMPORT", tooltip: "Import CSV" },
        { label: "EXPORT", command: "EXPORT", tooltip: "Export CSV" },
        { label: "CRS", command: "CRS", tooltip: "CRS Settings" },
        { label: "OPTIONS", command: "OPTIONS", tooltip: "CAD Options" },
        { separator: true },
        { label: "UNDO", command: "UNDO", tooltip: "Undo" },
        { label: "REDO", command: "REDO", tooltip: "Redo" },
        { label: "CLEAR", command: "CLEAR", tooltip: "Clear" }
    ]

    // Tool sidebar layout sizing (fit without scrolling)
    property int toolSidebarColumns: 3
    property int toolSidebarHeaderCount: 7
    property int toolSidebarEditCount: 3
    property int toolSidebarToggleCount: 3
    property int toolSidebarTileCount: navTools.length + drawTools.length + surveyTools.length +
                                      earthworkTools.length + displayTools.length + dataTools.length +
                                      toolSidebarEditCount + toolSidebarToggleCount
    property int toolSidebarTileRows: Math.ceil(toolSidebarTileCount / toolSidebarColumns)
    property int toolSidebarExtraRows: 1
    property real toolSidebarGridHeight: toolScroll ? toolScroll.height : 0
    property real toolSidebarRowSpacing: toolSidebarGridHeight < 620 ? 4 : 6
    property real toolSidebarHeaderHeight: toolSidebarGridHeight < 620 ? 16 : 18
    property real toolSidebarTileHeight: {
        var rows = toolSidebarTileRows
        if (rows <= 0) return 36
        var totalRows = toolSidebarHeaderCount + rows + toolSidebarExtraRows
        var usable = toolSidebarGridHeight -
                     (toolSidebarHeaderCount * toolSidebarHeaderHeight) -
                     (toolSidebarRowSpacing * Math.max(0, totalRows - 1))
        return Math.max(24, Math.min(44, Math.floor(usable / rows)))
    }
    property int toolSidebarIconSize: toolSidebarTileHeight >= 40 ? 12 :
                                      (toolSidebarTileHeight >= 34 ? 11 :
                                      (toolSidebarTileHeight >= 28 ? 10 : 9))
    property int toolSidebarLabelSize: toolSidebarTileHeight >= 42 ? 9 :
                                       (toolSidebarTileHeight >= 36 ? 8 :
                                       (toolSidebarTileHeight >= 30 ? 7 : 7))
    property int toolSidebarHeaderTextSize: toolSidebarGridHeight < 620 ? 7 : 8

    function startProcessing(message) {
        processingOverlayMessage = message || "Processing..."
        processingOverlayEnabled = true
        if (processingOverlay) processingOverlay.progress = 0
    }

    function stopProcessing() {
        processingOverlayEnabled = false
    }

    function clearTransientStates(clearSelection, clearDrawings) {
        if (clearSelection === undefined) clearSelection = true
        if (clearDrawings === undefined) clearDrawings = false
        measurePoints = []
        drawingState = { active: false }
        polylineDraftPoints = []
        polygonDraftPoints = []
        boundaryDraftPoints = []
        if (clearSelection) {
            selectedPoints = []
            selectedPointIndex = -1
        }

        if (clearDrawings) {
            drawnShapes = []
            boundaryPolygon = []
            undoStack = []
            redoStack = []
        } else {
            var cleanShapes = []
            for (var s = 0; s < drawnShapes.length; s++) {
                var t = drawnShapes[s].type
                if (t !== "measure_line" && t !== "measure_poly") {
                    cleanShapes.push(drawnShapes[s])
                }
            }
            drawnShapes = cleanShapes
        }
        if (selectionBox) selectionBox.visible = false
        if (canvasMouseArea) canvasMouseArea.isBoxSelecting = false
        if (pointsCanvas) pointsCanvas.requestPaint()
    }

    function openCogoFromSelection() {
        if (selectedPoints.length === 1 && selectedPoints[0] < importedPoints.count) {
            var pt = importedPoints.get(selectedPoints[0])
            cogoDialog.openForPoint(pt)
        } else {
            errorBanner.show("Select a single point to start COGO.")
        }
    }

    function openPointManager() {
        pointManagerDialog.open()
    }

    function generateTIN() {
        if (importedPoints.count < 3) {
            errorBanner.show("Need at least 3 points to generate a TIN.")
            return
        }
        startProcessing("Generating TIN...")
        var pts = []
        for (var i = 0; i < importedPoints.count; i++) {
            var p = importedPoints.get(i)
            pts.push({x: p.x, y: p.y, z: p.z || 0})
        }
        console.log("Generating TIN from", pts.length, "points...")
        var result = Earthwork.generateTIN(pts)
        if (result.success) {
            tinData = result
            console.log("TIN generated:", result.triangleCount, "triangles")
            pointsCanvas.requestPaint()
        }
        if (!Earthwork.isProcessing) stopProcessing()
    }

    function exportDTMObj() {
        if (!dtmData) {
            errorBanner.show("Generate a DTM before exporting.")
            return
        }
        var filename = "dtm_terrain_" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmss") + ".obj"
        var filepath = "/home/project3/Desktop/" + filename
        console.log("Exporting DTM to OBJ format...")
        var success = Earthwork.exportDTMasOBJ(filepath, 1.5)
        if (success) {
            console.log("✓ DTM exported successfully!")
            console.log("  File:", filepath)
        }
    }

    function handleToolClick(toolData) {
        if (!toolData) return

        switch (toolData.action) {
        case "zoomIn":
            var cx = pointsCanvas.width / 2
            var cy = pointsCanvas.height / 2
            var oldWorld = screenToWorld(cx, cy)
            canvasScale *= 1.2
            canvasOffsetX = cx - fitOffsetX - oldWorld.x * (fitScale * canvasScale)
            canvasOffsetY = cy - fitOffsetY + oldWorld.y * (fitScale * canvasScale)
            pointsCanvas.requestPaint()
            return
        case "zoomOut":
            var ocx = pointsCanvas.width / 2
            var ocy = pointsCanvas.height / 2
            var oldW = screenToWorld(ocx, ocy)
            canvasScale /= 1.2
            canvasOffsetX = ocx - fitOffsetX - oldW.x * (fitScale * canvasScale)
            canvasOffsetY = ocy - fitOffsetY + oldW.y * (fitScale * canvasScale)
            pointsCanvas.requestPaint()
            return
        case "fit":
            recalculateBounds()
            return
        case "origin":
            canvasScale = 1.0
            canvasOffsetX = (pointsCanvas.width / 2) - fitOffsetX
            canvasOffsetY = (pointsCanvas.height / 2) - fitOffsetY
            pointsCanvas.requestPaint()
            return
        case "pointManager":
            openPointManager()
            return
        case "cogo":
            openCogoFromSelection()
            return
        case "addPoint":
            selectedTool = 30
            addPointDialog.clearFields()
            addPointDialog.open()
            return
        case "buffer":
            if (selectedPoints.length > 0 || drawnShapes.length > 0) {
                bufferDialog.open()
            } else {
                errorBanner.show("Select a shape to buffer.")
            }
            return
        case "dtm":
            if (dtmData && dtmData.width > 0) {
                showDTM = !showDTM
                pointsCanvas.requestPaint()
            } else {
                if (importedPoints.count === 0) {
                    errorBanner.show("Import points before generating a DTM.")
                    return
                }
                dtmDialog.open()
            }
            return
        case "contours":
            if (contourLines && contourLines.length > 0) {
                showContours = !showContours
                pointsCanvas.requestPaint()
            } else {
                if (!dtmData) {
                    errorBanner.show("Generate a DTM before contours.")
                    return
                }
                contourDialog.open()
            }
            return
        case "tin":
            if (tinData && tinData.success) {
                showTIN = !showTIN
                pointsCanvas.requestPaint()
            } else {
                generateTIN()
            }
            return
        case "volume":
            volumeDialog.open()
            return
        case "exportObj":
            exportDTMObj()
            return
        case "gridSettings":
            gridSettingsDialog.open()
            return
        case "crs":
            crsDialog.open()
            return
        case "options":
            optionsDialog.open()
            return
        case "import":
            csvFileDialog.open()
            return
        case "export":
            if (importedPoints.count > 0) {
                exportCsvDialog.open()
            } else {
                errorBanner.show("No points to export.")
            }
            return
        case "clearDrafts":
            clearTransientStates(false)
            return
        default:
            break
        }
        if (toolData.id === 10) {
            selectedTool = 10
            measurePoints = []
            drawingState = { active: false }
            return
        }
        if (toolData.id === 11) {
            selectedTool = 11
            measurePoints = []
            drawingState = { active: false }
            return
        }
        if (toolData.id !== undefined) {
            selectedTool = toolData.id
        }
    }

    // Layers System
    property int activeLayer: 0
    property var layers: ListModel {
        ListElement { layerId: 0; layerName: "Layer 1"; visible: true; locked: false; layerColor: "#5B7C99" }
    }

    function addLayer(name, color) {
        var newId = layers.count
        var randomColor = color || Qt.hsla(Math.random(), 0.6, 0.6, 1.0).toString()
        layers.append({
            layerId: newId,
            layerName: name || "Layer " + (newId + 1),
            visible: true,
            locked: false,
            layerColor: randomColor
        })
        return newId
    }

    function deleteLayer(index) {
        if (layers.count > 1 && index >= 0 && index < layers.count) {
            layers.remove(index)
            if (activeLayer === index) activeLayer = 0
            else if (activeLayer > index) activeLayer--
        }
    }

    function toggleLayerVisibility(index) {
        if (index >= 0 && index < layers.count) {
            layers.setProperty(index, "visible", !layers.get(index).visible)
            pointsCanvas.requestPaint()
        }
    }

    function toggleLayerLock(index) {
        if (index >= 0 && index < layers.count) {
            layers.setProperty(index, "locked", !layers.get(index).locked)
        }
    }

    // Database Integration
    function loadPointsFromDB() {
        var pts = Database.getPoints()
        importedPoints.clear()
        for(var i=0; i<pts.length; i++) {
            importedPoints.append(pts[i])
        }
        console.log("Loaded " + pts.length + " points from DB")
        recalculateBounds()
        pointsCanvas.requestPaint()
    }

    Connections {
        target: Database
        function onPointsChanged() {
            if (root.isBulkImporting) return
            loadPointsFromDB()
        }
    }

    // Earthwork error and progress handling
    Connections {
        target: Earthwork
        
        function onErrorOccurred(error) {
            errorBanner.show(error)
            console.error("Earthwork Error:", error)
        }
        
        function onProgressChanged(value) {
            if (processingOverlayEnabled) processingOverlay.progress = value
        }
        
        function onProcessingChanged() {
            processingOverlay.isProcessing = Earthwork.isProcessing && processingOverlayEnabled
            if (!Earthwork.isProcessing) {
                stopProcessing()
                // Processing finished, reload DTM data if applicable
                if (dtmData) {
                    dtmData = Earthwork.getDTMData()
                    if (dtmData && dtmData.width > 0) {
                        pointsCanvas.requestPaint()
                    }
                }
            }
        }
    }

    property bool pickingControlPoint: false

    CADOptionsDialog {
        id: optionsDialog
        cadPage: root
    }

    // Refresh when CAD window becomes visible (no splash/loader)
    onVisibleChanged: {
        if (visible) {
            processingOverlayEnabled = false
            if (processingOverlay) processingOverlay.isProcessing = false
            loadPointsFromDB()
            if (canvasMouseArea) canvasMouseArea.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        if (visible) {
            processingOverlayEnabled = false
            if (processingOverlay) processingOverlay.isProcessing = false
            loadPointsFromDB()
            if (canvasMouseArea) canvasMouseArea.forceActiveFocus()
        }
        if (commandHistoryModel.count === 0) {
            appendCommandHistory("Ready. Type HELP for available commands.", "info")
        }
    }

    // ============ FILE DIALOG & CSV IMPORT ============
    Platform.FileDialog {
        id: csvFileDialog
        title: "Import CSV File - Format: Name,X,Y,Z"
        nameFilters: ["CSV files (*.csv)", "Text files (*.txt)", "All files (*)"]
        fileMode: Platform.FileDialog.OpenFile

        onAccepted: {
            parseCSVFromFile(file.toString())
        }
    }

    Platform.FileDialog {
        id: exportCsvDialog
        title: "Export CSV File"
        nameFilters: ["CSV files (*.csv)", "All files (*)"]
        fileMode: Platform.FileDialog.SaveFile

        onAccepted: {
            var filePath = file.toString().replace("file://", "")
            var ok = Database.exportToCSV(filePath)
            if (ok) {
                exportResultDialog.message = "✓ Exported " + importedPoints.count + " points to:\n" + filePath
            } else {
                exportResultDialog.message = "Export failed."
            }
            exportResultDialog.open()
        }
    }

    Dialog {
        id: exportResultDialog
        title: "CSV Export"
        modal: true
        standardButtons: Dialog.Ok

        property string message: ""

        background: Rectangle {
            color: darkCardBg
            border.color: accentColor
            border.width: 2
            radius: 4
        }

        contentItem: Rectangle {
            color: "transparent"
            implicitWidth: 420
            implicitHeight: exportResultText.implicitHeight + 24

            Text {
                id: exportResultText
                anchors.fill: parent
                anchors.margins: 12
                text: exportResultDialog.message
                wrapMode: Text.WordWrap
                font.family: "Codec Pro"
                font.pixelSize: 11
                color: textPrimary
            }
        }
    }

    // Column Mapping & Preview Dialog
    Dialog {
        id: crsDialog
        title: "Coordinate System Settings"
        modal: true
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 400
        height: 300
        standardButtons: Dialog.Ok | Dialog.Cancel

        contentItem: ColumnLayout {
            spacing: 15

            Text {
                text: "Select Coordinate Reference System"
                font.family: "Codec Pro"
                font.pixelSize: 14
                font.bold: true
                color: textPrimary
            }

            ColumnLayout {
                spacing: 5
                Text { text: "System"; color: textSecondary; font.pixelSize: 12 }
                ComboBox {
                    id: crsCombo
                    Layout.fillWidth: true
                    model: ["Lo29 (Harare) - EPSG:22289", "Lo31 (Beitbridge) - EPSG:22291", "WGS 84 - EPSG:4326", "UTM Zone 36S - EPSG:32736", "Custom EPSG..."]
                    currentIndex: selectedCRS

                    // AutoCAD Style
                    font.pixelSize: 11
                    font.family: "Codec Pro"

                    delegate: ItemDelegate {
                        width: parent.width
                        contentItem: Text {
                            text: modelData
                            color: "white"
                            font: crsCombo.font
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: highlighted ? accentColor : "#2A2A2A"
                        }
                    }

                    contentItem: Text {
                        leftPadding: 10
                        rightPadding: crsCombo.indicator.width + 10
                        text: crsCombo.displayText
                        font: crsCombo.font
                        color: "white"
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    background: Rectangle {
                        implicitWidth: 120
                        implicitHeight: 30
                        color: "#2A2A2A"
                        border.color: parent.activeFocus ? accentColor : "#5A5A5A"
                        border.width: 1
                        radius: 2
                    }

                    popup: Popup {
                        y: parent.height - 1
                        width: parent.width
                        implicitHeight: contentItem.implicitHeight
                        padding: 1

                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: crsCombo.popup.visible ? crsCombo.delegateModel : null
                            currentIndex: crsCombo.highlightedIndex
                            ScrollIndicator.vertical: ScrollIndicator { }
                        }

                        background: Rectangle {
                            color: "#2A2A2A"
                            border.color: "#5A5A5A"
                            radius: 2
                        }
                    }

                    onCurrentIndexChanged: {
                         if (currentIndex < 4) {
                             customEpsgInput.enabled = false
                         } else {
                             customEpsgInput.enabled = true
                         }
                    }
                }
            }

            ColumnLayout {
                spacing: 5
                Text { text: "Custom EPSG"; color: textSecondary; font.pixelSize: 12 }
                TextField {
                    id: customEpsgInput
                    Layout.fillWidth: true
                    placeholderText: "e.g. 32735"
                    enabled: false
                    text: customEpsg
                }
            }

            Item { Layout.fillHeight: true }
        }

        onAccepted: {
            selectedCRS = crsCombo.currentIndex
            if (selectedCRS === 4) {
                customEpsg = customEpsgInput.text
                console.log("CRS set to Custom EPSG:", customEpsg)
            } else {
                console.log("CRS set to:", crsList[selectedCRS].name)
            }
        }
    }

    Dialog {
        id: mappingDialog
        title: "CSV Import - Column Mapping"
        modal: true
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 600
        height: 500

        property var csvData: []

        standardButtons: Dialog.Ok | Dialog.Cancel

        onAccepted: {
            // Parse with selected mapping
            parseWithMapping(nameCol.currentIndex, xCol.currentIndex, yCol.currentIndex, zCol.currentIndex)
            confirmationDialog.pointCount = importedPoints.count
            confirmationDialog.open()
        }

        background: Rectangle {
            color: darkCardBg
            border.color: accentColor
            border.width: 2
            radius: 4
        }

        contentItem: ColumnLayout {
            spacing: 10

            Text {
                text: "Configure Column Mapping"
                font.family: "Codec Pro"
                font.pixelSize: 13
                font.bold: true
                color: textPrimary
                Layout.topMargin: 5
            }

            // Column mapping dropdowns
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                color: "#2A2A2A"
                border.color: "#3A3A3A"
                border.width: 1
                radius: 4

                GridLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    columns: 4
                    rowSpacing: 5
                    columnSpacing: 10

                    Text { text: "Name:"; color: textPrimary; font.family: "Codec Pro"; font.pixelSize: 10 }
                    ComboBox {
                        id: nameCol
                        model: ["Column 1", "Column 2", "Column 3", "Column 4", "Column 5"]
                        currentIndex: 0
                        Layout.preferredWidth: 100
                        font.pixelSize: 11
                        font.family: "Codec Pro"
                        delegate: ItemDelegate {
                            width: parent.width
                            contentItem: Text { text: modelData; color: "white"; font: nameCol.font; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: highlighted ? accentColor : "#2A2A2A" }
                        }
                        contentItem: Text { leftPadding: 10; rightPadding: 30; text: nameCol.displayText; font: nameCol.font; color: "white"; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                        background: Rectangle { implicitWidth: 100; implicitHeight: 25; color: "#2A2A2A"; border.color: nameCol.activeFocus ? accentColor : "#5A5A5A"; border.width: 1; radius: 2 }
                        popup: Popup {
                            y: parent.height - 1; width: parent.width; implicitHeight: contentItem.implicitHeight; padding: 1
                            contentItem: ListView { clip: true; implicitHeight: contentHeight; model: nameCol.popup.visible ? nameCol.delegateModel : null; currentIndex: nameCol.highlightedIndex }
                            background: Rectangle { color: "#2A2A2A"; border.color: "#5A5A5A"; radius: 2 }
                        }
                    }

                    Text { text: "X:"; color: textPrimary; font.family: "Codec Pro"; font.pixelSize: 10 }
                    ComboBox {
                        id: xCol
                        model: ["Column 1", "Column 2", "Column 3", "Column 4", "Column 5"]
                        currentIndex: 1
                        Layout.preferredWidth: 100
                        font.pixelSize: 11
                        font.family: "Codec Pro"
                        delegate: ItemDelegate {
                            width: parent.width
                            contentItem: Text { text: modelData; color: "white"; font: xCol.font; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: highlighted ? accentColor : "#2A2A2A" }
                        }
                        contentItem: Text { leftPadding: 10; rightPadding: 30; text: xCol.displayText; font: xCol.font; color: "white"; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                        background: Rectangle { implicitWidth: 100; implicitHeight: 25; color: "#2A2A2A"; border.color: xCol.activeFocus ? accentColor : "#5A5A5A"; border.width: 1; radius: 2 }
                        popup: Popup {
                            y: parent.height - 1; width: parent.width; implicitHeight: contentItem.implicitHeight; padding: 1
                            contentItem: ListView { clip: true; implicitHeight: contentHeight; model: xCol.popup.visible ? xCol.delegateModel : null; currentIndex: xCol.highlightedIndex }
                            background: Rectangle { color: "#2A2A2A"; border.color: "#5A5A5A"; radius: 2 }
                        }
                    }

                    Text { text: "Y:"; color: textPrimary; font.family: "Codec Pro"; font.pixelSize: 10 }
                    ComboBox {
                        id: yCol
                        model: ["Column 1", "Column 2", "Column 3", "Column 4", "Column 5"]
                        currentIndex: 2
                        Layout.preferredWidth: 100
                        font.pixelSize: 11
                        font.family: "Codec Pro"
                        delegate: ItemDelegate {
                            width: parent.width
                            contentItem: Text { text: modelData; color: "white"; font: yCol.font; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: highlighted ? accentColor : "#2A2A2A" }
                        }
                        contentItem: Text { leftPadding: 10; rightPadding: 30; text: yCol.displayText; font: yCol.font; color: "white"; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                        background: Rectangle { implicitWidth: 100; implicitHeight: 25; color: "#2A2A2A"; border.color: yCol.activeFocus ? accentColor : "#5A5A5A"; border.width: 1; radius: 2 }
                        popup: Popup {
                            y: parent.height - 1; width: parent.width; implicitHeight: contentItem.implicitHeight; padding: 1
                            contentItem: ListView { clip: true; implicitHeight: contentHeight; model: yCol.popup.visible ? yCol.delegateModel : null; currentIndex: yCol.highlightedIndex }
                            background: Rectangle { color: "#2A2A2A"; border.color: "#5A5A5A"; radius: 2 }
                        }
                    }

                    Text { text: "Z:"; color: textPrimary; font.family: "Codec Pro"; font.pixelSize: 10 }
                    ComboBox {
                        id: zCol
                        model: ["Column 1", "Column 2", "Column 3", "Column 4", "Column 5", "None"]
                        currentIndex: 3
                        Layout.preferredWidth: 100
                        font.pixelSize: 11
                        font.family: "Codec Pro"
                        delegate: ItemDelegate {
                            width: parent.width
                            contentItem: Text { text: modelData; color: "white"; font: zCol.font; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: highlighted ? accentColor : "#2A2A2A" }
                        }
                        contentItem: Text { leftPadding: 10; rightPadding: 30; text: zCol.displayText; font: zCol.font; color: "white"; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                        background: Rectangle { implicitWidth: 100; implicitHeight: 25; color: "#2A2A2A"; border.color: zCol.activeFocus ? accentColor : "#5A5A5A"; border.width: 1; radius: 2 }
                        popup: Popup {
                            y: parent.height - 1; width: parent.width; implicitHeight: contentItem.implicitHeight; padding: 1
                            contentItem: ListView { clip: true; implicitHeight: contentHeight; model: zCol.popup.visible ? zCol.delegateModel : null; currentIndex: zCol.highlightedIndex }
                            background: Rectangle { color: "#2A2A2A"; border.color: "#5A5A5A"; radius: 2 }
                        }
                    }
                }
            }

            Text {
                text: "Preview (first 10 rows)"
                font.family: "Codec Pro"
                font.pixelSize: 11
                color: textSecondary
            }

            // CSV Preview
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: canvasBg
                border.color: "#3A3A3A"
                border.width: 1
                radius: 4

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 5
                    clip: true

                    ListView {
                        model: mappingDialog.csvData
                        spacing: 2

                        delegate: Rectangle {
                            width: ListView.view.width - 10
                            height: 25
                            color: index % 2 === 0 ? "#252525" : "#2A2A2A"
                            radius: 2

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 15

                                Repeater {
                                    model: modelData
                                    Text {
                                        text: modelData
                                        color: textPrimary
                                        font.family: "Codec Pro"
                                        font.pixelSize: 9
                                        width: 110
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Confirmation Dialog with points preview
    Dialog {
        id: confirmationDialog
        title: "Import Complete"
        modal: true
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 500
        height: 400

        property int pointCount: 0

        standardButtons: Dialog.Ok

        background: Rectangle {
            color: darkCardBg
            border.color: accentColor
            border.width: 2
            radius: 4
        }

        contentItem: ColumnLayout {
            spacing: 10

            Text {
                text: "✓ " + confirmationDialog.pointCount + " points imported!"
                font.family: "Codec Pro"
                font.pixelSize: 13
                font.bold: true
                color: "#2ECC71"
                Layout.alignment: Qt.AlignHCenter
            }

            // Preview table
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: canvasBg
                border.color: "#3A3A3A"
                border.width: 1
                radius: 4

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 0

                    // Header
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        color: "#2A2A2A"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 20

                            Text { text: "Name"; color: accentColor; font.family: "Codec Pro"; font.pixelSize: 10; font.bold: true; width: 100 }
                            Text { text: "X"; color: accentColor; font.family: "Codec Pro"; font.pixelSize: 10; font.bold: true; width: 100 }
                            Text { text: "Y"; color: accentColor; font.family: "Codec Pro"; font.pixelSize: 10; font.bold: true; width: 100 }
                            Text { text: "Z"; color: accentColor; font.family: "Codec Pro"; font.pixelSize: 10; font.bold: true; width: 100 }
                        }
                    }

                    // Data
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ListView {
                            model: importedPoints
                            spacing: 1

                            delegate: Rectangle {
                                width: ListView.view.width - 10
                                height: 25
                                color: index % 2 === 0 ? "#252525" : "#2A2A2A"

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 20

                                    Text { text: model.name || ""; color: textPrimary; font.family: "Codec Pro"; font.pixelSize: 9; width: 100; elide: Text.ElideRight }
                                    Text { text: model.x ? model.x.toFixed(3) : "0.000"; color: textPrimary; font.family: "Codec Pro"; font.pixelSize: 9; width: 100 }
                                    Text { text: model.y ? model.y.toFixed(3) : "0.000"; color: textPrimary; font.family: "Codec Pro"; font.pixelSize: 9; width: 100 }
                                    Text { text: model.z ? model.z.toFixed(3) : "0.000"; color: textPrimary; font.family: "Codec Pro"; font.pixelSize: 9; width: 100 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Parse CSV from file URL - Show mapping dialog first
    function parseCSVFromFile(fileUrl) {
        var filePath = fileUrl.toString().replace("file://", "")
        console.log("Loading CSV from:", filePath)

        var xhr = new XMLHttpRequest()
        xhr.open("GET", fileUrl, true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.responseText && xhr.responseText.length > 0) {
                    // Store CSV content
                    root.csvContentCache = xhr.responseText

                    // Prepare preview data
                    var lines = xhr.responseText.split('\n')
                    mappingDialog.csvData = []
                    for (var i = 0; i < Math.min(11, lines.length); i++) {
                        var line = lines[i].trim()
                        if (line.length > 0) {
                            mappingDialog.csvData.push(line.split(','))
                        }
                    }

                    // Show mapping dialog
                    mappingDialog.open()
                } else {
                    console.error("No data loaded from file")
                }
            }
        }
        xhr.send()
    }

    // Recalculate Coordinate System Bounds
    function recalculateBounds() {
        if (!pointsCanvas || pointsCanvas.width <= 0 || pointsCanvas.height <= 0)
            return

        if (importedPoints.count === 0 && (!drawnShapes || drawnShapes.length === 0))
            return

        var minX = 999999999, maxX = -999999999
        var minY = 999999999, maxY = -999999999

        // Include points
        for (var i = 0; i < importedPoints.count; i++) {
            var pt = importedPoints.get(i)
            if (pt.x < minX) minX = pt.x
            if (pt.x > maxX) maxX = pt.x
            if (pt.y < minY) minY = pt.y
            if (pt.y > maxY) maxY = pt.y
        }

        // Include drawn geometry
        if (drawnShapes && drawnShapes.length > 0) {
            for (var k = 0; k < drawnShapes.length; k++) {
                var s = drawnShapes[k]
                if (s.type === "line" || s.type === "measure_line") {
                    minX = Math.min(minX, s.x1, s.x2); maxX = Math.max(maxX, s.x1, s.x2)
                    minY = Math.min(minY, s.y1, s.y2); maxY = Math.max(maxY, s.y1, s.y2)
                } else if (s.type === "circle") {
                    minX = Math.min(minX, s.cx - s.radius); maxX = Math.max(maxX, s.cx + s.radius)
                    minY = Math.min(minY, s.cy - s.radius); maxY = Math.max(maxY, s.cy + s.radius)
                } else if (s.type === "rectangle") {
                    minX = Math.min(minX, s.x, s.x + s.w); maxX = Math.max(maxX, s.x, s.x + s.w)
                    minY = Math.min(minY, s.y, s.y + s.h); maxY = Math.max(maxY, s.y, s.y + s.h)
                } else if ((s.type === "measure_poly" || s.type === "polygon" || s.type === "polyline" || s.type === "boundary") && s.points) {
                    for (var p = 0; p < s.points.length; p++) {
                        var sp = s.points[p]
                        minX = Math.min(minX, sp.x); maxX = Math.max(maxX, sp.x)
                        minY = Math.min(minY, sp.y); maxY = Math.max(maxY, sp.y)
                    }
                }
            }
        }

        if (minX > maxX) {
            minX = -50; maxX = 50; minY = -50; maxY = 50
        }

        var rangeX = maxX - minX
        var rangeY = maxY - minY
        var scale = Math.min((pointsCanvas.width - 100) / (rangeX || 1), (pointsCanvas.height - 100) / (rangeY || 1))

        if (scale === 0 || !isFinite(scale)) scale = 1.0

        fitScale = scale
        fitOffsetX = 50 - minX * scale
        fitOffsetY = pointsCanvas.height - 50 + minY * scale

        pointsCanvas.requestPaint()
    }

    // Convert Screen coordinates to World coordinates
    function screenToWorld(sx, sy) {
        // screenX = fitOffsetX + worldX * fitScale * canvasScale + canvasOffsetX
        // worldX = (screenX - canvasOffsetX - fitOffsetX) / (fitScale * canvasScale)

        var totalScale = fitScale * canvasScale
        var wx = (sx - canvasOffsetX - fitOffsetX) / totalScale
        var wy = -(sy - canvasOffsetY - fitOffsetY) / totalScale // Inverted Y
        return { x: wx, y: wy }
    }

    // Convert World coordinates to Screen coordinates
    function worldToScreen(wx, wy) {
        // Inverse of screenToWorld:
        // sx = canvasOffsetX + fitOffsetX + wx * (fitScale * canvasScale)
        // sy = canvasOffsetY + fitOffsetY - wy * (fitScale * canvasScale)
        var totalScale = fitScale * canvasScale
        var sx = canvasOffsetX + fitOffsetX + wx * totalScale
        var sy = canvasOffsetY + fitOffsetY - wy * totalScale // Inverted Y (sy = offset - wy*scale)
        // Check wy calc:
        // screenToWorld: wy = -(sy - offset) / scale => -wy*scale = sy - offset => sy = offset - wy*scale. Correct.
        return { x: sx, y: sy }
    }
    // Parse CSV with column mapping
    // Helper function to find point near click
    function findPointAtPosition(mouseX, mouseY, requireSnapEnabled) {
        if (requireSnapEnabled !== false && !snapEnabled) return -1
        if (importedPoints.count === 0) return -1
        var pickRadius = Math.max(8, pickboxSize * 1.5)

        // Check each point to see if click is near it
        var bestIdx = -1
        var bestDist = pickRadius
        for (var j = 0; j < importedPoints.count; j++) {
            var point = importedPoints.get(j)
            var screenPos = worldToScreen(point.x, point.y)
            var dx = mouseX - screenPos.x
            var dy = mouseY - screenPos.y
            var distance = Math.sqrt(dx * dx + dy * dy)
            if (distance <= bestDist) {  // click radius
                bestDist = distance
                bestIdx = j
            }
        }

        return bestIdx
    }

    function findSnapWorldPos(mouseX, mouseY) {
        if (!snapEnabled) return null
        var snapRadius = Math.max(8, pickboxSize * 1.5, snapMarkerSize * 0.5)
        var best = null
        var bestDist = snapRadius

        function considerPoint(wx, wy) {
            var screenPos = worldToScreen(wx, wy)
            var dx = mouseX - screenPos.x
            var dy = mouseY - screenPos.y
            var distance = Math.sqrt(dx * dx + dy * dy)
            if (distance <= bestDist) {
                bestDist = distance
                best = { x: wx, y: wy }
            }
        }

        for (var i = 0; i < importedPoints.count; i++) {
            var pt = importedPoints.get(i)
            considerPoint(pt.x, pt.y)
        }

        if (drawnShapes && drawnShapes.length > 0) {
            for (var s = 0; s < drawnShapes.length; s++) {
                var shape = drawnShapes[s]
                if (shape.type === "line" || shape.type === "measure_line") {
                    considerPoint(shape.x1, shape.y1)
                    considerPoint(shape.x2, shape.y2)
                } else if (shape.type === "rectangle") {
                    considerPoint(shape.x, shape.y)
                    considerPoint(shape.x + shape.w, shape.y)
                    considerPoint(shape.x, shape.y + shape.h)
                    considerPoint(shape.x + shape.w, shape.y + shape.h)
                } else if (shape.type === "circle") {
                    considerPoint(shape.cx, shape.cy)
                } else if ((shape.type === "polyline" || shape.type === "polygon" || shape.type === "boundary" || shape.type === "measure_poly") && shape.points) {
                    for (var p = 0; p < shape.points.length; p++) {
                        considerPoint(shape.points[p].x, shape.points[p].y)
                    }
                }
            }
        }

        return best
    }

    function getWorldPosWithSnap(mouseX, mouseY) {
        var snapPos = findSnapWorldPos(mouseX, mouseY)
        if (snapPos) return { x: snapPos.x, y: snapPos.y, snapped: true }
        var worldPos = screenToWorld(mouseX, mouseY)
        return { x: worldPos.x, y: worldPos.y, snapped: false }
    }
    function calculateDistance(x1, y1, x2, y2) {
        var dx = x2 - x1
        var dy = y2 - y1
        return Math.sqrt(dx * dx + dy * dy)
    }

    function calculateBearing(x1, y1, x2, y2) {
        var dx = x2 - x1
        var dy = y2 - y1
        var theta = Math.atan2(dy, dx) // radians
        var deg = theta * 180 / Math.PI
        // Convert arithmetic angle to geographic bearing (0 North, 90 East)
        // Standard Math.atan2: 0=East, 90=North.
        // Survey Bearing: 0=North, clockwise.
        // Survey = 90 - Math
        var bearing = 90 - deg
        if (bearing < 0) bearing += 360
        return bearing
    }

    function formatDMS(dd) {
        var d = Math.floor(dd);
        var m = Math.floor((dd - d) * 60);
        var s = Math.round(((dd - d) * 60 - m) * 60);
        if (s === 60) { s = 0; m++; }
        if (m === 60) { m = 0; d++; }
        return d + "° " + m + "' " + s + '"';
    }

    // Surveying quadrantal bearing string (e.g., "N 12° 34' 56\" E")
    function formatQuadrantBearing(azimuthDeg) {
        var az = azimuthDeg % 360
        if (az < 0) az += 360

        var ns = "N"
        var ew = "E"
        var angle = 0

        if (az >= 0 && az <= 90) {
            ns = "N"; ew = "E"; angle = az
        } else if (az > 90 && az <= 180) {
            ns = "S"; ew = "E"; angle = 180 - az
        } else if (az > 180 && az <= 270) {
            ns = "S"; ew = "W"; angle = az - 180
        } else {
            ns = "N"; ew = "W"; angle = 360 - az
        }

        return ns + " " + formatDMS(angle) + " " + ew
    }

    function calculatePolygonArea(points) {
        var area = 0.0
        if (points.length < 3) return 0.0
        var j = points.length - 1
        for (var i = 0; i < points.length; i++) {
            area += (points[j].x + points[i].x) * (points[j].y - points[i].y)
            j = i
        }
        return Math.abs(area / 2.0)
    }

    function lineDashForType(lineType) {
        switch (lineType) {
        case "Dashed":
            return [8, 6]
        case "Center":
            return [12, 4, 2, 4]
        case "Hidden":
            return [4, 4]
        default:
            return []
        }
    }

    function applyLineDash(ctx, lineType) {
        var effectiveType = (lineType && lineType.length > 0) ? lineType : "Continuous"
        var dash = lineDashForType(effectiveType)
        if (!dash || dash.length === 0) {
            ctx.setLineDash([])
            return
        }
        var scale = lineTypeScale > 0 ? lineTypeScale : 1.0
        var scaled = []
        for (var i = 0; i < dash.length; i++) {
            scaled.push(dash[i] * scale)
        }
        ctx.setLineDash(scaled)
    }

    function drawDimLabel(ctx, text, x, y, color) {
        if (!text) return
        ctx.save()
        ctx.font = "bold 11px sans-serif"
        ctx.textBaseline = "alphabetic"
        var pad = 3
        var metrics = ctx.measureText(text)
        var w = metrics.width
        ctx.fillStyle = "rgba(20,20,20,0.8)"
        ctx.fillRect(x - w / 2 - pad, y - 12, w + pad * 2, 14)
        ctx.fillStyle = color || "#FFD54F"
        ctx.fillText(text, x - w / 2, y - 2)
        ctx.restore()
    }

    function parseWithMapping(nameIdx, xIdx, yIdx, zIdx) {
        // importedPoints.clear() // Do not clear local model, let DB refresh handle it

        root.isBulkImporting = true // Suppress updates
        var lines = root.csvContentCache.split('\n')
        var pointCount = 0

        // Skip header (first line)
        for (var i = 1; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.length === 0) continue

            var parts = line.split(',')
            if (parts.length > Math.max(nameIdx, xIdx, yIdx)) {
                var name = parts[nameIdx].trim()
                var x = parseFloat(parts[xIdx])
                var y = parseFloat(parts[yIdx])
                var z = (zIdx < 5 && zIdx < parts.length) ? parseFloat(parts[zIdx]) : 0

                if (!isNaN(x) && !isNaN(y)) {
                    // Save to Database
                    Database.addPoint(name, x, y, z, "CSV", "Imported")
                    pointCount++
                }
            }
        }

        root.isBulkImporting = false
        // Now force a single refresh
        importedPoints.clear()
        loadPointsFromDB()

        console.log("Imported " + pointCount + " points to Database")
        recalculateBounds()
        if (pointsCanvas) pointsCanvas.requestPaint()
        return pointCount
    }

    // ============ CAD INTERFACE ============
    Rectangle {
        id: cadInterface
        anchors.fill: parent
        color: bgColor
        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Top Menu Bar (AutoCAD style)
            Rectangle {
                z: 5
                Layout.fillWidth: true
                Layout.preferredHeight: 0
                Layout.minimumHeight: 0
                Layout.maximumHeight: 0
                visible: false
                color: "#1A1A1A"
                border.color: "#3A3A3A"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Rectangle {
                        width: 36
                        height: 18
                        radius: 4
                        color: accentColor
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: "CAD"
                            font.family: "Codec Pro"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: "white"
                        }
                    }

                    Text {
                        text: "Engineering CAD"
                        font.family: "Codec Pro"
                        font.pixelSize: 10
                        color: textPrimary
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Rectangle {
                        width: 1
                        height: 18
                        color: "#3A3A3A"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // File Menu with dropdown
                    Rectangle {
                        implicitWidth: fileMenuText.implicitWidth + 22
                        implicitHeight: 30
                        radius: 2
                        color: fileMenuMa.containsMouse || fileMenu.visible ? "#333333" : "transparent"

                        Text {
                            id: fileMenuText
                            anchors.centerIn: parent
                            text: "File"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            color: textPrimary
                        }

                        MouseArea {
                            id: fileMenuMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: fileMenu.open()
                        }

                        Menu {
                            id: fileMenu
                            parent: menuOverlay
                            z: 2000
                            modal: false
                            closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
                            x: fileMenuMa.mapToItem(menuOverlay, 0, fileMenuMa.height).x
                            y: fileMenuMa.mapToItem(menuOverlay, 0, fileMenuMa.height).y
                            background: Rectangle {
                                color: "#2A2A2A"
                                border.color: "#4A4A4A"
                                radius: 4
                            }

                            StyledMenuItem {
                                text: "Import CSV..."
                                onTriggered: csvFileDialog.open()
                            }
                            StyledMenuItem {
                                text: "Export CSV..."
                                enabled: importedPoints.count > 0
                                onTriggered: exportCsvDialog.open()
                            }
                            MenuSeparator { }
                            StyledMenuItem {
                                text: "Point Manager..."
                                onTriggered: openPointManager()
                            }
                            StyledMenuItem {
                                text: "Add Control Point..."
                                onTriggered: handleToolClick({action: "addPoint"})
                            }
                            StyledMenuItem {
                                text: "CRS Settings..."
                                onTriggered: crsDialog.open()
                            }
                        }
                    }



                    // View Menu
                    Rectangle {
                        implicitWidth: viewMenuText.implicitWidth + 22
                        implicitHeight: 30
                        radius: 2
                        color: viewMenuMa.containsMouse || viewMenu.visible ? "#333333" : "transparent"

                        Text {
                            id: viewMenuText
                            anchors.centerIn: parent
                            text: "View"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            color: textPrimary
                        }

                        MouseArea {
                            id: viewMenuMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: viewMenu.open()
                        }

                        Menu {
                            id: viewMenu
                            parent: menuOverlay
                            z: 2000
                            modal: false
                            closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
                            x: viewMenuMa.mapToItem(menuOverlay, 0, viewMenuMa.height).x
                            y: viewMenuMa.mapToItem(menuOverlay, 0, viewMenuMa.height).y
                            background: Rectangle {
                                color: "#2A2A2A"
                                border.color: "#4A4A4A"
                                radius: 4
                            }

                            StyledMenuItem {
                                text: "Grid Settings..."
                                onTriggered: gridSettingsDialog.open()
                            }
                            StyledMenuItem {
                                text: showGrid ? "Hide Grid" : "Show Grid"
                                checkable: true
                                checked: showGrid
                                onTriggered: { showGrid = !showGrid; pointsCanvas.requestPaint() }
                            }
                            StyledMenuItem {
                                text: snapEnabled ? "Disable Snap" : "Enable Snap"
                                checkable: true
                                checked: snapEnabled
                                onTriggered: { snapEnabled = !snapEnabled }
                            }
                            StyledMenuItem {
                                text: showPointLabels ? "Hide Point Labels" : "Show Point Labels"
                                checkable: true
                                checked: showPointLabels
                                onTriggered: { showPointLabels = !showPointLabels; pointsCanvas.requestPaint() }
                            }
                            MenuSeparator { }
                            StyledMenuItem {
                                text: showDTM ? "Hide 2D DTM" : "Show 2D DTM"
                                checkable: true
                                checked: showDTM
                                onTriggered: { showDTM = !showDTM; pointsCanvas.requestPaint() }
                            }
                            StyledMenuItem {
                                text: showTIN ? "Hide TIN" : "Show TIN"
                                checkable: true
                                checked: showTIN
                                onTriggered: { showTIN = !showTIN; pointsCanvas.requestPaint() }
                            }
                            StyledMenuItem {
                                text: "Clear Contours"
                                enabled: contourLines && contourLines.length > 0
                                onTriggered: { contourLines = []; pointsCanvas.requestPaint() }
                            }
                        }
                    }

                    // Survey Menu
                    Rectangle {
                        implicitWidth: surveyMenuText.implicitWidth + 22
                        implicitHeight: 30
                        radius: 2
                        color: surveyMenuMa.containsMouse || surveyMenu.visible ? "#333333" : "transparent"

                        Text {
                            id: surveyMenuText
                            anchors.centerIn: parent
                            text: "Survey"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            color: textPrimary
                        }

                        MouseArea {
                            id: surveyMenuMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: surveyMenu.open()
                        }

                        Menu {
                            id: surveyMenu
                            parent: menuOverlay
                            z: 2000
                            modal: false
                            closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
                            x: surveyMenuMa.mapToItem(menuOverlay, 0, surveyMenuMa.height).x
                            y: surveyMenuMa.mapToItem(menuOverlay, 0, surveyMenuMa.height).y
                            background: Rectangle {
                                color: "#2A2A2A"
                                border.color: "#4A4A4A"
                                radius: 4
                            }

                            StyledMenuItem {
                                text: "Measure Distance"
                                onTriggered: { selectedTool = 10; measurePoints = []; drawingState = { active: false } }
                            }
                            StyledMenuItem {
                                text: "Measure Area"
                                onTriggered: { selectedTool = 11; measurePoints = []; drawingState = { active: false } }
                            }
                            StyledMenuItem {
                                text: "COGO (Bearing/Distance)..."
                                onTriggered: openCogoFromSelection()
                            }
                            StyledMenuItem {
                                text: "Add Control Point..."
                                onTriggered: handleToolClick({action: "addPoint"})
                            }
                            StyledMenuItem {
                                text: "Point Manager..."
                                onTriggered: openPointManager()
                            }
                            StyledMenuItem {
                                text: "Create Buffer..."
                                onTriggered: handleToolClick({action: "buffer"})
                            }
                            StyledMenuItem {
                                text: "Boundary Tool"
                                onTriggered: selectedTool = 12
                            }
                            MenuSeparator { }
                            StyledMenuItem {
                                text: "Clear Measurements"
                                onTriggered: clearTransientStates(false)
                            }
                        }
                    }

                    // Draft Menu
                    Rectangle {
                        implicitWidth: draftMenuText.implicitWidth + 22
                        implicitHeight: 30
                        radius: 2
                        color: draftMenuMa.containsMouse || draftMenu.visible ? "#333333" : "transparent"

                        Text {
                            id: draftMenuText
                            anchors.centerIn: parent
                            text: "Draft"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            color: textPrimary
                        }

                        MouseArea {
                            id: draftMenuMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: draftMenu.open()
                        }

                        Menu {
                            id: draftMenu
                            parent: menuOverlay
                            z: 2000
                            modal: false
                            closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
                            x: draftMenuMa.mapToItem(menuOverlay, 0, draftMenuMa.height).x
                            y: draftMenuMa.mapToItem(menuOverlay, 0, draftMenuMa.height).y
                            background: Rectangle {
                                color: "#2A2A2A"
                                border.color: "#4A4A4A"
                                radius: 4
                            }

                            StyledMenuItem { text: "Line"; onTriggered: selectedTool = 3 }
                            StyledMenuItem { text: "Circle"; onTriggered: selectedTool = 4 }
                            StyledMenuItem { text: "Rectangle"; onTriggered: selectedTool = 5 }
                            StyledMenuItem { text: "Polyline"; onTriggered: selectedTool = 6 }
                            StyledMenuItem { text: "Polygon"; onTriggered: selectedTool = 7 }
                            StyledMenuItem { text: "Boundary"; onTriggered: selectedTool = 12 }
                            MenuSeparator { }
                            StyledMenuItem { text: "Undo"; enabled: undoStack.length > 0; onTriggered: root.undo() }
                            StyledMenuItem { text: "Redo"; enabled: redoStack.length > 0; onTriggered: root.redo() }
                        }
                    }

                    // Settings Menu
                    Rectangle {
                        implicitWidth: settingsMenuText.implicitWidth + 22
                        implicitHeight: 30
                        radius: 2
                        color: settingsMenuMa.containsMouse || settingsMenu.visible ? "#333333" : "transparent"

                        Text {
                            id: settingsMenuText
                            anchors.centerIn: parent
                            text: "Settings"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            color: textPrimary
                        }

                        MouseArea {
                            id: settingsMenuMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: settingsMenu.open()
                        }

                        Menu {
                            id: settingsMenu
                            parent: menuOverlay
                            z: 2000
                            modal: false
                            closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
                            x: settingsMenuMa.mapToItem(menuOverlay, 0, settingsMenuMa.height).x
                            y: settingsMenuMa.mapToItem(menuOverlay, 0, settingsMenuMa.height).y
                            background: Rectangle {
                                color: "#2A2A2A"
                                border.color: "#4A4A4A"
                                radius: 4
                            }

                            StyledMenuItem {
                                text: "Options..."
                                onTriggered: optionsDialog.open()
                            }
                            StyledMenuItem {
                                text: "Coordinate System..."
                                onTriggered: crsDialog.open()
                            }
                        }
                    }

                    // Earthwork Menu
                    Rectangle {
                        implicitWidth: ewMenuText.implicitWidth + 22
                        implicitHeight: 30
                        radius: 2
                        color: ewMenuMa.containsMouse || ewMenu.visible ? "#333333" : "transparent"

                        Text {
                            id: ewMenuText
                            anchors.centerIn: parent
                            text: "Earthwork"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            color: textPrimary
                        }

                        MouseArea {
                            id: ewMenuMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ewMenu.open()
                        }

                        Menu {
                            id: ewMenu
                            parent: menuOverlay
                            z: 2000
                            modal: false
                            closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
                            x: ewMenuMa.mapToItem(menuOverlay, 0, ewMenuMa.height).x
                            y: ewMenuMa.mapToItem(menuOverlay, 0, ewMenuMa.height).y
                            background: Rectangle {
                                color: "#2A2A2A"
                                border.color: "#4A4A4A"
                                radius: 4
                            }

                            StyledMenuItem {
                                text: "Generate DTM..."
                                onTriggered: handleToolClick({action: "dtm"})
                            }

                            StyledMenuItem {
                                text: "Generate Contours..."
                                enabled: dtmData !== null
                                onTriggered: handleToolClick({action: "contours"})
                            }
                            MenuSeparator { }
                            StyledMenuItem {
                                text: "Generate TIN"
                                enabled: importedPoints.count >= 3
                                onTriggered: generateTIN()
                            }
                            StyledMenuItem {
                                text: "Calculate Volume..."
                                enabled: dtmData !== null || tinData !== null
                                onTriggered: volumeDialog.open()
                            }
                            MenuSeparator { }
                            StyledMenuItem {
                                text: "Export DTM as 3D Mesh (OBJ)..."
                                enabled: dtmData !== null
                                onTriggered: exportDTMObj()
                            }
                            // End of Earthwork Menu
                        }
                    }

                    // Help Menu Item
                    MenuBarItem {
                        text: "Help"
                    }

                    Item { Layout.fillWidth: true }

                    // Grid/Snap/Zoom in menu bar
                    RowLayout {
                        spacing: 6

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 4
                            color: gridTopMa.containsMouse ? "#3A3A3A" : (showGrid ? "#2F2F2F" : "transparent")
                            border.color: showGrid ? accentColor : "transparent"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "\uf009"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 11
                                color: showGrid ? accentColor : textSecondary
                            }
                            MouseArea {
                                id: gridTopMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { showGrid = !showGrid; pointsCanvas.requestPaint() }
                            }
                            ToolTip { visible: gridTopMa.containsMouse; text: "Toggle Grid" }
                        }

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 4
                            color: snapTopMa.containsMouse ? "#3A3A3A" : (snapEnabled ? "#2F2F2F" : "transparent")
                            border.color: snapEnabled ? accentColor : "transparent"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "\uf076"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 11
                                color: snapEnabled ? accentColor : textSecondary
                            }
                            MouseArea {
                                id: snapTopMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: snapEnabled = !snapEnabled
                            }
                            ToolTip { visible: snapTopMa.containsMouse; text: "Toggle Snap" }
                        }

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 4
                            color: labelTopMa.containsMouse ? "#3A3A3A" : (showPointLabels ? "#2F2F2F" : "transparent")
                            border.color: showPointLabels ? accentColor : "transparent"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "\uf02b"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 11
                                color: showPointLabels ? accentColor : textSecondary
                            }
                            MouseArea {
                                id: labelTopMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { showPointLabels = !showPointLabels; pointsCanvas.requestPaint() }
                            }
                            ToolTip { visible: labelTopMa.containsMouse; text: "Toggle Labels" }
                        }

                        Rectangle {
                            width: 1
                            height: 18
                            color: "#3A3A3A"
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Zoom Out
                        Rectangle {
                            width: 24; height: 24; color: "transparent"; radius: 4
                            Text { anchors.centerIn: parent; text: "\uf010"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 12; color: zOutMa.containsMouse ? accentColor : textSecondary }
                            MouseArea { id: zOutMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { canvasScale = Math.max(0.1, canvasScale * 0.8); pointsCanvas.requestPaint() } }
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Zoom Display
                        Text {
                            text: Math.round(canvasScale * 100) + "%"
                            font.family: "sans-serif"
                            font.pixelSize: 10
                            color: textSecondary
                            Layout.preferredWidth: 30
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Zoom In
                        Rectangle {
                            width: 24; height: 24; color: "transparent"; radius: 4
                            Text { anchors.centerIn: parent; text: "\uf00e"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 12; color: zInMa.containsMouse ? accentColor : textSecondary }
                            MouseArea { id: zInMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { canvasScale = Math.min(10.0, canvasScale * 1.25); pointsCanvas.requestPaint() } }
                            Layout.alignment: Qt.AlignVCenter
                        }

                         // Fit (Zoom Extents)
                        Rectangle {
                            width: 24; height: 24; color: "transparent"; radius: 4
                            Text { anchors.centerIn: parent; text: "\uf31e"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 12; color: zFitMa.containsMouse ? accentColor : textSecondary }
                            MouseArea { id: zFitMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { recalculateBounds() } }
                            Layout.alignment: Qt.AlignVCenter
                            ToolTip { visible: zFitMa.containsMouse; text: "Fit to Screen" }
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                height: 0
                Layout.fillWidth: true
                Layout.preferredHeight: 0
                Layout.minimumHeight: 0
                Layout.maximumHeight: 0
                visible: false
                color: "#3A3A3A"
            }



            // Main content area
            RowLayout {
                z: 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // Left sidebar - Tools (fixed 3-column grid)
                Rectangle {
                    id: toolSidebar
                    property bool collapsed: false

                    Layout.preferredWidth: collapsed ? 40 : 160
                    Layout.fillHeight: true
                    color: darkCardBg
                    border.color: "#3A3A3A"
                    border.width: 1
                    clip: true

                    Behavior on Layout.preferredWidth {
                        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6
                        RowLayout {
                            id: toolSidebarHeader
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            spacing: 6

                            Text {
                                text: "\uf0ad"  // tools icon
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 10
                                color: accentColor
                                visible: !toolSidebar.collapsed
                            }

                            Text {
                                text: "Tools"
                                font.family: "Codec Pro"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: textPrimary
                                Layout.fillWidth: true
                                visible: !toolSidebar.collapsed
                            }

                            Rectangle {
                                width: 26
                                height: 26
                                color: collapseToolBtnMa.containsMouse ? "#3A3A3A" : "transparent"
                                radius: 4

                                Text {
                                    anchors.centerIn: parent
                                    text: toolSidebar.collapsed ? "\uf054" : "\uf053"  // chevron-right / chevron-left
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 10
                                    color: accentColor
                                }

                                MouseArea {
                                    id: collapseToolBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: toolSidebar.collapsed = !toolSidebar.collapsed
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#3A3A3A"
                            visible: !toolSidebar.collapsed
                        }

                        // Tools (scrollable 3-column grid)
                        ScrollView {
                            id: toolScroll
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            visible: !toolSidebar.collapsed
                            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                            GridLayout {
                                width: toolScroll.width
                                columns: 3
                                rowSpacing: root.toolSidebarRowSpacing
                                columnSpacing: root.toolSidebarRowSpacing
                                ToolSectionHeader { label: "Navigation" }

                                Repeater {
                                    model: navTools
                                    delegate: ToolTile {
                                        toolData: modelData
                                        onClicked: handleToolClick(toolData)
                                    }
                                }

                                ToolSectionHeader { label: "Edit"; Layout.topMargin: 4 }

                                ToolTile {
                                    toolData: ({ icon: "\uf0e2", name: "Undo", tooltip: "Undo (Ctrl+Z)" })
                                    isEnabled: undoStack && undoStack.length > 0
                                    onClicked: if (isEnabled) root.undo()
                                }

                                ToolTile {
                                    toolData: ({ icon: "\uf01e", name: "Redo", tooltip: "Redo (Ctrl+Y / Ctrl+Shift+Z)" })
                                    isEnabled: redoStack && redoStack.length > 0
                                    onClicked: if (isEnabled) root.redo()
                                }

                                ToolTile {
                                    toolData: ({ icon: "\uf12d", name: "Clear", tooltip: "Clear drawings/measurements/drafts" })
                                    onClicked: clearTransientStates(true, true)
                                }

                                ToolSectionHeader { label: "Draft"; Layout.topMargin: 4 }

                                Repeater {
                                    model: drawTools
                                    delegate: ToolTile {
                                        toolData: modelData
                                        onClicked: handleToolClick(toolData)
                                    }
                                }

                                ToolSectionHeader { label: "Survey"; Layout.topMargin: 4 }

                                Repeater {
                                    model: surveyTools
                                    delegate: ToolTile {
                                        toolData: modelData
                                        onClicked: handleToolClick(toolData)
                                    }
                                }

                                ToolSectionHeader { label: "Earthwork"; Layout.topMargin: 4 }

                                ToggleToolTile {
                                    icon: "\uf5fd"
                                    label: "DTM"
                                    tooltip: "Generate/Toggle DTM"
                                    active: showDTM && dtmData !== null && dtmData.width > 0
                                    onClicked: handleToolClick({action: "dtm"})
                                }

                                ToggleToolTile {
                                    icon: "\uf5ee"
                                    label: "Cont"
                                    tooltip: "Generate/Toggle Contours"
                                    active: showContours && contourLines.length > 0
                                    onClicked: handleToolClick({action: "contours"})
                                }

                                ToggleToolTile {
                                    icon: "\uf1b2"
                                    label: "TIN"
                                    tooltip: "Generate/Toggle TIN"
                                    active: showTIN && tinData !== null && tinData.success
                                    onClicked: handleToolClick({action: "tin"})
                                }

                                Repeater {
                                    model: [
                                        {action: "volume", icon: "\uf547", name: "Vol", tooltip: "Calculate Volume"},
                                        {action: "exportObj", icon: "\uf56d", name: "OBJ", tooltip: "Export DTM OBJ"}
                                    ]
                                    delegate: ToolTile {
                                        toolData: modelData
                                        onClicked: handleToolClick(toolData)
                                    }
                                }

                                ToolSectionHeader { label: "Display"; Layout.topMargin: 4 }

                                ToggleToolTile {
                                    icon: "\uf009"
                                    label: "Grid"
                                    tooltip: "Toggle Grid"
                                    active: showGrid
                                    onClicked: { showGrid = !showGrid; pointsCanvas.requestPaint() }
                                }

                                ToggleToolTile {
                                    icon: "\uf076"
                                    label: "Snap"
                                    tooltip: "Toggle Snap"
                                    active: snapEnabled
                                    onClicked: snapEnabled = !snapEnabled
                                }

                                ToggleToolTile {
                                    icon: "\uf02b"
                                    label: "Labels"
                                    tooltip: "Toggle Labels"
                                    active: showPointLabels
                                    onClicked: { showPointLabels = !showPointLabels; pointsCanvas.requestPaint() }
                                }

                                Repeater {
                                    model: displayTools
                                    delegate: ToolTile {
                                        toolData: modelData
                                        onClicked: handleToolClick(toolData)
                                    }
                                }

                                ToolSectionHeader { label: "Data"; Layout.topMargin: 4 }

                                Repeater {
                                    model: dataTools
                                    delegate: ToolTile {
                                        toolData: modelData
                                        onClicked: handleToolClick(toolData)
                                    }
                                }

                                Item {
                                    Layout.columnSpan: 3
                                    Layout.preferredHeight: 1
                                    height: 1
                                }
                            }
                        }
                    }
                }

                // Canvas area
                Rectangle {
                    id: canvasArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: canvasBg
                    clip: true

                    // Grid pattern + Points Canvas
                    Canvas {
                        id: pointsCanvas
                        anchors.fill: parent

                        // Auto-zoom when canvas size is ready
                        onWidthChanged: if (width > 0 && height > 0) recalculateBounds()
                        onHeightChanged: if (width > 0 && height > 0) recalculateBounds()

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            // Draw grid (World Space)
                            // Debug logs
                            // console.log("Paint: showGrid=" + showGrid + ", w=" + width + ", h=" + height)
                            if (showGrid) {
                                ctx.strokeStyle = gridColor
                                ctx.lineWidth = 1
                                ctx.beginPath()

                                // Calculate grid step based on zoom
                                // Optimization: Ensure screen step is never too small (e.g., < 20px) to prevent lag
                                var possibleSteps = [10000, 5000, 2000, 1000, 500, 200, 100, 50, 20, 10, 5, 2, 1, 0.5, 0.2, 0.1]
                                var idealStep = 100

                                if (gridMode === "Manual") {
                                    idealStep = manualGridSpacing
                                } else {
                                    for (var s=0; s<possibleSteps.length; s++) {
                                        var step = possibleSteps[s]
                                        if (step * canvasScale * fitScale >= 40) { // Target ~40px spacing minimum
                                            idealStep = step
                                        }
                                    }
                                    // Fallback if scale is too small (avoid infinite lines)
                                    if (idealStep * canvasScale * fitScale < 20) {
                                         // If still too small, force a larger step
                                         idealStep = 100 / (canvasScale * fitScale)
                                    }
                                }

                                // World Bounds Visible
                                // screen(0,0) -> worldTL
                                // screen(w,h) -> worldBR
                                var tl = screenToWorld(0, 0)
                                var br = screenToWorld(width, height)

                                var startX = Math.floor(tl.x / idealStep) * idealStep
                                var endX = Math.ceil(br.x / idealStep) * idealStep
                                var startY = Math.floor(br.y / idealStep) * idealStep // Y up
                                var endY = Math.ceil(tl.y / idealStep) * idealStep

                                // Vertical lines
                                for (var gx = startX; gx <= endX; gx += idealStep) {
                                    var scrTop = worldToScreen(gx, tl.y)
                                    var scrBot = worldToScreen(gx, br.y)
                                    // Should be strictly vertical screen X ... wait, worldToScreen logic:
                                    // sx = ... + wx * scale. So constant wx = constant sx.
                                    var scrX = worldToScreen(gx, 0).x
                                    ctx.moveTo(scrX, 0)
                                    ctx.lineTo(scrX, height)
                                }

                                // Horizontal lines
                                for (var gy = startY; gy <= endY; gy += idealStep) {
                                    var scrY = worldToScreen(0, gy).y
                                    ctx.moveTo(0, scrY)
                                    ctx.lineTo(width, scrY)
                                }
                                ctx.stroke()
                            }

                            // Draw World Origin (0,0) - Red Crosshair attached to grid
                            var origin = worldToScreen(0,0)
                            // Only draw if within bounds (optional, but canvas clips anyway)
                            /*
                            if (origin.x >= -20 && origin.x <= width+20 && origin.y >= -20 && origin.y <= height+20) {
                                ctx.save()
                                ctx.strokeStyle = "#FF0000"
                                ctx.lineWidth = 2
                                ctx.beginPath()
                                ctx.moveTo(origin.x - 10, origin.y)
                                ctx.lineTo(origin.x + 10, origin.y)
                                ctx.moveTo(origin.x, origin.y - 10)
                                ctx.lineTo(origin.x, origin.y + 10)
                                ctx.stroke()
                                ctx.restore()
                            }
                            */
                            // User asked specifically for "crosshair in red must be attached to a grid"
                            // If they mean the Origin:
                            ctx.save()
                            ctx.strokeStyle = "#FF0000"
                            ctx.lineWidth = 2
                            ctx.beginPath()
                            ctx.moveTo(origin.x - 15, origin.y)
                            ctx.lineTo(origin.x + 15, origin.y)
                            ctx.moveTo(origin.x, origin.y - 15)
                            ctx.lineTo(origin.x, origin.y + 15)
                            ctx.stroke()
                            // Label Origin
                            ctx.fillStyle = "#FF0000"
                            ctx.font = "10px sans-serif"
                            ctx.fillText("(0,0)", origin.x + 5, origin.y - 5)
                            ctx.restore()

                            // Draw DTM (Digital Terrain Model) as colored elevation map
                            if (showDTM && dtmData && dtmData.width > 0) {
                                ctx.save()
                                var dtmWidth = dtmData.width
                                var dtmHeight = dtmData.height
                                var minElev = dtmData.minElev
                                var maxElev = dtmData.maxElev
                                var elevRange = maxElev - minElev

                                // Helper function to get elevation color
                                function getElevationColor(elev) {
                                    if (elev === -9999) return "rgba(0,0,0,0)" // Nodata = transparent

                                    var normalized = (elev - minElev) / elevRange
                                    // Color gradient: blue (low) -> green -> yellow -> red (high)
                                    var r, g, b
                                    if (normalized < 0.25) {
                                        var t = normalized * 4
                                        r = 0; g = Math.floor(t * 255); b = 255
                                    } else if (normalized < 0.5) {
                                        var t = (normalized - 0.25) * 4
                                        r = 0; g = 255; b = Math.floor((1-t) * 255)
                                    } else if (normalized < 0.75) {
                                        var t = (normalized - 0.5) * 4
                                        r = Math.floor(t * 255); g = 255; b = 0
                                    } else {
                                        var t = (normalized - 0.75) * 4
                                        r = 255; g = Math.floor((1-t) * 255); b = 0
                                    }
                                    return "rgba(" + r + "," + g + "," + b + ",0.5)"
                                }

                                // Draw DTM pixels
                                var pixelWidth = dtmData.pixelWidth
                                var pixelHeight = Math.abs(dtmData.pixelHeight)

                           for (var row = 0; row < dtmHeight; row++) {
                                    for (var col = 0; col < dtmWidth; col++) {
                                        var idx = row * dtmWidth + col
                                        var elev = dtmData.data[idx]

                                        // Convert DTM pixel to world coordinates
                                        var worldX = dtmData.originX + col * pixelWidth
                                        var worldY = dtmData.originY - row * pixelHeight

                                        // Convert to screen coordinates
                                        var screen = worldToScreen(worldX, worldY)
                                        var nextScreen = worldToScreen(worldX + pixelWidth, worldY - pixelHeight)

                                        var screenWidth = Math.abs(nextScreen.x - screen.x)
                                        var screenHeight = Math.abs(nextScreen.y - screen.y)

                                        ctx.fillStyle = getElevationColor(elev)
                                        ctx.fillRect(screen.x, screen.y, screenWidth, screenHeight)
                                    }
                                }
                                ctx.restore()
                            }

                            // Draw TIN (Triangulated Irregular Network)
                            if (showTIN && tinData && tinData.success) {
                                ctx.save()
                                ctx.strokeStyle = "#00CCCC" // Cyan for TIN edges
                                ctx.lineWidth = 0.5

                                var vertices = tinData.vertices
                                var triangles = tinData.triangles

                                // Get elevation range for coloring
                                var minZ = 999999, maxZ = -999999
                                for (var vi = 0; vi < vertices.length; vi++) {
                                    var z = vertices[vi].z
                                    if (z < minZ) minZ = z
                                    if (z > maxZ) maxZ = z
                                }
                                var zRange = maxZ - minZ

                                // Draw each triangle (stride of 3)
                                for (var ti = 0; ti < triangles.length; ti += 3) {
                                    if(ti + 2 >= triangles.length) break

                                    var i0 = triangles[ti]
                                    var i1 = triangles[ti+1]
                                    var i2 = triangles[ti+2]

                                    if (ti === 0) console.log("Rendering TIN tri 0:", i0, i1, i2)

                                    if (i0 === undefined || i1 === undefined || i2 === undefined) continue
                                    if (i0 >= vertices.length || i1 >= vertices.length || i2 >= vertices.length) continue

                                    var v0 = vertices[i0], v1 = vertices[i1], v2 = vertices[i2]
                                    var p0 = worldToScreen(v0.x, v0.y)
                                    var p1 = worldToScreen(v1.x, v1.y)
                                    var p2 = worldToScreen(v2.x, v2.y)

                                    // --- 3D Lighting Effect (Hillshade) ---
                                    // Calculate surface normal assuming counter-clockwise winding
                                    var ax = v1.x - v0.x, ay = v1.y - v0.y, az = v1.z - v0.z
                                    var bx = v2.x - v0.x, by = v2.y - v0.y, bz = v2.z - v0.z

                                    // Cross product for normal (nx, ny, nz)
                                    var nx = ay * bz - az * by
                                    var ny = az * bx - ax * bz
                                    var nz = ax * by - ay * bx

                                    // Normalize normal
                                    var len = Math.sqrt(nx*nx + ny*ny + nz*nz)
                                    if (len > 0) { nx /= len; ny /= len; nz /= len }

                                    // Light direction (from Top-Left, classic cartography)
                                    var lx = -0.5, ly = 0.5, lz = 0.7
                                    var lLen = Math.sqrt(lx*lx + ly*ly + lz*lz)
                                    lx/=lLen; ly/=lLen; lz/=lLen

                                    // Dot product for intensity (0.0 to 1.0)
                                    var intensity = nx*lx + ny*ly + nz*lz
                                    // Clamp and bias for ambient light
                                    intensity = Math.max(0.2, Math.min(1.0, 0.4 + 0.6 * intensity))

                                    // Base Color (Elevation Gradient)
                                    var avgZ = (v0.z + v1.z + v2.z) / 3
                                    var normZ = zRange > 0.001 ? (avgZ - minZ) / zRange : 0.5

                                    // Simple Earth Palette
                                    var r, g, b
                                    if (normZ < 0.3) {      // Low: Green
                                        r = 50; g = 160; b = 50
                                    } else if (normZ < 0.7) { // Mid: Yellow/Brown
                                        r = 200; g = 180; b = 50
                                    } else {                  // High: White/Grey
                                        r = 220; g = 220; b = 220
                                    }

                                    // Apply lighting intensity
                                    r = Math.floor(r * intensity)
                                    g = Math.floor(g * intensity)
                                    b = Math.floor(b * intensity)

                                    ctx.fillStyle = "rgba(" + r + "," + g + "," + b + ",0.85)" // More opaque for solid look
                                    ctx.strokeStyle = "rgba(0,0,0,0.1)" // Faint wireframe for definition

                                    // Draw filled triangle
                                    ctx.beginPath()
                                    ctx.moveTo(p0.x, p0.y)
                                    ctx.lineTo(p1.x, p1.y)
                                    ctx.lineTo(p2.x, p2.y)
                                    ctx.closePath()
                                    ctx.fill()
                                    ctx.stroke()
                                }
                                ctx.restore()
                            }

                            // Draw imported points
                                // Draw Contours
                                if (showContours && contourLines && contourLines.length > 0) {
                                    ctx.lineWidth = 1.0
                                    ctx.strokeStyle = "orange"
                                    ctx.font = "10px sans-serif"
                                    ctx.textAlign = "center"
                                    ctx.textBaseline = "middle"

                                    for (var c = 0; c < contourLines.length; c++) {
                                        var line = contourLines[c]
                                        var pts = line.points
                                        if (pts.length < 2) continue

                                        ctx.beginPath()
                                        var start = worldToScreen(pts[0].x, pts[0].y)
                                        ctx.moveTo(start.x, start.y)

                                        for (var p = 1; p < pts.length; p++) {
                                            var next = worldToScreen(pts[p].x, pts[p].y)
                                            ctx.lineTo(next.x, next.y)
                                        }
                                        ctx.stroke()

                                        // Draw Elevation Label (every ~5th contour or specific points logic could help, but labeling all valid ones for now)
                                        // Draw at center of line
                                        if (pts.length > 1) {
                                            var midIdx = Math.floor(pts.length / 2)
                                            var midPt = worldToScreen(pts[midIdx].x, pts[midIdx].y)

                                            // Only draw label if inside user view
                                            if (midPt.x >= 0 && midPt.x <= width && midPt.y >= 0 && midPt.y <= height) {
                                                var text = line.elevation.toFixed(1)
                                                var textWidth = ctx.measureText(text).width

                                                // Background for readability
                                                ctx.fillStyle = "rgba(30,30,30,0.8)"
                                                ctx.fillRect(midPt.x - textWidth/2 - 2, midPt.y - 6, textWidth + 4, 12)

                                                ctx.fillStyle = "#FFA500" // Orange
                                                ctx.fillText(text, midPt.x, midPt.y)
                                            }
                                        }
                                    }
                                }
                            // Draw imported points
                            if (importedPoints.count > 0) {
                                ctx.fillStyle = "#FF5555"
                                for (var i = 0; i < importedPoints.count; i++) {
                                    var pt = importedPoints.get(i)
                                    var pos = worldToScreen(pt.x, pt.y)

                                    if (selectedPoints.indexOf(i) >= 0) {
                                        ctx.fillStyle = "#FFFF00"
                                        ctx.beginPath()
                                        ctx.arc(pos.x, pos.y, 5, 0, 2 * Math.PI)
                                        ctx.fill()
                                        ctx.fillStyle = "#FF5555"
                                    } else {
                                        // Unique symbol for Control Points (with Code)
                                        if (pt.code && pt.code.length > 0) {
                                            ctx.fillStyle = "#00FF00" // Green for Control Points
                                            ctx.beginPath()
                                            // Draw Triangle
                                            ctx.moveTo(pos.x, pos.y - 5)
                                            ctx.lineTo(pos.x + 4, pos.y + 3)
                                            ctx.lineTo(pos.x - 4, pos.y + 3)
                                            ctx.closePath()
                                            ctx.fill()
                                        } else {
                                            // Standard Point
                                            ctx.fillStyle = "#FF5555"
                                            ctx.beginPath()
                                            ctx.arc(pos.x, pos.y, 2, 0, 2 * Math.PI)
                                            ctx.fill()
                                        }
                                    }
                                    // Draw Point Label
                                    if (showPointLabels && pt.name) {
                                        ctx.fillStyle = "#B0B0B0"
                                        ctx.font = "10px sans-serif"
                                        ctx.fillText(pt.name, pos.x + 8, pos.y + 3)
                                        ctx.fillStyle = "#FF5555"
                                    }
                                }
                            }
                                // Draw drawn shapes (Lines, Circles, Rectangles)
                                if (drawnShapes && drawnShapes.length > 0) {
                                    for (var k = 0; k < drawnShapes.length; k++) {
                                        var shape = drawnShapes[k]
                                        ctx.save()
                                        ctx.lineWidth = 1.5
                                        ctx.strokeStyle = shape.color || "white"
                                        ctx.beginPath()
                                        var skipFinalStroke = false

                                        if (shape.type === "line") {
                                            applyLineDash(ctx, shape.lineType)
                                            var p1 = worldToScreen(shape.x1, shape.y1)
                                            var p2 = worldToScreen(shape.x2, shape.y2)
                                            ctx.moveTo(p1.x, p1.y)
                                            ctx.lineTo(p2.x, p2.y)
                                        } else if (shape.type === "circle") {
                                            applyLineDash(ctx, shape.lineType)
                                            var c = worldToScreen(shape.cx, shape.cy)
                                            // Scale radius from world to screen
                                            var r = shape.radius * fitScale * canvasScale
                                            ctx.arc(c.x, c.y, r, 0, 2 * Math.PI)
                                        } else if (shape.type === "rectangle") {
                                            applyLineDash(ctx, shape.lineType)
                                            var pStart = worldToScreen(shape.x, shape.y)
                                            // Dimensions need to be scaled
                                            var sw = shape.w * fitScale * canvasScale
                                            var sh = -shape.h * fitScale * canvasScale // Y inverted
                                            ctx.rect(pStart.x, pStart.y, sw, sh)
                                        } else if (shape.type === "polyline" && shape.points) {
                                            applyLineDash(ctx, shape.lineType)
                                            var pts = shape.points
                                            if (pts.length > 1) {
                                                var p0 = worldToScreen(pts[0].x, pts[0].y)
                                                ctx.moveTo(p0.x, p0.y)
                                                for (var pp = 1; pp < pts.length; pp++) {
                                                    var pN = worldToScreen(pts[pp].x, pts[pp].y)
                                                    ctx.lineTo(pN.x, pN.y)
                                                }
                                            }
                                        } else if (shape.type === "boundary" && shape.points) {
                                            var pts = shape.points
                                            if (pts.length > 2) {
                                                ctx.strokeStyle = shape.color || "#FFB020"
                                                ctx.fillStyle = shape.fillColor || "rgba(255,176,32,0.07)"
                                                ctx.lineWidth = 2
                                                ctx.setLineDash([6, 4])

                                                var p0 = worldToScreen(pts[0].x, pts[0].y)
                                                ctx.moveTo(p0.x, p0.y)
                                                for (var pp = 1; pp < pts.length; pp++) {
                                                    var pN = worldToScreen(pts[pp].x, pts[pp].y)
                                                    ctx.lineTo(pN.x, pN.y)
                                                }
                                                ctx.closePath()
                                                ctx.fill()
                                                ctx.stroke()
                                                skipFinalStroke = true
                                            }
                                        } else if (shape.type === "polygon" && shape.points) {
                                            applyLineDash(ctx, shape.lineType)
                                            var pts = shape.points
                                            if (pts.length > 0) {
                                                var p0 = worldToScreen(pts[0].x, pts[0].y)
                                                ctx.moveTo(p0.x, p0.y)
                                                for (var pp = 1; pp < pts.length; pp++) {
                                                    var pN = worldToScreen(pts[pp].x, pts[pp].y)
                                                    ctx.lineTo(pN.x, pN.y)
                                                }
                                                ctx.closePath()
                                                ctx.save()
                                                ctx.fillStyle = shape.fillColor || "rgba(255,87,34,0.12)"
                                                ctx.fill()
                                                ctx.restore()
                                            }
                                        } else if (shape.type === "measure_line") {
                                            // Render Measure Distance Line
                                            var p1 = worldToScreen(shape.x1, shape.y1)
                                            var p2 = worldToScreen(shape.x2, shape.y2)
                                            ctx.moveTo(p1.x, p1.y)
                                            ctx.lineTo(p2.x, p2.y)
                                            ctx.stroke()

                                            // Label (Dist + Bearing)
                                            var midX = (p1.x + p2.x) / 2
                                            var midY = (p1.y + p2.y) / 2
                                            var bearing = calculateBearing(shape.x1, shape.y1, shape.x2, shape.y2)

                                            var label = shape.distance.toFixed(3) + "m  " + formatDMS(bearing)
                                            ctx.fillStyle = "#00CED1"
                                            ctx.font = "bold 11px sans-serif"
                                            var dim = ctx.measureText(label)
                                            // Background
                                            ctx.fillStyle = "rgba(30,30,30,0.8)"
                                            ctx.fillRect(midX - dim.width/2 - 2, midY - 14, dim.width + 4, 16)
                                            // Text
                                            ctx.fillStyle = "#00CED1"
                                            ctx.fillText(label, midX - dim.width/2, midY - 2)

                                            skipFinalStroke = true

                                        } else if (shape.type === "measure_poly") {
                                            // Render Measure Area Polygon
                                            ctx.fillStyle = "rgba(0, 206, 209, 0.15)"
                                            ctx.setLineDash([2, 4])

                                            var pts = shape.points
                                            if (pts.length > 0) {
                                                var p0 = worldToScreen(pts[0].x, pts[0].y)
                                                ctx.moveTo(p0.x, p0.y)
                                                var cx = 0, cy = 0
                                                for (var mp=0; mp < pts.length; mp++) {
                                                    var screenPt = worldToScreen(pts[mp].x, pts[mp].y)
                                                    if (mp > 0) ctx.lineTo(screenPt.x, screenPt.y)
                                                    cx += screenPt.x
                                                    cy += screenPt.y
                                                }
                                                ctx.closePath()
                                                ctx.fill()
                                                ctx.stroke()

                                                // Label (Area)
                                                cx /= pts.length
                                                cy /= pts.length

                                                var areaLabel = shape.area.toFixed(2) + " m²"
                                                if (shape.area > 10000) areaLabel += " (" + (shape.area/10000).toFixed(2) + " ha)"

                                                ctx.fillStyle = "#00CED1"
                                                ctx.font = "bold 11px sans-serif"
                                                var adim = ctx.measureText(areaLabel)
                                                ctx.fillStyle = "rgba(30,30,30,0.8)"
                                                ctx.fillRect(cx - adim.width/2 - 2, cy - 14, adim.width + 4, 16)
                                                ctx.fillStyle = "#00CED1"
                                                ctx.fillText(areaLabel, cx - adim.width/2, cy - 2)
                                            }
                                            skipFinalStroke = true
                                        }
                                        if (!skipFinalStroke) ctx.stroke()
                                        ctx.restore()
                                    }
                                }

                                // Draw active drawing preview
                                if (drawingState && drawingState.active) {

                                    var screenStart = worldToScreen(drawingState.startX, drawingState.startY)
                                    var screenCurr = worldToScreen(drawingState.currentX, drawingState.currentY)

                                    if (selectedTool === 3) { // Line
                                        ctx.save()
                                        ctx.strokeStyle = "yellow"
                                        ctx.lineWidth = 1.5
                                        applyLineDash(ctx, currentLineType)
                                        ctx.beginPath()
                                        ctx.moveTo(screenStart.x, screenStart.y)
                                        ctx.lineTo(screenCurr.x, screenCurr.y)
                                        ctx.stroke()

                                        // Guide lines (orthogonal tracking)
                                        ctx.setLineDash([3, 5])
                                        ctx.strokeStyle = "rgba(255,255,0,0.35)"
                                        ctx.beginPath()
                                        ctx.moveTo(screenStart.x, screenStart.y)
                                        ctx.lineTo(screenCurr.x, screenStart.y)
                                        ctx.lineTo(screenCurr.x, screenCurr.y)
                                        ctx.stroke()
                                        ctx.restore()

                                        var len = calculateDistance(drawingState.startX, drawingState.startY, drawingState.currentX, drawingState.currentY)
                                        var bearing = calculateBearing(drawingState.startX, drawingState.startY, drawingState.currentX, drawingState.currentY)
                                        drawDimLabel(ctx, len.toFixed(3) + "m  " + formatDMS(bearing),
                                                     (screenStart.x + screenCurr.x) / 2, (screenStart.y + screenCurr.y) / 2, "#FFD54F")
                                    } else if (selectedTool === 4) { // Circle
                                        ctx.save()
                                        ctx.strokeStyle = "yellow"
                                        ctx.lineWidth = 1.5
                                        applyLineDash(ctx, currentLineType)
                                        var dx = screenCurr.x - screenStart.x
                                        var dy = screenCurr.y - screenStart.y
                                        var r = Math.sqrt(dx*dx + dy*dy)
                                        ctx.beginPath()
                                        ctx.arc(screenStart.x, screenStart.y, r, 0, 2 * Math.PI)
                                        ctx.stroke()

                                        // Radius guide
                                        ctx.setLineDash([3, 5])
                                        ctx.strokeStyle = "rgba(255,255,0,0.35)"
                                        ctx.beginPath()
                                        ctx.moveTo(screenStart.x, screenStart.y)
                                        ctx.lineTo(screenCurr.x, screenCurr.y)
                                        ctx.stroke()
                                        ctx.restore()

                                        var radius = calculateDistance(drawingState.startX, drawingState.startY, drawingState.currentX, drawingState.currentY)
                                        drawDimLabel(ctx, "R=" + radius.toFixed(3) + "  D=" + (radius * 2).toFixed(3),
                                                     (screenStart.x + screenCurr.x) / 2, (screenStart.y + screenCurr.y) / 2, "#FFD54F")
                                    } else if (selectedTool === 5) { // Rectangle
                                        ctx.save()
                                        ctx.strokeStyle = "yellow"
                                        ctx.lineWidth = 1.5
                                        applyLineDash(ctx, currentLineType)
                                        // Simple rect preview (screen space)
                                        var w = screenCurr.x - screenStart.x
                                        var h = screenCurr.y - screenStart.y
                                        ctx.beginPath()
                                        ctx.rect(screenStart.x, screenStart.y, w, h)
                                        ctx.stroke()

                                        // Guide lines
                                        ctx.setLineDash([3, 5])
                                        ctx.strokeStyle = "rgba(255,255,0,0.35)"
                                        ctx.beginPath()
                                        ctx.moveTo(screenStart.x, screenStart.y)
                                        ctx.lineTo(screenCurr.x, screenStart.y)
                                        ctx.lineTo(screenCurr.x, screenCurr.y)
                                        ctx.stroke()
                                        ctx.restore()

                                        var wWorld = Math.abs(drawingState.currentX - drawingState.startX)
                                        var hWorld = Math.abs(drawingState.currentY - drawingState.startY)
                                        drawDimLabel(ctx, "W=" + wWorld.toFixed(3) + "  H=" + hWorld.toFixed(3),
                                                     (screenStart.x + screenCurr.x) / 2, (screenStart.y + screenCurr.y) / 2, "#FFD54F")
                                    } else if (selectedTool === 10) { // Measure Distance
                                        ctx.strokeStyle = "#00CED1"
                                        ctx.setLineDash([5, 5])
                                        ctx.beginPath()
                                        ctx.moveTo(screenStart.x, screenStart.y)
                                        ctx.lineTo(screenCurr.x, screenCurr.y)
                                        ctx.stroke() // Stroke WHILE dashed
                                        ctx.setLineDash([]) // Then reset
                                    } else {
                                        ctx.stroke() // Stroke for other tools
                                    }
                                }

                                // Draw Active Measurement Points (Area Tool)
                                if (selectedTool === 11 && measurePoints && measurePoints.length > 0) {
                                     ctx.strokeStyle = "#00CED1"
                                     ctx.fillStyle = "rgba(0, 206, 209, 0.2)"
                                     ctx.lineWidth = 2
                                     ctx.setLineDash([5, 5])
                                     ctx.beginPath()
                                     var pStart = worldToScreen(measurePoints[0].x, measurePoints[0].y)
                                     ctx.moveTo(pStart.x, pStart.y)
                                     for (var mp=1; mp < measurePoints.length; mp++) {
                                         var pNext = worldToScreen(measurePoints[mp].x, measurePoints[mp].y)
                                         ctx.lineTo(pNext.x, pNext.y)
                                     }

                                     // Rubber band to cursor
                                     var pCursor = {x: cursorX, y: cursorY}
                                     // Adjust cursorX/Y to generic canvas pos?
                                     // cursorX/Y properties are relative to CADPage, but pointsCanvas is inside.
                                     // Assuming cursorX/Y are safe to use or mapped correctly.
                                     // Actually pointsCanvas fills parent, so local coordinates if mouseX inside CanvasMouseArea?
                                     // canvasMouseArea onClicked: mouse.x -> passed to worldToScreen.
                                     // onPositionChanged updates lastMouseX/Y.

                                     // Let's rely on worldToScreen(screenToWorld(mouseX...))
                                     // Or just lineTo(mouse coordinates).
                                     // But onPaint doesn't know mouse coords unless in a property.
                                     // Use lastMouseX / lastMouseY

                                     ctx.lineTo(lastMouseX, lastMouseY)

                                     ctx.stroke()
                                     ctx.setLineDash([])
                                }

                                // Draft polyline (click points, double-click to finish)
                                if (selectedTool === 6 && polylineDraftPoints && polylineDraftPoints.length > 0) {
                                    ctx.save()
                                    ctx.strokeStyle = "yellow"
                                    ctx.lineWidth = 2
                                    ctx.setLineDash([4, 4])
                                    ctx.beginPath()

                                    var dp0 = worldToScreen(polylineDraftPoints[0].x, polylineDraftPoints[0].y)
                                    ctx.moveTo(dp0.x, dp0.y)
                                    for (var di = 1; di < polylineDraftPoints.length; di++) {
                                        var dp = worldToScreen(polylineDraftPoints[di].x, polylineDraftPoints[di].y)
                                        ctx.lineTo(dp.x, dp.y)
                                    }
                                    ctx.lineTo(lastMouseX, lastMouseY)
                                    ctx.stroke()
                                    ctx.restore()
                                }

                                // Draft polygon (click points, double-click to finish)
                                if (selectedTool === 7 && polygonDraftPoints && polygonDraftPoints.length > 0) {
                                    ctx.save()
                                    ctx.strokeStyle = "yellow"
                                    ctx.fillStyle = "rgba(255, 255, 0, 0.08)"
                                    ctx.lineWidth = 2
                                    ctx.setLineDash([4, 4])
                                    ctx.beginPath()

                                    var pg0 = worldToScreen(polygonDraftPoints[0].x, polygonDraftPoints[0].y)
                                    ctx.moveTo(pg0.x, pg0.y)
                                    for (var pi = 1; pi < polygonDraftPoints.length; pi++) {
                                        var pg = worldToScreen(polygonDraftPoints[pi].x, polygonDraftPoints[pi].y)
                                        ctx.lineTo(pg.x, pg.y)
                                    }
                                    ctx.lineTo(lastMouseX, lastMouseY)
                                    if (polygonDraftPoints.length >= 3) {
                                        ctx.closePath()
                                        ctx.fill()
                                    }
                                    ctx.stroke()
                                    ctx.restore()
                                }

                                // Draft boundary (earthwork volume/buffer)
                                if (selectedTool === 12 && boundaryDraftPoints && boundaryDraftPoints.length > 0) {
                                    ctx.save()
                                    ctx.strokeStyle = "#FFB020"
                                    ctx.fillStyle = "rgba(255,176,32,0.06)"
                                    ctx.lineWidth = 2
                                    ctx.setLineDash([6, 4])
                                    ctx.beginPath()

                                    var b0 = worldToScreen(boundaryDraftPoints[0].x, boundaryDraftPoints[0].y)
                                    ctx.moveTo(b0.x, b0.y)
                                    for (var bi = 1; bi < boundaryDraftPoints.length; bi++) {
                                        var bp = worldToScreen(boundaryDraftPoints[bi].x, boundaryDraftPoints[bi].y)
                                        ctx.lineTo(bp.x, bp.y)
                                    }
                                    ctx.lineTo(lastMouseX, lastMouseY)
                                    if (boundaryDraftPoints.length >= 3) {
                                        ctx.closePath()
                                        ctx.fill()
                                    }
                                    ctx.stroke()
                                    ctx.restore()
                                }

                                // Draw snap indicator when snapping is active during drawing
                                if (showSnapIndicator && currentSnapPos && snapEnabled) {
                                    ctx.save()
                                    var snapScreen = worldToScreen(currentSnapPos.x, currentSnapPos.y)
                                    var size = snapMarkerSize
                                    
                                    // Draw snap marker - magenta square with crosshairs
                                    ctx.strokeStyle = "#FF00FF"  // Magenta for high visibility
                                    ctx.fillStyle = "rgba(255, 0, 255, 0.2)"
                                    ctx.lineWidth = 2
                                    
                                    // Outer square
                                    ctx.beginPath()
                                    ctx.rect(snapScreen.x - size, snapScreen.y - size, size * 2, size * 2)
                                    ctx.fill()
                                    ctx.stroke()
                                    
                                    // Inner crosshairs
                                    ctx.beginPath()
                                    ctx.moveTo(snapScreen.x - size * 1.5, snapScreen.y)
                                    ctx.lineTo(snapScreen.x + size * 1.5, snapScreen.y)
                                    ctx.moveTo(snapScreen.x, snapScreen.y - size * 1.5)
                                    ctx.lineTo(snapScreen.x, snapScreen.y + size * 1.5)
                                    ctx.stroke()
                                    
                                    // Small diamond at center
                                    ctx.beginPath()
                                    ctx.moveTo(snapScreen.x, snapScreen.y - size / 2)
                                    ctx.lineTo(snapScreen.x + size / 2, snapScreen.y)
                                    ctx.lineTo(snapScreen.x, snapScreen.y + size / 2)
                                    ctx.lineTo(snapScreen.x - size / 2, snapScreen.y)
                                    ctx.closePath()
                                    ctx.fillStyle = "#FF00FF"
                                    ctx.fill()
                                    
                                    ctx.restore()
                                }
                            }
                    // Canvas MouseArea for panning
                    MouseArea {
                        id: canvasMouseArea
                        anchors.fill: parent
                        hoverEnabled: true // Required for position tracking
                        acceptedButtons: Qt.LeftButton
                        cursorShape: selectedTool === 1 ? Qt.OpenHandCursor : (selectedTool === 2 ? Qt.SizeAllCursor : Qt.CrossCursor)
                        property bool isPanning: false
                        focus: true // Enable Keyboard Input

                        // Box Selection Properties
                        property bool isBoxSelecting: false
                        property point selectionStart: Qt.point(0, 0)

                        Keys.onEscapePressed: {
                            clearTransientStates(true)
                            console.log("Measurements cleared via ESC")
                        }

                        Keys.onPressed: (event) => {
                            // Undo / Redo
                            if (event.modifiers & Qt.ControlModifier) {
                                if (event.key === Qt.Key_Z) {
                                    if (event.modifiers & Qt.ShiftModifier) root.redo()
                                    else root.undo()
                                    event.accepted = true
                                    return
                                }
                                if (event.key === Qt.Key_Y) {
                                    root.redo()
                                    event.accepted = true
                                    return
                                }
                            }

                            if (event.modifiers !== Qt.NoModifier)
                                return

                            switch (event.key) {
                            case Qt.Key_V: root.selectedTool = 0; break // Select
                            case Qt.Key_H: root.selectedTool = 1; break // Pan
                            case Qt.Key_L: root.selectedTool = 3; break // Line
                            case Qt.Key_C: root.selectedTool = 4; break // Circle
                            case Qt.Key_R: root.selectedTool = 5; break // Rectangle
                            case Qt.Key_P: root.selectedTool = 6; break // Polyline
                            case Qt.Key_O: root.selectedTool = 7; break // Polygon
                            case Qt.Key_B: root.selectedTool = 12; break // Boundary
                            case Qt.Key_D: root.selectedTool = 10; break // Measure Distance
                            case Qt.Key_A: root.selectedTool = 11; break // Measure Area
                            case Qt.Key_F: recalculateBounds(); break // Fit
                            case Qt.Key_G: showGrid = !showGrid; pointsCanvas.requestPaint(); break
                            case Qt.Key_S: snapEnabled = !snapEnabled; break
                            case Qt.Key_T: showPointLabels = !showPointLabels; pointsCanvas.requestPaint(); break
                            default:
                                return
                            }

                            event.accepted = true
                        }

                        onClicked: (mouse) => {
                            if (root.pickingControlPoint) {
                                var snapWorld = getWorldPosWithSnap(mouse.x, mouse.y)
                                addPointDialog.setCoordinates(snapWorld.x, snapWorld.y, 0.0)
                                addPointDialog.open()
                                root.pickingControlPoint = false
                                return
                            }

                            if (selectedTool === 10) { // Measure Distance (Click-Click)
                                if (!drawingState.active) {
                                    // Step 1: Start Measuring
                                    var snapWorld = getWorldPosWithSnap(mouse.x, mouse.y)
                                    var worldPos = { x: snapWorld.x, y: snapWorld.y }

                                    drawingState = {
                                        active: true,
                                        startX: worldPos.x,
                                        startY: worldPos.y,
                                        currentX: worldPos.x,
                                        currentY: worldPos.y
                                    }
                                } else {
                                    // Step 2: Finish Measuring
                                    var snapWorld = getWorldPosWithSnap(mouse.x, mouse.y)
                                    var finalPos = snapWorld.snapped ? { x: snapWorld.x, y: snapWorld.y } : { x: drawingState.currentX, y: drawingState.currentY }

                                    var dist = calculateDistance(drawingState.startX, drawingState.startY, finalPos.x, finalPos.y)
                                    if (dist > 0) {
                                        pushUndoState()
                                        drawnShapes.push({
                                            type: "measure_line",
                                            x1: drawingState.startX,
                                            y1: drawingState.startY,
                                            x2: finalPos.x,
                                            y2: finalPos.y,
                                            distance: dist,
                                            color: "#00CED1"
                                        })
                                        pointsCanvas.requestPaint()
                                    }
                                    drawingState = { active: false }
                                }
                            } else if (selectedTool === 11) { // Measure Area add point
                                var snapWorld = getWorldPosWithSnap(mouse.x, mouse.y)
                                var worldPos = { x: snapWorld.x, y: snapWorld.y }
                                var pts = measurePoints ? measurePoints : []
                                pts.push({x: worldPos.x, y: worldPos.y})
                                measurePoints = pts
                                pointsCanvas.requestPaint()
                            } else if (selectedTool === 3 || selectedTool === 4 || selectedTool === 5) { // Line/Circle/Rectangle click-click
                                var snapWorld = getWorldPosWithSnap(mouse.x, mouse.y)
                                var worldPos = { x: snapWorld.x, y: snapWorld.y }

                                if (!drawingState.active) {
                                    drawingState = {
                                        active: true,
                                        startX: worldPos.x,
                                        startY: worldPos.y,
                                        currentX: worldPos.x,
                                        currentY: worldPos.y
                                    }
                                } else {
                                    var shape = null
                                    var layerName = (activeLayer < layers.count) ? layers.get(activeLayer).layerName : "Layer"
                                    var layerColor = (activeLayer < layers.count) ? layers.get(activeLayer).layerColor : "white"

                                    if (selectedTool === 3) { // Line
                                        shape = {
                                            type: "line",
                                            x1: drawingState.startX,
                                            y1: drawingState.startY,
                                            x2: worldPos.x,
                                            y2: worldPos.y,
                                            color: layerColor,
                                            layer: layerName,
                                            lineType: currentLineType
                                        }
                                    } else if (selectedTool === 4) { // Circle
                                        var dx = worldPos.x - drawingState.startX
                                        var dy = worldPos.y - drawingState.startY
                                        var radius = Math.sqrt(dx*dx + dy*dy)
                                        shape = {
                                            type: "circle",
                                            cx: drawingState.startX,
                                            cy: drawingState.startY,
                                            radius: radius,
                                            color: layerColor,
                                            layer: layerName,
                                            lineType: currentLineType
                                        }
                                    } else if (selectedTool === 5) { // Rectangle
                                        var w = worldPos.x - drawingState.startX
                                        var h = worldPos.y - drawingState.startY
                                        shape = {
                                            type: "rectangle",
                                            x: drawingState.startX,
                                            y: drawingState.startY,
                                            w: w,
                                            h: h,
                                            color: layerColor,
                                            layer: layerName,
                                            lineType: currentLineType
                                        }
                                    }

                                    if (shape) {
                                        pushUndoState()
                                        var newShapes = drawnShapes
                                        if (!newShapes) newShapes = []
                                        newShapes.push(shape)
                                        drawnShapes = newShapes
                                        pointsCanvas.requestPaint()
                                    }
                                    drawingState = { active: false }
                                }
                                lastMouseX = mouse.x
                                lastMouseY = mouse.y
                                pointsCanvas.requestPaint()
                            } else if (selectedTool === 6) { // Polyline add point
                                var snapWorld = getWorldPosWithSnap(mouse.x, mouse.y)
                                var worldPos = { x: snapWorld.x, y: snapWorld.y }
                                var pts = polylineDraftPoints ? polylineDraftPoints : []
                                pts.push({ x: worldPos.x, y: worldPos.y })
                                polylineDraftPoints = pts
                                pointsCanvas.requestPaint()
                            } else if (selectedTool === 7) { // Polygon add point
                                var snapWorld = getWorldPosWithSnap(mouse.x, mouse.y)
                                var worldPos = { x: snapWorld.x, y: snapWorld.y }
                                var pts = polygonDraftPoints ? polygonDraftPoints : []
                                pts.push({ x: worldPos.x, y: worldPos.y })
                                polygonDraftPoints = pts
                                pointsCanvas.requestPaint()
                            } else if (selectedTool === 12) { // Boundary add point
                                var snapWorld = getWorldPosWithSnap(mouse.x, mouse.y)
                                var worldPos = { x: snapWorld.x, y: snapWorld.y }
                                var pts = boundaryDraftPoints ? boundaryDraftPoints : []
                                pts.push({ x: worldPos.x, y: worldPos.y })
                                boundaryDraftPoints = pts
                                pointsCanvas.requestPaint()
                            }
                        }

                        onDoubleClicked: (mouse) => {
                             if (selectedTool === 11) { // Measure Area finish
                                 if (measurePoints && measurePoints.length >= 3) {
                                     var area = calculatePolygonArea(measurePoints)
                                     pushUndoState()
                                     drawnShapes.push({
                                         type: "measure_poly",
                                         points: measurePoints,
                                         area: area,
                                         color: "#00CED1"
                                     })
                                     measurePoints = [] // Clear active
                                     pointsCanvas.requestPaint()
                                 }
                             } else if (selectedTool === 6) { // Polyline finish
                                 if (polylineDraftPoints && polylineDraftPoints.length >= 2) {
                                     var layerName = (activeLayer < layers.count) ? layers.get(activeLayer).layerName : "Layer"
                                     var layerColor = (activeLayer < layers.count) ? layers.get(activeLayer).layerColor : "white"
                                     pushUndoState()
                                     drawnShapes.push({
                                         type: "polyline",
                                         points: polylineDraftPoints,
                                         color: layerColor,
                                         layer: layerName,
                                         lineType: currentLineType
                                     })
                                     polylineDraftPoints = []
                                     pointsCanvas.requestPaint()
                                 }
                             } else if (selectedTool === 7) { // Polygon finish
                                 if (polygonDraftPoints && polygonDraftPoints.length >= 3) {
                                     var layerName = (activeLayer < layers.count) ? layers.get(activeLayer).layerName : "Layer"
                                     var layerColor = (activeLayer < layers.count) ? layers.get(activeLayer).layerColor : "white"
                                     pushUndoState()
                                     drawnShapes.push({
                                         type: "polygon",
                                         points: polygonDraftPoints,
                                         color: layerColor,
                                         layer: layerName,
                                         lineType: currentLineType
                                     })
                                     polygonDraftPoints = []
                                     pointsCanvas.requestPaint()
                                 }
                             } else if (selectedTool === 12) { // Boundary finish
                                 if (boundaryDraftPoints && boundaryDraftPoints.length >= 3) {
                                     pushUndoState()
                                     boundaryPolygon = boundaryDraftPoints

                                     // Keep a single boundary shape
                                     var nextShapes = []
                                     for (var si = 0; si < drawnShapes.length; si++) {
                                         if (drawnShapes[si].type !== "boundary") nextShapes.push(drawnShapes[si])
                                     }
                                     nextShapes.push({
                                         type: "boundary",
                                         points: boundaryDraftPoints,
                                         color: "#FFB020",
                                         fillColor: "rgba(255,176,32,0.07)",
                                         layer: "Boundary",
                                         lineType: currentLineType
                                     })
                                     drawnShapes = nextShapes
                                     boundaryDraftPoints = []
                                     pointsCanvas.requestPaint()
                                 }
                             }
                        }

                        onPressed: (mouse) => {
                            if (selectedTool === 0) {  // Select tool
                                var pointIndex = findPointAtPosition(mouse.x, mouse.y, false)
                                if (pointIndex >= 0) {
                                    // Point Selection
                                    if (mouse.modifiers & Qt.ControlModifier) { // Multi-select
                                        var idx = selectedPoints.indexOf(pointIndex)
                                        if (idx >= 0) {
                                            var newSelection = selectedPoints.slice()
                                            newSelection.splice(idx, 1)
                                            selectedPoints = newSelection
                                        } else {
                                            selectedPoints = selectedPoints.concat([pointIndex])
                                        }
                                    } else { // Single select
                                        selectedPoints = [pointIndex]
                                        selectedPointIndex = pointIndex
                                    }
                                    pointsCanvas.requestPaint()
                                } else { // No point clicked
                                    // Box Selection Start
                                    isBoxSelecting = true
                                    selectionStart = Qt.point(mouse.x, mouse.y)
                                    selectionBox.x = mouse.x
                                    selectionBox.y = mouse.y
                                    selectionBox.width = 0
                                    selectionBox.height = 0
                                    selectionBox.visible = true

                                    // Clear selection if not holding control
                                    if (!(mouse.modifiers & Qt.ControlModifier)) {
                                        selectedPoints = []
                                        selectedPointIndex = -1
                                    }
                                }
                            } else {
                                // Standard logic for other tools (Pan, etc)
                                lastMouseX = mouse.x
                                lastMouseY = mouse.y
                                if (selectedTool === 1) { // Pan tool
                                    isPanning = true
                                    cursorShape = Qt.ClosedHandCursor
                                }
                            }
                        }

                        onWheel: (wheel) => {
                            var zoomFactor = wheel.angleDelta.y > 0 ? 1.1 : 0.9

                            // Zoom centered on cursor
                            // Formula: offset_new = offset - (mouse_rel_center) * (factor - 1)
                            // where mouse_rel_center is the distance from the zoom center (offset) to the mouse

                            // Simplification derived from screenToWorld math:
                            // We want the World Point under cursor to stay at the Screen Point under cursor.
                            // screenX = canvasOffsetX + fitOffsetX + (WX * ...)
                            // term dependent on scale is (screenX - canvasOffsetX - fitOffsetX)

                            var termX = wheel.x - canvasOffsetX - fitOffsetX
                            var termY = wheel.y - canvasOffsetY - fitOffsetY

                            // Adjust offset
                            canvasOffsetX -= termX * (zoomFactor - 1)
                            canvasOffsetY -= termY * (zoomFactor - 1)

                            // Apply scale
                            canvasScale *= zoomFactor

                            pointsCanvas.requestPaint()
                        }



                        onPositionChanged: (mouse) => {
                            // Update status bar coordinates
                            var worldPos = screenToWorld(mouse.x, mouse.y)
                            cursorX = worldPos.x
                            cursorY = worldPos.y

                            // Reset snap indicator by default
                            var snapDetected = false
                            var snapWorldPos = null
                            
                            // Check if current tool supports snapping
                            var isDrawingTool = (selectedTool === 3 || selectedTool === 4 || selectedTool === 5 || selectedTool === 10 || 
                                                selectedTool === 11 || selectedTool === 6 || selectedTool === 7 || selectedTool === 12);

                            if (isPanning && selectedTool === 1) {
                                var dx = mouse.x - lastMouseX
                                var dy = mouse.y - lastMouseY
                                canvasOffsetX += dx
                                canvasOffsetY += dy
                                lastMouseX = mouse.x
                                lastMouseY = mouse.y
                                pointsCanvas.requestPaint()
                            } else if (isDrawingTool) {
                                // Unified Snapping Logic for all drawing tools
                                var snapWorld = getWorldPosWithSnap(mouse.x, mouse.y)
                                
                                if (snapWorld.snapped) {
                                    var snapScreen = worldToScreen(snapWorld.x, snapWorld.y)
                                    // Visual cursor update to snap position
                                    lastMouseX = snapScreen.x
                                    lastMouseY = snapScreen.y
                                    
                                    // Track snap state
                                    snapDetected = true
                                    snapWorldPos = { x: snapWorld.x, y: snapWorld.y }
                                    
                                    // Update drawing state current pos if active
                                    if (drawingState.active) {
                                        drawingState.currentX = snapWorld.x
                                        drawingState.currentY = snapWorld.y
                                    }
                                } else {
                                    lastMouseX = mouse.x
                                    lastMouseY = mouse.y
                                    
                                    // Update drawing state current pos if active
                                    if (drawingState.active) {
                                        drawingState.currentX = snapWorld.x // snapWorld is just worldPos if not snapped
                                        drawingState.currentY = snapWorld.y
                                    }
                                }
                                
                                // Determine if repaint is needed
                                var needsRepaint = false;
                                
                                // Always repaint if active drawing state (rubber banding)
                                if (drawingState.active) needsRepaint = true;
                                
                                // Always repaint if actively drafting multi-point shapes
                                if (selectedTool === 11 && measurePoints && measurePoints.length > 0) needsRepaint = true;
                                if ((selectedTool === 6 && polylineDraftPoints && polylineDraftPoints.length > 0) ||
                                    (selectedTool === 7 && polygonDraftPoints && polygonDraftPoints.length > 0) ||
                                    (selectedTool === 12 && boundaryDraftPoints && boundaryDraftPoints.length > 0)) needsRepaint = true;
                                    
                                // Always repaint if snap status changed or snap is active (to show/hide indicator)
                                if (snapDetected || showSnapIndicator) needsRepaint = true;
                                
                                if (needsRepaint) pointsCanvas.requestPaint()
                            }

                            // Update snap indicator state property
                            if (snapDetected && snapEnabled) {
                                currentSnapPos = snapWorldPos
                                showSnapIndicator = true
                            } else {
                                showSnapIndicator = false
                                currentSnapPos = null
                            }

                            // Box Selection Update (Visual)
                            if (isBoxSelecting) {
                                var x = Math.min(selectionStart.x, mouse.x)
                                var y = Math.min(selectionStart.y, mouse.y)
                                var w = Math.abs(selectionStart.x - mouse.x)
                                var h = Math.abs(selectionStart.y - mouse.y)

                                selectionBox.x = x
                                selectionBox.y = y
                                selectionBox.width = w
                                selectionBox.height = h
                            }
                        }

                        onReleased: (mouse) => {
                            isPanning = false

                            if (isBoxSelecting) {
                                isBoxSelecting = false
                                selectionBox.visible = false

                                // Calculate Box in Screen Coords
                                var bx = selectionBox.x
                                var by = selectionBox.y
                                var bw = selectionBox.width
                                var bh = selectionBox.height

                                // Find points inside
                                if (bw > 2 && bh > 2) { // Minimal threshold
                                    var newSelected = (mouse.modifiers & Qt.ControlModifier) ? selectedPoints.slice() : []

                                    for (var i = 0; i < importedPoints.count; i++) {
                                       var pt = importedPoints.get(i)
                                       // Convert point to screen
                                       var screenPt = worldToScreen(pt.x, pt.y)

                                       if (screenPt.x >= bx && screenPt.x <= bx + bw &&
                                           screenPt.y >= by && screenPt.y <= by + bh) {
                                           if (newSelected.indexOf(i) === -1) {
                                               newSelected.push(i)
                                           }
                                       }
                                    }
                                    selectedPoints = newSelected
                                    pointsCanvas.requestPaint()
                                }
                            }

                            if (selectedTool === 1) {
                                cursorShape = Qt.OpenHandCursor
                            } else if (selectedTool === 10 && drawingState.active) {
                                // Do nothing. Wait for second click.
                            } else if (selectedTool === 11 && drawingState.active) {
                                // For measure area, we only clear drawingState.active on release
                                // Points are added on click, not drag.
                                drawingState = { active: false }
                                pointsCanvas.requestPaint()
                            }
                        }
                    }

                    // Visual Selection Box
                    Rectangle {
                        id: selectionBox
                        visible: false
                        color: Qt.rgba(0.35, 0.48, 0.60, 0.2) // #5B7C99 with opacity 0.2
                        border.color: "#5B7C99"
                        border.width: 1
                        z: 10 // Above canvas
                    }
                    // Command Console (AutoCAD-style)
                    Rectangle {
                        id: commandConsole
                        width: Math.min(commandConsoleWidth, canvasArea.width - 20)
                        height: commandConsoleCollapsed ? commandConsoleCollapsedHeight : commandConsoleExpandedHeight
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 10
                        anchors.bottomMargin: 10
                        radius: 4
                        color: "#1A1A1A"
                        border.color: "#3A3A3A"
                        border.width: 1
                        z: 20
                        clip: true

                        Behavior on height {
                            NumberAnimation { duration: 220; easing.type: Easing.InOutQuad }
                        }

                        Item {
                            id: commandConsoleHeader
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 6
                            height: 22

                            RowLayout {
                                anchors.fill: parent
                                spacing: 8

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 3
                                    color: collapseConsoleMa.containsMouse ? "#3A3A3A" : "#2A2A2A"
                                    border.color: "#3A3A3A"
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: commandConsoleCollapsed ? "\uf078" : "\uf077"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 8
                                        color: textSecondary
                                    }

                                    MouseArea {
                                        id: collapseConsoleMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: commandConsoleCollapsed = !commandConsoleCollapsed
                                    }
                                }

                                Text {
                                    text: "Command Console"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: textPrimary
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 54
                                    height: 18
                                    radius: 3
                                    color: clearConsoleMa.containsMouse ? accentColor : "#2A2A2A"
                                    border.color: "#3A3A3A"
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Clear"
                                        font.family: "Codec Pro"
                                        font.pixelSize: 8
                                        color: "white"
                                    }

                                    MouseArea {
                                        id: clearConsoleMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: clearCommandHistory()
                                    }
                                }
                            }
                        }

                        Item {
                            id: commandConsoleBody
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: commandConsoleHeader.bottom
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: commandConsoleCollapsed ? 0 : 6
                            anchors.bottomMargin: commandConsoleCollapsed ? 0 : 8
                            opacity: commandConsoleCollapsed ? 0 : 1
                            enabled: !commandConsoleCollapsed
                            clip: true

                            Behavior on opacity {
                                NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 6

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 54
                                    color: "#111111"
                                    radius: 3
                                    border.color: "#2F2F2F"
                                    border.width: 1

                                    ListView {
                                        id: commandHistoryView
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        clip: true
                                        model: commandHistoryModel
                                        spacing: 2
                                        ScrollBar.vertical: ScrollBar { }

                                        delegate: Text {
                                            text: line
                                            color: kind === "error" ? "#E55353"
                                                                 : (kind === "prompt" ? accentColor : textSecondary)
                                            font.family: "Codec Pro"
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: "Command:"
                                        font.family: "Codec Pro"
                                        font.pixelSize: 9
                                        color: textPrimary
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    TextField {
                                        id: commandInputField
                                        Layout.fillWidth: true
                                        placeholderText: "Type a command (HELP for list)"
                                        color: "white"
                                        font.family: "Codec Pro"
                                        font.pixelSize: 10
                                        selectByMouse: true

                                        background: Rectangle {
                                            color: "#0F0F0F"
                                            radius: 2
                                            border.color: commandInputField.activeFocus ? accentColor : "#3A3A3A"
                                            border.width: 1
                                        }

                                        onAccepted: {
                                            executeCommand(text)
                                            text = ""
                                        }

                                        Keys.onPressed: (event) => {
                                            if (event.key === Qt.Key_Up) {
                                                if (commandInputHistory.length > 0) {
                                                    if (commandInputHistoryIndex < 0) {
                                                        commandInputHistoryIndex = commandInputHistory.length - 1
                                                    } else if (commandInputHistoryIndex > 0) {
                                                        commandInputHistoryIndex = commandInputHistoryIndex - 1
                                                    }
                                                    text = commandInputHistory[commandInputHistoryIndex] || ""
                                                    cursorPosition = text.length
                                                    event.accepted = true
                                                }
                                            } else if (event.key === Qt.Key_Down) {
                                                if (commandInputHistory.length > 0) {
                                                    if (commandInputHistoryIndex < commandInputHistory.length - 1) {
                                                        commandInputHistoryIndex++
                                                        text = commandInputHistory[commandInputHistoryIndex] || ""
                                                    } else {
                                                        commandInputHistoryIndex = commandInputHistory.length
                                                        text = ""
                                                    }
                                                    cursorPosition = text.length
                                                    event.accepted = true
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 46
                                        height: 22
                                        radius: 3
                                        color: runCommandMa.containsMouse ? accentColor : "#2A2A2A"
                                        border.color: "#3A3A3A"
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Run"
                                            font.family: "Codec Pro"
                                            font.pixelSize: 9
                                            color: "white"
                                        }

                                        MouseArea {
                                            id: runCommandMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                executeCommand(commandInputField.text)
                                                commandInputField.text = ""
                                            }
                                        }
                                    }
                                }

                                Flickable {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 20
                                    contentWidth: quickCommandRow.width
                                    contentHeight: quickCommandRow.height
                                    clip: true

                                    ScrollBar.horizontal: ScrollBar { }

                                    Row {
                                        id: quickCommandRow
                                        spacing: 6

                                        Repeater {
                                            model: commandQuickList
                                            delegate: Item {
                                                width: modelData.separator ? 8 : chip.implicitWidth
                                                height: 18

                                                Rectangle {
                                                    visible: modelData.separator === true
                                                    width: 1
                                                    height: 12
                                                    color: "#3A3A3A"
                                                    anchors.centerIn: parent
                                                }

                                                CommandChip {
                                                    id: chip
                                                    visible: !modelData.separator
                                                    label: modelData.label || ""
                                                    command: modelData.command || ""
                                                    tooltip: modelData.tooltip || ""
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    }

                }

                // Right sidebar - Layers & Properties Panel
                Rectangle {
                    id: layersPanel
                    property bool collapsed: false

                    Layout.preferredWidth: collapsed ? 40 : 240
                    Layout.fillHeight: true
                    color: darkCardBg
                    border.color: "#3A3A3A"
                    border.width: 1

                    Behavior on Layout.preferredWidth {
                        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        // Header with collapse button
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "\uf5fd"  // layer-group icon
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 11
                                color: accentColor
                                visible: !layersPanel.collapsed
                            }

                            Text {
                                text: "Layers"
                                font.family: "Codec Pro"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: textPrimary
                                Layout.fillWidth: true
                                visible: !layersPanel.collapsed
                            }

                            Rectangle {
                                width: 26
                                height: 26
                                color: collapseLpBtnMa.containsMouse ? "#3A3A3A" : "transparent"
                                radius: 4

                                Text {
                                    anchors.centerIn: parent
                                    text: layersPanel.collapsed ? "\uf053" : "\uf054"  // chevron-left / chevron-right
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 10
                                    color: accentColor
                                }

                                MouseArea {
                                    id: collapseLpBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: layersPanel.collapsed = !layersPanel.collapsed
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#3A3A3A"
                            visible: !layersPanel.collapsed
                        }

                        // Add Layer Button
                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            color: addLayerMa.containsMouse ? "#3A3A3A" : "#2A2A2A"
                            radius: 4
                            border.color: accentColor
                            border.width: 1
                            visible: !layersPanel.collapsed

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "\uf067"  // plus icon
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 9
                                    color: accentColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "New Layer"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 10
                                    color: textPrimary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: addLayerMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: addLayer()
                            }
                        }

                        // Layers List
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: !layersPanel.collapsed
                            clip: true

                            Column {
                                width: parent.width
                                spacing: 3

                                Repeater {
                                    model: layers

                                    Rectangle {
                                        property bool isRenaming: false
                                        width: parent.width - 10
                                        height: 36
                                        color: activeLayer === index ? "#3A3A3A" : (layerItemMa.containsMouse ? "#2F2F2F" : "transparent")
                                        radius: 4
                                        border.color: activeLayer === index ? root.accentColor : "transparent"
                                        border.width: 1

                                        // Background Selection MouseArea (z: 0)
                                        MouseArea {
                                            id: layerItemMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            propagateComposedEvents: true
                                            onClicked: if (!model.locked) activeLayer = index
                                            z: 0
                                        }

                                        // Layout (z: 1 to be above MouseArea)
                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            spacing: 8
                                            z: 1

                                            // Color Indicator
                                            Rectangle {
                                                width: 16; height: 16
                                                color: model.layerColor
                                                radius: 3
                                                border.color: "#5A5A5A"; border.width: 1
                                                anchors.verticalCenter: parent.verticalCenter
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (!model.locked) activeLayer = index
                                                    }
                                                }
                                            }

                                            // Action Icons (Eye, Lock, Trash) -> Direct children
                                            Rectangle {
                                                width: 20; height: 20
                                                color: visToggleMa.containsMouse ? "#4A4A4A" : "transparent"
                                                radius: 3
                                                anchors.verticalCenter: parent.verticalCenter
                                                Text { anchors.centerIn: parent; text: model.visible ? "\uf06e" : "\uf070"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 9; color: model.visible ? root.accentColor : root.textSecondary }
                                                MouseArea { id: visToggleMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: toggleLayerVisibility(index) }
                                            }

                                            Rectangle {
                                                width: 20; height: 20
                                                color: lockToggleMa.containsMouse ? "#4A4A4A" : "transparent"
                                                radius: 3
                                                anchors.verticalCenter: parent.verticalCenter
                                                Text { anchors.centerIn: parent; text: model.locked ? "\uf023" : "\uf09c"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 9; color: model.locked ? "#E55353" : root.textSecondary }
                                                MouseArea { id: lockToggleMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: toggleLayerLock(index) }
                                            }

                                            Rectangle {
                                                width: 20; height: 20
                                                color: deleteLayerMa.containsMouse ? "#4A4A4A" : "transparent"
                                                radius: 3
                                                visible: layers.count > 1
                                                anchors.verticalCenter: parent.verticalCenter
                                                Text { anchors.centerIn: parent; text: "\uf2ed"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 9; color: deleteLayerMa.containsMouse ? "#E55353" : root.textSecondary }
                                                MouseArea { id: deleteLayerMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deleteLayer(index) }
                                            }

                                            // Spacer to fill width (clickable for selection via background MA)
                                            Item {
                                                width: parent.width - 140
                                                height: 1
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Legend
                        Rectangle {
                            Layout.fillWidth: true
                            height: 50
                            color: "#2A2A2A"
                            radius: 4
                            visible: !layersPanel.collapsed

                            Column {
                                anchors.centerIn: parent
                                spacing: 3

                                Text {
                                    text: "Active Layer:"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 8
                                    color: textSecondary
                                }
                                TextField {
                                    text: activeLayer < layers.count ? layers.get(activeLayer).layerName : ""
                                    font.family: "Codec Pro"
                                    font.pixelSize: 10
                                    color: "white" // Input needs to be readable
                                    enabled: activeLayer < layers.count
                                    background: Rectangle { color: "transparent"; border.width: 0 } // Clean look
                                    selectByMouse: true
                                    onEditingFinished: {
                                        if (activeLayer < layers.count && text.length > 0) {
                                            layers.setProperty(activeLayer, "layerName", text)
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#3A3A3A"
                            visible: !layersPanel.collapsed
                        }

                        // Properties Panel Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            visible: !layersPanel.collapsed

                            Text {
                                text: "\uf05a"  // info-circle icon
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 10
                                color: accentColor
                            }

                            Text {
                                text: "Properties"
                                font.family: "Codec Pro"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: textPrimary
                                Layout.fillWidth: true
                            }
                        }

                        // Properties Content
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 180
                            color: "#2A2A2A"
                            radius: 4
                            visible: !layersPanel.collapsed

                            ScrollView {
                                anchors.fill: parent
                                anchors.margins: 8
                                clip: true

                                ColumnLayout {
                                    width: parent.width
                                    spacing: 8

                                    // Selection Info
                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        visible: selectedPoints.length > 0

                                        Text {
                                            text: selectedPoints.length > 0 ? (selectedPoints.length === 1 ? "1 Point Selected" : selectedPoints.length + " Points Selected") : "No Selection"
                                            font.family: "Codec Pro"
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            color: selectedPoints.length > 0 ? accentColor : textSecondary
                                        }

                                        // Show first selected point details
                                        Loader {
                                            active: selectedPoints.length === 1 && selectedPoints[0] < importedPoints.count
                                            sourceComponent: Column {
                                                spacing: 6
                                                width: parent.width

                                                property var point: importedPoints.get(selectedPoints[0])

                                                // Point Name (ID)
                                                Row {
                                                    spacing: 6
                                                    Text {
                                                        text: "Name:"
                                                        font.family: "Codec Pro"
                                                        font.pixelSize: 9
                                                        color: textSecondary
                                                        width: 40
                                                    }
                                                    Text {
                                                        text: point ? (point.name || "N/A") : "N/A"
                                                        font.family: "Codec Pro"
                                                        font.pixelSize: 9
                                                        color: textPrimary
                                                        font.weight: Font.Medium
                                                    }
                                                }

                                                // X Coordinate
                                                Row {
                                                    spacing: 6
                                                    Text {
                                                        text: "X:"
                                                        font.family: "Codec Pro"
                                                        font.pixelSize: 9
                                                        color: textSecondary
                                                        width: 40
                                                    }
                                                    Text {
                                                        text: point ? (point.x ? point.x.toFixed(3) : "0.000") : "0.000"
                                                        font.family: "Codec Pro"
                                                        font.pixelSize: 9
                                                        color: accentColor
                                                        font.weight: Font.Medium
                                                    }
                                                }

                                                // Y Coordinate
                                                Row {
                                                    spacing: 6
                                                    Text {
                                                        text: "Y:"
                                                        font.family: "Codec Pro"
                                                        font.pixelSize: 9
                                                        color: textSecondary
                                                        width: 40
                                                    }
                                                    Text {
                                                        text: point ? (point.y ? point.y.toFixed(3) : "0.000") : "0.000"
                                                        font.family: "Codec Pro"
                                                        font.pixelSize: 9
                                                        color: accentColor
                                                        font.weight: Font.Medium
                                                    }
                                                }

                                                // Z Elevation
                                                Row {
                                                    spacing: 6
                                                    Text {
                                                        text: "Z:"
                                                        font.family: "Codec Pro"
                                                        font.pixelSize: 9
                                                        color: textSecondary
                                                        width: 40
                                                    }
                                                    Text {
                                                        text: point ? (point.z ? point.z.toFixed(3) : "0.000") : "0.000"
                                                        font.family: "Codec Pro"
                                                        font.pixelSize: 9
                                                        color: "#2ECC71"
                                                        font.weight: Font.Medium
                                                    }
                                                }



                                                Rectangle {
                                                    width: parent.width
                                                    height: 1
                                                    color: "#3A3A3A"
                                                }

                                                // Quick Actions
                                                Text {
                                                    text: "Quick Actions"
                                                    font.family: "Codec Pro"
                                                    font.pixelSize: 8
                                                    color: textSecondary
                                                }

                                                Row {
                                                    spacing: 4

                                                    Rectangle {
                                                        width: 70
                                                        height: 22
                                                        color: deletePtMa.containsMouse ? "#E55353" : "#3A3A3A"
                                                        radius: 3

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "Delete"
                                                            font.family: "Codec Pro"
                                                            font.pixelSize: 8
                                                            color: "white"
                                                        }

                                                        MouseArea {
                                                            id: deletePtMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (selectedPoints.length === 1 && point && point.id !== undefined) {
                                                                    Database.deletePoint(point.id)
                                                                    selectedPoints = []
                                                                    selectedPointIndex = -1
                                                                }
                                                            }
                                                        }
                                                    }

                                                    Rectangle {
                                                        width: 70
                                                        height: 22
                                                        color: zoomPtMa.containsMouse ? accentColor : "#3A3A3A"
                                                        radius: 3

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "Zoom To"
                                                            font.family: "Codec Pro"
                                                            font.pixelSize: 8
                                                            color: "white"
                                                        }

                                                        MouseArea {
                                                            id: zoomPtMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (selectedPoints.length === 1 && point) {
                                                                    // Center on point
                                                                    var totalScale = fitScale * canvasScale
                                                                    canvasOffsetX = (pointsCanvas.width / 2) - fitOffsetX - point.x * totalScale
                                                                    canvasOffsetY = (pointsCanvas.height / 2) - fitOffsetY + point.y * totalScale
                                                                    pointsCanvas.requestPaint()
                                                                }
                                                            }
                                                        }
                                                    }

                                                    Rectangle {
                                                        width: 70
                                                        height: 22
                                                        color: cogoPtMa.containsMouse ? accentColor : "#3A3A3A"
                                                        radius: 3

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "COGO"
                                                            font.family: "Codec Pro"
                                                            font.pixelSize: 8
                                                            color: "white"
                                                        }

                                                        MouseArea {
                                                            id: cogoPtMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (selectedPoints.length === 1 && point) {
                                                                    cogoDialog.openForPoint(point)
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Two-point inverse (survey)
                                        Loader {
                                            active: selectedPoints.length === 2 && selectedPoints[0] < importedPoints.count && selectedPoints[1] < importedPoints.count
                                            sourceComponent: Column {
                                                spacing: 6
                                                width: parent.width

                                                property var p1: importedPoints.get(selectedPoints[0])
                                                property var p2: importedPoints.get(selectedPoints[1])

                                                property real dx: (p2 ? p2.x : 0) - (p1 ? p1.x : 0)
                                                property real dy: (p2 ? p2.y : 0) - (p1 ? p1.y : 0)
                                                property real dz: ((p2 && p2.z !== undefined) ? p2.z : 0) - ((p1 && p1.z !== undefined) ? p1.z : 0)
                                                property real horizDist: Math.sqrt(dx * dx + dy * dy)
                                                property real slopeDist: Math.sqrt(dx * dx + dy * dy + dz * dz)
                                                property real az: (p1 && p2) ? calculateBearing(p1.x, p1.y, p2.x, p2.y) : 0

                                                Rectangle { width: parent.width; height: 1; color: "#3A3A3A" }

                                                Text {
                                                    text: "Inverse (2 points)"
                                                    font.family: "Codec Pro"
                                                    font.pixelSize: 8
                                                    color: textSecondary
                                                }

                                                Row {
                                                    spacing: 6
                                                    Text { text: "Bearing:"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary; width: 55 }
                                                    Text { text: formatQuadrantBearing(az); font.family: "Codec Pro"; font.pixelSize: 9; color: accentColor; font.weight: Font.Medium }
                                                }

                                                Row {
                                                    spacing: 6
                                                    Text { text: "Dist:"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary; width: 55 }
                                                    Text { text: horizDist.toFixed(3) + " m"; font.family: "Codec Pro"; font.pixelSize: 9; color: textPrimary; font.weight: Font.Medium }
                                                }

                                                Row {
                                                    spacing: 6
                                                    Text { text: "ΔX:"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary; width: 55 }
                                                    Text { text: dx.toFixed(3); font.family: "Codec Pro"; font.pixelSize: 9; color: textPrimary }
                                                }

                                                Row {
                                                    spacing: 6
                                                    Text { text: "ΔY:"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary; width: 55 }
                                                    Text { text: dy.toFixed(3); font.family: "Codec Pro"; font.pixelSize: 9; color: textPrimary }
                                                }

                                                Row {
                                                    spacing: 6
                                                    visible: Math.abs(dz) > 0.0005
                                                    Text { text: "ΔZ:"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary; width: 55 }
                                                    Text { text: dz.toFixed(3); font.family: "Codec Pro"; font.pixelSize: 9; color: "#2ECC71" }
                                                }

                                                Row {
                                                    spacing: 6
                                                    visible: Math.abs(dz) > 0.0005
                                                    Text { text: "Slope:"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary; width: 55 }
                                                    Text { text: slopeDist.toFixed(3) + " m"; font.family: "Codec Pro"; font.pixelSize: 9; color: textPrimary }
                                                }
                                            }
                                        }

                                        // Multi-selection info
                                        Text {
                                            visible: selectedPoints.length > 2
                                            text: "Multiple points selected\nGroup operations available"
                                            font.family: "Codec Pro"
                                            font.pixelSize: 9
                                            color: textSecondary
                                            lineHeight: 1.3
                                        }
                                    }

                                    // Layer Properties (Visible when no points selected)
                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        visible: selectedPoints.length === 0 && layers.count > 0 && activeLayer < layers.count

                                        // Header
                                        Text {
                                            text: "Layer Details"
                                            font.family: "Codec Pro"
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            color: textSecondary
                                        }

                                        Rectangle { width: parent.width; height: 1; color: "#3A3A3A" }

                                        // Property Rows
                                        // Name
                                        Row {
                                            spacing: 6
                                            Text { text: "Name:"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary; width: 40 }
                                            Text {
                                                text: layers.get(activeLayer).layerName
                                                font.family: "Codec Pro"; font.pixelSize: 9; color: textPrimary; font.weight: Font.Medium
                                            }
                                        }

                                        // Color
                                        Row {
                                            spacing: 6
                                            Text { text: "Color:"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary; width: 40 }
                                            Rectangle {
                                                width: 12; height: 12
                                                color: layers.get(activeLayer).layerColor
                                                radius: 2
                                                border.color: "#5A5A5A"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                text: layers.get(activeLayer).layerColor
                                                font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        // Visible
                                        Row {
                                            spacing: 6
                                            Text { text: "Visible:"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary; width: 40 }
                                            Text {
                                                text: layers.get(activeLayer).visible ? "Yes" : "No"
                                                font.family: "Codec Pro"; font.pixelSize: 9
                                                color: layers.get(activeLayer).visible ? "#2ECC71" : "#E55353"
                                                font.weight: Font.Medium
                                            }
                                        }

                                        // Locked
                                        Row {
                                            spacing: 6
                                            Text { text: "Locked:"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary; width: 40 }
                                            Text {
                                                text: layers.get(activeLayer).locked ? "Yes" : "No"
                                                font.family: "Codec Pro"; font.pixelSize: 9
                                                color: layers.get(activeLayer).locked ? "#E55353" : "#2ECC71"
                                                font.weight: Font.Medium
                                            }
                                        }

                                        // Object Count (Calculated)
                                        Row {
                                            spacing: 6
                                            Text { text: "Objects:"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary; width: 40 }
                                            Text {
                                                text: {
                                                    var count = 0;
                                                    var lname = layers.get(activeLayer).layerName;
                                                    if (drawnShapes) {
                                                        for(var i=0; i<drawnShapes.length; i++) {
                                                            if (drawnShapes[i].layer === lname) count++;
                                                        }
                                                    }
                                                    return count + " Shapes"
                                                }
                                                font.family: "Codec Pro"; font.pixelSize: 9; color: textPrimary; font.weight: Font.Medium
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Survey Summary
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 160
                            color: "#2A2A2A"
                            radius: 4
                            visible: !layersPanel.collapsed

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: "\uf05a"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 9
                                        color: accentColor
                                    }
                                    Text {
                                        text: "Survey Summary"
                                        font.family: "Codec Pro"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: textPrimary
                                    }
                                }

                                Rectangle { height: 1; Layout.fillWidth: true; color: "#3A3A3A" }

                                Text {
                                    text: "Points: " + importedPoints.count
                                    font.family: "Codec Pro"
                                    font.pixelSize: 9
                                    color: textSecondary
                                }
                                Text {
                                    text: "Shapes: " + (drawnShapes ? drawnShapes.length : 0)
                                    font.family: "Codec Pro"
                                    font.pixelSize: 9
                                    color: textSecondary
                                }
                                Text {
                                    text: boundaryPolygon && boundaryPolygon.length >= 3
                                          ? "Boundary: " + calculatePolygonArea(boundaryPolygon).toFixed(2) + " m²"
                                          : "Boundary: not set"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 9
                                    color: textSecondary
                                }
                                Text {
                                    text: dtmData && dtmData.width > 0
                                          ? "DTM: " + dtmData.width + "×" + dtmData.height
                                          : "DTM: none"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 9
                                    color: textSecondary
                                }
                                Text {
                                    text: tinData && tinData.success
                                          ? "TIN: " + tinData.triangleCount + " tris"
                                          : "TIN: none"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 9
                                    color: textSecondary
                                }
                                Text {
                                    text: contourLines && contourLines.length > 0
                                          ? "Contours: " + contourLines.length
                                          : "Contours: none"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 9
                                    color: textSecondary
                                }

                                RowLayout {
                                    spacing: 6
                                    Layout.fillWidth: true

                                    Rectangle {
                                        width: 60
                                        height: 22
                                        radius: 3
                                        color: cogoQuickMa.containsMouse ? accentColor : "#3A3A3A"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "COGO"
                                            font.family: "Codec Pro"
                                            font.pixelSize: 8
                                            color: "white"
                                        }
                                        MouseArea {
                                            id: cogoQuickMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: openCogoFromSelection()
                                        }
                                    }

                                    Rectangle {
                                        width: 60
                                        height: 22
                                        radius: 3
                                        color: pointsQuickMa.containsMouse ? accentColor : "#3A3A3A"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Points"
                                            font.family: "Codec Pro"
                                            font.pixelSize: 8
                                            color: "white"
                                        }
                                        MouseArea {
                                            id: pointsQuickMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: openPointManager()
                                        }
                                    }

                                    Rectangle {
                                        width: 60
                                        height: 22
                                        radius: 3
                                        color: crsQuickMa.containsMouse ? accentColor : "#3A3A3A"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "CRS"
                                            font.family: "Codec Pro"
                                            font.pixelSize: 8
                                            color: "white"
                                        }
                                        MouseArea {
                                            id: crsQuickMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: crsDialog.open()
                                        }
                                    }
                                }
                            }
                        }
                }
            }
        }


            // Bottom status bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                color: charcoalBg
                border.color: "#3A3A3A"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 15

                    // Cursor Coordinates
                    Row {
                        spacing: 4
                        Text {
                            text: "\uf545"  // crosshairs icon
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 9
                            color: accentColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "X: " + cursorX.toFixed(3) + "  Y: " + cursorY.toFixed(3)
                            font.family: "Codec Pro"
                            font.pixelSize: 9
                            color: accentColor
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle { width: 1; height: 18; color: "#4A5C6D" }

                    // Scale Display
                    Row {
                        spacing: 4
                        Text {
                            text: "\uf424"  // search-plus icon
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 9
                            color: textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "1:" + Math.round(1 / canvasScale)
                            font.family: "Codec Pro"
                            font.pixelSize: 9
                            color: textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle { width: 1; height: 18; color: "#4A5C6D" }

                    // Current Tool
                    Row {
                        spacing: 4
                        Text {
                            text: "\uf1de"  // sliders-h icon
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 9
                            color: textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: currentToolName
                            font.family: "Codec Pro"
                            font.pixelSize: 9
                            color: textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle { width: 1; height: 18; color: "#4A5C6D" }

                    // Object Count
                    Row {
                        spacing: 4
                        Text {
                            text: "\uf3c5"  // map-marker-alt icon
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 9
                            color: textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: importedPoints.count + " pts"
                            font.family: "Codec Pro"
                            font.pixelSize: 9
                            color: textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle { width: 1; height: 18; color: "#4A5C6D" }

                    // CRS Display
                    Row {
                        spacing: 4
                        Text {
                            text: "\uf0ac"  // globe icon
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 9
                            color: textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: selectedCRS < crsList.length ? crsList[selectedCRS].name : "Custom"
                            font.family: "Codec Pro"
                            font.pixelSize: 9
                            color: textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Status Indicator
                    Row {
                        spacing: 4
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: Earthwork.isProcessing ? "#F39C12" : "#2ECC71"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: Earthwork.isProcessing ? "Processing..." : "Ready"
                            font.family: "Codec Pro"
                            font.pixelSize: 9
                            color: Earthwork.isProcessing ? "#F39C12" : "#2ECC71"
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }



    Dialog {
        id: bufferDialog
        title: "Create Buffer"
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 300
        standardButtons: Dialog.Ok | Dialog.Cancel

        contentItem: ColumnLayout {
            spacing: 12
            Text {
                text: "Buffer Distance (meters):"
                color: textPrimary
                font.family: "Codec Pro"
            }
            TextField {
                id: bufferDistanceField
                Layout.fillWidth: true
                text: "5.0"
                validator: DoubleValidator { bottom: -1000; top: 1000; decimals: 2 }
                selectByMouse: true
            }
        }

        onAccepted: {
            // Find a polygon-like input: prefer the most recent shape with a points[] array, otherwise boundaryPolygon
            var pointsToBuffer = []
            if (drawnShapes && drawnShapes.length > 0) {
                for (var i = drawnShapes.length - 1; i >= 0; i--) {
                    if (drawnShapes[i].points && drawnShapes[i].points.length >= 3) {
                        pointsToBuffer = drawnShapes[i].points
                        break
                    }
                }
            }

            if ((!pointsToBuffer || pointsToBuffer.length < 3) && boundaryPolygon && boundaryPolygon.length >= 3) {
                pointsToBuffer = boundaryPolygon
            }

            if (!pointsToBuffer || pointsToBuffer.length < 3) {
                console.log("Buffer: no polygon to buffer")
                return
            }

            var dist = parseFloat(bufferDistanceField.text)
            if (isNaN(dist)) dist = 0

            // Earthwork.createBuffer expects a list of QPointF/Qt.point
            var qpoints = []
            for (var p = 0; p < pointsToBuffer.length; p++) {
                var pt = pointsToBuffer[p]
                if (pt && pt.x !== undefined && pt.y !== undefined) {
                    qpoints.push(Qt.point(pt.x, pt.y))
                }
            }

            var bufferedPoints = Earthwork.createBuffer(qpoints, dist)
            if (bufferedPoints && bufferedPoints.length > 0) {
                drawnShapes.push({
                    type: "polygon",
                    points: bufferedPoints,
                    color: "#FF5722"
                })
                pointsCanvas.requestPaint()
            }
        }
    }

    // Grid Settings Dialog
    Dialog {
        id: gridSettingsDialog
        title: "Grid Settings"
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 350
        height: 260
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel

        contentItem: Item {
            implicitHeight: 200

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12

                Text {
                    text: "Grid Mode"
                    font.family: "Codec Pro"
                    color: textPrimary
                    font.bold: true
                    font.pixelSize: 12
                }

                RowLayout {
                    spacing: 15
                    RadioButton {
                        text: "Auto (Dynamic)"
                        checked: gridMode === "Auto"
                        onCheckedChanged: if(checked) gridMode = "Auto"
                        contentItem: Text {
                            text: parent.text
                            color: textPrimary
                            leftPadding: parent.indicator.width + 10
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 11
                        }
                    }
                    RadioButton {
                        text: "Manual (Fixed)"
                        checked: gridMode === "Manual"
                        onCheckedChanged: if(checked) gridMode = "Manual"
                        contentItem: Text {
                            text: parent.text
                            color: textPrimary
                            leftPadding: parent.indicator.width + 10
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 11
                        }
                    }
                }

                Rectangle {
                    height: 1
                    Layout.fillWidth: true
                    color: "#3A3A3A"
                    Layout.topMargin: 5
                    Layout.bottomMargin: 5
                }

                Text {
                    text: "Manual Spacing (meters)"
                    font.family: "Codec Pro"
                    color: textPrimary
                    font.pixelSize: 11
                    opacity: gridMode === "Manual" ? 1.0 : 0.5
                }

                TextField {
                    id: manualGridInput
                    text: manualGridSpacing.toString()
                    enabled: gridMode === "Manual"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    validator: DoubleValidator { bottom: 0.1; top: 10000.0; decimals: 2 }
                    selectByMouse: true
                    font.pixelSize: 11
                    onEditingFinished: {
                        var val = parseFloat(text)
                        if (!isNaN(val) && val > 0) manualGridSpacing = val
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        onAccepted: {
            // Apply immediately (bindings handle rest)
            var val = parseFloat(manualGridInput.text)
            if (!isNaN(val) && val > 0) manualGridSpacing = val
            pointsCanvas.requestPaint()
        }
    }

    // Custom Input Dialog for DTM Resolution
    Dialog {
        id: dtmDialog
        title: "DTM Generation"
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 300
        height: 180
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel

        property alias resolution: dtmResInput.text

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
                text: "Grid Resolution (meters):"
                font.family: "Codec Pro"
                color: textPrimary
            }

            TextField {
                id: dtmResInput
                text: "2.0"
                placeholderText: "e.g. 1.0"
                Layout.fillWidth: true
                validator: DoubleValidator { bottom: 0.1; top: 100.0; decimals: 2 }
                selectByMouse: true
            }

            Text {
                text: "Smaller values = Higher detail (slower)"
                font.family: "Codec Pro"
                font.pixelSize: 10
                color: textSecondary
            }
        }

        onAccepted: {
            var res = parseFloat(dtmResInput.text)
            if (isNaN(res) || res <= 0) res = 2.0

            var pts = []
            for(var i=0; i<importedPoints.count; i++) {
                var p = importedPoints.get(i)
                pts.push({x: p.x, y: p.y, z: p.z || 0})
            }

            console.log("Generating DTM with resolution:", res)
            startProcessing("Generating DTM...")
            Earthwork.generateDTM(pts, res)

            // Load DTM data for visualization
            dtmData = Earthwork.getDTMData()
            if (dtmData && dtmData.width > 0) {
                pointsCanvas.requestPaint()
            }
            if (!Earthwork.isProcessing) stopProcessing()
        }
    }

    // Custom Input Dialog for Contours
    Dialog {
        id: contourDialog
        title: "Generate Contours"
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 300
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel

        ColumnLayout {
            spacing: 15
            width: parent.width

            Text {
                text: "Enter contour interval (meters):"
                color: textPrimary
                font.family: "Codec Pro"
            }

            TextField {
                id: intervalInput
                Layout.fillWidth: true
                text: "1.0"
                placeholderText: "e.g. 0.5, 1.0, 5.0"
                validator: DoubleValidator { bottom: 0.1; top: 100.0; decimals: 2 }
                selectByMouse: true
                focus: true
            }
        }

        onAccepted: {
            var val = parseFloat(intervalInput.text)
            if (isNaN(val) || val <= 0) return

            console.log("Generating contours at " + val + "m interval...")
            startProcessing("Generating contours...")
            var result = Earthwork.generateContours(val)

            if (result.length > 5000) {
                console.warn("WARNING: Generated", result.length, "contours - too many to render efficiently!")
                contourLines = result.slice(0, 2000) // Limit for performance
            } else {
                contourLines = result
            }
            pointsCanvas.requestPaint()
            console.log("Displaying", contourLines.length, "contour lines")
            if (!Earthwork.isProcessing) stopProcessing()
        }
    }

    component StyledMenuItem : MenuItem {
        id: menuItem
        font.family: "Codec Pro"
        font.pixelSize: 10

        contentItem: RowLayout {
            anchors.fill: parent
            spacing: 6

            Text {
                text: menuItem.checkable && menuItem.checked ? "\uf00c" : ""
                font.family: "Font Awesome 5 Pro Solid"
                font.pixelSize: 8
                color: menuItem.enabled ? accentColor : "#555"
                width: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                text: menuItem.text
                font.family: menuItem.font.family
                font.pixelSize: menuItem.font.pixelSize
                color: menuItem.enabled ? textPrimary : "#666"
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Item { Layout.fillWidth: true }
        }

        background: Rectangle {
            color: menuItem.highlighted ? "#3A3A3A" : "transparent"
        }
    }

    component ToolSectionHeader : Rectangle {
        property string label: ""
        Layout.columnSpan: 3
        Layout.fillWidth: true
        Layout.preferredHeight: root.toolSidebarHeaderHeight
        height: root.toolSidebarHeaderHeight
        color: "transparent"

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            font.family: "Codec Pro"
            font.pixelSize: root.toolSidebarHeaderTextSize
            font.weight: Font.Bold
            color: textSecondary
        }
    }

    component ToolTile : Rectangle {
        property var toolData: ({})
        property bool isSelected: toolData.id !== undefined && root.selectedTool === toolData.id
        property bool isEnabled: toolData.enabled === undefined ? true : toolData.enabled
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: root.toolSidebarTileHeight
        radius: 4
        color: tileMa.containsMouse ? "#3A3A3A" : (isSelected ? "#4A4A4A" : "transparent")
        border.color: isSelected ? accentColor : "transparent"
        border.width: 2
        opacity: isEnabled ? 1.0 : 0.35

        ColumnLayout {
            anchors.centerIn: parent
            spacing: root.toolSidebarTileHeight >= 38 ? 2 : 1

            Text {
                text: toolData.icon || ""
                font.family: "Font Awesome 5 Pro Solid"
                font.pixelSize: root.toolSidebarIconSize
                color: "white"
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: toolData.name || ""
                font.family: "Codec Pro"
                font.pixelSize: Math.max(8, root.toolSidebarLabelSize)
                color: textPrimary
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
            }
        }

        MouseArea {
            id: tileMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: isEnabled
            cursorShape: isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: parent.clicked()
        }

        ToolTip {
            visible: tileMa.containsMouse
            text: toolData.tooltip || toolData.name || ""
            delay: 500
        }
    }

    component ToggleToolTile : Rectangle {
        property string icon: ""
        property string label: ""
        property string tooltip: ""
        property bool active: false
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: root.toolSidebarTileHeight
        radius: 4
        color: toggleMa.containsMouse ? "#3A3A3A" : (active ? "#4A4A4A" : "transparent")
        border.color: active ? accentColor : "transparent"
        border.width: 2

        ColumnLayout {
            anchors.centerIn: parent
            spacing: root.toolSidebarTileHeight >= 38 ? 2 : 1

            Text {
                text: icon
                font.family: "Font Awesome 5 Pro Solid"
                font.pixelSize: root.toolSidebarIconSize
                color: "white"
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: label
                font.family: "Codec Pro"
                font.pixelSize: Math.max(8, root.toolSidebarLabelSize)
                color: textPrimary
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
            }
        }

        MouseArea {
            id: toggleMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }

        ToolTip {
            visible: toggleMa.containsMouse
            text: tooltip
            delay: 500
        }
    }
    component CommandChip : Rectangle {
        property string label: ""
        property string command: ""
        property string tooltip: ""

        implicitWidth: commandText.implicitWidth + 14
        implicitHeight: 18
        height: implicitHeight
        radius: 3
        color: chipMa.containsMouse ? "#3A3A3A" : "#2A2A2A"
        border.color: "#4A4A4A"
        border.width: 1

        Text {
            id: commandText
            anchors.centerIn: parent
            text: label
            font.family: "Codec Pro"
            font.pixelSize: 8
            color: textPrimary
        }

        MouseArea {
            id: chipMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: executeCommand(command)
        }

        ToolTip {
            visible: chipMa.containsMouse && tooltip.length > 0
            text: tooltip
            delay: 400
        }
    }

    // Menu Bar Item Component
    component MenuBarItem : Rectangle {
        property string text: ""
        signal clicked()

        implicitWidth: menuText.implicitWidth + 20
        implicitHeight: 30
        color: menuMa.containsMouse ? "#3A3A3A" : "transparent"

        Text {
            id: menuText
            anchors.centerIn: parent
            text: parent.text
            font.family: "Codec Pro"
            font.pixelSize: 10
            color: textPrimary
        }

        MouseArea {
            id: menuMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    // Dialogs
    Dialog {
        id: volumeDialog
        title: "Volume Calculation"
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 350
        height: 320
        modal: true
        standardButtons: Dialog.Close
        padding: 0

        background: Rectangle {
            color: darkCardBg
            border.color: accentColor
            border.width: 1
            radius: 6
        }

        header: Rectangle {
            height: 40
            color: darkCardBg
            radius: 6

            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#3A3A3A" }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                text: "Earthwork Volumes"
                font.family: "Codec Pro"
                font.pixelSize: 12
                font.weight: Font.Bold
                color: textPrimary
            }
        }

        property double cutVol: 0
        property double fillVol: 0
        property double netVol: 0
        property double area: 0
        property double baseElev: 0
        property string method: "DTM"

        onOpened: {
            // Prefer TIN if available, fallback to DTM
            if (tinData && tinData.success) {
                // TIN-based calculation
                method = "TIN"
                // Get min elevation from vertices
                var minZ = 999999
                for (var v = 0; v < tinData.vertices.length; v++) {
                    var z = tinData.vertices[v].z
                    if (z < minZ) minZ = z
                }
                baseElev = minZ
                var result = Earthwork.calculateVolumeTIN(baseElev, boundaryPolygon)
                cutVol = result.cut
                fillVol = result.fill
                netVol = result.net
                area = result.area
            } else if (dtmData && dtmData.minElev !== undefined) {
                // DTM-based calculation
                method = "DTM"
                baseElev = dtmData.minElev
                var pointsToUse = []
                for(var i=0; i<importedPoints.count; i++) {
                    var p = importedPoints.get(i)
                    pointsToUse.push({x: p.x, y: p.y, z: p.z || 0})
                }
                var result = Earthwork.calculateVolume(baseElev, pointsToUse, "gdal")
                cutVol = result.cut
                fillVol = result.fill
                netVol = result.net
                area = result.area
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
                text: volumeDialog.method + " Method"
                font.family: "Codec Pro"
                font.pixelSize: 10
                font.weight: Font.Medium
                color: textSecondary
                Layout.fillWidth: true
            }

            Rectangle { height: 1; Layout.fillWidth: true; color: "#3A3A3A" }

            Text {
                text: "Reference Elevation: " + volumeDialog.baseElev.toFixed(3) + " m"
                font.family: "Codec Pro"
                font.pixelSize: 10
                color: textSecondary
            }

            // AutoCAD-style Results Table
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 160
                color: "#1A1A1A"
                border.color: "#5A5A5A"
                border.width: 1
                radius: 2

                Column {
                    anchors.fill: parent

                    // Table Header
                    Rectangle {
                        width: parent.width
                        height: 28
                        color: "#2A2A2A"
                        border.color: "#5A5A5A"
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.margins: 1

                            Rectangle {
                                width: parent.width * 0.5
                                height: parent.height
                                color: "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "Description"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: accentColor
                                }
                            }
                            Rectangle {
                                width: 1
                                height: parent.height
                                color: "#5A5A5A"
                            }
                            Rectangle {
                                width: parent.width * 0.5 - 1
                                height: parent.height
                                color: "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "Value"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: accentColor
                                }
                            }
                        }
                    }

                    // Cut Volume Row
                    Rectangle {
                        width: parent.width
                        height: 30
                        color: "#252525"
                        border.color: "#3A3A3A"
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            Rectangle {
                                width: parent.width * 0.5
                                height: parent.height
                                color: "transparent"
                                Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "Cut Volume"; font.family: "Codec Pro"; font.pixelSize: 10; color: "#E55353" }
                            }
                            Rectangle { width: 1; height: parent.height; color: "#3A3A3A" }
                            Rectangle {
                                width: parent.width * 0.5 - 1
                                height: parent.height
                                color: "transparent"
                                Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: volumeDialog.cutVol.toFixed(3) + " m³"; font.family: "Codec Pro"; font.pixelSize: 10; color: "#E55353" }
                            }
                        }
                    }

                    // Fill Volume Row
                    Rectangle {
                        width: parent.width
                        height: 30
                        color: "#1E1E1E"
                        border.color: "#3A3A3A"
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            Rectangle {
                                width: parent.width * 0.5
                                height: parent.height
                                color: "transparent"
                                Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "Fill Volume"; font.family: "Codec Pro"; font.pixelSize: 10; color: "#2ECC71" }
                            }
                            Rectangle { width: 1; height: parent.height; color: "#3A3A3A" }
                            Rectangle {
                                width: parent.width * 0.5 - 1
                                height: parent.height
                                color: "transparent"
                                Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: volumeDialog.fillVol.toFixed(3) + " m³"; font.family: "Codec Pro"; font.pixelSize: 10; color: "#2ECC71" }
                            }
                        }
                    }

                    // Net Volume Row
                    Rectangle {
                        width: parent.width
                        height: 30
                        color: "#252525"
                        border.color: "#3A3A3A"
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            Rectangle {
                                width: parent.width * 0.5
                                height: parent.height
                                color: "transparent"
                                Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "Net Volume"; font.family: "Codec Pro"; font.pixelSize: 10; font.bold: true; color: "white" }
                            }
                            Rectangle { width: 1; height: parent.height; color: "#3A3A3A" }
                            Rectangle {
                                width: parent.width * 0.5 - 1
                                height: parent.height
                                color: "transparent"
                                Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: volumeDialog.netVol.toFixed(3) + " m³"; font.family: "Codec Pro"; font.pixelSize: 10; font.bold: true; color: "white" }
                            }
                        }
                    }

                    // Total Area Row
                    Rectangle {
                        width: parent.width
                        height: 30
                        color: "#1E1E1E"
                        border.color: "#3A3A3A"
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            Rectangle {
                                width: parent.width * 0.5
                                height: parent.height
                                color: "transparent"
                                Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "Total Area"; font.family: "Codec Pro"; font.pixelSize: 10; color: textSecondary }
                            }
                            Rectangle { width: 1; height: parent.height; color: "#3A3A3A" }
                            Rectangle {
                                width: parent.width * 0.5 - 1
                                height: parent.height
                                color: "transparent"
                                Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: volumeDialog.area.toFixed(2) + " m²"; font.family: "Codec Pro"; font.pixelSize: 10; color: textSecondary }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true } // Spacer
        }
    }
    Dialog {
        id: cogoDialog
        title: "COGO - Bearing/Distance"
        modal: true
        width: 420
        height: 520
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        property var basePoint: null
        property real baseX: 0
        property real baseY: 0
        property real baseZ: 0

        property real outX: 0
        property real outY: 0
        property real outZ: 0

        property string errorText: ""

        function openForPoint(pt) {
            basePoint = pt
            baseX = pt && pt.x !== undefined ? pt.x : 0
            baseY = pt && pt.y !== undefined ? pt.y : 0
            baseZ = pt && pt.z !== undefined ? pt.z : 0

            newPointNameField.text = ""
            newPointCodeField.text = ""
            newPointDescField.text = ""

            quadrantCombo.currentIndex = 0
            degField.text = "0"
            minField.text = "0"
            secField.text = "0"

            distField.text = "0"
            dzField.text = "0"
            drawLineCheck.checked = true

            errorText = ""
            updateComputed()
            open()
        }

        function safeFloat(text, fallback) {
            var v = parseFloat(text)
            return isNaN(v) ? fallback : v
        }

        function safeInt(text, fallback) {
            var v = parseInt(text)
            return isNaN(v) ? fallback : v
        }

        function updateComputed() {
            var deg = safeInt(degField.text, 0)
            var min = safeInt(minField.text, 0)
            var sec = safeFloat(secField.text, 0)
            var angle = deg + (min / 60.0) + (sec / 3600.0)
            var dist = safeFloat(distField.text, 0)
            var dz = safeFloat(dzField.text, 0)

            if (angle < 0) angle = 0
            if (angle > 90) angle = 90

            var quad = quadrantCombo.currentText
            var az = angle
            if (quad === "SE") az = 180 - angle
            else if (quad === "SW") az = 180 + angle
            else if (quad === "NW") az = 360 - angle

            var rad = az * Math.PI / 180.0
            var dx = dist * Math.sin(rad)
            var dy = dist * Math.cos(rad)

            outX = baseX + dx
            outY = baseY + dy
            outZ = baseZ + dz

            bearingPreview.text = formatDMS(az)
        }

        background: Rectangle {
            color: darkCardBg
            border.color: accentColor
            border.width: 2
            radius: 4
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
                text: cogoDialog.basePoint && cogoDialog.basePoint.name ? ("From: " + cogoDialog.basePoint.name) : "From: (selected point)"
                font.family: "Codec Pro"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: textPrimary
            }

            Text {
                text: "X: " + cogoDialog.baseX.toFixed(3) + "   Y: " + cogoDialog.baseY.toFixed(3) + "   Z: " + cogoDialog.baseZ.toFixed(3)
                font.family: "Codec Pro"
                font.pixelSize: 10
                color: textSecondary
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#3A3A3A" }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 10

                Text { text: "New Name"; color: textSecondary; font.family: "Codec Pro"; font.pixelSize: 10 }
                TextField {
                    id: newPointNameField
                    Layout.fillWidth: true
                    placeholderText: "e.g. PT101"
                    onTextChanged: cogoDialog.errorText = ""
                }

                Text { text: "Code"; color: textSecondary; font.family: "Codec Pro"; font.pixelSize: 10 }
                TextField {
                    id: newPointCodeField
                    Layout.fillWidth: true
                    placeholderText: "Optional"
                }

                Text { text: "Description"; color: textSecondary; font.family: "Codec Pro"; font.pixelSize: 10 }
                TextField {
                    id: newPointDescField
                    Layout.fillWidth: true
                    placeholderText: "Optional"
                }

                Text { text: "Bearing"; color: textSecondary; font.family: "Codec Pro"; font.pixelSize: 10 }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    ComboBox {
                        id: quadrantCombo
                        model: ["NE", "SE", "SW", "NW"]
                        currentIndex: 0
                        onCurrentIndexChanged: updateComputed()
                        Layout.preferredWidth: 70
                    }

                    TextField {
                        id: degField
                        text: "0"
                        validator: IntValidator { bottom: 0; top: 90 }
                        Layout.preferredWidth: 50
                        onTextChanged: updateComputed()
                    }
                    Text { text: "°"; color: textSecondary; font.family: "Codec Pro"; font.pixelSize: 10 }

                    TextField {
                        id: minField
                        text: "0"
                        validator: IntValidator { bottom: 0; top: 59 }
                        Layout.preferredWidth: 45
                        onTextChanged: updateComputed()
                    }
                    Text { text: "'"; color: textSecondary; font.family: "Codec Pro"; font.pixelSize: 10 }

                    TextField {
                        id: secField
                        text: "0"
                        validator: DoubleValidator { bottom: 0; top: 59.999; decimals: 3 }
                        Layout.preferredWidth: 55
                        onTextChanged: updateComputed()
                    }
                    Text { text: "\""; color: textSecondary; font.family: "Codec Pro"; font.pixelSize: 10 }
                }

                Text { text: "Distance (m)"; color: textSecondary; font.family: "Codec Pro"; font.pixelSize: 10 }
                TextField {
                    id: distField
                    text: "0"
                    validator: DoubleValidator { bottom: 0; top: 10000000; decimals: 3 }
                    Layout.fillWidth: true
                    onTextChanged: updateComputed()
                }

                Text { text: "ΔZ (m)"; color: textSecondary; font.family: "Codec Pro"; font.pixelSize: 10 }
                TextField {
                    id: dzField
                    text: "0"
                    validator: DoubleValidator { bottom: -10000000; top: 10000000; decimals: 3 }
                    Layout.fillWidth: true
                    onTextChanged: updateComputed()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                CheckBox {
                    id: drawLineCheck
                    text: "Draw line"
                    checked: true
                    contentItem: Text {
                        text: parent.text
                        color: textPrimary
                        font.family: "Codec Pro"
                        font.pixelSize: 10
                        leftPadding: 24
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    id: bearingPreview
                    text: ""
                    font.family: "Codec Pro"
                    font.pixelSize: 10
                    color: accentColor
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: "#2A2A2A"
                radius: 4
                border.color: "#3A3A3A"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Text { text: "Computed"; font.family: "Codec Pro"; font.pixelSize: 10; font.weight: Font.Bold; color: textPrimary }
                    Text { text: "X: " + cogoDialog.outX.toFixed(3); font.family: "Codec Pro"; font.pixelSize: 10; color: textSecondary }
                    Text { text: "Y: " + cogoDialog.outY.toFixed(3); font.family: "Codec Pro"; font.pixelSize: 10; color: textSecondary }
                    Text { text: "Z: " + cogoDialog.outZ.toFixed(3); font.family: "Codec Pro"; font.pixelSize: 10; color: textSecondary }
                }
            }

            Text {
                text: cogoDialog.errorText
                visible: cogoDialog.errorText.length > 0
                color: "#E55353"
                font.family: "Codec Pro"
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }
        }

        footer: Rectangle {
            height: 52
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Item { Layout.fillWidth: true }

                Button {
                    text: "Cancel"
                    onClicked: cogoDialog.close()
                }

                Button {
                    text: "Add Point"
                    onClicked: {
                        var name = newPointNameField.text.trim()
                        if (name.length === 0) {
                            cogoDialog.errorText = "Point name is required."
                            return
                        }

                        Database.addPoint(name, cogoDialog.outX, cogoDialog.outY, cogoDialog.outZ, newPointCodeField.text, newPointDescField.text)

                        if (drawLineCheck.checked) {
                            drawnShapes.push({
                                type: "line",
                                x1: cogoDialog.baseX,
                                y1: cogoDialog.baseY,
                                x2: cogoDialog.outX,
                                y2: cogoDialog.outY,
                                color: accentColor
                            })
                            pointsCanvas.requestPaint()
                        }

                        cogoDialog.close()
                    }
                }
            }
        }
    }

    PointManagerDialog {
        id: pointManagerDialog
        pointsModel: importedPoints

        onZoomToRequested: {
            if (!point) return
            var totalScale = fitScale * canvasScale
            canvasOffsetX = (pointsCanvas.width / 2) - fitOffsetX - point.x * totalScale
            canvasOffsetY = (pointsCanvas.height / 2) - fitOffsetY + point.y * totalScale
            pointsCanvas.requestPaint()
        }

        onDeleteRequested: {
            if (index >= 0 && index < importedPoints.count) {
                var pt = importedPoints.get(index)
                if (pt && pt.id !== undefined) {
                    Database.deletePoint(pt.id)
                    selectedPoints = []
                    selectedPointIndex = -1
                }
            }
        }
    }
    AddPointDialog {
        id: addPointDialog
        onPickRequested: {
            root.pickingControlPoint = true
            // Tool 30 is already selected from the click
        }
        onAccepted: {
             // Database.refreshPoints() - Removed, using Connections instead
        }
    }

    // Error Banner - displays Earthwork errors
    ErrorBanner {
        id: errorBanner
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 10
        }
        z: 1000
        autoHide: true
        displayDuration: 7000
    }

    // Processing Overlay - shows DTM generation progress
    ProcessingOverlay {
        id: processingOverlay
        anchors.fill: parent
        message: processingOverlayMessage
        isProcessing: false
    }
}

