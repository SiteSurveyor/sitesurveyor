import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string label: ""
    property string value: ""
    property string subValue: ""
    property string icon: ""
    property color iconColor: "#333333"

    property color bgColor: "white"
    property color borderColor: "#d8dbe0"

    radius: 4
    color: bgColor

    border.color: borderColor
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // Icon Box (Left)
        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 8
            color: Qt.lighter(root.iconColor, 1.8) // Lighter background for icon

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.family: "Font Awesome 5 Pro Solid"
                font.pixelSize: 18
                color: root.iconColor
            }
        }

        // Text Content (Right)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.value
                font.family: "Codec Pro"
                font.pixelSize: 18
                font.bold: true
                color: "#333333"
            }

            Text {
                text: root.label
                font.family: "Codec Pro"
                font.pixelSize: 11
                font.bold: true
                color: "#768192"
            }

            Text {
                visible: root.subValue.length > 0
                text: root.subValue
                font.family: "Codec Pro"
                font.pixelSize: 10
                color: "#9da5b1"
            }
        }
    }
}
