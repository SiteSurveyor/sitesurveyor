import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtLocation
import QtPositioning
import "components"

Item {
    id: root

    property string discipline: ""

    signal projectSelected(int projectId, string projectName)
    signal backRequested()

    // CoreUI Light theme colors (matching dashboard)
    property color bgColor: "#ebedef"
    property color cardColor: "#ffffff"
    property color cardHoverColor: "#f8f9fa"
    property color accentColor: "#321fdb"
    property color textPrimary: "#3c4b64"
    property color textSecondary: "#768192"
    property color borderColor: "#d8dbe0"
    property color dangerColor: "#e55353"
    property color successColor: "#2eb85c"
    property color warningColor: "#f9b115"
    property color infoColor: "#39f"

    Rectangle {
        anchors.fill: parent
        color: bgColor
    }

    // Raw projects from database
    property var allProjects: []
    // Filtered and sorted projects for display
    property var projectsList: []
    
    // Search and filter state
    property string searchQuery: ""
    property string sortBy: "recent"  // "name", "date", "recent"
    property string filterStatus: "all"  // "all", "Active", "Completed", "Archived"
    
    // View mode: "grid" or "list"
    property string viewMode: "grid"
    
    // Multi-select state
    property bool selectionMode: false
    property var selectedProjects: []  // Array of project IDs

    Component.onCompleted: {
        console.log("ProjectManagementView completed, discipline: " + discipline)
        refreshProjects()
    }

    // Refresh when view becomes visible again (after pop from dashboard)
    StackView.onActivated: {
        console.log("ProjectManagementView activated, refreshing projects")
        refreshProjects()
    }

    function refreshProjects() {
        console.log("Refreshing projects for discipline: " + discipline)
        allProjects = Database.getProjects(discipline)
        applyFiltersAndSort()
        console.log("Found " + allProjects.length + " projects")
    }
    
    function applyFiltersAndSort() {
        var filtered = allProjects.slice()  // Copy array
        
        // Apply search filter
        if (searchQuery.length > 0) {
            var query = searchQuery.toLowerCase()
            filtered = filtered.filter(function(p) {
                return p.name.toLowerCase().indexOf(query) >= 0 ||
                       (p.description && p.description.toLowerCase().indexOf(query) >= 0)
            })
        }
        
        // Apply status filter
        if (filterStatus !== "all") {
            filtered = filtered.filter(function(p) {
                return (p.status || "Active") === filterStatus
            })
        }
        
        // Apply sorting
        filtered.sort(function(a, b) {
            if (sortBy === "name") {
                return a.name.localeCompare(b.name)
            } else if (sortBy === "date") {
                return (b.createdAt || "").localeCompare(a.createdAt || "")
            } else {  // "recent"
                var aTime = a.lastAccessed || a.createdAt || ""
                var bTime = b.lastAccessed || b.createdAt || ""
                return bTime.localeCompare(aTime)
            }
        })
        
        projectsList = filtered
    }
    
    // Watch for filter changes
    onSearchQueryChanged: applyFiltersAndSort()
    onSortByChanged: applyFiltersAndSort()
    onFilterStatusChanged: applyFiltersAndSort()
    
    // Selection helpers
    function isSelected(projectId) {
        return selectedProjects.indexOf(projectId) >= 0
    }
    
    function toggleSelection(projectId) {
        var idx = selectedProjects.indexOf(projectId)
        if (idx >= 0) {
            selectedProjects.splice(idx, 1)
        } else {
            selectedProjects.push(projectId)
        }
        selectedProjects = selectedProjects.slice()  // Trigger update
    }
    
    function selectAll() {
        selectedProjects = projectsList.map(function(p) { return p.id })
    }
    
    function clearSelection() {
        selectedProjects = []
        selectionMode = false
    }
    
    function formatRelativeTime(timestamp) {
        if (!timestamp) return "Never"
        
        var date = new Date(timestamp)
        var now = new Date()
        var diffMs = now - date
        var diffMins = Math.floor(diffMs / 60000)
        var diffHours = Math.floor(diffMs / 3600000)
        var diffDays = Math.floor(diffMs / 86400000)
        
        if (diffMins < 1) return "Just now"
        if (diffMins < 60) return diffMins + " min ago"
        if (diffHours < 24) return diffHours + " hr ago"
        if (diffDays < 7) return diffDays + " day" + (diffDays > 1 ? "s" : "") + " ago"
        
        return Qt.formatDate(date, "MMM d, yyyy")
    }
    
    function getStatusColor(status) {
        switch(status) {
            case "Active": return successColor
            case "Completed": return accentColor
            case "Archived": return textSecondary
            default: return successColor
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        // Header Card - Enhanced with search, sort, filter
        Rectangle {
            Layout.fillWidth: true
            height: 72
            radius: 8
            color: cardColor
            border.color: borderColor
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 12

                // Back button
                Rectangle {
                    width: 40
                    height: 40
                    radius: 8
                    color: backMa.containsMouse ? bgColor : "transparent"
                    border.color: backMa.containsMouse ? accentColor : borderColor
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf060"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 14
                        color: backMa.containsMouse ? accentColor : textPrimary
                    }

                    MouseArea {
                        id: backMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.backRequested()
                    }
                }

                // Vertical separator
                Rectangle {
                    width: 1
                    height: 32
                    color: borderColor
                }

                // Logo
                Image {
                    source: "qrc:/logo/SiteSurveyor.png"
                    sourceSize.height: 36
                    fillMode: Image.PreserveAspectFit
                }

                // Title section
                ColumnLayout {
                    spacing: 2

                    Text {
                        text: discipline
                        font.family: "Codec Pro"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: textPrimary
                    }

                    Text {
                        text: allProjects.length + " project" + (allProjects.length !== 1 ? "s" : "") + 
                              (projectsList.length !== allProjects.length ? " (" + projectsList.length + " shown)" : "")
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: textSecondary
                    }
                }

                Item { Layout.fillWidth: true }

                // Functional Search field
                Rectangle {
                    width: 220
                    height: 36
                    radius: 6
                    color: searchField.activeFocus ? "#ffffff" : bgColor
                    border.color: searchField.activeFocus ? accentColor : borderColor
                    border.width: searchField.activeFocus ? 2 : 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: "\uf002"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 12
                            color: textSecondary
                        }

                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            placeholderText: "Search projects..."
                            font.family: "Codec Pro"
                            font.pixelSize: 12
                            color: textPrimary
                            placeholderTextColor: textSecondary
                            background: Item {}
                            leftPadding: 0
                            rightPadding: 0
                            
                            onTextChanged: searchQuery = text
                        }

                        // Clear button
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: clearSearchMa.containsMouse ? borderColor : "transparent"
                            visible: searchField.text.length > 0

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 9
                                color: textSecondary
                            }

                            MouseArea {
                                id: clearSearchMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchField.text = ""
                                    searchField.focus = false
                                }
                            }
                        }
                    }
                }

                // Sort dropdown
                Rectangle {
                    width: sortRow.width + 24
                    height: 36
                    radius: 6
                    color: sortMa.containsMouse ? Qt.darker(bgColor, 1.03) : bgColor
                    border.color: borderColor
                    border.width: 1

                    RowLayout {
                        id: sortRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "\uf0dc"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 10
                            color: textSecondary
                        }

                        Text {
                            text: sortBy === "name" ? "Name" : sortBy === "date" ? "Created" : "Recent"
                            font.family: "Codec Pro"
                            font.pixelSize: 11
                            color: textPrimary
                        }

                        Text {
                            text: "\uf078"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 8
                            color: textSecondary
                        }
                    }

                    MouseArea {
                        id: sortMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sortMenu.open()
                    }

                    Menu {
                        id: sortMenu
                        y: parent.height + 4

                        MenuItem {
                            text: "Recent Activity"
                            font.family: "Codec Pro"
                            checkable: true
                            checked: sortBy === "recent"
                            onTriggered: sortBy = "recent"
                        }
                        MenuItem {
                            text: "Name (A-Z)"
                            font.family: "Codec Pro"
                            checkable: true
                            checked: sortBy === "name"
                            onTriggered: sortBy = "name"
                        }
                        MenuItem {
                            text: "Date Created"
                            font.family: "Codec Pro"
                            checkable: true
                            checked: sortBy === "date"
                            onTriggered: sortBy = "date"
                        }
                    }
                }

                // View toggle (Grid/List)
                Rectangle {
                    width: 72
                    height: 36
                    radius: 6
                    color: bgColor
                    border.color: borderColor
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 3
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 4
                            color: viewMode === "grid" ? accentColor : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00a"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 12
                                color: viewMode === "grid" ? "white" : textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: viewMode = "grid"
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 4
                            color: viewMode === "list" ? accentColor : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf0c9"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 12
                                color: viewMode === "list" ? "white" : textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: viewMode = "list"
                            }
                        }
                    }
                }

                // Create new project button
                Rectangle {
                    width: newProjectRow.width + 24
                    height: 36
                    radius: 6
                    color: newBtnMa.containsMouse ? Qt.darker(accentColor, 1.1) : accentColor

                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        id: newProjectRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "\uf067"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 11
                            color: "white"
                        }

                        Text {
                            text: "New"
                            font.family: "Codec Pro"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: "white"
                        }
                    }

                    MouseArea {
                        id: newBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: createProjectDialog.open()
                    }
                }
            }
        }
        
        // Bulk actions bar (visible when in selection mode)
        Rectangle {
            Layout.fillWidth: true
            height: selectionMode ? 48 : 0
            radius: 8
            color: Qt.lighter(accentColor, 1.95)
            border.color: Qt.lighter(accentColor, 1.5)
            border.width: 1
            clip: true
            visible: selectionMode
            
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12
                
                // Checkbox for select all
                Rectangle {
                    width: 24
                    height: 24
                    radius: 4
                    color: selectAllMa.containsMouse ? Qt.lighter(accentColor, 1.8) : "transparent"
                    border.color: accentColor
                    border.width: 2
                    
                    Text {
                        anchors.centerIn: parent
                        text: selectedProjects.length === projectsList.length ? "\uf00c" : 
                              selectedProjects.length > 0 ? "\uf068" : ""
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 12
                        color: accentColor
                    }
                    
                    MouseArea {
                        id: selectAllMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (selectedProjects.length === projectsList.length) {
                                selectedProjects = []
                            } else {
                                selectAll()
                            }
                        }
                    }
                }
                
                Text {
                    text: selectedProjects.length + " selected"
                    font.family: "Codec Pro"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: accentColor
                }
                
                Item { Layout.fillWidth: true }
                
                // Bulk status change
                Rectangle {
                    width: statusBulkRow.width + 20
                    height: 32
                    radius: 6
                    color: statusBulkMa.containsMouse ? Qt.lighter(accentColor, 1.7) : "transparent"
                    border.color: accentColor
                    border.width: 1
                    visible: selectedProjects.length > 0
                    
                    RowLayout {
                        id: statusBulkRow
                        anchors.centerIn: parent
                        spacing: 6
                        
                        Text {
                            text: "\uf0ec"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 11
                            color: accentColor
                        }
                        
                        Text {
                            text: "Change Status"
                            font.family: "Codec Pro"
                            font.pixelSize: 11
                            color: accentColor
                        }
                    }
                    
                    MouseArea {
                        id: statusBulkMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bulkStatusMenu.open()
                    }
                    
                    Menu {
                        id: bulkStatusMenu
                        y: parent.height + 4
                        
                        MenuItem {
                            text: "Set Active"
                            font.family: "Codec Pro"
                            onTriggered: {
                                for (var i = 0; i < selectedProjects.length; i++) {
                                    Database.updateProjectStatus(selectedProjects[i], "Active")
                                }
                                refreshProjects()
                            }
                        }
                        MenuItem {
                            text: "Set Completed"
                            font.family: "Codec Pro"
                            onTriggered: {
                                for (var i = 0; i < selectedProjects.length; i++) {
                                    Database.updateProjectStatus(selectedProjects[i], "Completed")
                                }
                                refreshProjects()
                            }
                        }
                        MenuItem {
                            text: "Archive"
                            font.family: "Codec Pro"
                            onTriggered: {
                                for (var i = 0; i < selectedProjects.length; i++) {
                                    Database.updateProjectStatus(selectedProjects[i], "Archived")
                                }
                                refreshProjects()
                            }
                        }
                    }
                }
                
                // Bulk delete
                Rectangle {
                    width: deleteBulkRow.width + 20
                    height: 32
                    radius: 6
                    color: deleteBulkMa.containsMouse ? Qt.lighter(dangerColor, 1.8) : "transparent"
                    border.color: dangerColor
                    border.width: 1
                    visible: selectedProjects.length > 0
                    
                    RowLayout {
                        id: deleteBulkRow
                        anchors.centerIn: parent
                        spacing: 6
                        
                        Text {
                            text: "\uf1f8"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 11
                            color: dangerColor
                        }
                        
                        Text {
                            text: "Delete"
                            font.family: "Codec Pro"
                            font.pixelSize: 11
                            color: dangerColor
                        }
                    }
                    
                    MouseArea {
                        id: deleteBulkMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bulkDeleteDialog.open()
                    }
                }
                
                // Cancel selection
                Rectangle {
                    width: 32
                    height: 32
                    radius: 6
                    color: cancelSelMa.containsMouse ? Qt.lighter(accentColor, 1.7) : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 12
                        color: accentColor
                    }
                    
                    MouseArea {
                        id: cancelSelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clearSelection()
                    }
                }
            }
        }
        
        // Status filter tabs
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: allProjects.length > 0
            
            Repeater {
                model: [
                    { key: "all", label: "All", icon: "\uf07c" },
                    { key: "Active", label: "Active", icon: "\uf058" },
                    { key: "Completed", label: "Completed", icon: "\uf00c" },
                    { key: "Archived", label: "Archived", icon: "\uf187" }
                ]
                
                Rectangle {
                    width: filterTabRow.width + 16
                    height: 30
                    radius: 15
                    color: filterStatus === modelData.key ? accentColor : 
                           filterTabMa.containsMouse ? Qt.lighter(accentColor, 1.9) : "transparent"
                    border.color: filterStatus === modelData.key ? accentColor : borderColor
                    border.width: 1
                    
                    RowLayout {
                        id: filterTabRow
                        anchors.centerIn: parent
                        spacing: 6
                        
                        Text {
                            text: modelData.icon
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 10
                            color: filterStatus === modelData.key ? "white" : textSecondary
                        }
                        
                        Text {
                            text: modelData.label
                            font.family: "Codec Pro"
                            font.pixelSize: 11
                            color: filterStatus === modelData.key ? "white" : textPrimary
                        }
                    }
                    
                    MouseArea {
                        id: filterTabMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: filterStatus = modelData.key
                    }
                }
            }
            
            Item { Layout.fillWidth: true }
            
            // Selection mode toggle
            Rectangle {
                width: selectModeRow.width + 16
                height: 30
                radius: 15
                color: selectionMode ? warningColor : selectModeMa.containsMouse ? bgColor : "transparent"
                border.color: selectionMode ? warningColor : borderColor
                border.width: 1
                
                RowLayout {
                    id: selectModeRow
                    anchors.centerIn: parent
                    spacing: 6
                    
                    Text {
                        text: "\uf14a"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 10
                        color: selectionMode ? "white" : textSecondary
                    }
                    
                    Text {
                        text: selectionMode ? "Exit Select" : "Select"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: selectionMode ? "white" : textPrimary
                    }
                }
                
                MouseArea {
                    id: selectModeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (selectionMode) {
                            clearSelection()
                        } else {
                            selectionMode = true
                        }
                    }
                }
            }
        }

        // Projects Grid or Empty State
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Enhanced Empty state card with quick-start tips
            Rectangle {
                anchors.centerIn: parent
                width: 500
                height: 420
                radius: 12
                color: cardColor
                border.color: borderColor
                border.width: 1
                visible: allProjects.length === 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 32
                    spacing: 20

                    // Icon container
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 72
                        height: 72
                        radius: 36
                        color: Qt.lighter(accentColor, 1.92)

                        Text {
                            anchors.centerIn: parent
                            text: "\uf07b"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 28
                            color: accentColor
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Welcome to " + discipline
                        font.family: "Codec Pro"
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        color: textPrimary
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Get started by creating your first project"
                        font.family: "Codec Pro"
                        font.pixelSize: 13
                        color: textSecondary
                    }

                    // Quick start tips
                    Rectangle {
                        Layout.fillWidth: true
                        height: 120
                        radius: 8
                        color: bgColor
                        border.color: borderColor
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10

                            Text {
                                text: "Quick Start Tips"
                                font.family: "Codec Pro"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: textPrimary
                            }

                            RowLayout {
                                spacing: 10
                                Text {
                                    text: "\uf00c"
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 10
                                    color: successColor
                                }
                                Text {
                                    text: "Set a project location by clicking on the map"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 11
                                    color: textSecondary
                                }
                            }

                            RowLayout {
                                spacing: 10
                                Text {
                                    text: "\uf00c"
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 10
                                    color: successColor
                                }
                                Text {
                                    text: "Import existing data from CSV files"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 11
                                    color: textSecondary
                                }
                            }

                            RowLayout {
                                spacing: 10
                                Text {
                                    text: "\uf00c"
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 10
                                    color: successColor
                                }
                                Text {
                                    text: "Add survey points, traverses, and level runs"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 11
                                    color: textSecondary
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Create button
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: createFirstRow.width + 40
                        height: 48
                        radius: 8
                        color: emptyBtnMa.containsMouse ? Qt.darker(accentColor, 1.1) : accentColor

                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            id: createFirstRow
                            anchors.centerIn: parent
                            spacing: 10

                            Text {
                                text: "\uf067"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 14
                                color: "white"
                            }

                            Text {
                                text: "Create Your First Project"
                                font.family: "Codec Pro"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                color: "white"
                            }
                        }

                        MouseArea {
                            id: emptyBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: createProjectDialog.open()
                        }
                    }
                }
            }
            
            // No results state (when filtering produces no results)
            Rectangle {
                anchors.centerIn: parent
                width: 350
                height: 200
                radius: 12
                color: cardColor
                border.color: borderColor
                border.width: 1
                visible: allProjects.length > 0 && projectsList.length === 0
                
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "\uf002"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 32
                        color: textSecondary
                    }
                    
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No projects found"
                        font.family: "Codec Pro"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: textPrimary
                    }
                    
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: searchQuery.length > 0 ? 
                              "No results for \"" + searchQuery + "\"" :
                              "No " + filterStatus + " projects"
                        font.family: "Codec Pro"
                        font.pixelSize: 12
                        color: textSecondary
                    }
                    
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: clearFiltersText.width + 24
                        height: 32
                        radius: 6
                        color: clearFiltersMa.containsMouse ? bgColor : "transparent"
                        border.color: borderColor
                        border.width: 1
                        
                        Text {
                            id: clearFiltersText
                            anchors.centerIn: parent
                            text: "Clear Filters"
                            font.family: "Codec Pro"
                            font.pixelSize: 12
                            color: accentColor
                        }
                        
                        MouseArea {
                            id: clearFiltersMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchQuery = ""
                                searchField.text = ""
                                filterStatus = "all"
                            }
                        }
                    }
                }
            }

            // Projects grid view - Enhanced with status badge, point count, last accessed
            GridView {
                id: projectsGrid
                anchors.fill: parent
                anchors.topMargin: 4
                visible: viewMode === "grid" && projectsList.length > 0

                property int columns: Math.max(1, Math.floor(width / 360))
                cellWidth: width / columns
                cellHeight: 200
                clip: true

                model: projectsList

                delegate: Item {
                    width: projectsGrid.cellWidth
                    height: projectsGrid.cellHeight
                    
                    property bool isItemSelected: isSelected(modelData.id)
                    property string itemStatus: modelData.status || "Active"
                    property int pointCount: modelData.pointCount || 0

                    Rectangle {
                        id: projectCard
                        anchors.fill: parent
                        anchors.margins: 8
                        radius: 12
                        color: isItemSelected ? Qt.lighter(accentColor, 1.95) : 
                               cardMa.containsMouse ? cardHoverColor : cardColor
                        border.color: isItemSelected ? accentColor : 
                                      cardMa.containsMouse ? accentColor : borderColor
                        border.width: isItemSelected || cardMa.containsMouse ? 2 : 1

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        scale: cardMa.containsMouse ? 1.01 : 1.0

                        MouseArea {
                            id: cardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (selectionMode) {
                                    toggleSelection(modelData.id)
                                } else {
                                    Database.loadProject(modelData.id)
                                    root.projectSelected(modelData.id, modelData.name)
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 8

                            // Top row: Checkbox (if selection mode), Icon, Title, Status, Delete
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                
                                // Selection checkbox
                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 4
                                    color: isItemSelected ? accentColor : "transparent"
                                    border.color: isItemSelected ? accentColor : borderColor
                                    border.width: 2
                                    visible: selectionMode
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf00c"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 11
                                        color: "white"
                                        visible: isItemSelected
                                    }
                                }

                                // Project icon
                                Rectangle {
                                    width: 40
                                    height: 40
                                    radius: 8
                                    color: Qt.lighter(getStatusColor(itemStatus), 1.85)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf07c"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 16
                                        color: getStatusColor(itemStatus)
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: modelData.name
                                        font.family: "Codec Pro"
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                        color: textPrimary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: formatRelativeTime(modelData.lastAccessed || modelData.createdAt)
                                        font.family: "Codec Pro"
                                        font.pixelSize: 10
                                        color: textSecondary
                                    }
                                }
                                
                                // Status badge
                                Rectangle {
                                    width: statusText.width + 12
                                    height: 22
                                    radius: 11
                                    color: Qt.lighter(getStatusColor(itemStatus), 1.8)
                                    
                                    Text {
                                        id: statusText
                                        anchors.centerIn: parent
                                        text: itemStatus
                                        font.family: "Codec Pro"
                                        font.pixelSize: 9
                                        font.weight: Font.Medium
                                        color: getStatusColor(itemStatus)
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: cardStatusMenu.open()
                                    }
                                    
                                    Menu {
                                        id: cardStatusMenu
                                        y: parent.height + 4
                                        
                                        MenuItem {
                                            text: "Active"
                                            font.family: "Codec Pro"
                                            onTriggered: {
                                                Database.updateProjectStatus(modelData.id, "Active")
                                                refreshProjects()
                                            }
                                        }
                                        MenuItem {
                                            text: "Completed"
                                            font.family: "Codec Pro"
                                            onTriggered: {
                                                Database.updateProjectStatus(modelData.id, "Completed")
                                                refreshProjects()
                                            }
                                        }
                                        MenuItem {
                                            text: "Archived"
                                            font.family: "Codec Pro"
                                            onTriggered: {
                                                Database.updateProjectStatus(modelData.id, "Archived")
                                                refreshProjects()
                                            }
                                        }
                                    }
                                }

                                // Delete button
                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 6
                                    color: deleteMa.containsMouse ? Qt.lighter(dangerColor, 1.75) : "transparent"
                                    opacity: cardMa.containsMouse ? 1 : 0.3
                                    visible: !selectionMode

                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf1f8"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 11
                                        color: deleteMa.containsMouse ? dangerColor : textSecondary
                                    }

                                    MouseArea {
                                        id: deleteMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            deleteProjectId = modelData.id
                                            deleteProjectName = modelData.name
                                            deleteConfirmDialog.open()
                                        }
                                    }
                                }
                            }

                            // Description
                            Text {
                                text: modelData.description || "No description provided."
                                font.family: "Codec Pro"
                                font.pixelSize: 11
                                color: textSecondary
                                lineHeight: 1.3
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                            }

                            Item { Layout.fillHeight: true }

                            // Bottom row: Point count, Location badge, Open arrow
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                // Point count badge
                                Rectangle {
                                    width: pointsRow.width + 12
                                    height: 24
                                    radius: 6
                                    color: bgColor

                                    RowLayout {
                                        id: pointsRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: "\uf3c5"
                                            font.family: "Font Awesome 5 Pro Solid"
                                            font.pixelSize: 9
                                            color: accentColor
                                        }

                                        Text {
                                            text: pointCount + " point" + (pointCount !== 1 ? "s" : "")
                                            font.family: "Codec Pro"
                                            font.pixelSize: 10
                                            color: textPrimary
                                        }
                                    }
                                }

                                // Location Badge
                                Rectangle {
                                    visible: modelData.centerY !== 0 || modelData.centerX !== 0
                                    width: locRow.width + 12
                                    height: 24
                                    radius: 6
                                    color: bgColor

                                    RowLayout {
                                        id: locRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: "\uf5a0"
                                            font.family: "Font Awesome 5 Pro Solid"
                                            font.pixelSize: 9
                                            color: successColor
                                        }

                                        Text {
                                            text: "Location"
                                            font.family: "Codec Pro"
                                            font.pixelSize: 10
                                            color: textPrimary
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Open arrow indicator
                                Text {
                                    text: selectionMode ? "" : "\uf061"
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 12
                                    color: cardMa.containsMouse ? accentColor : borderColor
                                    opacity: cardMa.containsMouse ? 1 : 0.5

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }
                            }
                        }
                    }
                }
            }
            
            // List view - Compact table format
            ListView {
                id: projectsList_ListView
                anchors.fill: parent
                anchors.topMargin: 4
                visible: viewMode === "list" && projectsList.length > 0
                clip: true
                spacing: 4
                
                model: projectsList
                
                delegate: Rectangle {
                    width: projectsList_ListView.width
                    height: 56
                    radius: 8
                    color: listItemMa.containsMouse ? cardHoverColor : 
                           isSelected(modelData.id) ? Qt.lighter(accentColor, 1.95) : cardColor
                    border.color: isSelected(modelData.id) ? accentColor : 
                                  listItemMa.containsMouse ? accentColor : borderColor
                    border.width: 1
                    
                    property string itemStatus: modelData.status || "Active"
                    property int pointCount: modelData.pointCount || 0
                    
                    MouseArea {
                        id: listItemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (selectionMode) {
                                toggleSelection(modelData.id)
                            } else {
                                Database.loadProject(modelData.id)
                                root.projectSelected(modelData.id, modelData.name)
                            }
                        }
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12
                        
                        // Checkbox
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 4
                            color: isSelected(modelData.id) ? accentColor : "transparent"
                            border.color: isSelected(modelData.id) ? accentColor : borderColor
                            border.width: 2
                            visible: selectionMode
                            
                            Text {
                                anchors.centerIn: parent
                                text: "\uf00c"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 10
                                color: "white"
                                visible: isSelected(modelData.id)
                            }
                        }
                        
                        // Icon
                        Rectangle {
                            width: 36
                            height: 36
                            radius: 8
                            color: Qt.lighter(getStatusColor(itemStatus), 1.85)
                            
                            Text {
                                anchors.centerIn: parent
                                text: "\uf07c"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 14
                                color: getStatusColor(itemStatus)
                            }
                        }
                        
                        // Name & description
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            
                            Text {
                                text: modelData.name
                                font.family: "Codec Pro"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: textPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            
                            Text {
                                text: modelData.description || "No description"
                                font.family: "Codec Pro"
                                font.pixelSize: 11
                                color: textSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                        
                        // Points
                        Text {
                            text: pointCount + " pts"
                            font.family: "Codec Pro"
                            font.pixelSize: 11
                            color: textSecondary
                            Layout.preferredWidth: 50
                        }
                        
                        // Status
                        Rectangle {
                            width: listStatusText.width + 10
                            height: 20
                            radius: 10
                            color: Qt.lighter(getStatusColor(itemStatus), 1.8)
                            
                            Text {
                                id: listStatusText
                                anchors.centerIn: parent
                                text: itemStatus
                                font.family: "Codec Pro"
                                font.pixelSize: 9
                                color: getStatusColor(itemStatus)
                            }
                        }
                        
                        // Last accessed
                        Text {
                            text: formatRelativeTime(modelData.lastAccessed || modelData.createdAt)
                            font.family: "Codec Pro"
                            font.pixelSize: 11
                            color: textSecondary
                            Layout.preferredWidth: 80
                            horizontalAlignment: Text.AlignRight
                        }
                        
                        // Delete button
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 6
                            color: listDeleteMa.containsMouse ? Qt.lighter(dangerColor, 1.75) : "transparent"
                            visible: !selectionMode
                            
                            Text {
                                anchors.centerIn: parent
                                text: "\uf1f8"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 11
                                color: listDeleteMa.containsMouse ? dangerColor : textSecondary
                            }
                            
                            MouseArea {
                                id: listDeleteMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    deleteProjectId = modelData.id
                                    deleteProjectName = modelData.name
                                    deleteConfirmDialog.open()
                                }
                            }
                        }
                        
                        // Arrow
                        Text {
                            text: "\uf054"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 10
                            color: listItemMa.containsMouse ? accentColor : borderColor
                            visible: !selectionMode
                        }
                    }
                }
            }
        }
    }

    // Create Project Dialog
    property int deleteProjectId: -1
    property string deleteProjectName: ""
    
    // Form validation state
    property bool formSubmitted: false
    
    function resetCreateForm() {
        formSubmitted = false
        projectNameField.text = ""
        projectDescField.text = ""
        // Reset map picker state
        if (mapPicker) {
            mapPicker.locationPicked = false
            mapPicker.selectedY = 0
            mapPicker.selectedX = 0
        }
    }

    Dialog {
        id: createProjectDialog
        anchors.centerIn: parent
        width: Math.min(500, root.width - 48)
        height: Math.min(520, root.height - 80)
        modal: true
        padding: 0
        dim: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        onOpened: {
            formSubmitted = false
            projectNameField.forceActiveFocus()
        }
        
        onClosed: {
            resetCreateForm()
        }

        Overlay.modal: Rectangle {
            color: "#80000000"
        }

        background: Rectangle {
            color: cardColor
            radius: 8
            border.color: borderColor
            border.width: 1
        }

        header: Rectangle {
            color: cardColor
            height: 56
            radius: 8

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: borderColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 12
                
                // Icon
                Rectangle {
                    width: 36
                    height: 36
                    radius: 8
                    color: Qt.lighter(accentColor, 1.9)
                    
                    Text {
                        anchors.centerIn: parent
                        text: "\uf07c"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 14
                        color: accentColor
                    }
                }

                Text {
                    text: "New Project"
                    font.family: "Codec Pro"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: textPrimary
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: closeDialogMa.containsMouse ? bgColor : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 12
                        color: textSecondary
                    }

                    MouseArea {
                        id: closeDialogMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: createProjectDialog.close()
                    }
                }
            }
        }

        contentItem: Flickable {
            id: formFlickable
            contentWidth: width
            contentHeight: formColumn.height + 20
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: formColumn
                width: parent.width
                spacing: 16

                Item { height: 4 }

                // Project Name Field
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    spacing: 6

                    Text {
                        text: "Project Name <font color=\"" + dangerColor + "\">*</font>"
                        textFormat: Text.RichText
                        font.family: "Codec Pro"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: textPrimary
                    }

                    TextField {
                        id: projectNameField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        placeholderText: "Enter project name"
                        font.family: "Codec Pro"
                        font.pixelSize: 13
                        color: textPrimary
                        placeholderTextColor: textSecondary
                        leftPadding: 12
                        rightPadding: 12
                        selectByMouse: true

                        background: Rectangle {
                            color: "#ffffff"
                            radius: 6
                            border.color: {
                                if (formSubmitted && projectNameField.text.length === 0) return dangerColor
                                if (projectNameField.activeFocus) return accentColor
                                return borderColor
                            }
                            border.width: projectNameField.activeFocus ? 2 : 1
                        }
                    }
                    
                    Text {
                        visible: formSubmitted && projectNameField.text.length === 0
                        text: "\uf071 Project name is required"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 11
                        color: dangerColor
                    }
                }

                // Description Field
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    spacing: 6

                    Text {
                        text: "Description <font color=\"" + dangerColor + "\">*</font>"
                        textFormat: Text.RichText
                        font.family: "Codec Pro"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: textPrimary
                    }

                    TextField {
                        id: projectDescField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        placeholderText: "Brief project description"
                        font.family: "Codec Pro"
                        font.pixelSize: 13
                        color: textPrimary
                        placeholderTextColor: textSecondary
                        leftPadding: 12
                        rightPadding: 12
                        selectByMouse: true

                        background: Rectangle {
                            color: "#ffffff"
                            radius: 6
                            border.color: {
                                if (formSubmitted && projectDescField.text.length === 0) return dangerColor
                                if (projectDescField.activeFocus) return accentColor
                                return borderColor
                            }
                            border.width: projectDescField.activeFocus ? 2 : 1
                        }
                    }
                    
                    Text {
                        visible: formSubmitted && projectDescField.text.length === 0
                        text: "\uf071 Description is required"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 11
                        color: dangerColor
                    }
                }

                // Location section with Map Picker
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Project Location <font color=\"" + dangerColor + "\">*</font>"
                            textFormat: Text.RichText
                            font.family: "Codec Pro"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: textPrimary
                        }
                        
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: crsLabel.width + 12
                            height: 20
                            radius: 10
                            color: Qt.lighter(accentColor, 1.9)

                            Text {
                                id: crsLabel
                                anchors.centerIn: parent
                                text: "Lo29"
                                font.family: "Codec Pro"
                                font.pixelSize: 9
                                font.weight: Font.Medium
                                color: accentColor
                            }
                        }
                    }

                    MapPicker {
                        id: mapPicker
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        accentColor: root.accentColor
                        textPrimary: root.textPrimary
                        textSecondary: root.textSecondary
                        borderColor: root.borderColor
                    }
                    
                    Text {
                        visible: formSubmitted && !mapPicker.locationPicked
                        text: "\uf071 Please select a location on the map"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 11
                        color: dangerColor
                    }
                }

                Item { height: 4 }
            }
        }

        footer: Item {
            width: parent.width
            height: 64
            z: 100
            
            Rectangle {
                anchors.fill: parent
                color: bgColor
                radius: 8
                
                // Top border line
                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: borderColor
                }
                
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    
                    // Cancel button
                    Button {
                        id: cancelBtn
                        text: "Cancel"
                        Layout.preferredHeight: 38
                        Layout.preferredWidth: implicitWidth + 20
                        
                        contentItem: Text {
                            text: cancelBtn.text
                            font.family: "Codec Pro"
                            font.pixelSize: 13
                            color: textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        background: Rectangle {
                            color: cancelBtn.hovered ? Qt.darker(bgColor, 1.05) : "transparent"
                            border.color: borderColor
                            border.width: 1
                            radius: 6
                        }
                        
                        onClicked: createProjectDialog.close()
                    }
                    
                    // Create button
                    Button {
                        id: createBtn
                        text: "Create Project"
                        Layout.preferredHeight: 38
                        Layout.preferredWidth: implicitWidth + 20
                        
                        property bool canCreate: projectNameField.text.length > 0 &&
                                                 projectDescField.text.length > 0 &&
                                                 mapPicker.locationPicked
                        
                        contentItem: Text {
                            text: createBtn.text
                            font.family: "Codec Pro"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        background: Rectangle {
                            color: createBtn.canCreate ?
                                   (createBtn.hovered ? Qt.darker(accentColor, 1.1) : accentColor) :
                                   Qt.lighter(accentColor, 1.4)
                            radius: 6
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        
                        onClicked: {
                            console.log("Create button clicked")
                            formSubmitted = true
                            
                            if (createBtn.canCreate) {
                                console.log("Creating project...")
                                var result = Database.createProject(
                                    projectNameField.text,
                                    projectDescField.text,
                                    discipline,
                                    mapPicker.selectedY,
                                    mapPicker.selectedX
                                )
                                console.log("Create result:", result)
                                createProjectDialog.close()
                                refreshProjects()
                            }
                        }
                    }
                }
            }
        }
    }

    // Delete Confirmation Dialog
    Dialog {
        id: deleteConfirmDialog
        anchors.centerIn: parent
        width: 380
        modal: true
        padding: 0
        dim: true

        // Modal overlay
        Overlay.modal: Rectangle {
            color: "#80000000"
        }

        background: Rectangle {
            color: cardColor
            radius: 4
            border.color: borderColor
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 16

            Item { height: 8 }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 64
                height: 64
                radius: 32
                color: Qt.lighter(dangerColor, 1.85)

                Text {
                    anchors.centerIn: parent
                    text: "\uf1f8"
                    font.family: "Font Awesome 5 Pro Solid"
                    font.pixelSize: 24
                    color: dangerColor
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Delete Project?"
                font.family: "Codec Pro"
                font.pixelSize: 18
                font.weight: Font.Medium
                color: textPrimary
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                text: "Are you sure you want to delete \"" + deleteProjectName + "\"? This action cannot be undone."
                font.family: "Codec Pro"
                font.pixelSize: 14
                color: textSecondary
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Item { height: 8 }
        }

        footer: Rectangle {
            color: bgColor
            height: 64
            radius: 4

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: borderColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 4
                    color: delCancelMa.containsMouse ? Qt.darker(cardColor, 1.03) : cardColor
                    border.color: borderColor
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: "Codec Pro"
                        font.pixelSize: 14
                        color: textPrimary
                    }

                    MouseArea {
                        id: delCancelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: deleteConfirmDialog.close()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 4
                    color: delConfirmMa.containsMouse ? Qt.darker(dangerColor, 1.1) : dangerColor

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Delete Project"
                        font.family: "Codec Pro"
                        font.pixelSize: 14
                        color: "white"
                    }

                    MouseArea {
                        id: delConfirmMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Database.deleteProject(deleteProjectId)
                            deleteConfirmDialog.close()
                            refreshProjects()
                        }
                    }
                }
            }
        }
    }
    
    // Bulk Delete Confirmation Dialog
    Dialog {
        id: bulkDeleteDialog
        anchors.centerIn: parent
        width: 400
        modal: true
        padding: 0
        dim: true

        Overlay.modal: Rectangle {
            color: "#80000000"
        }

        background: Rectangle {
            color: cardColor
            radius: 4
            border.color: borderColor
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 16

            Item { height: 8 }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 64
                height: 64
                radius: 32
                color: Qt.lighter(dangerColor, 1.85)

                Text {
                    anchors.centerIn: parent
                    text: "\uf071"
                    font.family: "Font Awesome 5 Pro Solid"
                    font.pixelSize: 24
                    color: dangerColor
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Delete " + selectedProjects.length + " Projects?"
                font.family: "Codec Pro"
                font.pixelSize: 18
                font.weight: Font.Medium
                color: textPrimary
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                text: "Are you sure you want to delete " + selectedProjects.length + " selected projects? This action cannot be undone."
                font.family: "Codec Pro"
                font.pixelSize: 14
                color: textSecondary
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Item { height: 8 }
        }

        footer: Rectangle {
            color: bgColor
            height: 64
            radius: 4

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: borderColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 4
                    color: bulkCancelMa.containsMouse ? Qt.darker(cardColor, 1.03) : cardColor
                    border.color: borderColor
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: "Codec Pro"
                        font.pixelSize: 14
                        color: textPrimary
                    }

                    MouseArea {
                        id: bulkCancelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bulkDeleteDialog.close()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 4
                    color: bulkConfirmMa.containsMouse ? Qt.darker(dangerColor, 1.1) : dangerColor

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Delete " + selectedProjects.length + " Projects"
                        font.family: "Codec Pro"
                        font.pixelSize: 14
                        color: "white"
                    }

                    MouseArea {
                        id: bulkConfirmMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Database.deleteProjects(selectedProjects)
                            bulkDeleteDialog.close()
                            clearSelection()
                            refreshProjects()
                        }
                    }
                }
            }
        }
    }
}
