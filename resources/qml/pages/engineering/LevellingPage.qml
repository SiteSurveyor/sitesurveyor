import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs

Item {
    id: root

    // Theme
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

    // Levelling properties
    property bool isRiseFallMethod: true
    property real startRL: 100.000
    property real closingRL: 100.000
    property string lineName: "New Level Line"

    // Calculations
    property real totalBS: 0
    property real totalFS: 0
    property real totalRise: 0
    property real totalFall: 0
    property real totalDistance: 0
    property real misclose: 0

    // Model
    ListModel { id: levelModel }

    Component.onCompleted: resetTable()

    onIsRiseFallMethodChanged: sidebarFlickable.contentY = 0

    function resetTable() {
        levelModel.clear()
        levelModel.append({
            station: "BM1", bs: 0, is: 0, fs: 0,
            rise: 0, fall: 0, hpc: 0, rl: startRL,
            remarks: "Benchmark", distance: 0, adjRl: startRL
        })
        calculateLevels()
    }

    function calculateLevels() {
        if (levelModel.count === 0) return

        var runningRL = startRL
        var tBS = 0, tFS = 0, tRise = 0, tFall = 0

        levelModel.setProperty(0, "rl", startRL)
        var currentHI = startRL + levelModel.get(0).bs
        levelModel.setProperty(0, "hpc", currentHI)
        tBS += levelModel.get(0).bs

        var lastReading = parseFloat(levelModel.get(0).bs)

        for (var i = 1; i < levelModel.count; i++) {
            var curr = levelModel.get(i)
            var cBS = parseFloat(curr.bs) || 0
            var cIS = parseFloat(curr.is) || 0
            var cFS = parseFloat(curr.fs) || 0

            tBS += cBS; tFS += cFS

            var currentReading = cIS > 0 ? cIS : (cFS > 0 ? cFS : 0)
            var diff = lastReading - currentReading
            var rise = diff > 0 ? diff : 0
            var fall = diff < 0 ? -diff : 0

            runningRL = runningRL + rise - fall
            var rl_HI = currentHI - currentReading

            levelModel.setProperty(i, "rise", rise)
            levelModel.setProperty(i, "fall", fall)
            levelModel.setProperty(i, "rl", isRiseFallMethod ? runningRL : rl_HI)

            tRise += rise; tFall += fall

            if (cFS > 0) {
                if (cBS > 0) {
                    currentHI = (isRiseFallMethod ? runningRL : rl_HI) + cBS
                    lastReading = cBS
                } else {
                    lastReading = 0
                }
            } else {
                lastReading = cIS
            }
            levelModel.setProperty(i, "hpc", currentHI)
        }

        // Distance & Adjustment
        var tDist = 0, distances = []
        for (var j = 0; j < levelModel.count; j++) {
            var d = parseFloat(levelModel.get(j).distance) || 0
            tDist += d
            distances.push(d)
        }
        totalDistance = tDist

        var closingError = closingRL !== 0 ? runningRL - closingRL : 0
        misclose = closingError

        var cumDist = 0
        for (var k = 0; k < levelModel.count; k++) {
            if (k > 0) cumDist += distances[k]
            var correction = (tDist > 0 && closingRL !== 0) ? -(closingError * cumDist / tDist) : 0
            levelModel.setProperty(k, "adjRl", levelModel.get(k).rl + correction)
        }

        totalBS = tBS; totalFS = tFS; totalRise = tRise; totalFall = tFall
    }

    function addRow() {
        levelModel.append({
            station: "P" + levelModel.count,
            bs: 0, is: 0, fs: 0, rise: 0, fall: 0,
            hpc: 0, rl: 0, remarks: "", distance: 0, adjRl: 0
        })
    }

    Rectangle {
        anchors.fill: parent
        color: bgColor
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Left Sidebar - Settings & Summary
        Rectangle {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            color: cardColor
            radius: 12
            border.color: borderColor
            border.width: 1
            clip: true

            Flickable {
                id: sidebarFlickable
                anchors.fill: parent
                anchors.margins: 20
                clip: true
                contentWidth: width
                contentHeight: sidebarContent.height
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                ColumnLayout {
                    id: sidebarContent
                    width: sidebarFlickable.width
                    height: Math.max(implicitHeight, sidebarFlickable.height)
                    spacing: 0

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        width: 40; height: 40; radius: 10
                        color: Qt.lighter(accentColor, 1.85)
                        Text {
                            anchors.centerIn: parent
                            text: "\uf545"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 12
                            color: accentColor
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "Level Line"
                            font.family: "Codec Pro"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: textPrimary
                        }
                        Text {
                            text: "Settings & Results"
                            font.family: "Codec Pro"
                            font.pixelSize: 9
                            color: textSecondary
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    height: 1
                    color: borderColor
                }

                // Line Name
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    spacing: 6

                    Text {
                        text: "Line Name"
                        font.family: "Codec Pro"
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        color: textSecondary
                    }

                    TextField {
                        Layout.fillWidth: true
                        text: lineName
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: textPrimary
                        placeholderText: "Enter line name"
                        placeholderTextColor: Qt.lighter(textSecondary, 1.2)
                        leftPadding: 12; rightPadding: 12
                        background: Rectangle {
                            color: "#f8f9fa"
                            radius: 6
                            border.color: parent.activeFocus ? accentColor : borderColor
                            border.width: parent.activeFocus ? 2 : 1
                        }
                        onTextChanged: lineName = text
                    }
                }

                // Method Selection
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    spacing: 6

                    Text {
                        text: "Calculation Method"
                        font.family: "Codec Pro"
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        color: textSecondary
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: 8
                        color: "#f8f9fa"
                        border.color: borderColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 4

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 6
                                color: isRiseFallMethod ? accentColor : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "Rise & Fall"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 10
                                    font.weight: isRiseFallMethod ? Font.DemiBold : Font.Normal
                                    color: isRiseFallMethod ? "white" : textSecondary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { isRiseFallMethod = true; calculateLevels() }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 6
                                color: !isRiseFallMethod ? accentColor : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "HPC Method"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 10
                                    font.weight: !isRiseFallMethod ? Font.DemiBold : Font.Normal
                                    color: !isRiseFallMethod ? "white" : textSecondary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { isRiseFallMethod = false; calculateLevels() }
                                }
                            }
                        }
                    }
                }

                // Control Points
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    spacing: 6

                    Text {
                        text: "Control Points"
                        font.family: "Codec Pro"
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        color: textSecondary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                text: "Start RL"
                                font.family: "Codec Pro"
                                font.pixelSize: 9
                                color: successColor
                            }
                            TextField {
                                Layout.fillWidth: true
                                text: startRL.toFixed(3)
                                font.family: "Codec Pro"
                                font.pixelSize: 11
                                color: textPrimary
                                horizontalAlignment: Text.AlignHCenter
                                leftPadding: 8; rightPadding: 8
                                background: Rectangle {
                                    color: Qt.lighter(successColor, 1.9)
                                    radius: 6
                                    border.color: successColor
                                    border.width: 1
                                }
                                onEditingFinished: { startRL = parseFloat(text) || 0; calculateLevels() }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                text: "Check RL"
                                font.family: "Codec Pro"
                                font.pixelSize: 9
                                color: infoColor
                            }
                            TextField {
                                Layout.fillWidth: true
                                text: closingRL.toFixed(3)
                                font.family: "Codec Pro"
                                font.pixelSize: 11
                                color: textPrimary
                                horizontalAlignment: Text.AlignHCenter
                                leftPadding: 8; rightPadding: 8
                                background: Rectangle {
                                    color: Qt.lighter(infoColor, 1.9)
                                    radius: 6
                                    border.color: infoColor
                                    border.width: 1
                                }
                                onEditingFinished: { closingRL = parseFloat(text) || 0; calculateLevels() }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 20
                    height: 1
                    color: borderColor
                }

                // Results Summary
                Text {
                    Layout.topMargin: 16
                    text: "CALCULATION RESULTS"
                    font.family: "Codec Pro"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: textSecondary
                    font.letterSpacing: 1
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 12

                    // Stat mini cards
                    Repeater {
                        model: [
                            { label: "Total Distance", value: totalDistance.toFixed(3) + " m", icon: "\uf546", color: infoColor },
                            { label: "Σ Backsight", value: totalBS.toFixed(3), icon: "\uf062", color: successColor },
                            { label: "Σ Foresight", value: totalFS.toFixed(3), icon: "\uf063", color: warningColor },
                            { label: "Total Rise", value: totalRise.toFixed(3), icon: "\uf077", color: successColor },
                            { label: "Total Fall", value: totalFall.toFixed(3), icon: "\uf078", color: dangerColor },
                            { label: "Misclose", value: misclose.toFixed(4) + " m", icon: "\uf12a", color: Math.abs(misclose) < 0.01 ? successColor : dangerColor }
                        ]

                        Rectangle {
                            Layout.fillWidth: true
                            height: 56
                            radius: 8
                            color: Qt.lighter(modelData.color, 1.92)
                            border.color: Qt.lighter(modelData.color, 1.5)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Rectangle {
                                    width: 32; height: 32; radius: 8
                                    color: Qt.lighter(modelData.color, 1.7)
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 10
                                        color: modelData.color
                                    }
                                }

                                ColumnLayout {
                                    spacing: 1
                                    Text {
                                        text: modelData.value
                                        font.family: "Codec Pro"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: textPrimary
                                    }
                                    Text {
                                        text: modelData.label
                                        font.family: "Codec Pro"
                                        font.pixelSize: 8
                                        color: textSecondary
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // Action Buttons
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Button {
                        Layout.fillWidth: true
                        height: 42
                        text: "Calculate & Adjust"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        font.weight: Font.Medium

                        contentItem: RowLayout {
                            spacing: 8
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "\uf1ec"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 10
                                color: "white"
                            }
                            Text {
                                text: "Calculate & Adjust"
                                font.family: "Codec Pro"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: "white"
                            }
                            Item { Layout.fillWidth: true }
                        }

                        background: Rectangle {
                            color: parent.pressed ? Qt.darker(accentColor, 1.1) : (parent.hovered ? Qt.lighter(accentColor, 1.1) : accentColor)
                            radius: 8
                        }

                        onClicked: calculateLevels()
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Button {
                            Layout.fillWidth: true
                            height: 38

                            contentItem: RowLayout {
                                spacing: 6
                                Item { Layout.fillWidth: true }
                                Text { text: "\uf0c7"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 9; color: successColor }
                                Text { text: "Save"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }
                                Item { Layout.fillWidth: true }
                            }

                            background: Rectangle {
                                color: parent.pressed ? Qt.darker("#f8f9fa", 1.05) : (parent.hovered ? "#f0f2f5" : "#f8f9fa")
                                radius: 6
                                border.color: borderColor
                            }

                            onClicked: console.log("Saving...")
                        }

                        Button {
                            Layout.fillWidth: true
                            height: 38

                            contentItem: RowLayout {
                                spacing: 6
                                Item { Layout.fillWidth: true }
                                Text { text: "\uf1c3"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 9; color: infoColor }
                                Text { text: "Export"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }
                                Item { Layout.fillWidth: true }
                            }

                            background: Rectangle {
                                color: parent.pressed ? Qt.darker("#f8f9fa", 1.05) : (parent.hovered ? "#f0f2f5" : "#f8f9fa")
                                radius: 6
                                border.color: borderColor
                            }

                            onClicked: console.log("Exporting...")
                        }
                    }
                }
            }
            }
        }

        // Main Content - Data Table
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: cardColor
            radius: 12
            border.color: borderColor
            border.width: 1

                Flickable {
                    id: tableFlickable
                    anchors.fill: parent
                    anchors.margins: 1
                    contentWidth: Math.max(width, 1100) // Ensure enough width for all columns
                    contentHeight: height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.horizontal: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        active: tableFlickable.moving || tableFlickable.flicking
                    }

                    ColumnLayout {
                        width: tableFlickable.contentWidth
                        height: tableFlickable.height
                        spacing: 0

                        // Table Header Bar
                        Rectangle {
                            Layout.fillWidth: true
                            height: 56
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 20
                                anchors.rightMargin: 20
                                spacing: 12

                                Text {
                                    text: "\uf0ce"
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 12
                                    color: accentColor
                                }

                                ColumnLayout {
                                    spacing: 2
                                    Text {
                                        text: "Level Observations"
                                        font.family: "Codec Pro"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: textPrimary
                                    }
                                    Text {
                                        text: levelModel.count + " readings"
                                        font.family: "Codec Pro"
                                        font.pixelSize: 9
                                        color: textSecondary
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Button {
                                    height: 36
                                    contentItem: RowLayout {
                                        spacing: 6
                                        Text { text: "\uf067"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 9; color: "white" }
                                        Text { text: "Add Reading"; font.family: "Codec Pro"; font.pixelSize: 10; font.weight: Font.Medium; color: "white" }
                                    }
                                    background: Rectangle {
                                        color: parent.pressed ? Qt.darker(accentColor, 1.1) : (parent.hovered ? Qt.lighter(accentColor, 1.1) : accentColor)
                                        radius: 6
                                    }
                                    leftPadding: 14; rightPadding: 14
                                    onClicked: addRow()
                                }

                                Button {
                                    height: 36
                                    contentItem: RowLayout {
                                        spacing: 6
                                        Text { text: "\uf2f9"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 9; color: dangerColor }
                                        Text { text: "Reset"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }
                                    }
                                    background: Rectangle {
                                        color: parent.pressed ? "#f0f0f0" : (parent.hovered ? "#f8f8f8" : "transparent")
                                        radius: 6
                                        border.color: borderColor
                                    }
                                    leftPadding: 12; rightPadding: 12
                                    onClicked: resetTable()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: borderColor
                        }

                        // Table
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: 16
                            radius: 8
                            border.color: borderColor
                            clip: true

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0

                                // Column Headers
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 44
                                    color: "#f8f9fb"

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0

                                        // Header cell component
                                        component HdrCell: Rectangle {
                                            Layout.preferredWidth: cellWidth
                                            Layout.fillWidth: fillW
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            property int cellWidth: 80
                                            property bool fillW: false
                                            property string label: ""
                                            property string sublabel: ""

                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 1
                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: label
                                                    font.family: "Codec Pro"
                                                    font.pixelSize: 9
                                                    font.weight: Font.DemiBold
                                                    color: textPrimary
                                                }
                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    visible: sublabel !== ""
                                                    text: sublabel
                                                    font.family: "Codec Pro"
                                                    font.pixelSize: 8
                                                    color: textSecondary
                                                }
                                            }

                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: borderColor
                                            }
                                        }

                                        HdrCell { cellWidth: 45; label: "#" }
                                        HdrCell { fillW: true; label: "Station" }
                                        HdrCell { cellWidth: 75; label: "Dist"; sublabel: "(m)" }
                                        HdrCell { cellWidth: 75; label: "BS" }
                                        HdrCell { cellWidth: 75; label: "IS" }
                                        HdrCell { cellWidth: 75; label: "FS" }
                                        HdrCell { cellWidth: 75; visible: isRiseFallMethod; label: "Rise" }
                                        HdrCell { cellWidth: 75; visible: isRiseFallMethod; label: "Fall" }
                                        HdrCell { cellWidth: 80; visible: !isRiseFallMethod; label: "HPC" }
                                        HdrCell { cellWidth: 90; label: "RL" }
                                        HdrCell { cellWidth: 90; label: "Adj RL" }
                                        HdrCell { fillW: true; label: "Remarks" }
                                        Item { Layout.preferredWidth: 40 }
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: 1
                                        color: borderColor
                                    }
                                }

                                // Data Rows
                                ListView {
                                    id: tableView
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    model: levelModel
                                    boundsBehavior: Flickable.StopAtBounds

                                    ScrollBar.vertical: ScrollBar {
                                        policy: ScrollBar.AsNeeded
                                    }

                                    delegate: Rectangle {
                                        width: tableView.width
                                        height: 40
                                        color: index % 2 === 0 ? "#ffffff" : "#fafbfc"

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: 1
                                            color: "#f0f2f5"
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            spacing: 0

                                            // Data cell component
                                            component DataCell: Rectangle {
                                                Layout.preferredWidth: cellWidth
                                                Layout.fillWidth: fillW
                                                Layout.fillHeight: true
                                                color: "transparent"
                                                property int cellWidth: 80
                                                property bool fillW: false
                                                property alias value: cellInput.text
                                                property bool readOnly: false
                                                property bool highlight: false
                                                property color textColor: textPrimary
                                                property bool bold: false
                                                signal edited(string newValue)

                                                TextInput {
                                                    id: cellInput
                                                    anchors.fill: parent
                                                    anchors.margins: 4
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    font.family: "Codec Pro"
                                                    font.pixelSize: 10
                                                    font.bold: bold
                                                    color: readOnly ? textSecondary : textColor
                                                    readOnly: parent.readOnly
                                                    selectByMouse: !readOnly
                                                    onEditingFinished: parent.edited(text)

                                                    Rectangle {
                                                        visible: parent.activeFocus && !parent.readOnly
                                                        anchors.fill: parent
                                                        anchors.margins: -2
                                                        color: "transparent"
                                                        border.color: accentColor
                                                        border.width: 2
                                                        radius: 4
                                                        z: -1
                                                    }
                                                }

                                                Rectangle {
                                                    visible: highlight
                                                    anchors.fill: parent
                                                    color: Qt.lighter(accentColor, 1.95)
                                                    z: -1
                                                }

                                                Rectangle {
                                                    anchors.right: parent.right
                                                    width: 1
                                                    height: parent.height
                                                    color: "#f0f2f5"
                                                }
                                            }

                                            // Row number
                                            Rectangle {
                                                Layout.preferredWidth: 45
                                                Layout.fillHeight: true
                                                color: "#f8f9fb"
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: index + 1
                                                    font.family: "Codec Pro"
                                                    font.pixelSize: 9
                                                    color: textSecondary
                                                }
                                                Rectangle {
                                                    anchors.right: parent.right
                                                    width: 1; height: parent.height
                                                    color: "#f0f2f5"
                                                }
                                            }

                                            DataCell {
                                                fillW: true
                                                value: model.station
                                                onEdited: levelModel.setProperty(index, "station", newValue)
                                            }
                                            DataCell {
                                                cellWidth: 75
                                                value: model.distance.toFixed(3)
                                                onEdited: { levelModel.setProperty(index, "distance", parseFloat(newValue) || 0); calculateLevels() }
                                            }
                                            DataCell {
                                                cellWidth: 75
                                                value: model.bs === 0 ? "" : model.bs.toFixed(3)
                                                textColor: successColor
                                                onEdited: { levelModel.setProperty(index, "bs", parseFloat(newValue) || 0); calculateLevels() }
                                            }
                                            DataCell {
                                                cellWidth: 75
                                                value: model.is === 0 ? "" : model.is.toFixed(3)
                                                onEdited: { levelModel.setProperty(index, "is", parseFloat(newValue) || 0); calculateLevels() }
                                            }
                                            DataCell {
                                                cellWidth: 75
                                                value: model.fs === 0 ? "" : model.fs.toFixed(3)
                                                textColor: warningColor
                                                onEdited: { levelModel.setProperty(index, "fs", parseFloat(newValue) || 0); calculateLevels() }
                                            }
                                            DataCell {
                                                cellWidth: 75
                                                visible: isRiseFallMethod
                                                value: model.rise > 0 ? model.rise.toFixed(3) : ""
                                                readOnly: true
                                                textColor: successColor
                                            }
                                            DataCell {
                                                cellWidth: 75
                                                visible: isRiseFallMethod
                                                value: model.fall > 0 ? model.fall.toFixed(3) : ""
                                                readOnly: true
                                                textColor: dangerColor
                                            }
                                            DataCell {
                                                cellWidth: 80
                                                visible: !isRiseFallMethod
                                                value: model.hpc.toFixed(3)
                                                readOnly: true
                                            }
                                            DataCell {
                                                cellWidth: 90
                                                value: model.rl.toFixed(3)
                                                readOnly: true
                                                bold: true
                                                textColor: textPrimary
                                            }
                                            DataCell {
                                                cellWidth: 90
                                                value: model.adjRl.toFixed(3)
                                                readOnly: true
                                                bold: true
                                                highlight: true
                                                textColor: accentColor
                                            }
                                            DataCell {
                                                fillW: true
                                                value: model.remarks
                                                onEdited: levelModel.setProperty(index, "remarks", newValue)
                                            }

                                            // Delete button
                                            Rectangle {
                                                Layout.preferredWidth: 40
                                                Layout.fillHeight: true
                                                color: deleteMA.containsMouse ? Qt.lighter(dangerColor, 1.9) : "transparent"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf1f8"
                                                    font.family: "Font Awesome 5 Pro Solid"
                                                    font.pixelSize: 10
                                                    color: deleteMA.containsMouse ? dangerColor : textSecondary
                                                }

                                                MouseArea {
                                                    id: deleteMA
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (levelModel.count > 1) {
                                                            levelModel.remove(index)
                                                            calculateLevels()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Footer Totals
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 44
                                    color: "#f0f4f8"

                                    Rectangle {
                                        anchors.top: parent.top
                                        width: parent.width
                                        height: 1
                                        color: borderColor
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0

                                        Rectangle {
                                            Layout.preferredWidth: 45
                                            Layout.fillHeight: true
                                            color: "transparent"
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Text {
                                                anchors.right: parent.right
                                                anchors.rightMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "TOTALS"
                                                font.family: "Codec Pro"
                                                font.pixelSize: 9
                                                font.weight: Font.Bold
                                                color: textPrimary
                                            }
                                        }

                                        Item {
                                            Layout.preferredWidth: 75
                                            Text {
                                                anchors.centerIn: parent
                                                text: totalDistance.toFixed(3)
                                                font.family: "Codec Pro"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: textPrimary
                                            }
                                        }
                                        Item {
                                            Layout.preferredWidth: 75
                                            Text {
                                                anchors.centerIn: parent
                                                text: totalBS.toFixed(3)
                                                font.family: "Codec Pro"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: successColor
                                            }
                                        }
                                        Item { Layout.preferredWidth: 75 }
                                        Item {
                                            Layout.preferredWidth: 75
                                            Text {
                                                anchors.centerIn: parent
                                                text: totalFS.toFixed(3)
                                                font.family: "Codec Pro"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: warningColor
                                            }
                                        }
                                        Item {
                                            Layout.preferredWidth: 75
                                            visible: isRiseFallMethod
                                            Text {
                                                anchors.centerIn: parent
                                                text: totalRise.toFixed(3)
                                                font.family: "Codec Pro"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: successColor
                                            }
                                        }
                                        Item {
                                            Layout.preferredWidth: 75
                                            visible: isRiseFallMethod
                                            Text {
                                                anchors.centerIn: parent
                                                text: totalFall.toFixed(3)
                                                font.family: "Codec Pro"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: dangerColor
                                            }
                                        }
                                        Item { Layout.preferredWidth: 80; visible: !isRiseFallMethod }
                                        Item { Layout.preferredWidth: 90 }
                                        Item { Layout.preferredWidth: 90 }
                                        Item { Layout.fillWidth: true }
                                        Item { Layout.preferredWidth: 40 }
                                    }
                                }
                            }
                        }
                    }
                }
        }
    }
}
