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

    // Levelling specific properties
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

    // Model for observations
    property var obsModel: ListModel {
        id: levelModel
    }

    Component.onCompleted: {
        resetTable()
    }

    function resetTable() {
        levelModel.clear()
        levelModel.append({
            station: "BM1",
            bs: 0.000, is: 0.000, fs: 0.000,
            rise: 0.000, fall: 0.000, hpc: 0.000,
            rl: startRL,
            remarks: "Benchmark",
            distance: 0.000,
            adjRl: startRL
        })
        calculateLevels()
    }

    function calculateLevels() {
        if (levelModel.count === 0) return;

        var runningRL = startRL
        var runningHPC = 0
        var tBS = 0, tFS = 0, tRise = 0, tFall = 0

        // Reset first row RL
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

            tBS += cBS; tFS += cFS;

            var currentReading = 0
            if (cIS > 0) currentReading = cIS
            else if (cFS > 0) currentReading = cFS

            var diff = lastReading - currentReading
            var rise = diff > 0 ? diff : 0
            var fall = diff < 0 ? -diff : 0

            runningRL = runningRL + rise - fall
            var rl_HI = currentHI - currentReading

            levelModel.setProperty(i, "rise", rise)
            levelModel.setProperty(i, "fall", fall)
            levelModel.setProperty(i, "rl", isRiseFallMethod ? runningRL : rl_HI)

            tRise += rise; tFall += fall;

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

        // --- Distance & Adjustment ---
        var tDist = 0
        var distances = []
        for (var i = 0; i < levelModel.count; i++) {
            var d = parseFloat(levelModel.get(i).distance) || 0
            tDist += d
            distances.push(d)
        }
        totalDistance = tDist

        var closingError = 0
        if (closingRL !== 0) closingError = runningRL - closingRL
        misclose = closingError

        var cumDist = 0
        for (var i = 0; i < levelModel.count; i++) {
            if (i > 0) cumDist += distances[i]
            var correction = 0
            if (tDist > 0 && closingRL !== 0) {
                correction = -(closingError * cumDist / tDist)
            }
            var unadjustedRL = levelModel.get(i).rl
            levelModel.setProperty(i, "adjRl", unadjustedRL + correction)
        }

        totalBS = tBS; totalFS = tFS; totalRise = tRise; totalFall = tFall;
    }

    function addRow() {
        levelModel.append({
            station: "Stn" + (levelModel.count + 1),
            bs: 0, is: 0, fs: 0,
            rise: 0, fall: 0, hpc: 0, rl: 0,
            remarks: "", distance: 0, adjRl: 0
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
                    text: "Levelling Computation"
                    font.family: "Codec Pro"
                    font.pixelSize: 24
                    font.weight: Font.Medium
                    color: textPrimary
                }
                Text {
                    text: isRiseFallMethod ? "Standard Rise & Fall Method" : "Height of Collimation (HPC) Method"
                    font.family: "Codec Pro"
                    font.pixelSize: 13
                    color: textSecondary
                }
            }

            Item { Layout.fillWidth: true }

            // Method Toggle (Moved to Header)
            Rectangle {
                width: 162; height: 38; radius: 4; border.color: borderColor
                color: cardColor
                Row {
                    anchors.centerIn: parent
                    Rectangle {
                        width: 80; height: 30; radius: 3; color: isRiseFallMethod ? accentColor : "transparent"
                        Text { anchors.centerIn: parent; text: "Rise & Fall"; color: isRiseFallMethod ? "white" : textSecondary; font.pixelSize: 11; font.family: "Codec Pro"; font.bold: isRiseFallMethod }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { isRiseFallMethod = true; calculateLevels() } }
                    }
                    Rectangle {
                        width: 80; height: 30; radius: 3; color: !isRiseFallMethod ? accentColor : "transparent"
                        Text { anchors.centerIn: parent; text: "HPC / HI"; color: !isRiseFallMethod ? "white" : textSecondary; font.pixelSize: 11; font.family: "Codec Pro"; font.bold: !isRiseFallMethod }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { isRiseFallMethod = false; calculateLevels() } }
                    }
                }
            }

            // Calculate Button
            Rectangle {
                width: 150; height: 38; radius: 4; color: infoColor
                RowLayout {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: "\uf1ec"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 12; color: "white" }
                    Text { text: "Calculate Adjustment"; font.family: "Codec Pro"; font.pixelSize: 13; color: "white" }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: calculateLevels() }
            }

            // Save Button
            Rectangle {
                width: 100; height: 38; radius: 4; color: successColor
                RowLayout {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: "\uf0c7"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 12; color: "white" }
                    Text { text: "Save Line"; font.family: "Codec Pro"; font.pixelSize: 13; color: "white" }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: console.log("Saving...") }
            }

            // Add Row Button (Personnel Style)
            Rectangle {
                width: 110; height: 38; radius: 4; color: accentColor
                RowLayout {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: "\uf067"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 12; color: "white" }
                    Text { text: "Add Reading"; font.family: "Codec Pro"; font.pixelSize: 13; color: "white" }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: addRow() }
            }
        }

        // 2. STATS CARDS (Top Summary)
        RowLayout {
            Layout.fillWidth: true; spacing: 16
            property int cardW: (parent.width - 48) / 4

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
            StatCard { title: "Total Rise"; value: totalRise.toFixed(3) + "m"; icon: "\uf3c5"; iconColor: successColor }
            StatCard { title: "Total Fall"; value: totalFall.toFixed(3) + "m"; icon: "\uf3c5"; iconColor: warningColor }
            StatCard { title: "Misclose"; value: misclose.toFixed(3) + "m"; icon: "\uf12a"; iconColor: misclose == 0 ? successColor : dangerColor }
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
                    spacing: 15

                    TextField {
                        placeholderText: "Line Name"
                        placeholderTextColor: textSecondary // Ensure placeholder visibility
                        text: lineName
                        color: textPrimary // Ensure text visibility
                        font.family: "Codec Pro"; font.pixelSize: 13
                        Layout.preferredWidth: 200
                        background: Rectangle { border.color: borderColor; border.width: 1; radius: 4 }
                        onEditingFinished: lineName = text
                    }

                    Rectangle { width: 1; height: 30; color: borderColor }

                    Text { text: "Start RL:"; font.family: "Codec Pro"; font.pixelSize: 12; color: textSecondary }
                    TextField {
                        text: startRL.toFixed(3); font.family: "Codec Pro"; font.pixelSize: 13
                        color: textPrimary // Ensure text visibility
                        Layout.preferredWidth: 80
                        background: Rectangle { border.color: borderColor; border.width: 1; radius: 4 }
                        onEditingFinished: { startRL = parseFloat(text)||0; calculateLevels() }
                    }

                    Text { text: "Check RL:"; font.family: "Codec Pro"; font.pixelSize: 12; color: textSecondary }
                    TextField {
                        text: closingRL.toFixed(3); font.family: "Codec Pro"; font.pixelSize: 13
                        color: textPrimary // Ensure text visibility
                        Layout.preferredWidth: 80
                        background: Rectangle { border.color: borderColor; border.width: 1; radius: 4 }
                        onEditingFinished: { closingRL = parseFloat(text)||0; calculateLevels() }
                    }
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
                            Layout.fillWidth: true; height: 40; color: "#f7f9fa" // slightly different header bg
                            Rectangle { width: parent.width; height: 1; color: borderColor; anchors.bottom: parent.bottom }

                            RowLayout {
                                anchors.fill: parent; spacing: 0
                                component HeaderCell : Rectangle {
                                    Layout.fillHeight: true; Layout.preferredWidth: w; color: "transparent"
                                    property int w; property string txt
                                    Text { anchors.centerIn: parent; text: txt; font.family: "Codec Pro"; font.bold: true; font.pixelSize: 11; color: textSecondary }
                                    Rectangle { width: 1; height: parent.height; color: borderColor; anchors.right: parent.right }
                                }

                                HeaderCell { w: 40; txt: "#" }
                                HeaderCell { Layout.fillWidth: true; txt: "Station" }
                                HeaderCell { w: 80; txt: "Dist" }
                                HeaderCell { w: 80; txt: "BS" }
                                HeaderCell { w: 80; txt: "IS" }
                                HeaderCell { w: 80; txt: "FS" }
                                HeaderCell { w: 80; visible: isRiseFallMethod; txt: "Rise" }
                                HeaderCell { w: 80; visible: isRiseFallMethod; txt: "Fall" }
                                HeaderCell { w: 80; visible: !isRiseFallMethod; txt: "HPC" }
                                HeaderCell { w: 90; txt: "RL" }
                                HeaderCell { w: 90; txt: "Adj RL" }
                                HeaderCell { w: 150; txt: "Remarks" }
                                HeaderCell { w: 40; txt: "" }
                            }
                        }

                        // List
                        ListView {
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                            model: levelModel
                            boundsBehavior: Flickable.StopAtBounds
                            delegate: Rectangle {
                                width: parent.width; height: 35
                                color: index % 2 === 0 ? "white" : "#fbfcfe" // lighter alternating color

                                RowLayout {
                                    anchors.fill: parent; spacing: 0
                                    component Cell : Rectangle {
                                        Layout.fillHeight: true; Layout.preferredWidth: w; color: "transparent"
                                        property int w; property alias content: inp.text; property bool ro: false; property alias font: inp.font; property alias textColor: inp.color
                                        TextInput {
                                            id: inp; anchors.fill: parent; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
                                            font.pixelSize: 12; font.family: "Codec Pro"; color: textPrimary
                                            text: parent.content; readOnly: ro; selectByMouse: true
                                            onEditingFinished: parent.edited(text)
                                        }
                                        signal edited(string v)
                                        Rectangle { width: 1; height: parent.height; color: "#f0f0f0"; anchors.right: parent.right }
                                    }

                                    Cell { w: 40; content: (index+1).toString(); ro: true; textColor: textSecondary }
                                    Cell { Layout.fillWidth: true; content: model.station; onEdited: (v)=>levelModel.setProperty(index,"station",v) }
                                    Cell { w: 80; content: model.distance.toFixed(3); onEdited: (v)=>{levelModel.setProperty(index,"distance",parseFloat(v)||0); calculateLevels()} }
                                    Cell { w: 80; content: model.bs==0?"":model.bs.toFixed(3); onEdited: (v)=>{levelModel.setProperty(index,"bs",parseFloat(v)||0); calculateLevels()} }
                                    Cell { w: 80; content: model.is==0?"":model.is.toFixed(3); onEdited: (v)=>{levelModel.setProperty(index,"is",parseFloat(v)||0); calculateLevels()} }
                                    Cell { w: 80; content: model.fs==0?"":model.fs.toFixed(3); onEdited: (v)=>{levelModel.setProperty(index,"fs",parseFloat(v)||0); calculateLevels()} }

                                    Cell { w: 80; visible: isRiseFallMethod; content: model.rise>0?model.rise.toFixed(3):""; ro: true; textColor: textSecondary }
                                    Cell { w: 80; visible: isRiseFallMethod; content: model.fall>0?model.fall.toFixed(3):""; ro: true; textColor: textSecondary }
                                    Cell { w: 80; visible: !isRiseFallMethod; content: model.hpc.toFixed(3); ro: true; textColor: textSecondary }

                                    Cell { w: 90; content: model.rl.toFixed(3); ro: true; font.bold: true }
                                    Cell { w: 90; content: model.adjRl.toFixed(3); ro: true; font.bold: true; textColor: accentColor }
                                    Cell { w: 150; content: model.remarks; onEdited: (v)=>levelModel.setProperty(index,"remarks",v) }

                                    Rectangle {
                                        Layout.preferredWidth: 40; Layout.fillHeight: true; color: "transparent"
                                        Text { anchors.centerIn: parent; text: "×"; color: dangerColor; font.bold: true; font.pixelSize: 16 }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if(levelModel.count>1){levelModel.remove(index);calculateLevels()} }
                                        Rectangle { width: 1; height: parent.height; color: "#f0f0f0"; anchors.right: parent.right }
                                    }
                                }
                                Rectangle { width: parent.width; height: 1; color: "#f0f0f0"; anchors.bottom: parent.bottom }
                            }
                        }

                        // Footer Summary
                        Rectangle {
                            Layout.fillWidth: true; height: 40; color: "#f8f9fa"
                            Rectangle { width: parent.width; height: 1; color: borderColor; anchors.top: parent.top }

                            RowLayout {
                                anchors.fill: parent; spacing: 0
                                Item { width: 40 }
                                Item { Layout.fillWidth: true; Text { text: "TOTALS"; anchors.right: parent.right; anchors.rightMargin: 10; font.bold: true; font.family: "Codec Pro"; color: textPrimary } }
                                Item { width: 80; Text { text: totalDistance.toFixed(3); anchors.centerIn: parent; font.bold: true; color: textPrimary } }
                                Item { width: 80; Text { text: totalBS.toFixed(3); anchors.centerIn: parent; font.bold: true; color: textPrimary } }
                                Item { width: 80 }
                                Item { width: 80; Text { text: totalFS.toFixed(3); anchors.centerIn: parent; font.bold: true; color: textPrimary } }
                                Item { width: 80; visible: isRiseFallMethod; Text { text: totalRise.toFixed(3); anchors.centerIn: parent; font.bold: true; color: textPrimary } }
                                Item { width: 80; visible: isRiseFallMethod; Text { text: totalFall.toFixed(3); anchors.centerIn: parent; font.bold: true; color: textPrimary } }
                                Item { width: 80; visible: !isRiseFallMethod }
                                Item { width: 90 }
                                Item { width: 90 }
                                Item { width: 150 }
                                Item { width: 40 }
                            }
                        }
                    }
                }
            }
        }
    }
}
