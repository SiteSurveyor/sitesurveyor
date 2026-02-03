import QtQuick
import QtQuick.Controls

Item {
    id: root

    property alias pointsModel: pointsModel

    // Model to store points {x, y}
    ListModel {
        id: pointsModel
        onCountChanged: canvasLayer.requestPaint()
    }

    // Canvas Background / Grid
    Rectangle {
        id: canvasArea
        anchors.fill: parent
        color: "white"
        clip: true

        // Simple Grid Pattern via Image
        Image {
            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40'><path d='M 40 0 L 0 0 0 40' fill='none' stroke='#f0f0f0' stroke-width='1'/></svg>"
            fillMode: Image.Tile
            anchors.fill: parent
            opacity: 0.5
        }

        // Connection Lines (Canvas)
        Canvas {
            id: canvasLayer
            anchors.fill: parent

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                if (pointsModel.count < 2) return;

                ctx.strokeStyle = "#0d8bfd";
                ctx.lineWidth = 2;
                ctx.beginPath();

                var start = pointsModel.get(0);
                ctx.moveTo(start.x, start.y);

                for (var i = 1; i < pointsModel.count; i++) {
                    var p = pointsModel.get(i);
                    ctx.lineTo(p.x, p.y);
                }

                ctx.stroke();
            }
        }

        // Points
        Repeater {
            model: pointsModel

            Rectangle {
                x: model.x - width/2
                y: model.y - height/2
                width: 12
                height: 12
                radius: 6
                color: "white"
                border.color: "#0d8bfd"
                border.width: 3

                // Tooltip or label
                Text {
                    anchors.top: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "P" + (index + 1)
                    font.pixelSize: 10
                    color: "#555555"
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            onClicked: (mouse) => {
                pointsModel.append({ "x": mouse.x, "y": mouse.y })
                canvasLayer.requestPaint()
            }
        }

        // Instructions
        Text {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 10
            text: "Click to add survey points"
            font.pixelSize: 12
            color: "#999999"
            visible: pointsModel.count === 0
        }
    }
}
