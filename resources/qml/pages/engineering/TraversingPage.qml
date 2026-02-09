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

    // Traverse mode
    property int traverseMode: 0
    property bool isLoopTraverse: traverseMode === 0

    // Control Points
    property string openingStationName: isLoopTraverse ? "A" : "BM1"
    property real openingX: 500000.000
    property real openingY: 7800000.000

    property string closingStationName: "BM2"
    property real closingX: 500300.080
    property real closingY: 7800299.443

    // Calculated values
    property real totalDistance: 0
    property real linearMisclose: 0
    property real accuracy: 0
    property real closureX: 0
    property real closureY: 0

    // Model
    ListModel { id: stationsModel }

    Component.onCompleted: initializeTraverse()

    onTraverseModeChanged: sidebarFlickable.contentY = 0

    function initializeTraverse() {
        stationsModel.clear()
        stationsModel.append({
            station: openingStationName, bearing: "", distance: 0,
            deltaX: 0, deltaY: 0, adjX: openingX, adjY: openingY
        })
        calculateTraverse()
    }

    function bearingToDecimal(bearingStr) {
        if (!bearingStr || bearingStr === "-" || bearingStr === "") return 0
        var match = bearingStr.match(/(\d+)[°](\d+)['](\d+\.?\d*)[\"']?/)
        if (match) {
            return parseFloat(match[1]) + parseFloat(match[2])/60.0 + parseFloat(match[3])/3600.0
        }
        return parseFloat(bearingStr) || 0
    }

    function toRadians(deg) { return deg * Math.PI / 180.0 }

    function calculateTraverse() {
        if (stationsModel.count < 2) {
            totalDistance = 0; linearMisclose = 0; accuracy = 0
            return
        }

        var total = 0
        for (var i = 0; i < stationsModel.count; i++) {
            total += stationsModel.get(i).distance
        }
        totalDistance = total

        if (totalDistance === 0) {
            linearMisclose = 0; accuracy = 0
            return
        }

        var sumDX = 0, sumDY = 0
        var departures = [], latitudes = []

        for (var j = 0; j < stationsModel.count; j++) {
            var stn = stationsModel.get(j)
            var bearing = bearingToDecimal(stn.bearing)
            var dist = stn.distance
            var rad = toRadians(bearing)

            var dx = dist * Math.sin(rad)
            var dy = dist * Math.cos(rad)
            departures.push(dx)
            latitudes.push(dy)
            sumDX += dx
            sumDY += dy

            stationsModel.setProperty(j, "deltaX", dx)
            stationsModel.setProperty(j, "deltaY", dy)
        }

        if (isLoopTraverse) {
            closureX = sumDX
            closureY = sumDY
        } else {
            closureX = (openingX + sumDX) - closingX
            closureY = (openingY + sumDY) - closingY
        }

        linearMisclose = Math.sqrt(closureX * closureX + closureY * closureY)
        accuracy = totalDistance > 0 && linearMisclose > 0 ? totalDistance / linearMisclose : 0

        // Apply Bowditch correction
        var cumX = openingX, cumY = openingY
        for (var k = 0; k < stationsModel.count; k++) {
            if (k === 0) {
                stationsModel.setProperty(k, "adjX", openingX)
                stationsModel.setProperty(k, "adjY", openingY)
            } else {
                var d = stationsModel.get(k).distance
                var corrX = -(closureX * d / totalDistance)
                var corrY = -(closureY * d / totalDistance)
                cumX += departures[k] + corrX
                cumY += latitudes[k] + corrY
                stationsModel.setProperty(k, "adjX", cumX)
                stationsModel.setProperty(k, "adjY", cumY)
            }
        }
    }

    function addStation() {
        stationsModel.append({
            station: "P" + stationsModel.count,
            bearing: "0°00'00\"", distance: 0,
            deltaX: 0, deltaY: 0, adjX: 0, adjY: 0
        })
    }

    function getAccuracyGrade() {
        if (accuracy >= 10000) return { grade: "1st Order", color: successColor }
        if (accuracy >= 5000) return { grade: "2nd Order", color: successColor }
        if (accuracy >= 3000) return { grade: "3rd Order", color: warningColor }
        if (accuracy >= 1000) return { grade: "4th Order", color: warningColor }
        return { grade: "Low", color: dangerColor }
    }

    Rectangle {
        anchors.fill: parent
        color: bgColor
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Left Sidebar
        Rectangle {
            Layout.preferredWidth: 300
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
                            text: "\uf124"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 12
                            color: accentColor
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "Traverse"
                            font.family: "Codec Pro"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: textPrimary
                        }
                        Text {
                            text: "Bowditch Adjustment"
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

                // Traverse Type Toggle
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    spacing: 6

                    Text {
                        text: "Traverse Type"
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
                                color: isLoopTraverse ? accentColor : "transparent"

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: "\uf0e2"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 9
                                        color: isLoopTraverse ? "white" : textSecondary
                                    }
                                    Text {
                                        text: "Closed Loop"
                                        font.family: "Codec Pro"
                                        font.pixelSize: 9
                                        font.weight: isLoopTraverse ? Font.DemiBold : Font.Normal
                                        color: isLoopTraverse ? "white" : textSecondary
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { traverseMode = 0; initializeTraverse() }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 6
                                color: !isLoopTraverse ? accentColor : "transparent"

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: "\uf337"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 9
                                        color: !isLoopTraverse ? "white" : textSecondary
                                    }
                                    Text {
                                        text: "Link"
                                        font.family: "Codec Pro"
                                        font.pixelSize: 9
                                        font.weight: !isLoopTraverse ? Font.DemiBold : Font.Normal
                                        color: !isLoopTraverse ? "white" : textSecondary
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { traverseMode = 1; initializeTraverse() }
                                }
                            }
                        }
                    }
                }

                // Starting Point
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    spacing: 8

                    RowLayout {
                        spacing: 6
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: successColor
                        }
                        Text {
                            text: "Starting Point"
                            font.family: "Codec Pro"
                            font.pixelSize: 9
                            font.weight: Font.Medium
                            color: textSecondary
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 80
                        radius: 8
                        color: Qt.lighter(successColor, 1.92)
                        border.color: Qt.lighter(successColor, 1.5)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            TextField {
                                Layout.fillWidth: true
                                text: openingStationName
                                font.family: "Codec Pro"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: textPrimary
                                leftPadding: 8
                                background: Rectangle {
                                    color: "white"
                                    radius: 4
                                    border.color: Qt.lighter(successColor, 1.3)
                                }
                                onTextChanged: openingStationName = text
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                TextField {
                                    Layout.fillWidth: true
                                    text: openingX.toFixed(3)
                                    font.family: "Codec Pro"
                                    font.pixelSize: 9
                                    color: textPrimary
                                    horizontalAlignment: Text.AlignHCenter
                                    background: Rectangle {
                                        color: "white"
                                        radius: 4
                                    }
                                    onEditingFinished: { openingX = parseFloat(text) || 0; calculateTraverse() }
                                }
                                Text {
                                    text: "E"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 9
                                    color: successColor
                                }
                                TextField {
                                    Layout.fillWidth: true
                                    text: openingY.toFixed(3)
                                    font.family: "Codec Pro"
                                    font.pixelSize: 9
                                    color: textPrimary
                                    horizontalAlignment: Text.AlignHCenter
                                    background: Rectangle {
                                        color: "white"
                                        radius: 4
                                    }
                                    onEditingFinished: { openingY = parseFloat(text) || 0; calculateTraverse() }
                                }
                                Text {
                                    text: "N"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 9
                                    color: successColor
                                }
                            }
                        }
                    }
                }

                // Closing Point (Link only)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    spacing: 8
                    visible: !isLoopTraverse

                    RowLayout {
                        spacing: 6
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: dangerColor
                        }
                        Text {
                            text: "Closing Point (Known)"
                            font.family: "Codec Pro"
                            font.pixelSize: 9
                            font.weight: Font.Medium
                            color: textSecondary
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 80
                        radius: 8
                        color: Qt.lighter(dangerColor, 1.92)
                        border.color: Qt.lighter(dangerColor, 1.5)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            TextField {
                                Layout.fillWidth: true
                                text: closingStationName
                                font.family: "Codec Pro"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: textPrimary
                                leftPadding: 8
                                background: Rectangle {
                                    color: "white"
                                    radius: 4
                                    border.color: Qt.lighter(dangerColor, 1.3)
                                }
                                onTextChanged: closingStationName = text
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                TextField {
                                    Layout.fillWidth: true
                                    text: closingX.toFixed(3)
                                    font.family: "Codec Pro"
                                    font.pixelSize: 9
                                    color: textPrimary
                                    horizontalAlignment: Text.AlignHCenter
                                    background: Rectangle { color: "white"; radius: 4 }
                                    onEditingFinished: { closingX = parseFloat(text) || 0; calculateTraverse() }
                                }
                                Text { text: "E"; font.family: "Codec Pro"; font.pixelSize: 9; color: dangerColor }
                                TextField {
                                    Layout.fillWidth: true
                                    text: closingY.toFixed(3)
                                    font.family: "Codec Pro"
                                    font.pixelSize: 9
                                    color: textPrimary
                                    horizontalAlignment: Text.AlignHCenter
                                    background: Rectangle { color: "white"; radius: 4 }
                                    onEditingFinished: { closingY = parseFloat(text) || 0; calculateTraverse() }
                                }
                                Text { text: "N"; font.family: "Codec Pro"; font.pixelSize: 9; color: dangerColor }
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

                // Results
                Text {
                    Layout.topMargin: 16
                    text: "ADJUSTMENT RESULTS"
                    font.family: "Codec Pro"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: textSecondary
                    font.letterSpacing: 1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    spacing: 10

                    // Total Distance
                    Rectangle {
                        Layout.fillWidth: true
                        height: 52
                        radius: 8
                        color: Qt.lighter(infoColor, 1.92)
                        border.color: Qt.lighter(infoColor, 1.5)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Rectangle {
                                width: 28; height: 28; radius: 6
                                color: Qt.lighter(infoColor, 1.7)
                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf546"
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 9
                                    color: infoColor
                                }
                            }
                            ColumnLayout {
                                spacing: 1
                                Text {
                                    text: totalDistance.toFixed(3) + " m"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: textPrimary
                                }
                                Text {
                                    text: "Total Distance"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 8
                                    color: textSecondary
                                }
                            }
                        }
                    }

                    // Linear Misclose
                    Rectangle {
                        Layout.fillWidth: true
                        height: 52
                        radius: 8
                        color: Qt.lighter(linearMisclose < 0.05 ? successColor : dangerColor, 1.92)
                        border.color: Qt.lighter(linearMisclose < 0.05 ? successColor : dangerColor, 1.5)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Rectangle {
                                width: 28; height: 28; radius: 6
                                color: Qt.lighter(linearMisclose < 0.05 ? successColor : dangerColor, 1.7)
                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf12a"
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 9
                                    color: linearMisclose < 0.05 ? successColor : dangerColor
                                }
                            }
                            ColumnLayout {
                                spacing: 1
                                Text {
                                    text: linearMisclose.toFixed(4) + " m"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: textPrimary
                                }
                                Text {
                                    text: "Linear Misclose"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 8
                                    color: textSecondary
                                }
                            }
                        }
                    }

                    // Accuracy
                    Rectangle {
                        Layout.fillWidth: true
                        height: 64
                        radius: 8
                        color: Qt.lighter(getAccuracyGrade().color, 1.92)
                        border.color: Qt.lighter(getAccuracyGrade().color, 1.5)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Rectangle {
                                width: 28; height: 28; radius: 6
                                color: Qt.lighter(getAccuracyGrade().color, 1.7)
                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf2f1"
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 9
                                    color: getAccuracyGrade().color
                                }
                            }
                            ColumnLayout {
                                spacing: 2
                                Text {
                                    text: "1 : " + (accuracy > 0 ? accuracy.toFixed(0) : "∞")
                                    font.family: "Codec Pro"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: textPrimary
                                }
                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: "Accuracy"
                                        font.family: "Codec Pro"
                                        font.pixelSize: 8
                                        color: textSecondary
                                    }
                                    Rectangle {
                                        width: gradeText.width + 8
                                        height: 14
                                        radius: 3
                                        color: getAccuracyGrade().color
                                        Text {
                                            id: gradeText
                                            anchors.centerIn: parent
                                            text: getAccuracyGrade().grade
                                            font.family: "Codec Pro"
                                            font.pixelSize: 8
                                            font.weight: Font.Bold
                                            color: "white"
                                        }
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
                                text: "Calculate Bowditch"
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

                        onClicked: calculateTraverse()
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
                                color: parent.pressed ? "#f0f0f0" : (parent.hovered ? "#f5f5f5" : "#f8f9fa")
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
                                color: parent.pressed ? "#f0f0f0" : (parent.hovered ? "#f5f5f5" : "#f8f9fa")
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

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Header Bar
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
                                text: "Traverse Stations"
                                font.family: "Codec Pro"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: textPrimary
                            }
                            Text {
                                text: stationsModel.count + " stations"
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
                                Text { text: "Add Station"; font.family: "Codec Pro"; font.pixelSize: 10; font.weight: Font.Medium; color: "white" }
                            }
                            background: Rectangle {
                                color: parent.pressed ? Qt.darker(accentColor, 1.1) : (parent.hovered ? Qt.lighter(accentColor, 1.1) : accentColor)
                                radius: 6
                            }
                            leftPadding: 14; rightPadding: 14
                            onClicked: addStation()
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
                            onClicked: initializeTraverse()
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

                        // Header Row
                        Rectangle {
                            Layout.fillWidth: true
                            height: 44
                            color: "#f8f9fb"

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                component HdrCell: Rectangle {
                                    Layout.preferredWidth: cellW
                                    Layout.fillWidth: fillW
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    property int cellW: 90
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
                                        width: 1; height: parent.height
                                        color: borderColor
                                    }
                                }

                                HdrCell { cellW: 45; label: "#" }
                                HdrCell { fillW: true; label: "Station" }
                                HdrCell { cellW: 100; label: "Bearing"; sublabel: "(D°M'S\")" }
                                HdrCell { cellW: 90; label: "Distance"; sublabel: "(m)" }
                                HdrCell { cellW: 100; label: "ΔX"; sublabel: "Departure" }
                                HdrCell { cellW: 100; label: "ΔY"; sublabel: "Latitude" }
                                HdrCell { cellW: 110; label: "Adj Easting" }
                                HdrCell { cellW: 110; label: "Adj Northing" }
                                Item { Layout.preferredWidth: 40 }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width; height: 1
                                color: borderColor
                            }
                        }

                        // Data Rows
                        ListView {
                            id: tableView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: stationsModel
                            boundsBehavior: Flickable.StopAtBounds

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: Rectangle {
                                width: tableView.width
                                height: 42
                                color: index % 2 === 0 ? "#ffffff" : "#fafbfc"

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width; height: 1
                                    color: "#f0f2f5"
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    component DataCell: Rectangle {
                                        Layout.preferredWidth: cellW
                                        Layout.fillWidth: fillW
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        property int cellW: 90
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
                                            width: 1; height: parent.height
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
                                        onEdited: stationsModel.setProperty(index, "station", newValue)
                                    }
                                    DataCell {
                                        cellW: 100
                                        value: model.bearing
                                        onEdited: { stationsModel.setProperty(index, "bearing", newValue); calculateTraverse() }
                                    }
                                    DataCell {
                                        cellW: 90
                                        value: model.distance === 0 ? "" : model.distance.toFixed(3)
                                        onEdited: { stationsModel.setProperty(index, "distance", parseFloat(newValue) || 0); calculateTraverse() }
                                    }
                                    DataCell {
                                        cellW: 100
                                        value: model.deltaX.toFixed(3)
                                        readOnly: true
                                    }
                                    DataCell {
                                        cellW: 100
                                        value: model.deltaY.toFixed(3)
                                        readOnly: true
                                    }
                                    DataCell {
                                        cellW: 110
                                        value: model.adjX.toFixed(3)
                                        readOnly: true
                                        bold: true
                                        textColor: textPrimary
                                    }
                                    DataCell {
                                        cellW: 110
                                        value: model.adjY.toFixed(3)
                                        readOnly: true
                                        bold: true
                                        highlight: true
                                        textColor: accentColor
                                    }

                                    // Delete button
                                    Rectangle {
                                        Layout.preferredWidth: 40
                                        Layout.fillHeight: true
                                        color: delMA.containsMouse ? Qt.lighter(dangerColor, 1.9) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf1f8"
                                            font.family: "Font Awesome 5 Pro Solid"
                                            font.pixelSize: 10
                                            color: delMA.containsMouse ? dangerColor : textSecondary
                                            visible: index > 0
                                        }

                                        MouseArea {
                                            id: delMA
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: index > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: {
                                                if (index > 0) {
                                                    stationsModel.remove(index)
                                                    calculateTraverse()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Footer
                        Rectangle {
                            Layout.fillWidth: true
                            height: 44
                            color: "#f0f4f8"

                            Rectangle {
                                anchors.top: parent.top
                                width: parent.width; height: 1
                                color: borderColor
                            }

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                Item { Layout.preferredWidth: 45 }
                                Item {
                                    Layout.fillWidth: true
                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "TOTALS"
                                        font.family: "Codec Pro"
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        color: textPrimary
                                    }
                                }
                                Item { Layout.preferredWidth: 100 }
                                Item {
                                    Layout.preferredWidth: 90
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
                                    Layout.preferredWidth: 100
                                    Text {
                                        anchors.centerIn: parent
                                        text: closureX.toFixed(3)
                                        font.family: "Codec Pro"
                                        font.pixelSize: 9
                                        color: textSecondary
                                    }
                                }
                                Item {
                                    Layout.preferredWidth: 100
                                    Text {
                                        anchors.centerIn: parent
                                        text: closureY.toFixed(3)
                                        font.family: "Codec Pro"
                                        font.pixelSize: 9
                                        color: textSecondary
                                    }
                                }
                                Item { Layout.preferredWidth: 110 }
                                Item { Layout.preferredWidth: 110 }
                                Item { Layout.preferredWidth: 40 }
                            }
                        }
                    }
                }
            }
        }
    }
}
