import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    // Signal to notify Main.qml of selection
    signal disciplineSelected(string name)

    property real introProgress: 0

    Component.onCompleted: introAnim.start()

    NumberAnimation {
        id: introAnim
        target: root
        property: "introProgress"
        from: 0
        to: 1
        duration: 200
        easing.type: Easing.OutCubic
    }

    // Simple, consistent light theme
    property color bgColor: "#f6f7f9"
    property color cardColor: "#ffffff"
    property color borderColor: "#d0d7de"
    property color textPrimary: "#111827"
    property color textSecondary: "#6b7280"
    property color accentColor: "#2563eb"

    property int pageMargin: Math.max(12, Math.min(24, Math.round(Math.min(width, height) * 0.04)))
    property int maxGridWidth: 900

    Rectangle {
        anchors.fill: parent
        color: bgColor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: pageMargin
        spacing: 16
        opacity: root.introProgress
        transform: Translate { y: (1 - root.introProgress) * 10 }

        // Header Section
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
            spacing: 6
            Layout.preferredWidth: 640

            Image {
                Layout.alignment: Qt.AlignHCenter
                source: "qrc:/logo/SiteSurveyor.png"
                sourceSize.height: 32
                fillMode: Image.PreserveAspectFit
            }

            Text {
                text: "Select discipline"
                font.family: "Codec Pro"
                font.pixelSize: 18
                font.weight: Font.Medium
                color: textPrimary
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            Text {
                text: "Choose a module to continue"
                font.family: "Codec Pro"
                font.pixelSize: 11
                color: textSecondary
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }

        // Disciplines Grid
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                id: gridContainer
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, maxGridWidth)

                GridView {
                    id: disciplinesGrid
                    anchors.fill: parent
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    property int columns: Math.max(1, Math.min(3, Math.floor(width / 320)))
                    cellWidth: Math.floor(width / columns)
                    cellHeight: 64

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    model: [
                        { name: "Engineering Surveying", icon: "\uf5ae", desc: "Layout, as-builts, earthworks" },
                        { name: "Mining Surveying", icon: "\uf6e3", desc: "Underground and open-pit control" },
                        { name: "Geodetic Surveying", icon: "\uf57d", desc: "GNSS control and precise coords" },
                        { name: "Cadastral Surveying", icon: "\uf5a0", desc: "Boundaries and legal plans" },
                        { name: "Remote Sensing", icon: "\uf7c0", desc: "UAV/LiDAR imagery and surfaces" },
                        { name: "Topographic Surveying", icon: "\uf6fc", desc: "Contours and feature mapping" }
                    ]

                    delegate: Item {
                        width: disciplinesGrid.cellWidth
                        height: disciplinesGrid.cellHeight

                        Rectangle {
                            id: tile
                            anchors.fill: parent
                            anchors.margins: 6
                            radius: 6
                            color: mouseArea.containsMouse ? Qt.lighter(cardColor, 1.02) : cardColor
                            border.color: mouseArea.containsMouse ? accentColor : borderColor
                            border.width: 1
                            scale: mouseArea.pressed ? 0.985 : 1.0

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                Text {
                                    text: modelData.icon
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 16
                                    color: mouseArea.containsMouse ? accentColor : textSecondary
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: modelData.name
                                        font.family: "Codec Pro"
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        color: textPrimary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.desc
                                        font.family: "Codec Pro"
                                        font.pixelSize: 10
                                        color: textSecondary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        maximumLineCount: 1
                                    }
                                }

                                Text {
                                    text: "\uf054"
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 10
                                    color: textSecondary
                                    opacity: mouseArea.containsMouse ? 1.0 : 0.6
                                    transform: Translate {
                                        x: mouseArea.containsMouse ? 2 : 0
                                        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                    }
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.disciplineSelected(modelData.name)
                            }
                        }
                    }
                }
            }
        }
    }
}
