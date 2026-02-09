import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtLocation
import QtPositioning
import "components"

Item {
    id: root

    property string discipline: ""

    signal projectSelected(int projectId, string projectName)
    signal backRequested()

    property real introProgress: 0

    NumberAnimation {
        id: introAnim
        target: root
        property: "introProgress"
        from: 0
        to: 1
        duration: 180
        easing.type: Easing.OutCubic
    }

    // Simple light theme (consistent + compact)
    property color bgColor: "#f6f7f9"
    property color cardColor: "#ffffff"
    property color cardHoverColor: "#f2f4f7"
    property color accentColor: "#2563eb"
    property color textPrimary: "#111827"
    property color textSecondary: "#6b7280"
    property color borderColor: "#d0d7de"
    property color dangerColor: "#dc2626"
    property color successColor: accentColor
    property color warningColor: accentColor
    property color infoColor: accentColor

    property int pageMargin: Math.max(12, Math.min(24, Math.round(Math.min(width, height) * 0.035)))
    property bool compactHeader: width < 900
    property bool veryCompactHeader: width < 740

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
        introAnim.restart()
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
            case "Active": return accentColor
            case "Completed": return textSecondary
            case "Archived": return textSecondary
            default: return textSecondary
        }
    }

    function getFilterCount(statusKey) {
        var list = allProjects || []

        // Mirror search filtering so counts stay meaningful while typing.
        if (searchQuery && searchQuery.length > 0) {
            var query = searchQuery.toLowerCase()
            list = list.filter(function(p) {
                return (p.name && p.name.toLowerCase().indexOf(query) >= 0) ||
                       (p.description && p.description.toLowerCase().indexOf(query) >= 0)
            })
        }

        if (statusKey === "all")
            return list.length

        return list.filter(function(p) {
            return (p.status || "Active") === statusKey
        }).length
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: pageMargin
        spacing: 16
        opacity: root.introProgress
        transform: Translate { y: (1 - root.introProgress) * 8 }

        // Header Card - Enhanced with search, sort, filter
        Rectangle {
            Layout.fillWidth: true
            height: 56
            radius: 6
            color: cardColor
            border.color: borderColor
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10

                // Back button
                Rectangle {
                    width: 32
                    height: 32
                    radius: 6
                    color: backMa.containsMouse ? bgColor : "transparent"
                    border.color: backMa.containsMouse ? accentColor : borderColor
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    ToolTip.visible: backMa.containsMouse
                    ToolTip.text: "Back"
                    ToolTip.delay: 500

                    Text {
                        anchors.centerIn: parent
                        text: "\uf060"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 12
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
                    height: 24
                    color: borderColor
                }

                // Logo
                Image {
                    visible: !veryCompactHeader
                    source: "qrc:/logo/SiteSurveyor.png"
                    sourceSize.height: 28
                    fillMode: Image.PreserveAspectFit
                }

                // Title section
                ColumnLayout {
                    spacing: 2

                    Text {
                        text: discipline
                        font.family: "Codec Pro"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: textPrimary
                    }

                    Text {
                        text: allProjects.length + " " + (allProjects.length !== 1 ? "projects" : "project")
                        font.family: "Codec Pro"
                        font.pixelSize: 9
                        color: textSecondary
                    }
                }

                Item { Layout.fillWidth: true }

                // Functional Search field
                Rectangle {
                    width: Math.max(160, Math.min(260, Math.round(root.width * 0.22)))
                    height: 32
                    radius: 6
                    color: searchField.activeFocus ? "#ffffff" : bgColor
                    border.color: searchField.activeFocus ? accentColor : borderColor
                    border.width: searchField.activeFocus ? 2 : 1

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Behavior on border.width { NumberAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: "\uf002"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 11
                            color: textSecondary
                        }

                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            placeholderText: "Search projects..."
                            font.family: "Codec Pro"
                            font.pixelSize: 11
                            color: textPrimary
                            placeholderTextColor: textSecondary
                            background: Item {}
                            leftPadding: 0
                            rightPadding: 0
                            
                            onTextChanged: searchQuery = text
                        }

                        // Clear button
                        Rectangle {
                            width: 16
                            height: 16
                            radius: 8
                            color: clearSearchMa.containsMouse ? borderColor : "transparent"
                            visible: searchField.text.length > 0

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 8
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
                    width: sortRow.width + 20
                    height: 32
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
                            font.pixelSize: 9
                            color: textSecondary
                        }

                        Text {
                            visible: !veryCompactHeader
                            text: sortBy === "name" ? "Name" : sortBy === "date" ? "Created" : "Recent"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            color: textPrimary
                        }

                        Text {
                            text: "\uf078"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 7
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
                    width: 64
                    height: 32
                    radius: 6
                    color: bgColor
                    border.color: borderColor
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 2
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
                                font.pixelSize: 11
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
                                font.pixelSize: 11
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

                // Database location button
                Rectangle {
                    width: dbLocRow.width + 20
                    height: 32
                    radius: 6
                    color: dbLocMa.containsMouse ? Qt.darker(bgColor, 1.03) : bgColor
                    border.color: borderColor
                    border.width: 1

                    ToolTip.visible: dbLocMa.containsMouse
                    ToolTip.text: "Change database location: " + Database.databasePath
                    ToolTip.delay: 500

                    RowLayout {
                        id: dbLocRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "\uf07b"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 10
                            color: textSecondary
                        }

                        Text {
                            visible: !veryCompactHeader
                            text: "Database"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            color: textPrimary
                        }

                        Text {
                            text: "\uf078"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 7
                            color: textSecondary
                        }
                    }

                    MouseArea {
                        id: dbLocMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dbLocationMenu.open()
                    }

                    Menu {
                        id: dbLocationMenu
                        y: parent.height + 4

                        MenuItem {
                            text: "Open existing database..."
                            font.family: "Codec Pro"
                            onTriggered: openDbDialog.open()
                        }
                        MenuItem {
                            text: "Create new database..."
                            font.family: "Codec Pro"
                            onTriggered: newDbDialog.open()
                        }
                        MenuSeparator {}
                        MenuItem {
                            text: "Current: " + Database.databasePath.split("/").pop()
                            font.family: "Codec Pro"
                            font.pixelSize: 9
                            enabled: false
                        }
                    }
                }

                // Create new project button
                Rectangle {
                    width: newProjectRow.width + 20
                    height: 32
                    radius: 6
                    color: newBtnMa.containsMouse ? Qt.darker(accentColor, 1.1) : accentColor

                    Behavior on color { ColorAnimation { duration: 150 } }

                    ToolTip.visible: newBtnMa.containsMouse
                    ToolTip.text: "New project"
                    ToolTip.delay: 500

                    RowLayout {
                        id: newProjectRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "\uf067"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 10
                            color: "white"
                        }

                        Text {
                            visible: !veryCompactHeader
                            text: "New"
                            font.family: "Codec Pro"
                            font.pixelSize: 11
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
            height: selectionMode ? 40 : 0
            radius: 6
            color: Qt.lighter(accentColor, 1.95)
            border.color: Qt.lighter(accentColor, 1.5)
            border.width: 1
            clip: true
            visible: selectionMode
            
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10
                
                // Checkbox for select all
                Rectangle {
                    width: 20
                    height: 20
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
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: accentColor
                }
                
                Item { Layout.fillWidth: true }
                
                // Bulk status change
                Rectangle {
                    width: statusBulkRow.width + 16
                    height: 28
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
                            font.pixelSize: 10
                            color: accentColor
                        }
                        
                        Text {
                            text: "Status"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
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
                    width: deleteBulkRow.width + 16
                    height: 28
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
                            font.pixelSize: 10
                            color: dangerColor
                        }
                        
                        Text {
                            text: "Delete"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
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
                    width: 28
                    height: 28
                    radius: 6
                    color: cancelSelMa.containsMouse ? Qt.lighter(accentColor, 1.7) : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 11
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
                    width: filterTabRow.width + 14
                    height: 26
                    radius: 13
                    color: filterStatus === modelData.key ? accentColor : 
                           filterTabMa.containsMouse ? Qt.lighter(accentColor, 1.9) : "transparent"
                    border.color: filterStatus === modelData.key ? accentColor : borderColor
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    
                    RowLayout {
                        id: filterTabRow
                        anchors.centerIn: parent
                        spacing: 6
                        
                        Text {
                            text: modelData.icon
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 9
                            color: filterStatus === modelData.key ? "white" : textSecondary
                        }
                        
                        Text {
                            text: modelData.label
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            color: filterStatus === modelData.key ? "white" : textPrimary
                        }

                        Rectangle {
                            width: countText.width + 10
                            height: 16
                            radius: 8
                            color: filterStatus === modelData.key ? Qt.rgba(1, 1, 1, 0.25) : bgColor
                            border.color: filterStatus === modelData.key ? Qt.rgba(1, 1, 1, 0.35) : borderColor
                            border.width: 1

                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: getFilterCount(modelData.key)
                                font.family: "Codec Pro"
                                font.pixelSize: 9
                                font.weight: Font.Medium
                                color: filterStatus === modelData.key ? "white" : textSecondary
                            }
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
                width: selectModeRow.width + 14
                height: 26
                radius: 13
                color: selectionMode ? warningColor : selectModeMa.containsMouse ? bgColor : "transparent"
                border.color: selectionMode ? warningColor : borderColor
                border.width: 1

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }
                
                RowLayout {
                    id: selectModeRow
                    anchors.centerIn: parent
                    spacing: 6
                    
                    Text {
                        text: "\uf14a"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 9
                        color: selectionMode ? "white" : textSecondary
                    }
                    
                    Text {
                        text: selectionMode ? "Exit Select" : "Select"
                        font.family: "Codec Pro"
                        font.pixelSize: 10
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
                width: Math.min(420, parent.width - 40)
                height: Math.min(340, parent.height - 40)
                radius: 8
                color: cardColor
                border.color: borderColor
                border.width: 1
                visible: allProjects.length === 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    // Icon container
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 56
                        height: 56
                        radius: 28
                        color: Qt.lighter(accentColor, 1.92)

                        Text {
                            anchors.centerIn: parent
                            text: "\uf07b"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 20
                            color: accentColor
                        }
                    }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: discipline
                font.family: "Codec Pro"
                font.pixelSize: 14
                font.weight: Font.Medium
                color: textPrimary
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Create your first project"
                font.family: "Codec Pro"
                font.pixelSize: 11
                color: textSecondary
            }

                    // Quick start tips
                    Rectangle {
                        Layout.fillWidth: true
                        height: 100
                        radius: 6
                        color: bgColor
                        border.color: borderColor
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                    Text {
                        text: "Tips"
                        font.family: "Codec Pro"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: textPrimary
                    }

                    RowLayout {
                        spacing: 8
                        Text {
                            text: "\uf00c"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 9
                            color: successColor
                        }
                        Text {
                            text: "Set project location on map"
                            font.family: "Codec Pro"
                            font.pixelSize: 9
                            color: textSecondary
                        }
                    }

                    RowLayout {
                        spacing: 8
                        Text {
                            text: "\uf00c"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 9
                            color: successColor
                        }
                        Text {
                            text: "Import data from CSV"
                            font.family: "Codec Pro"
                            font.pixelSize: 9
                            color: textSecondary
                        }
                    }

                    RowLayout {
                        spacing: 8
                        Text {
                            text: "\uf00c"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 9
                            color: successColor
                        }
                        Text {
                            text: "Add survey points & data"
                            font.family: "Codec Pro"
                            font.pixelSize: 9
                            color: textSecondary
                        }
                    }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Create button
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: createFirstRow.width + 34
                        height: 40
                        radius: 6
                        color: emptyBtnMa.containsMouse ? Qt.darker(accentColor, 1.1) : accentColor

                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            id: createFirstRow
                            anchors.centerIn: parent
                            spacing: 10

                            Text {
                                text: "\uf067"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 12
                                color: "white"
                            }

                            Text {
                                text: "Create Project"
                                font.family: "Codec Pro"
                                font.pixelSize: 11
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
                width: Math.min(340, parent.width - 40)
                height: Math.min(190, parent.height - 40)
                radius: 8
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
                        font.pixelSize: 24
                        color: textSecondary
                    }
                    
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No projects found"
                        font.family: "Codec Pro"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: textPrimary
                    }
                    
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: searchQuery.length > 0 ? 
                              "No results for \"" + searchQuery + "\"" :
                              "No " + filterStatus + " projects"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: textSecondary
                    }
                    
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: clearFiltersText.width + 20
                        height: 28
                        radius: 6
                        color: clearFiltersMa.containsMouse ? bgColor : "transparent"
                        border.color: borderColor
                        border.width: 1
                        
                        Text {
                            id: clearFiltersText
                            anchors.centerIn: parent
                            text: "Clear Filters"
                            font.family: "Codec Pro"
                            font.pixelSize: 11
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

                property int columns: Math.max(1, Math.floor(width / 320))
                cellWidth: width / columns
                cellHeight: 170
                clip: true

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

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
                        anchors.margins: 6
                        radius: 8
                        color: isItemSelected ? Qt.lighter(accentColor, 1.95) : 
                               cardMa.containsMouse ? cardHoverColor : cardColor
                        border.color: isItemSelected ? accentColor : 
                                      cardMa.containsMouse ? accentColor : borderColor
                        border.width: isItemSelected || cardMa.containsMouse ? 2 : 1
                        scale: cardMa.pressed ? 0.99 : 1.0
                        transformOrigin: Item.Center

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

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
                            anchors.margins: 12
                            spacing: 6

                            // Top row: Checkbox (if selection mode), Icon, Title, Status, Delete
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                
                                // Selection checkbox
                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 4
                                    color: isItemSelected ? accentColor : "transparent"
                                    border.color: isItemSelected ? accentColor : borderColor
                                    border.width: 2
                                    visible: selectionMode
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf00c"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 10
                                        color: "white"
                                        visible: isItemSelected
                                    }
                                }

                                // Project icon
                                Rectangle {
                                    width: 34
                                    height: 34
                                    radius: 6
                                    color: Qt.lighter(getStatusColor(itemStatus), 1.85)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf07c"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 14
                                        color: getStatusColor(itemStatus)
                                    }
                                }

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
                                        text: formatRelativeTime(modelData.lastAccessed || modelData.createdAt)
                                        font.family: "Codec Pro"
                                        font.pixelSize: 9
                                        color: textSecondary
                                    }
                                }
                                
                                // Status badge
                                Rectangle {
                                    width: statusText.width + 10
                                    height: 18
                                    radius: 9
                                    color: Qt.lighter(getStatusColor(itemStatus), 1.8)
                                    
                                    Text {
                                        id: statusText
                                        anchors.centerIn: parent
                                        text: itemStatus
                                        font.family: "Codec Pro"
                                        font.pixelSize: 8
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
                                            text: "Edit Details"
                                            font.family: "Codec Pro"
                                            onTriggered: openEditDialog(modelData)
                                        }

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
                                    width: 24
                                    height: 24
                                    radius: 6
                                    color: deleteMa.containsMouse ? Qt.lighter(dangerColor, 1.75) : "transparent"
                                    opacity: cardMa.containsMouse ? 1 : 0.3
                                    visible: !selectionMode

                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf1f8"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 10
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
                                font.pixelSize: 10
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
                                    width: pointsRow.width + 10
                                    height: 20
                                    radius: 5
                                    color: bgColor

                                    RowLayout {
                                        id: pointsRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: "\uf3c5"
                                            font.family: "Font Awesome 5 Pro Solid"
                                            font.pixelSize: 8
                                            color: accentColor
                                        }

                                        Text {
                                            text: pointCount + " point" + (pointCount !== 1 ? "s" : "")
                                            font.family: "Codec Pro"
                                            font.pixelSize: 9
                                            color: textPrimary
                                        }
                                    }
                                }

                                // Location Badge
                                Rectangle {
                                    visible: modelData.centerY !== 0 || modelData.centerX !== 0
                                    width: locRow.width + 10
                                    height: 20
                                    radius: 5
                                    color: bgColor

                                    RowLayout {
                                        id: locRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: "\uf5a0"
                                            font.family: "Font Awesome 5 Pro Solid"
                                            font.pixelSize: 8
                                            color: accentColor
                                        }

                                        Text {
                                            text: "Location"
                                            font.family: "Codec Pro"
                                            font.pixelSize: 9
                                            color: textPrimary
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Open arrow indicator
                                Text {
                                    text: selectionMode ? "" : "\uf061"
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 11
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
                spacing: 2

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
                
                model: projectsList
                
                delegate: Rectangle {
                    width: projectsList_ListView.width
                    height: 48
                    radius: 6
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
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10
                        
                        // Checkbox
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 4
                            color: isSelected(modelData.id) ? accentColor : "transparent"
                            border.color: isSelected(modelData.id) ? accentColor : borderColor
                            border.width: 2
                            visible: selectionMode
                            
                            Text {
                                anchors.centerIn: parent
                                text: "\uf00c"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 9
                                color: "white"
                                visible: isSelected(modelData.id)
                            }
                        }
                        
                        // Icon
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 6
                            color: Qt.lighter(getStatusColor(itemStatus), 1.85)
                            
                            Text {
                                anchors.centerIn: parent
                                text: "\uf07c"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 12
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
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: textPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            
                            Text {
                                text: modelData.description || "No description"
                                font.family: "Codec Pro"
                                font.pixelSize: 10
                                color: textSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                        
                        // Points
                        Text {
                            text: pointCount + " pts"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            color: textSecondary
                            Layout.preferredWidth: 50
                        }
                        
                        // Status
                        Rectangle {
                            width: listStatusText.width + 10
                            height: 18
                            radius: 9
                            color: Qt.lighter(getStatusColor(itemStatus), 1.8)
                            
                            Text {
                                id: listStatusText
                                anchors.centerIn: parent
                                text: itemStatus
                                font.family: "Codec Pro"
                                font.pixelSize: 8
                                color: getStatusColor(itemStatus)
                            }
                        }
                        
                        // Last accessed
                        Text {
                            text: formatRelativeTime(modelData.lastAccessed || modelData.createdAt)
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            color: textSecondary
                            Layout.preferredWidth: 80
                            horizontalAlignment: Text.AlignRight
                        }
                        
                        // Edit button
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 6
                            color: listEditMa.containsMouse ? Qt.lighter(accentColor, 1.75) : "transparent"
                            visible: !selectionMode
                            
                            Text {
                                anchors.centerIn: parent
                                text: "\uf044"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 10
                                color: listEditMa.containsMouse ? accentColor : textSecondary
                            }
                            
                            MouseArea {
                                id: listEditMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: openEditDialog(modelData)
                            }
                        }

                        // Delete button
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 6
                            color: listDeleteMa.containsMouse ? Qt.lighter(dangerColor, 1.75) : "transparent"
                            visible: !selectionMode
                            
                            Text {
                                anchors.centerIn: parent
                                text: "\uf1f8"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 10
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
        width: Math.min(420, root.width - 40)
        height: Math.min(480, root.height - 60)
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
            id: createDialogBg
            color: cardColor
            radius: 6
            border.color: borderColor
            border.width: 1
            opacity: createProjectDialog.visible ? 1 : 0
            scale: createProjectDialog.visible ? 1 : 0.98
            transformOrigin: Item.Center

            Behavior on opacity { NumberAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        header: Rectangle {
            color: cardColor
            height: 48
            radius: 6

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: borderColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10
                
                // Icon
                Rectangle {
                    width: 32
                    height: 32
                    radius: 6
                    color: Qt.lighter(accentColor, 1.9)
                    
                    Text {
                        anchors.centerIn: parent
                        text: "\uf07c"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 12
                        color: accentColor
                    }
                }

                Text {
                    text: "Create Project"
                    font.family: "Codec Pro"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: textPrimary
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: closeDialogMa.containsMouse ? bgColor : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 11
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
                spacing: 12

                Item { height: 4 }

                // Project Name Field
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 4

                    Text {
                        text: "Name"
                        font.family: "Codec Pro"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: textPrimary
                    }

                    TextField {
                        id: projectNameField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        placeholderText: "e.g., Bridge Survey"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: textPrimary
                        placeholderTextColor: textSecondary
                        leftPadding: 10
                        rightPadding: 10
                        selectByMouse: true

                        background: Rectangle {
                            color: bgColor
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
                        text: "Name is required"
                        font.family: "Codec Pro"
                        font.pixelSize: 9
                        color: dangerColor
                    }
                }

                // Description Field
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 4

                    Text {
                        text: "Description"
                        font.family: "Codec Pro"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: textPrimary
                    }

                    TextField {
                        id: projectDescField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        placeholderText: "Project details"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: textPrimary
                        placeholderTextColor: textSecondary
                        leftPadding: 10
                        rightPadding: 10
                        selectByMouse: true

                        background: Rectangle {
                            color: bgColor
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
                        text: "Description is required"
                        font.family: "Codec Pro"
                        font.pixelSize: 9
                        color: dangerColor
                    }
                }

                // Location section with Map Picker
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Location"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: textPrimary
                        }
                        
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: crsLabel.width + 12
                            height: 18
                            radius: 9
                            color: Qt.lighter(accentColor, 1.9)

                            Text {
                                id: crsLabel
                                anchors.centerIn: parent
                                text: "Lo29"
                                font.family: "Codec Pro"
                                font.pixelSize: 8
                                font.weight: Font.Medium
                                color: accentColor
                            }
                        }
                    }

                    MapPicker {
                        id: mapPicker
                        Layout.fillWidth: true
                        Layout.preferredHeight: 140
                        accentColor: root.accentColor
                        textPrimary: root.textPrimary
                        textSecondary: root.textSecondary
                        borderColor: root.borderColor
                    }
                    
                    Text {
                        visible: formSubmitted && !mapPicker.locationPicked
                        text: "Location required"
                        font.family: "Codec Pro"
                        font.pixelSize: 9
                        color: dangerColor
                    }
                }

                Item { height: 4 }
            }
        }

        footer: Item {
            width: parent.width
            height: 56
            z: 100
            
            Rectangle {
                anchors.fill: parent
                color: bgColor
                radius: 6
                
                // Top border line
                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: borderColor
                }
                
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    
                    // Cancel button
                    Button {
                        id: cancelBtn
                        text: "Cancel"
                        Layout.preferredHeight: 34
                        Layout.preferredWidth: implicitWidth + 20
                        
                        contentItem: Text {
                            text: cancelBtn.text
                            font.family: "Codec Pro"
                            font.pixelSize: 11
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
                        Layout.preferredHeight: 34
                        Layout.preferredWidth: implicitWidth + 20
                        
                        property bool canCreate: projectNameField.text.length > 0 &&
                                                 projectDescField.text.length > 0 &&
                                                 mapPicker.locationPicked
                        
                        contentItem: Text {
                            text: createBtn.text
                            font.family: "Codec Pro"
                            font.pixelSize: 11
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

    // Edit Project Dialog
    property int editProjectId: -1
    
    function openEditDialog(project) {
        editProjectId = project.id
        editNameField.text = project.name
        editDescField.text = project.description || ""
        // Map picker setup
        if (editMapPicker) {
            if (project.centerY !== 0 || project.centerX !== 0) {
                editMapPicker.setLocationFromLo29(project.centerY, project.centerX)
            } else {
                editMapPicker.locationPicked = false
                editMapPicker.selectedY = 0
                editMapPicker.selectedX = 0
            }
        }
        editProjectDialog.open()
    }

    Dialog {
        id: editProjectDialog
        anchors.centerIn: parent
        width: Math.min(420, root.width - 40)
        height: Math.min(480, root.height - 60)
        modal: true
        padding: 0
        dim: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        onOpened: {
            editNameField.forceActiveFocus()
        }
        
        Overlay.modal: Rectangle {
            color: "#80000000"
        }

        background: Rectangle {
            color: cardColor
            radius: 6
            border.color: borderColor
            border.width: 1
            opacity: editProjectDialog.visible ? 1 : 0
            scale: editProjectDialog.visible ? 1 : 0.98
            transformOrigin: Item.Center

            Behavior on opacity { NumberAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        header: Rectangle {
            color: cardColor
            height: 48
            radius: 6

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: borderColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10
                
                // Icon
                Rectangle {
                    width: 32
                    height: 32
                    radius: 6
                    color: Qt.lighter(accentColor, 1.9)
                    
                    Text {
                        anchors.centerIn: parent
                        text: "\uf044" // Edit icon
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 12
                        color: accentColor
                    }
                }

                Text {
                    text: "Edit Project"
                    font.family: "Codec Pro"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: textPrimary
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: closeEditDialogMa.containsMouse ? bgColor : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 11
                        color: textSecondary
                    }

                    MouseArea {
                        id: closeEditDialogMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editProjectDialog.close()
                    }
                }
            }
        }

        contentItem: Flickable {
            id: editFormFlickable
            contentWidth: width
            contentHeight: editFormColumn.height + 20
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: editFormColumn
                width: parent.width
                spacing: 12

                Item { height: 4 }

                // Project Name Field
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 4

                    Text {
                        text: "Name"
                        font.family: "Codec Pro"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: textPrimary
                    }

                    TextField {
                        id: editNameField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        placeholderText: "Project Name"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: textPrimary
                        placeholderTextColor: textSecondary
                        leftPadding: 10
                        rightPadding: 10
                        selectByMouse: true

                        background: Rectangle {
                            color: bgColor
                            radius: 6
                            border.color: editNameField.activeFocus ? accentColor : borderColor
                            border.width: editNameField.activeFocus ? 2 : 1
                        }
                    }
                }

                // Description Field
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 4

                    Text {
                        text: "Description"
                        font.family: "Codec Pro"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: textPrimary
                    }

                    TextField {
                        id: editDescField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        placeholderText: "Project details"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: textPrimary
                        placeholderTextColor: textSecondary
                        leftPadding: 10
                        rightPadding: 10
                        selectByMouse: true

                        background: Rectangle {
                            color: bgColor
                            radius: 6
                            border.color: editDescField.activeFocus ? accentColor : borderColor
                            border.width: editDescField.activeFocus ? 2 : 1
                        }
                    }
                }

                // Location section with Map Picker
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Location"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: textPrimary
                        }
                        
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: editCrsLabel.width + 12
                            height: 18
                            radius: 9
                            color: Qt.lighter(accentColor, 1.9)

                            Text {
                                id: editCrsLabel
                                anchors.centerIn: parent
                                text: "Lo29"
                                font.family: "Codec Pro"
                                font.pixelSize: 8
                                font.weight: Font.Medium
                                color: accentColor
                            }
                        }
                    }

                    MapPicker {
                        id: editMapPicker
                        Layout.fillWidth: true
                        Layout.preferredHeight: 140
                        accentColor: root.accentColor
                        textPrimary: root.textPrimary
                        textSecondary: root.textSecondary
                        borderColor: root.borderColor
                    }
                }

                Item { height: 4 }
            }
        }

        footer: Item {
            width: parent.width
            height: 56
            z: 100
            
            Rectangle {
                anchors.fill: parent
                color: bgColor
                radius: 6
                
                // Top border line
                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: borderColor
                }
                
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    
                    // Cancel button
                    Button {
                        text: "Cancel"
                        Layout.preferredHeight: 34
                        Layout.preferredWidth: implicitWidth + 20
                        
                        contentItem: Text {
                            text: parent.text
                            font.family: "Codec Pro"
                            font.pixelSize: 11
                            color: textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        background: Rectangle {
                            color: parent.hovered ? Qt.darker(bgColor, 1.05) : "transparent"
                            border.color: borderColor
                            border.width: 1
                            radius: 6
                        }
                        
                        onClicked: editProjectDialog.close()
                    }
                    
                    // Save button
                    Button {
                        id: saveBtn
                        text: "Save Changes"
                        Layout.preferredHeight: 34
                        Layout.preferredWidth: implicitWidth + 20
                        
                        property bool canSave: editNameField.text.length > 0 &&
                                               editDescField.text.length > 0
                        
                        contentItem: Text {
                            text: saveBtn.text
                            font.family: "Codec Pro"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        background: Rectangle {
                            color: saveBtn.canSave ?
                                   (saveBtn.hovered ? Qt.darker(accentColor, 1.1) : accentColor) :
                                   Qt.lighter(accentColor, 1.4)
                            radius: 6
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        
                        onClicked: {
                            if (saveBtn.canSave) {
                                console.log("Updating project...")
                                var result = Database.updateProject(
                                    editProjectId,
                                    editNameField.text,
                                    editDescField.text,
                                    editMapPicker.selectedY,
                                    editMapPicker.selectedX
                                )
                                console.log("Update result:", result)
                                editProjectDialog.close()
                                refreshProjects()
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
            width: 340
        modal: true
        padding: 0
        dim: true

        // Modal overlay
        Overlay.modal: Rectangle {
            color: "#80000000"
        }

        background: Rectangle {
            color: cardColor
            radius: 6
            border.color: borderColor
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 12

            Item { height: 8 }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 52
                height: 52
                radius: 26
                color: Qt.lighter(dangerColor, 1.85)

                Text {
                    anchors.centerIn: parent
                    text: "\uf1f8"
                    font.family: "Font Awesome 5 Pro Solid"
                    font.pixelSize: 18
                    color: dangerColor
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Delete project?"
                font.family: "Codec Pro"
                font.pixelSize: 14
                font.weight: Font.Medium
                color: textPrimary
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                text: "Delete \"" + deleteProjectName + "\"? This action cannot be undone."
                font.family: "Codec Pro"
                font.pixelSize: 11
                color: textSecondary
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Item { height: 8 }
        }

        footer: Rectangle {
            color: bgColor
            height: 56
            radius: 6

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: borderColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: 6
                    color: delCancelMa.containsMouse ? Qt.darker(cardColor, 1.03) : cardColor
                    border.color: borderColor
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
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
                    height: 34
                    radius: 6
                    color: delConfirmMa.containsMouse ? Qt.darker(dangerColor, 1.1) : dangerColor

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Delete"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
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
            width: 360
        modal: true
        padding: 0
        dim: true

        Overlay.modal: Rectangle {
            color: "#80000000"
        }

        background: Rectangle {
            color: cardColor
            radius: 6
            border.color: borderColor
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 12

            Item { height: 8 }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 52
                height: 52
                radius: 26
                color: Qt.lighter(dangerColor, 1.85)

                Text {
                    anchors.centerIn: parent
                    text: "\uf071"
                    font.family: "Font Awesome 5 Pro Solid"
                    font.pixelSize: 18
                    color: dangerColor
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Delete " + selectedProjects.length + " projects?"
                font.family: "Codec Pro"
                font.pixelSize: 14
                font.weight: Font.Medium
                color: textPrimary
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                text: "Delete " + selectedProjects.length + " selected projects? This action cannot be undone."
                font.family: "Codec Pro"
                font.pixelSize: 11
                color: textSecondary
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Item { height: 8 }
        }

        footer: Rectangle {
            color: bgColor
            height: 56
            radius: 6

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: borderColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: 6
                    color: bulkCancelMa.containsMouse ? Qt.darker(cardColor, 1.03) : cardColor
                    border.color: borderColor
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
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
                    height: 34
                    radius: 6
                    color: bulkConfirmMa.containsMouse ? Qt.darker(dangerColor, 1.1) : dangerColor

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Delete"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
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

    // File dialog for opening existing database
    FileDialog {
        id: openDbDialog
        title: "Open Database"
        nameFilters: ["SQLite Database (*.db *.sqlite)"]
        currentFolder: "file://" + Database.databasePath.substring(0, Database.databasePath.lastIndexOf("/"))
        onAccepted: {
            var path = selectedFile.toString().replace("file://", "")
            if (Database.changeDatabasePath(path)) {
                refreshProjects()
            }
        }
    }

    // File dialog for creating new database
    FileDialog {
        id: newDbDialog
        title: "Create New Database"
        nameFilters: ["SQLite Database (*.db)"]
        fileMode: FileDialog.SaveFile
        currentFolder: "file://" + Database.databasePath.substring(0, Database.databasePath.lastIndexOf("/"))
        onAccepted: {
            var path = selectedFile.toString().replace("file://", "")
            // Ensure .db extension
            if (!path.endsWith(".db")) {
                path += ".db"
            }
            if (Database.changeDatabasePath(path)) {
                refreshProjects()
            }
        }
    }

    // Watch for database path changes
    Connections {
        target: Database
        function onDatabasePathChanged() {
            refreshProjects()
        }
    }
}
}
