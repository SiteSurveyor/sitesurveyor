import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs

Item {
    id: root

    // --- Personnel Page Style Palette ---
    property color bgColor: "#ebedef"
    property color cardColor: "#ffffff"
    property color accentColor: "#321fdb"
    property color textPrimary: "#3c4b64"
    property color textSecondary: "#768192"
    property color borderColor: "#d8dbe0"
    property color successColor: "#2eb85c"
    property color warningColor: "#f9b115"
    property color dangerColor: "#e55353"
    property color infoColor: "#3399ff"

    // Glass Effect Properties
    property color glassBg: Qt.rgba(1, 1, 1, 0.85)
    property color glassBorder: Qt.rgba(1, 1, 1, 0.6)
    property int glassRadius: 8

    // Traverse mode: 0 = Loop, 1 = Link
    property int traverseMode: 0
    property bool isLoopTraverse: traverseMode === 0

    // Control Point Coordinates
    property string openingStationName: isLoopTraverse ? "A" : "BM1"
    property real openingX: 500000.000
    property real openingY: 7800000.000
    property real openingBearing: 0.0

    property string closingStationName: "BM2"
    property real closingX: 500300.080
    property real closingY: 7800299.443
    property real closingBearing: 0.0

    // Traverse data
    property var traverseStations: ListModel {
        id: stationsModel
    }

    // Calculated values
    property real totalDistance: 0
    property real angularMisclose: 0
    property real linearMisclose: 0
    property real accuracy: 0

    Component.onCompleted: {
        initializeTraverse()
    }

    function initializeTraverse() {
        stationsModel.clear()
        if (isLoopTraverse) {
            stationsModel.append({ station: openingStationName, backSight: "-", foreSight: "", bearing: "", distance: 0.000, deltaX: 0.000, deltaY: 0.000, corrX: 0.000, corrY: 0.000, adjX: openingX, adjY: openingY })
        } else {
            stationsModel.append({ station: openingStationName, backSight: "-", foreSight: "", bearing: "", distance: 0.000, deltaX: 0.000, deltaY: 0.000, corrX: 0.000, corrY: 0.000, adjX: openingX, adjY: openingY })
        }
        calculateTraverse()
    }

    function bearingToDecimal(bearingStr) {
        if (!bearingStr || bearingStr === "-" || bearingStr === "") return 0
        var match = bearingStr.match(/(\d+)[°](\d+)['](\d+\.?\d*)[\"']?/)
        if (match) {
            return parseFloat(match[1]) + parseFloat(match[2])/60.0 + parseFloat(match[3])/3600.0
        }
        var val = parseFloat(bearingStr)
        return isNaN(val) ? 0 : val
    }

    function toRadians(degrees) { return degrees * Math.PI / 180.0 }

    function calculateTraverse() {
        if (stationsModel.count < 2) {
            totalDistance=0; angularMisclose=0; linearMisclose=0; accuracy=0; return;
        }

        var total = 0
        for (var i = 0; i < stationsModel.count; i++) total += stationsModel.get(i).distance
        totalDistance = total

        if (totalDistance === 0) { angularMisclose=0; linearMisclose=0; accuracy=0; return; }

        var sumDeltaX = 0, sumDeltaY = 0
        var departures = [], latitudes = []

        for (var i = 0; i < stationsModel.count; i++) {
            var station = stationsModel.get(i)
            var bearing = bearingToDecimal(station.bearing)
            var distance = station.distance
            var bearingRad = toRadians(bearing)

            var deltaX = distance * Math.sin(bearingRad)
            var deltaY = distance * Math.cos(bearingRad)
            departures.push(deltaX); latitudes.push(deltaY)
            sumDeltaX += deltaX; sumDeltaY += deltaY

            stationsModel.setProperty(i, "deltaX", deltaX)
            stationsModel.setProperty(i, "deltaY", deltaY)
        }

        var closureX, closureY
        if (isLoopTraverse) {
            closureX = sumDeltaX; closureY = sumDeltaY
        } else {
            var computedX = openingX + sumDeltaX
            var computedY = openingY + sumDeltaY
            closureX = computedX - closingX
            closureY = computedY - closingY
        }

        linearMisclose = Math.sqrt(closureX*closureX + closureY*closureY)
        accuracy = totalDistance > 0 ? totalDistance / linearMisclose : 0
        angularMisclose = Math.abs(closureX + closureY) * 3600 / totalDistance

        var cumX = openingX, cumY = openingY

        for (var i = 0; i < stationsModel.count; i++) {
            var dist = stationsModel.get(i).distance
            var corrX = -(closureX * dist / totalDistance)
            var corrY = -(closureY * dist / totalDistance)

            if (i === 0) {
               stationsModel.setProperty(i, "adjX", openingX)
               stationsModel.setProperty(i, "adjY", openingY)
            } else {
               var adjDX = departures[i] + corrX
               var adjDY = latitudes[i] + corrY
               cumX += adjDX; cumY += adjDY
               stationsModel.setProperty(i, "adjX", cumX)
               stationsModel.setProperty(i, "adjY", cumY)
            }
        }
    }

    function addNewStation() {
        var newIndex = stationsModel.count
        var prevName = newIndex > 0 ? stationsModel.get(newIndex-1).station : "-"
        stationsModel.append({
            station: "P" + (newIndex + 1),
            backSight: prevName, foreSight: "", bearing: "0°00'00\"", distance: 0.000,
            deltaX: 0, deltaY: 0, corrX: 0, corrY: 0, adjX: 0, adjY: 0
        })
    }

    // --- Background ---
    Rectangle {
        anchors.fill: parent
        color: bgColor
    }

    // --- MAIN CONTENT ---
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // 1. HEADER (Personnel Style)
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            ColumnLayout {
                spacing: 4
                Text {
                    text: "Traverse Computation"
                    font.family: "Codec Pro"
                    font.pixelSize: 24
                    font.weight: Font.Medium
                    color: textPrimary
                }
                Text {
                    text: isLoopTraverse ? "Closed Loop Adjustment (Bowditch)" : "Link Traverse Adjustment (Bowditch)"
                    font.family: "Codec Pro"
                    font.pixelSize: 13
                    color: textSecondary
                }
            }

            Item { Layout.fillWidth: true }

            // Mode Toggle (Moved to Header)
            Rectangle {
                width: 140; height: 38; radius: 4; border.color: borderColor
                color: cardColor
                Row {
                    anchors.centerIn: parent
                    Rectangle {
                        width: 70; height: 30; radius: 3; color: isLoopTraverse ? accentColor : "transparent"
                        Text { anchors.centerIn: parent; text: "Loop"; color: isLoopTraverse ? "white" : textSecondary; font.pixelSize: 11; font.family: "Codec Pro"; font.bold: isLoopTraverse }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { traverseMode=0; initializeTraverse() } }
                    }
                    Rectangle {
                        width: 70; height: 30; radius: 3; color: !isLoopTraverse ? accentColor : "transparent"
                        Text { anchors.centerIn: parent; text: "Link"; color: !isLoopTraverse ? "white" : textSecondary; font.pixelSize: 11; font.family: "Codec Pro"; font.bold: !isLoopTraverse }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { traverseMode=1; initializeTraverse() } }
                    }
                }
            }

            // Calculate Bowditch Button
            Rectangle {
                width: 150; height: 38; radius: 4; color: infoColor
                RowLayout {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: "\uf1ec"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 12; color: "white" }
                    Text { text: "Calculate Bowditch"; font.family: "Codec Pro"; font.pixelSize: 13; color: "white" }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: calculateTraverse() }
            }

            // Add Personnel/Station Button
            Rectangle {
                width: 120; height: 38; radius: 4; color: accentColor
                RowLayout {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: "\uf067"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 12; color: "white" }
                    Text { text: "Add Station"; font.family: "Codec Pro"; font.pixelSize: 13; color: "white" }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: addNewStation() }
            }
        }

        // 2. STATS CARDS (Top Summary)
        RowLayout {
            Layout.fillWidth: true; spacing: 16
            property int cardW: (parent.width - 32) / 3

            // Entry Animation
            opacity: 0
            transform: Translate {
                y: 20
                NumberAnimation on y { to: 0; duration: 500; easing.type: Easing.OutCubic }
            }
            NumberAnimation on opacity { to: 1; duration: 500; easing.type: Easing.OutCubic }

            component StatCard : Rectangle {
                Layout.preferredWidth: parent.cardW; Layout.preferredHeight: 80
                color: glassBg; radius: glassRadius; border.color: glassBorder
                property string title; property string value; property string icon; property color iconColor
                RowLayout {
                    anchors.fill: parent; anchors.margins: 16; spacing: 16
                    Rectangle { width: 48; height: 48; radius: 8; color: Qt.lighter(iconColor, 1.8); Text { anchors.centerIn: parent; text: icon; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 20; color: iconColor } }
                    ColumnLayout {
                        Text { text: value; font.family: "Codec Pro"; font.pixelSize: 20; font.bold: true; color: textPrimary }
                        Text { text: title; font.family: "Codec Pro"; font.pixelSize: 12; color: textSecondary }
                    }
                }
            }

            StatCard { title: "Total Distance"; value: totalDistance.toFixed(3) + "m"; icon: "\uf546"; iconColor: infoColor }
            StatCard { title: "Linear Misclose"; value: linearMisclose.toFixed(4) + "m"; icon: "\uf12a"; iconColor: linearMisclose > 0.05 ? dangerColor : successColor }
            StatCard { title: "Accuracy (1:N)"; value: "1:" + accuracy.toFixed(0); icon: "\uf2f1"; iconColor: accuracy > 5000 ? successColor : (accuracy > 2000 ? warningColor : dangerColor) }
        }

        // 3. MAIN CONTENT CARD
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: glassBg
            radius: glassRadius
            border.color: glassBorder

            // Entry Animation
            opacity: 0
            transform: Translate {
                y: 30
                SequentialAnimation on y {
                    PauseAnimation { duration: 150 }
                    NumberAnimation { to: 0; duration: 600; easing.type: Easing.OutCubic }
                }
            }
            SequentialAnimation on opacity {
                PauseAnimation { duration: 150 }
                NumberAnimation { to: 1; duration: 600; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15

                // Toolbar (Inputs)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20

                    // Opening Point
                    RowLayout {
                        spacing: 8
                        Text { text: "Start Point (" + (isLoopTraverse ? "Loop" : "Link Start") + ")"; font.pixelSize: 12; color: successColor; font.bold: true; font.family: "Codec Pro" }
                        TextField { placeholderText: "Stn"; placeholderTextColor: textSecondary; text: openingStationName; Layout.preferredWidth: 50; font.pixelSize: 12; font.family: "Codec Pro"; color: textPrimary; onEditingFinished: openingStationName = text; background: Rectangle{border.color: borderColor; border.width: 1; radius: 4} }
                        TextField { placeholderText: "E"; placeholderTextColor: textSecondary; text: openingX.toFixed(3); Layout.preferredWidth: 80; font.pixelSize: 12; font.family: "Codec Pro"; color: textPrimary; onEditingFinished: { openingX = parseFloat(text); calculateTraverse() } background: Rectangle{border.color: borderColor; border.width: 1; radius: 4} }
                        TextField { placeholderText: "N"; placeholderTextColor: textSecondary; text: openingY.toFixed(3); Layout.preferredWidth: 80; font.pixelSize: 12; font.family: "Codec Pro"; color: textPrimary; onEditingFinished: { openingY = parseFloat(text); calculateTraverse() } background: Rectangle{border.color: borderColor; border.width: 1; radius: 4} }
                    }

                    Rectangle { width: 1; height: 30; color: borderColor; visible: !isLoopTraverse }

                    // Closing Point (Link only)
                    RowLayout {
                        visible: !isLoopTraverse
                        spacing: 8
                        Text { text: "Closing Point (Known)"; font.pixelSize: 12; color: dangerColor; font.bold: true; font.family: "Codec Pro" }
                        TextField { placeholderText: "Stn"; placeholderTextColor: textSecondary; text: closingStationName; Layout.preferredWidth: 50; font.pixelSize: 12; font.family: "Codec Pro"; color: textPrimary; onEditingFinished: closingStationName = text; background: Rectangle{border.color: borderColor; border.width: 1; radius: 4} }
                        TextField { placeholderText: "E"; placeholderTextColor: textSecondary; text: closingX.toFixed(3); Layout.preferredWidth: 80; font.pixelSize: 12; font.family: "Codec Pro"; color: textPrimary; onEditingFinished: { closingX = parseFloat(text); calculateTraverse() } background: Rectangle{border.color: borderColor; border.width: 1; radius: 4} }
                        TextField { placeholderText: "N"; placeholderTextColor: textSecondary; text: closingY.toFixed(3); Layout.preferredWidth: 80; font.pixelSize: 12; font.family: "Codec Pro"; color: textPrimary; onEditingFinished: { closingY = parseFloat(text); calculateTraverse() } background: Rectangle{border.color: borderColor; border.width: 1; radius: 4} }
                    }

                    Item { Layout.fillWidth: true }
                }

                // Grid (Excel-like) inside the card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    border.color: borderColor
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // Header
                        Rectangle {
                            Layout.fillWidth: true; height: 40; color: "#f7f9fa"
                            Rectangle { width: parent.width; height: 1; color: borderColor; anchors.bottom: parent.bottom }

                            RowLayout {
                                anchors.fill: parent; spacing: 0
                                component HCell : Rectangle { Layout.fillHeight: true; Layout.preferredWidth: w; color: "transparent"; property int w; property string txt; Text { anchors.centerIn: parent; text: txt; font.bold: true; font.pixelSize: 11; font.family: "Codec Pro"; color: textSecondary } Rectangle { width: 1; height: parent.height; color: borderColor; anchors.right: parent.right } }
                                HCell { w: 40; txt: "#" }
                                HCell { Layout.fillWidth: true; txt: "Station" }
                                HCell { w: 90; txt: "Bearing" }
                                HCell { w: 90; txt: "Distance" }
                                HCell { w: 90; txt: "Delta X" }
                                HCell { w: 90; txt: "Delta Y" }
                                HCell { w: 100; txt: "Adj Easting" }
                                HCell { w: 100; txt: "Adj Northing" }
                                HCell { w: 40; txt: "" }
                            }
                        }

                        // Rows
                        ListView {
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                            model: stationsModel
                            boundsBehavior: Flickable.StopAtBounds
                            delegate: Rectangle {
                                width: parent.width; height: 35
                                color: index % 2 === 0 ? "white" : "#fbfcfe"
                                RowLayout {
                                     anchors.fill: parent; spacing: 0
                                     component Cell : Rectangle {
                                         Layout.fillHeight: true; Layout.preferredWidth: w; color: "transparent"; property int w; property alias content: inp.text; property bool ro: false; property alias font: inp.font; property alias textColor: inp.color
                                         TextInput { id: inp; anchors.fill: parent; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 12; font.family: "Codec Pro"; text: parent.content; readOnly: ro; color: textPrimary; selectByMouse: true; onEditingFinished: parent.edited(text) }
                                         signal edited(string v)
                                         Rectangle { width: 1; height: parent.height; color: "#f0f0f0"; anchors.right: parent.right }
                                     }

                                     Cell { w: 40; content: (index+1).toString(); ro: true; textColor: textSecondary }
                                     Cell { Layout.fillWidth: true; content: model.station; onEdited: (v)=>stationsModel.setProperty(index, "station", v) }
                                     Cell { w: 90; content: model.bearing; onEdited: (v)=> { stationsModel.setProperty(index, "bearing", v); calculateTraverse() } }
                                     Cell { w: 90; content: model.distance === 0 ? "" : model.distance.toFixed(3); onEdited: (v)=> { stationsModel.setProperty(index, "distance", parseFloat(v)||0); calculateTraverse() } }

                                     Cell { w: 90; content: model.deltaX.toFixed(3); ro: true; textColor: textSecondary }
                                     Cell { w: 90; content: model.deltaY.toFixed(3); ro: true; textColor: textSecondary }

                                     Cell { w: 100; content: model.adjX.toFixed(3); ro: true; font.bold: true }
                                     Cell { w: 100; content: model.adjY.toFixed(3); ro: true; font.bold: true; textColor: accentColor }

                                     Rectangle { width: 40; height: parent.height; color: "transparent"
                                        Text { anchors.centerIn: parent; text: "×"; color: dangerColor; font.bold: true; font.pixelSize: 16 }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if(index>0) { stationsModel.remove(index); calculateTraverse() } }
                                        Rectangle { width: 1; height: parent.height; color: "#f0f0f0"; anchors.right: parent.right }
                                     }
                                }
                                Rectangle { width: parent.width; height: 1; color: "#f0f0f0"; anchors.bottom: parent.bottom }
                            }
                        }

                        // Footer
                        Rectangle {
                            Layout.fillWidth: true; height: 30; color: "#f8f9fa"
                            Rectangle { width: parent.width; height: 1; color: borderColor; anchors.top: parent.top }

                        }
                    }
                }
            }
        }
    }
}
