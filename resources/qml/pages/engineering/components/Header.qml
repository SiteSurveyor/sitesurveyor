import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: root

    property string title: "Dashboard"
    property string projectName: Database.currentProject || "Project"
    signal toggleSidebar()
    signal exitRequested()

    color: "white"

    // Bottom border
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: "#d8dbe0"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 15

        // Hamburger / Toggle
        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignVCenter
            color: menuMa.containsMouse ? "#f8f9fa" : "transparent"
            radius: 4

            Text {
                anchors.centerIn: parent
                text: "\uf0c9"
                font.family: "Font Awesome 5 Pro Solid"
                font.pixelSize: 18
                color: "#768192"
            }

            MouseArea {
                id: menuMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleSidebar()
            }
        }

        // Breadcrumb / Title with project name
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 8

            Text {
                text: projectName
                font.family: "Codec Pro"
                font.pixelSize: 14
                font.weight: Font.Medium
                color: "#3c4b64"
            }

            Text {
                text: "/"
                font.family: "Codec Pro"
                font.pixelSize: 14
                color: "#9da5b1"
            }

            Text {
                text: root.title
                font.family: "Codec Pro"
                font.pixelSize: 14
                color: "#768192"
            }

            Item { Layout.fillWidth: true }
        }

        // Exit button
        Rectangle {
            Layout.preferredWidth: exitRow.width + 20
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignVCenter
            radius: 4
            color: exitMa.containsMouse ? "#fef2f2" : "transparent"
            border.color: exitMa.containsMouse ? "#e55353" : "#d8dbe0"
            border.width: 1

            RowLayout {
                id: exitRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "\uf2f5"
                    font.family: "Font Awesome 5 Pro Solid"
                    font.pixelSize: 14
                    color: exitMa.containsMouse ? "#e55353" : "#768192"
                }

                Text {
                    text: "Exit Project"
                    font.family: "Codec Pro"
                    font.pixelSize: 13
                    color: exitMa.containsMouse ? "#e55353" : "#768192"
                }
            }

            MouseArea {
                id: exitMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    console.log("Exit button clicked")
                    root.exitRequested()
                }
            }
        }

        // Notification icons
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 16

            Repeater {
                model: ["\uf0f3", "\uf0e0", "\uf007"]

                Rectangle {
                    width: 32
                    height: 32
                    radius: 4
                    color: iconMa.containsMouse ? "#f8f9fa" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 16
                        color: "#768192"
                    }

                    MouseArea {
                        id: iconMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }
    }
}
