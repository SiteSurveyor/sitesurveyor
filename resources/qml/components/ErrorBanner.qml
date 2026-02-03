import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Reusable error banner component for displaying error messages
Rectangle {
    id: root
    
    property string errorText: ""
    property int displayDuration: 5000 // Auto-hide after 5 seconds
    property bool autoHide: true
    
    visible: errorText !== ""
    height: visible ? 50 : 0
    color: "#f44336" // Material Design Red
    border.color: "#d32f2f"
    border.width: 1
    radius: 4
    
    Behavior on height {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    
    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        
        // Error icon
        Text {
            text: "\uf071" // FontAwesome exclamation-triangle
            font.family: "Font Awesome 5 Pro Solid"
            font.pixelSize: 18
            color: "white"
            Layout.alignment: Qt.AlignVCenter
        }
        
        // Error message
        Text {
            text: root.errorText
            font.family: "Codec Pro"
            font.pixelSize: 11
            color: "white"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
        
        // Close button
        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: closeMouseArea.containsMouse ? "#ffffff20" : "transparent"
            Layout.alignment: Qt.AlignVCenter
            
            Text {
                anchors.centerIn: parent
                text: "\uf00d" // FontAwesome times
                font.family: "Font Awesome 5 Pro Solid"
                font.pixelSize: 14
                color: "white"
            }
            
            MouseArea {
                id: closeMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    hideTimer.stop()
                    root.errorText = ""
                }
            }
        }
    }
    
    // Auto-hide timer
    Timer {
        id: hideTimer
        interval: root.displayDuration
        running: root.autoHide && root.visible
        onTriggered: root.errorText = ""
    }
    
    // Public function to show error
    function show(message) {
        errorText = message
        if (autoHide) {
            hideTimer.restart()
        }
    }
    
    // Public function to clear error
    function clear() {
        hideTimer.stop()
        errorText = ""
    }
}
