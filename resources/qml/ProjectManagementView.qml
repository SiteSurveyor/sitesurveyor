import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

    Rectangle {
        anchors.fill: parent
        color: bgColor
    }

    // Get projects for this discipline
    property var projectsList: []

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
        projectsList = Database.getProjects(discipline)
        console.log("Found " + projectsList.length + " projects")
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20

        // Header Card - Enhanced
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
                spacing: 16

                // Back button - larger touch target
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

                // Logo - slightly larger
                Image {
                    source: "qrc:/logo/SiteSurveyor.png"
                    sourceSize.height: 40
                    fillMode: Image.PreserveAspectFit
                }

                // Title section
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: discipline
                        font.family: "Codec Pro"
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: textPrimary
                    }

                    Text {
                        text: projectsList.length + " project" + (projectsList.length !== 1 ? "s" : "") + " in this discipline"
                        font.family: "Codec Pro"
                        font.pixelSize: 12
                        color: textSecondary
                    }
                }

                // Search field placeholder (visual enhancement)
                Rectangle {
                    width: 180
                    height: 36
                    radius: 6
                    color: bgColor
                    border.color: borderColor
                    border.width: 1
                    visible: projectsList.length > 3

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: "\uf002"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 12
                            color: textSecondary
                        }

                        Text {
                            text: "Search projects..."
                            font.family: "Codec Pro"
                            font.pixelSize: 12
                            color: textSecondary
                            Layout.fillWidth: true
                        }
                    }
                }

                // Create new project button - larger and more prominent
                Rectangle {
                    width: newProjectRow.width + 28
                    height: 40
                    radius: 8
                    color: newBtnMa.containsMouse ? Qt.darker(accentColor, 1.1) : accentColor

                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        id: newProjectRow
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "\uf067"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 12
                            color: "white"
                        }

                        Text {
                            text: "New Project"
                            font.family: "Codec Pro"
                            font.pixelSize: 13
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

        // Projects Grid or Empty State
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Empty state card - Enhanced
            Rectangle {
                anchors.centerIn: parent
                width: 400
                height: 280
                radius: 12
                color: cardColor
                border.color: borderColor
                border.width: 1
                visible: projectsList.length === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 16

                    // Icon container with gradient background
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 80
                        height: 80
                        radius: 40
                        color: Qt.lighter(accentColor, 1.92)

                        Text {
                            anchors.centerIn: parent
                            text: "\uf07b"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 32
                            color: accentColor
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No projects yet"
                        font.family: "Codec Pro"
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: textPrimary
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Create your first " + discipline + " project to get started"
                        font.family: "Codec Pro"
                        font.pixelSize: 13
                        color: textSecondary
                    }

                    Item { height: 8 }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: createFirstRow.width + 32
                        height: 44
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
                                text: "Create First Project"
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

            // Projects grid with responsive layout - Enhanced
            GridView {
                id: projectsGrid
                anchors.fill: parent
                anchors.topMargin: 4
                visible: projectsList.length > 0

                // responsive cell width calculation - wider minimum
                property int columns: Math.max(1, Math.floor(width / 340))
                cellWidth: width / columns
                cellHeight: 180
                clip: true

                model: projectsList

                delegate: Item {
                    width: projectsGrid.cellWidth
                    height: projectsGrid.cellHeight

                    Rectangle {
                        id: projectCard
                        anchors.fill: parent
                        anchors.margins: 10
                        radius: 12
                        color: cardMa.containsMouse ? cardHoverColor : cardColor
                        border.color: cardMa.containsMouse ? accentColor : borderColor
                        border.width: cardMa.containsMouse ? 2 : 1

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        scale: cardMa.containsMouse ? 1.01 : 1.0

                        // Card click area
                        MouseArea {
                            id: cardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Database.loadProject(modelData.id)
                                root.projectSelected(modelData.id, modelData.name)
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 10

                            // Top row: Logo, Title, Delete
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                // Project icon with color
                                Rectangle {
                                    width: 44
                                    height: 44
                                    radius: 10
                                    color: Qt.lighter(accentColor, 1.85)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf07c"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 18
                                        color: accentColor
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: modelData.name
                                        font.family: "Codec Pro"
                                        font.pixelSize: 15
                                        font.weight: Font.Bold
                                        color: textPrimary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.createdAt ? "Created " + modelData.createdAt.substring(0, 10) : "Unknown date"
                                        font.family: "Codec Pro"
                                        font.pixelSize: 11
                                        color: textSecondary
                                    }
                                }

                                // Delete button
                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: 8
                                    color: deleteMa.containsMouse ? Qt.lighter(dangerColor, 1.75) : "transparent"
                                    opacity: cardMa.containsMouse ? 1 : 0.4

                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf1f8"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 13
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
                                font.pixelSize: 12
                                color: textSecondary
                                lineHeight: 1.3
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                                verticalAlignment: Text.AlignTop
                            }

                            // Bottom row: Badges
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                // Location Badge
                                Rectangle {
                                    visible: modelData.centerY !== 0 || modelData.centerX !== 0
                                    width: locRow.width + 14
                                    height: 26
                                    radius: 6
                                    color: bgColor

                                    RowLayout {
                                        id: locRow
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Text {
                                            text: "\uf3c5"
                                            font.family: "Font Awesome 5 Pro Solid"
                                            font.pixelSize: 10
                                            color: accentColor
                                        }

                                        Text {
                                            text: "Location"
                                            font.family: "Codec Pro"
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            color: textPrimary
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Open arrow indicator
                                Text {
                                    text: "\uf061"
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
        }
    }

    // Create Project Dialog
    property int deleteProjectId: -1
    property string deleteProjectName: ""

    Dialog {
        id: createProjectDialog
        anchors.centerIn: parent
        width: Math.min(480, root.width - 40)
        height: Math.min(580, root.height - 60)
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

        header: Rectangle {
            color: cardColor
            height: 56
            radius: 4

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

                Text {
                    text: "Create New Project"
                    font.family: "Codec Pro"
                    font.pixelSize: 17
                    font.weight: Font.Medium
                    color: textPrimary
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 32
                    height: 32
                    radius: 4
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
            contentWidth: width
            contentHeight: formColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: formColumn
                width: parent.width
                spacing: 14

                Item { height: 2 }

                // Project Name
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 4

                    Text {
                        text: "Project Name *"
                        font.family: "Codec Pro"
                        font.pixelSize: 12
                        color: textPrimary
                    }

                    TextField {
                        id: projectNameField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        placeholderText: "Enter project name"
                        font.family: "Codec Pro"
                        font.pixelSize: 13
                        color: textPrimary
                        placeholderTextColor: textSecondary
                        leftPadding: 10
                        rightPadding: 10

                        background: Rectangle {
                            color: "#ffffff"
                            radius: 4
                            border.color: projectNameField.activeFocus ? accentColor : borderColor
                            border.width: projectNameField.activeFocus ? 2 : 1
                        }
                    }
                }

                // Description
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 4

                    Text {
                        text: "Description *"
                        font.family: "Codec Pro"
                        font.pixelSize: 12
                        color: textPrimary
                    }

                    TextField {
                        id: projectDescField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        placeholderText: "Enter project description"
                        font.family: "Codec Pro"
                        font.pixelSize: 13
                        color: textPrimary
                        placeholderTextColor: textSecondary
                        leftPadding: 10
                        rightPadding: 10

                        background: Rectangle {
                            color: "#ffffff"
                            radius: 4
                            border.color: projectDescField.activeFocus ? accentColor : borderColor
                            border.width: projectDescField.activeFocus ? 2 : 1
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
                            text: "Project Location *"
                            font.family: "Codec Pro"
                            font.pixelSize: 12
                            color: textPrimary
                        }

                        Rectangle {
                            width: crsLabel.width + 10
                            height: 18
                            radius: 9
                            color: Qt.lighter(accentColor, 1.85)

                            Text {
                                id: crsLabel
                                anchors.centerIn: parent
                                text: "Lo29 (WG)"
                                font.family: "Codec Pro"
                                font.pixelSize: 9
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
                }

                Item { height: 2 }
            }
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

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: cancelText.width + 28
                    height: 38
                    radius: 4
                    color: cancelMa.containsMouse ? Qt.darker(bgColor, 1.05) : "transparent"
                    border.color: borderColor
                    border.width: 1

                    Text {
                        id: cancelText
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: "Codec Pro"
                        font.pixelSize: 13
                        color: textSecondary
                    }

                    MouseArea {
                        id: cancelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: createProjectDialog.close()
                    }
                }

                Rectangle {
                    id: createBtn
                    width: createText.width + 28
                    height: 38
                    radius: 4

                    property bool canCreate: projectNameField.text.length > 0 &&
                                             projectDescField.text.length > 0 &&
                                             mapPicker.locationPicked

                    color: canCreate ?
                           (createBtnMa.containsMouse ? Qt.darker(accentColor, 1.1) : accentColor) :
                           Qt.lighter(accentColor, 1.4)

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: createText
                        anchors.centerIn: parent
                        text: "Create Project"
                        font.family: "Codec Pro"
                        font.pixelSize: 13
                        color: "white"
                    }

                    MouseArea {
                        id: createBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: createBtn.canCreate ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: {
                            if (createBtn.canCreate) {
                                console.log("Creating project:", projectNameField.text)
                                console.log("Description:", projectDescField.text)
                                console.log("Discipline:", discipline)
                                console.log("Y:", mapPicker.selectedY, "X:", mapPicker.selectedX)

                                var result = Database.createProject(
                                    projectNameField.text,
                                    projectDescField.text,
                                    discipline,
                                    mapPicker.selectedY,
                                    mapPicker.selectedX
                                )
                                console.log("Create result:", result)

                                // Clear fields and reset map
                                projectNameField.text = ""
                                projectDescField.text = ""
                                mapPicker.locationPicked = false

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
}
