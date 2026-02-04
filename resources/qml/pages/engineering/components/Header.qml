import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: root

    property string title: "Dashboard"
    property string projectName: Database.currentProject || "Project"
    signal toggleSidebar()
    signal exitRequested()
    // Theme
    property color bgColor: "#f6f7f9"
    property color cardColor: "#ffffff"
    property color borderColor: "#d0d7de"
    property color textPrimary: "#111827"
    property color textSecondary: "#6b7280"
    property color accentColor: "#2563eb"
    property color dangerColor: "#dc2626"

    color: cardColor

    // Bottom border
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: borderColor
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
            color: menuMa.containsMouse ? bgColor : "transparent"
            radius: 4
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "\uf0c9"
                font.family: "Font Awesome 5 Pro Solid"
                font.pixelSize: 13
                color: menuMa.containsMouse ? accentColor : textSecondary
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
                font.pixelSize: 11
                font.weight: Font.Medium
                color: textPrimary
            }

            Text {
                text: "/"
                font.family: "Codec Pro"
                font.pixelSize: 11
                color: textSecondary
            }

            Text {
                text: root.title
                font.family: "Codec Pro"
                font.pixelSize: 11
                color: textSecondary
            }

            Item { Layout.fillWidth: true }
        }

        // Exit button
        Rectangle {
            Layout.preferredWidth: exitRow.width + 20
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignVCenter
            radius: 4
            color: exitMa.containsMouse ? Qt.lighter(dangerColor, 1.9) : "transparent"
            border.color: exitMa.containsMouse ? dangerColor : borderColor
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            RowLayout {
                id: exitRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "\uf2f5"
                    font.family: "Font Awesome 5 Pro Solid"
                    font.pixelSize: 11
                    color: exitMa.containsMouse ? dangerColor : textSecondary
                }

                Text {
                    text: "Exit Project"
                    font.family: "Codec Pro"
                    font.pixelSize: 11
                    color: exitMa.containsMouse ? dangerColor : textSecondary
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
                    color: iconMa.containsMouse ? bgColor : "transparent"

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 12
                        color: iconMa.containsMouse ? accentColor : textSecondary
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
