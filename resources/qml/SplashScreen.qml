import QtQuick 2.15
import QtQuick.Controls 2.15


Item {
    id: root
    anchors.fill: parent
    visible: true

    // Signal to notify when splash is done
    signal timeout

    Rectangle {
        id: bg
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#ffffff" }
            GradientStop { position: 1.0; color: "#f0f0f0" }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 20

        Image {
            id: logo
            source: "qrc:/logo/SiteSurveyor.png"
            width: 128
            height: 128
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter

            // Subtle pulse animation
            SequentialAnimation on scale {
                loops: Animation.Infinite
                PropertyAnimation { to: 1.1; duration: 1000; easing.type: Easing.InOutQuad }
                PropertyAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutQuad }
            }
        }



        BusyIndicator {
            running: true
            anchors.horizontalCenter: parent.horizontalCenter
            palette.dark: "#333333"
            palette.text: "#333333" // Basic style uses palette.text
        }

        Text {
            text: "Loading Components..."
            color: "#666666"
            font.pixelSize: 14
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Timer {
        interval: 3000 // 3 seconds
        running: true
        repeat: false
        onTriggered: root.timeout()
    }
}
