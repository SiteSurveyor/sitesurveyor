import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Processing overlay with progress bar for long-running operations
Rectangle {
    id: root
    
    property bool isProcessing: false
    property int progress: 0
    property string message: "Processing..."
    
    visible: isProcessing
    color: "#80000000" // Semi-transparent black
    z: 999 // Always on top
    
    Behavior on opacity {
        NumberAnimation { duration: 300 }
    }
    
    opacity: visible ? 1.0 : 0.0
    
    // Center content
    Rectangle {
        anchors.centerIn: parent
        width: 400
        height: 180
        color: "#2A2A2A"
        border.color: "#5A5A5A"
        border.width: 1
        radius: 8
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 20
            
            // Spinning loader icon
            Text {
                text: "\uf110" // FontAwesome spinner
                font.family: "Font Awesome 5 Pro Solid"
                font.pixelSize: 40
                color: "#2196F3"
                Layout.alignment: Qt.AlignHCenter
                
                RotationAnimation on rotation {
                    running: root.isProcessing
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 1000
                }
            }
            
            // Processing message
            Text {
                text: root.message
                font.family: "Codec Pro"
                font.pixelSize: 14
                color: "#EEEEEE"
                Layout.alignment: Qt.AlignHCenter
            }
            
            // Progress bar
            ProgressBar {
                id: progressBar
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                from: 0
                to: 100
                value: root.progress
                
                background: Rectangle {
                    implicitWidth: 200
                    implicitHeight: 8
                    color: "#1A1A1A"
                    radius: 4
                    border.color: "#5A5A5A"
                    border.width: 1
                }
                
                contentItem: Item {
                    Rectangle {
                        width: progressBar.visualPosition * parent.width
                        height: parent.height
                        radius: 4
                        color: "#2196F3"
                        
                        // Animated gradient effect
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#42A5F5" }
                            GradientStop { position: 1.0; color: "#1976D2" }
                        }
                    }
                }
            }
            
            // Progress percentage
            Text {
                text: root.progress + "%"
                font.family: "Codec Pro"
                font.pixelSize: 12
                color: "#AAAAAA"
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
    
    // Prevent mouse events from propagating through overlay
    MouseArea {
        anchors.fill: parent
        enabled: root.visible
        onClicked: {} // Consume clicks
    }
}
