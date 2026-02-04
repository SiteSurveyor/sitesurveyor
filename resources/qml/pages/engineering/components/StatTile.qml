import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string label: ""
    property string value: ""
    property string subValue: ""
    property string icon: ""
    property color iconColor: "#333333"
    property color bgColor: "#ffffff"
    property color textPrimary: "#111827"
    property color textSecondary: "#6b7280"
    property color borderColor: "#d0d7de"

    radius: 6
    color: bgColor

    border.color: borderColor
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // Icon Box (Left)
        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 6
            color: Qt.lighter(root.iconColor, 1.8) // Lighter background for icon

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.family: "Font Awesome 5 Pro Solid"
                font.pixelSize: 13
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
                font.pixelSize: 13
                font.bold: true
                color: textPrimary
            }

            Text {
                text: root.label
                font.family: "Codec Pro"
                font.pixelSize: 9
                font.bold: true
                color: textSecondary
            }

            Text {
                visible: root.subValue.length > 0
                text: root.subValue
                font.family: "Codec Pro"
                font.pixelSize: 9
                color: textSecondary
            }
        }
    }
}
