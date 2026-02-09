import QtQuick
import QtQuick.Controls

Label {
    id: lbl

    property real size: 28
    property string icon

    text: icon
    color: textColor
    font.pixelSize: size
    font.family: "Font Awesome 5 Pro Solid"
}
