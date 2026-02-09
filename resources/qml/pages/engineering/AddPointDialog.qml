import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: "Add Control Point"
    modal: true
    width: 400
    height: 480
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    // Signals
    signal pickRequested()
    signal pointSaved(string name, double x, double y, double z)

    // Properties to hold data
    property string pointName: ""
    property double coordX: 0.0
    property double coordY: 0.0
    property double coordZ: 0.0
    property string pointCode: ""
    property string pointDesc: ""
    property var existingPointsModel: null
    // Added so other QML (e.g. CADPage.qml) can set this without error
    property bool isBulkImporting: false

    Component.onCompleted: {
        // initialize fields from properties
        pointNameField.text = pointName
        xField.text = coordX.toFixed(3)
        yField.text = coordY.toFixed(3)
        zField.text = coordZ.toFixed(3)
        codeField.text = pointCode
        descField.text = pointDesc
    }

    // Clear form fields
    function clearFields() {
        pointName = ""
        coordX = 0.0
        coordY = 0.0
        coordZ = 0.0
        pointCode = ""
        pointDesc = ""

        pointNameField.text = ""
        xField.text = "0.000"
        yField.text = "0.000"
        zField.text = "0.000"
        codeField.text = ""
        descField.text = ""
    }

    // Update coordinates from external source (e.g., canvas pick)
    function setCoordinates(x, y, z) {
        coordX = typeof x === "number" ? x : coordX
        coordY = typeof y === "number" ? y : coordY
        if (z !== undefined && typeof z === "number") coordZ = z

        xField.text = coordX.toFixed(3)
        yField.text = coordY.toFixed(3)
        if (z !== undefined) zField.text = coordZ.toFixed(3)
    }

    background: Rectangle {
        color: "#2b2b2b"
        border.color: "#444"
        radius: 4
    }

    header: Rectangle {
        width: parent.width
        height: 40
        color: "#333"

        Text {
            anchors.centerIn: parent
            text: root.title
            color: "white"
            font.family: "Codec Pro"
            font.bold: true
        }
    }

    contentItem: ColumnLayout {
        spacing: 15

        // Pick Button
        Button {
            text: "Pick from Workspace"
            Layout.fillWidth: true
            Layout.preferredHeight: 36

            contentItem: RowLayout {
                spacing: 8
                anchors.centerIn: parent
                Text { text: "\uf3c5"; font.family: "Font Awesome 5 Pro Solid"; color: "white" } // map-marker-alt
                Text { text: "Pick from Workspace"; color: "white"; font.family: "Codec Pro" }
            }

            background: Rectangle {
                color: parent.down ? "#444" : "#555"
                radius: 4
                border.color: "#4d90fe"
                border.width: 1
            }

            onClicked: {
                root.pickRequested()
                root.close()
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#444" }

        // Form Fields
        GridLayout {
            columns: 2
            columnSpacing: 10
            rowSpacing: 15
            Layout.fillWidth: true

            // Name
            Text { text: "Point Name:"; color: "#ccc"; font.pixelSize: 12; font.family: "Codec Pro" }
            TextField {
                id: pointNameField
                Layout.fillWidth: true
                placeholderText: "e.g. STN1"
                color: "black"
                background: Rectangle { color: "white"; radius: 2 }
            }

            // X
            Text { text: "X:"; color: "#ccc"; font.pixelSize: 12; font.family: "Codec Pro" }
            TextField {
                id: xField
                Layout.fillWidth: true
                text: "0.000"
                validator: DoubleValidator { decimals: 3 }
                color: "black"
                background: Rectangle { color: "white"; radius: 2 }
            }

            // Y
            Text { text: "Y:"; color: "#ccc"; font.pixelSize: 12; font.family: "Codec Pro" }
            TextField {
                id: yField
                Layout.fillWidth: true
                text: "0.000"
                validator: DoubleValidator { decimals: 3 }
                color: "black"
                background: Rectangle { color: "white"; radius: 2 }
            }

            // Z (Elevation)
            Text { text: "Z (Elevation):"; color: "#ccc"; font.pixelSize: 12; font.family: "Codec Pro" }
            TextField {
                id: zField
                Layout.fillWidth: true
                text: "0.000"
                validator: DoubleValidator { decimals: 3 }
                color: "black"
                background: Rectangle { color: "white"; radius: 2 }
            }

            // Code
            Text { text: "Code:"; color: "#ccc"; font.pixelSize: 12; font.family: "Codec Pro" }
            TextField {
                id: codeField
                Layout.fillWidth: true
                placeholderText: "e.g. PEG"
                color: "black"
                background: Rectangle { color: "white"; radius: 2 }
            }

            // Description
            Text { text: "Description:"; color: "#ccc"; font.pixelSize: 12; font.family: "Codec Pro" }
            TextField {
                id: descField
                Layout.fillWidth: true
                placeholderText: "Optional"
                color: "black"
                background: Rectangle { color: "white"; radius: 2 }
            }
        }
    }

    footer: Rectangle {
        height: 50
        color: "transparent"

        RowLayout {
            anchors.centerIn: parent
            spacing: 20

            Button {
                text: "Cancel"
                contentItem: Text { text: parent.text; color: "#ccc"; font.family: "Codec Pro"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: "transparent"; border.color: "#666"; radius: 4; width: 80; height: 32 }
                onClicked: root.close()
            }

            Button {
                text: "Save Point"
                contentItem: Text { text: parent.text; color: "white"; font.family: "Codec Pro"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.down ? "#2a65c0" : "#3277d5"; radius: 4; width: 100; height: 32 }
                onClicked: {
                    var n = pointNameField.text.trim()
                    var x = parseFloat(xField.text)
                    var y = parseFloat(yField.text)
                    var z = parseFloat(zField.text)
                    var c = codeField.text
                    var d = descField.text

                    if (n === "") {
                        console.log("Error: Point Name required")
                        return
                    }

                    // Update dialog properties before saving/emitting
                    pointName = n
                    coordX = isNaN(x) ? 0.0 : x
                    coordY = isNaN(y) ? 0.0 : y
                    coordZ = isNaN(z) ? 0.0 : z
                    pointCode = c
                    pointDesc = d

                    try {
                        Database.addPoint(n, coordX, coordY, coordZ, c, d)
                        console.log("Point added:", n, coordX, coordY, coordZ)
                        root.pointSaved(n, coordX, coordY, coordZ)
                        root.accept()
                    } catch(e) {
                        console.log("Database Error:", e)
                    }
                }
            }
        }
    }
}
