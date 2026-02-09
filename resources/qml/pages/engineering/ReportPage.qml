import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs

Item {
    id: root

    // Compact light theme
    property color bgColor: "#f6f7f9"
    property color cardColor: "#ffffff"
    property color accentColor: "#2563eb"
    property color textPrimary: "#111827"
    property color textSecondary: "#6b7280"
    property color borderColor: "#d0d7de"
    property color successColor: "#16a34a"
    property color warningColor: "#f59e0b"
    property color dangerColor: "#dc2626"
    property color infoColor: "#0ea5e9"

    // Glass Effect Properties
    property color glassBg: Qt.rgba(1, 1, 1, 0.85)
    property color glassBorder: Qt.rgba(1, 1, 1, 0.6)
    property int glassRadius: 8

    // Project data
    property var projectInfo: Database.currentProjectDetails()
    property string projectName: projectInfo.name || "Unknown Project"
    property string projectDescription: projectInfo.description || "No description"
    property string projectDiscipline: projectInfo.discipline || "Engineering"
    property real projectY: projectInfo.centerY || 0
    property real projectX: projectInfo.centerX || 0
    property int projectSrid: projectInfo.srid || 4326

    // Data from database
    property var personnelList: Database.getPersonnel()
    property var instrumentsList: Database.getInstruments()
    property var surveyPoints: Database.getPointsInBounds(-90, -180, 90, 180)

    // Computed stats
    property int totalPersonnel: personnelList ? personnelList.length : 0
    property int onSitePersonnel: personnelList ? personnelList.filter(p => p.status === "On Site").length : 0
    property int totalInstruments: instrumentsList ? instrumentsList.length : 0
    property int availableInstruments: instrumentsList ? instrumentsList.filter(i => i.status === "Available").length : 0
    property int totalPoints: surveyPoints ? surveyPoints.length : 0

    // Report date
    property string reportDate: Qt.formatDateTime(new Date(), "dd MMMM yyyy, hh:mm")

    function refreshData() {
        projectInfo = Database.currentProjectDetails()
        personnelList = Database.getPersonnel()
        instrumentsList = Database.getInstruments()
        surveyPoints = Database.getPointsInBounds(-90, -180, 90, 180)
        reportDate = Qt.formatDateTime(new Date(), "dd MMMM yyyy, hh:mm")
    }

    Component.onCompleted: refreshData()

    Rectangle {
        anchors.fill: parent
        color: bgColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 0

            // Fixed Header
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Project Report"
                        font.family: "Codec Pro"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: textPrimary
                    }

                    Text {
                        text: "Generated: " + reportDate
                        font.family: "Codec Pro"
                        font.pixelSize: 9
                        color: textSecondary
                    }
                }

                // Refresh button
                Rectangle {
                    width: 90
                    height: 32
                    radius: 4
                    color: refreshMa.containsMouse ? Qt.darker(infoColor, 1.1) : infoColor

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "\uf021"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 9
                            color: "white"
                        }
                        Text {
                            text: "Refresh"
                            font.family: "Codec Pro"
                            font.pixelSize: 9
                            color: "white"
                        }
                    }

                    MouseArea {
                        id: refreshMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: refreshData()
                    }
                }

                // Print button
                Rectangle {
                    width: 80
                    height: 32
                    radius: 4
                    color: printMa.containsMouse ? Qt.darker(successColor, 1.1) : successColor

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "\uf02f"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 9
                            color: "white"
                        }
                        Text {
                            text: "Print"
                            font.family: "Codec Pro"
                            font.pixelSize: 9
                            color: "white"
                        }
                    }

                    MouseArea {
                        id: printMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: saveReportDialog.open()
                    }
                }
            }

            // Scrollable Content
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 16
                contentWidth: width
                contentHeight: contentCol.height + 20
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: contentCol
                    width: parent.width
                    spacing: 16

                    // Project Information Card
                    Rectangle {
                        width: parent.width
                        height: projInfoCol.height + 40
                        color: glassBg
                        radius: glassRadius
                        border.color: glassBorder

                        // Entry Animation
                        opacity: 0
                        transform: Translate {
                            y: 20
                            NumberAnimation on y { to: 0; duration: 500; easing.type: Easing.OutCubic }
                        }
                        NumberAnimation on opacity { to: 1; duration: 500; easing.type: Easing.OutCubic }

                        Column {
                            id: projInfoCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 16

                            Row {
                                spacing: 10
                                Rectangle {
                                    width: 32; height: 32; radius: 6
                                    color: Qt.lighter(accentColor, 1.85)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf15c"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 11
                                        color: accentColor
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Project Information"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: textPrimary
                                }
                            }

                            // Info Grid
                            Grid {
                                width: parent.width
                                columns: 2
                                rowSpacing: 14
                                columnSpacing: 30

                                Column {
                                    width: (parent.width - 30) / 2
                                    spacing: 3
                                    Text { text: "Project Name"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary }
                                    Text { text: projectName; font.family: "Codec Pro"; font.pixelSize: 11; font.weight: Font.Medium; color: textPrimary }
                                }

                                Column {
                                    width: (parent.width - 30) / 2
                                    spacing: 3
                                    Text { text: "Discipline"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary }
                                    Rectangle {
                                        width: discTxt.width + 10; height: 20; radius: 4
                                        color: Qt.lighter(accentColor, 1.85)
                                        Text { id: discTxt; anchors.centerIn: parent; text: projectDiscipline; font.family: "Codec Pro"; font.pixelSize: 9; color: accentColor }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 3
                                    Text { text: "Description"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary }
                                    Text { width: parent.width; text: projectDescription; font.family: "Codec Pro"; font.pixelSize: 11; color: textPrimary; wrapMode: Text.WordWrap }
                                }

                                Column {
                                    width: (parent.width - 30) / 2
                                    spacing: 3
                                    Text { text: "Coordinates (Lo29)"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary }
                                    Text { text: "Y: " + projectY.toFixed(2) + ", X: " + projectX.toFixed(2); font.family: "Codec Pro"; font.pixelSize: 11; color: textPrimary }
                                }

                                Column {
                                    width: (parent.width - 30) / 2
                                    spacing: 3
                                    Text { text: "SRID"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary }
                                    Text { text: "EPSG:" + projectSrid; font.family: "Codec Pro"; font.pixelSize: 11; color: textPrimary }
                                }
                            }
                        }
                    }

                    // Stats Cards Row
                    RowLayout {
                        width: parent.width
                        spacing: 16

                        // Entry Animation
                        opacity: 0
                        transform: Translate {
                            y: 20
                            SequentialAnimation on y {
                                PauseAnimation { duration: 100 }
                                NumberAnimation { to: 0; duration: 500; easing.type: Easing.OutCubic }
                            }
                        }
                        SequentialAnimation on opacity {
                            PauseAnimation { duration: 100 }
                            NumberAnimation { to: 1; duration: 500; easing.type: Easing.OutCubic }
                        }

                        // Personnel Stats
                        Rectangle {
                            Layout.fillWidth: true
                            height: 110
                            color: glassBg
                            radius: glassRadius
                            border.color: glassBorder

                            Column {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                Row {
                                    spacing: 8
                                    Rectangle {
                                        width: 28; height: 28; radius: 6
                                        color: Qt.lighter(accentColor, 1.85)
                                        Text { anchors.centerIn: parent; text: "\uf0c0"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 10; color: accentColor }
                                    }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Personnel"; font.family: "Codec Pro"; font.pixelSize: 11; font.weight: Font.Bold; color: textPrimary }
                                }

                                Row {
                                    spacing: 16
                                    Column {
                                        Text { text: totalPersonnel.toString(); font.family: "Codec Pro"; font.pixelSize: 16; font.weight: Font.Bold; color: accentColor }
                                        Text { text: "Total"; font.family: "Codec Pro"; font.pixelSize: 8; color: textSecondary }
                                    }
                                    Column {
                                        Text { text: onSitePersonnel.toString(); font.family: "Codec Pro"; font.pixelSize: 16; font.weight: Font.Bold; color: successColor }
                                        Text { text: "On Site"; font.family: "Codec Pro"; font.pixelSize: 8; color: textSecondary }
                                    }
                                }
                            }
                        }

                        // Instruments Stats
                        Rectangle {
                            Layout.fillWidth: true
                            height: 110
                            color: glassBg
                            radius: glassRadius
                            border.color: glassBorder

                            Column {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                Row {
                                    spacing: 8
                                    Rectangle {
                                        width: 28; height: 28; radius: 6
                                        color: Qt.lighter(infoColor, 1.85)
                                        Text { anchors.centerIn: parent; text: "\uf0ad"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 10; color: infoColor }
                                    }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Instruments"; font.family: "Codec Pro"; font.pixelSize: 11; font.weight: Font.Bold; color: textPrimary }
                                }

                                Row {
                                    spacing: 16
                                    Column {
                                        Text { text: totalInstruments.toString(); font.family: "Codec Pro"; font.pixelSize: 16; font.weight: Font.Bold; color: infoColor }
                                        Text { text: "Total"; font.family: "Codec Pro"; font.pixelSize: 8; color: textSecondary }
                                    }
                                    Column {
                                        Text { text: availableInstruments.toString(); font.family: "Codec Pro"; font.pixelSize: 16; font.weight: Font.Bold; color: successColor }
                                        Text { text: "Available"; font.family: "Codec Pro"; font.pixelSize: 8; color: textSecondary }
                                    }
                                }
                            }
                        }

                        // Survey Stats
                        Rectangle {
                            Layout.fillWidth: true
                            height: 110
                            color: glassBg
                            radius: glassRadius
                            border.color: glassBorder

                            Column {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                Row {
                                    spacing: 8
                                    Rectangle {
                                        width: 28; height: 28; radius: 6
                                        color: Qt.lighter(successColor, 1.85)
                                        Text { anchors.centerIn: parent; text: "\uf3c5"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 10; color: successColor }
                                    }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Survey Points"; font.family: "Codec Pro"; font.pixelSize: 11; font.weight: Font.Bold; color: textPrimary }
                                }

                                Column {
                                    Text { text: totalPoints.toString(); font.family: "Codec Pro"; font.pixelSize: 18; font.weight: Font.Bold; color: successColor }
                                    Text { text: "Points Recorded"; font.family: "Codec Pro"; font.pixelSize: 8; color: textSecondary }
                                }
                            }
                        }
                    }

                    // Personnel Table
                    Rectangle {
                        width: parent.width
                        height: personnelTableCol.height + 40
                        color: glassBg
                        radius: glassRadius
                        border.color: glassBorder

                        // Entry Animation
                        opacity: 0
                        transform: Translate {
                            y: 30
                            SequentialAnimation on y {
                                PauseAnimation { duration: 200 }
                                NumberAnimation { to: 0; duration: 600; easing.type: Easing.OutCubic }
                            }
                        }
                        SequentialAnimation on opacity {
                            PauseAnimation { duration: 200 }
                            NumberAnimation { to: 1; duration: 600; easing.type: Easing.OutCubic }
                        }

                        Column {
                            id: personnelTableCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 10

                            Row {
                                width: parent.width
                                spacing: 10
                                Rectangle {
                                    width: 32; height: 32; radius: 6
                                    color: Qt.lighter(accentColor, 1.85)
                                    Text { anchors.centerIn: parent; text: "\uf0c0"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 11; color: accentColor }
                                }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "Personnel List"; font.family: "Codec Pro"; font.pixelSize: 12; font.weight: Font.Bold; color: textPrimary }
                                Item { width: 1; height: 1 }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: totalPersonnel + " members"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary }
                            }

                            // Header
                            Rectangle {
                                width: parent.width
                                height: 32
                                color: bgColor
                                radius: 4

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    spacing: 0
                                    Text { width: 180; text: "Name"; font.family: "Codec Pro"; font.pixelSize: 9; font.weight: Font.Bold; color: textSecondary }
                                    Text { width: 140; text: "Role"; font.family: "Codec Pro"; font.pixelSize: 9; font.weight: Font.Bold; color: textSecondary }
                                    Text { width: 130; text: "Phone"; font.family: "Codec Pro"; font.pixelSize: 9; font.weight: Font.Bold; color: textSecondary }
                                    Text { text: "Status"; font.family: "Codec Pro"; font.pixelSize: 9; font.weight: Font.Bold; color: textSecondary }
                                }
                            }

                            // Rows
                            Repeater {
                                model: personnelList
                                Rectangle {
                                    width: parent.width
                                    height: 36
                                    color: index % 2 === 0 ? "transparent" : Qt.lighter(bgColor, 1.03)
                                    radius: 3

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        spacing: 0
                                        Text { width: 180; text: modelData.name || ""; font.family: "Codec Pro"; font.pixelSize: 9; color: textPrimary; elide: Text.ElideRight }
                                        Text { width: 140; text: modelData.role || ""; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary; elide: Text.ElideRight }
                                        Text { width: 130; text: modelData.phone || "-"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary; elide: Text.ElideRight }
                                        Rectangle {
                                            width: pStat.width + 10; height: 20; radius: 3
                                            color: modelData.status === "On Site" ? Qt.lighter(successColor, 1.85) : modelData.status === "Off Site" ? Qt.lighter(warningColor, 1.85) : Qt.lighter(dangerColor, 1.85)
                                            Text { id: pStat; anchors.centerIn: parent; text: modelData.status || ""; font.family: "Codec Pro"; font.pixelSize: 8; color: modelData.status === "On Site" ? successColor : modelData.status === "Off Site" ? warningColor : dangerColor }
                                        }
                                    }
                                }
                            }

                            Text { visible: totalPersonnel === 0; text: "No personnel"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary }
                        }
                    }

                    // Instruments Table
                    Rectangle {
                        width: parent.width
                        height: instrumentsTableCol.height + 40
                        color: glassBg
                        radius: glassRadius
                        border.color: glassBorder

                        // Entry Animation
                        opacity: 0
                        transform: Translate {
                            y: 30
                            SequentialAnimation on y {
                                PauseAnimation { duration: 300 }
                                NumberAnimation { to: 0; duration: 600; easing.type: Easing.OutCubic }
                            }
                        }
                        SequentialAnimation on opacity {
                            PauseAnimation { duration: 300 }
                            NumberAnimation { to: 1; duration: 600; easing.type: Easing.OutCubic }
                        }

                        Column {
                            id: instrumentsTableCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 10

                            Row {
                                width: parent.width
                                spacing: 10
                                Rectangle {
                                    width: 32; height: 32; radius: 6
                                    color: Qt.lighter(infoColor, 1.85)
                                    Text { anchors.centerIn: parent; text: "\uf0ad"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 11; color: infoColor }
                                }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "Instruments List"; font.family: "Codec Pro"; font.pixelSize: 12; font.weight: Font.Bold; color: textPrimary }
                                Item { width: 1; height: 1 }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: totalInstruments + " instruments"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary }
                            }

                            // Header
                            Rectangle {
                                width: parent.width
                                height: 32
                                color: bgColor
                                radius: 4

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    spacing: 0
                                    Text { width: 180; text: "Name"; font.family: "Codec Pro"; font.pixelSize: 9; font.weight: Font.Bold; color: textSecondary }
                                    Text { width: 140; text: "Type"; font.family: "Codec Pro"; font.pixelSize: 9; font.weight: Font.Bold; color: textSecondary }
                                    Text { width: 130; text: "Serial"; font.family: "Codec Pro"; font.pixelSize: 9; font.weight: Font.Bold; color: textSecondary }
                                    Text { text: "Status"; font.family: "Codec Pro"; font.pixelSize: 9; font.weight: Font.Bold; color: textSecondary }
                                }
                            }

                            // Rows
                            Repeater {
                                model: instrumentsList
                                Rectangle {
                                    width: parent.width
                                    height: 36
                                    color: index % 2 === 0 ? "transparent" : Qt.lighter(bgColor, 1.03)
                                    radius: 3

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        spacing: 0
                                        Text { width: 180; text: modelData.name || ""; font.family: "Codec Pro"; font.pixelSize: 9; color: textPrimary; elide: Text.ElideRight }
                                        Text { width: 140; text: modelData.type || ""; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary; elide: Text.ElideRight }
                                        Text { width: 130; text: modelData.serial || "-"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary; elide: Text.ElideRight }
                                        Rectangle {
                                            width: iStat.width + 10; height: 20; radius: 3
                                            color: modelData.status === "Available" ? Qt.lighter(successColor, 1.85) : modelData.status === "In Use" ? Qt.lighter(infoColor, 1.85) : Qt.lighter(warningColor, 1.85)
                                            Text { id: iStat; anchors.centerIn: parent; text: modelData.status || ""; font.family: "Codec Pro"; font.pixelSize: 8; color: modelData.status === "Available" ? successColor : modelData.status === "In Use" ? infoColor : warningColor }
                                        }
                                    }
                                }
                            }

                            Text { visible: totalInstruments === 0; text: "No instruments"; font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary }
                        }
                    }

                    // Footer
                    Rectangle {
                        width: parent.width
                        height: 50
                        color: glassBg
                        radius: glassRadius
                        border.color: glassBorder

                        // Entry Animation
                        opacity: 0
                        transform: Translate {
                            y: 20
                            SequentialAnimation on y {
                                PauseAnimation { duration: 400 }
                                NumberAnimation { to: 0; duration: 500; easing.type: Easing.OutCubic }
                            }
                        }
                        SequentialAnimation on opacity {
                            PauseAnimation { duration: 400 }
                            NumberAnimation { to: 1; duration: 500; easing.type: Easing.OutCubic }
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.margins: 16
                            spacing: 12
                            Text { text: "\uf15c"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 11; color: textSecondary }
                            Column {
                                spacing: 1
                                Text { text: "SiteSurveyor Project Report"; font.family: "Codec Pro"; font.pixelSize: 9; font.weight: Font.Medium; color: textPrimary }
                                Text { text: "Generated: " + reportDate; font.family: "Codec Pro"; font.pixelSize: 8; color: textSecondary }
                            }
                        }
                    }

                    Item { width: 1; height: 20 }
                }
            }
        }
    }

    FileDialog {
        id: saveReportDialog
        title: "Save Report"
        nameFilters: ["Text files (*.txt)"]
        fileMode: FileDialog.SaveFile
        onAccepted: console.log("Saved to:", selectedFile)
    }
}
