import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    // Signal to notify Main.qml of selection
    signal disciplineSelected(string name)

    property string bgGradientStart: '#ffffff'
    property string bgGradientStop: '#f0f0f0'
    property string textColor: '#333333'

    Rectangle {
        id: bg
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: bgGradientStart }
            GradientStop { position: 1.0; color: bgGradientStop }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 30
        width: Math.min(parent.width * 0.8, 1000)

        Text {
            text: "Select Discipline"
            font.family: "Codec Pro"
            font.pixelSize: 28
            font.weight: Font.Light
            color: "#555555"
            Layout.alignment: Qt.AlignHCenter
        }

        GridLayout {
            columns: 3
            columnSpacing: 20
            rowSpacing: 20
            Layout.fillWidth: true

            Repeater {
                model: ListModel {
                    ListElement { name: "Engineering Surveying"; icon: "\uf5ae" } // ruler-combined
                    ListElement { name: "Mining Surveying"; icon: "\uf6e3" } // hammer
                    ListElement { name: "Geodetic Surveying"; icon: "\uf57d" } // globe-americas
                    ListElement { name: "Cadastral Surveying"; icon: "\uf5a0" } // map-marked
                    ListElement { name: "Remote Sensing"; icon: "\uf7c0" } // satellite
                    ListElement { name: "Topographic Surveying"; icon: "\uf6fc" } // mountain
                }

                delegate: Rectangle {
                    id: tile
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    radius: 8
                    color: "white"

                    // Shadow effect (simulated)
                    layer.enabled: true
                    // Note: GraphicalEffects for DropShadow might be missing,
                    // so we use a simple border/color change for now or simple opacity

                    // Thinner, subtler border
                    border.color: mouseArea.containsMouse ? "#0d8bfd" : "#efefef"
                    border.width: mouseArea.containsMouse ? 1 : 1

                    Behavior on border.color { ColorAnimation { duration: 200 } }
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    scale: mouseArea.pressed ? 0.98 : (mouseArea.containsMouse ? 1.01 : 1.0)

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            text: model.icon
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 32
                            color: mouseArea.containsMouse ? "#0d8bfd" : "#777777"
                            anchors.horizontalCenter: parent.horizontalCenter

                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        Text {
                            text: model.name
                            font.family: "Codec Pro"
                            font.pixelSize: 14
                            font.weight: Font.Normal
                            color: "#555555"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.disciplineSelected(model.name)
                    }
                }
            }
        }
    }
}
