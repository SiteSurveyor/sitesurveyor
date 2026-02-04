import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    color: glassyBgColor
    radius: 8
    border.color: borderColor
    border.width: 1

    Layout.fillWidth: true
    Layout.preferredHeight: 90

    property string label
    property real value
    property string units
    property bool alignUnitsRight: true

    Item {
        anchors.fill: parent
        anchors.margins: 16

        Text {
            text: label
            font.pixelSize: 11
            color: textColor
            anchors.top: parent.top
            anchors.left: parent.left
        }

        Text {
            id: valuetxt
            text: value
            font.pixelSize: 32
            color: textColor
            anchors.bottom: parent.bottom
            anchors.bottomMargin: alignUnitsRight ? 0 : 16
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                text: units
                font.pixelSize: 12
                color: textColor
                anchors.top: parent.top
                anchors.left: parent.right
                visible: alignUnitsRight
            }
        }

        Text {
            text: units
            font.pixelSize: 12
            color: textColor
            visible: !alignUnitsRight
            anchors.top: valuetxt.bottom
            anchors.right: valuetxt.right
        }
    }
}
