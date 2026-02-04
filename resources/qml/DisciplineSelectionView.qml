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

    Dialog {
        id: comingSoonDialog
        anchors.centerIn: parent
        width: Math.min(380, Math.max(260, root.width - pageMargin * 2))
        modal: true
        padding: 16
        title: "Coming soon"
        standardButtons: Dialog.Ok

        property string disciplineName: ""

        Overlay.modal: Rectangle { color: "#80000000" }

        background: Rectangle {
            color: cardColor
            radius: 8
            border.color: borderColor
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 8

            Text {
                text: comingSoonDialog.disciplineName.length > 0
                      ? (comingSoonDialog.disciplineName + " is under development.")
                      : "This module is under development."
                font.family: "Codec Pro"
                font.pixelSize: 12
                font.weight: Font.Medium
                color: textPrimary
                wrapMode: Text.Wrap
            }

            Text {
                text: "For now, use Engineering Surveying (recommended)."
                font.family: "Codec Pro"
                font.pixelSize: 11
                color: textSecondary
                wrapMode: Text.Wrap
            }
        }
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

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 640
                radius: 8
                color: Qt.lighter(accentColor, 1.95)
                border.color: Qt.lighter(accentColor, 1.65)
                border.width: 1
                height: bannerLayout.implicitHeight + 14

                RowLayout {
                    id: bannerLayout
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: "\uf05a"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 14
                        color: accentColor
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Recommended: Engineering Surveying (fully implemented). Other disciplines are coming soon."
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: textPrimary
                        wrapMode: Text.Wrap
                    }
                }
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
                    cellHeight: 96

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    model: [
                        { name: "Engineering Surveying", icon: "\uf5ae", desc: "Layout, as-builts, earthworks", available: true, recommended: true },
                        { name: "Mining Surveying", icon: "\uf6e3", desc: "Underground and open-pit control", available: false },
                        { name: "Geodetic Surveying", icon: "\uf57d", desc: "GNSS control and precise coords", available: false },
                        { name: "Cadastral Surveying", icon: "\uf5a0", desc: "Boundaries and legal plans", available: false },
                        { name: "Remote Sensing", icon: "\uf7c0", desc: "UAV/LiDAR imagery and surfaces", available: false },
                        { name: "Topographic Surveying", icon: "\uf6fc", desc: "Contours and feature mapping", available: false }
                    ]

                    delegate: Item {
                        width: disciplinesGrid.cellWidth
                        height: disciplinesGrid.cellHeight

                        readonly property bool isAvailable: modelData.available === undefined ? true : modelData.available
                        readonly property bool isRecommended: modelData.recommended === true
                        readonly property string badgeLabel: isRecommended ? "Recommended" : (isAvailable ? "" : "Coming soon")

                        Rectangle {
                            id: tile
                            anchors.fill: parent
                            anchors.margins: 10
                            radius: 8
                            color: (isAvailable && mouseArea.containsMouse) ? Qt.lighter(cardColor, 1.02) : cardColor
                            border.color: (isAvailable && mouseArea.containsMouse) ? accentColor : borderColor
                            border.width: (isAvailable && mouseArea.containsMouse) ? 2 : 1
                            opacity: isAvailable ? 1.0 : 0.55
                            scale: (isAvailable && mouseArea.pressed) ? 0.985 : 1.0

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Rectangle {
                                id: badge
                                visible: badgeLabel.length > 0
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: 10
                                anchors.rightMargin: 10
                                height: 18
                                width: badgeText.implicitWidth + 14
                                radius: 9
                                color: isRecommended ? Qt.lighter(accentColor, 1.92) : Qt.lighter(borderColor, 1.65)
                                border.color: isRecommended ? "transparent" : borderColor
                                border.width: isRecommended ? 0 : 1

                                Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: badgeLabel
                                    font.family: "Codec Pro"
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: isRecommended ? accentColor : textSecondary
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 12

                                Text {
                                    text: modelData.icon
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 18
                                    color: (isAvailable && mouseArea.containsMouse) ? accentColor : textSecondary
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: modelData.name
                                        font.family: "Codec Pro"
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: textPrimary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.desc
                                        font.family: "Codec Pro"
                                        font.pixelSize: 11
                                        color: textSecondary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        maximumLineCount: 1
                                    }
                                }

                                Text {
                                    text: isAvailable ? "\uf054" : "\uf023"
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 10
                                    color: textSecondary
                                    opacity: (isAvailable && mouseArea.containsMouse) ? 1.0 : 0.6
                                    transform: Translate {
                                        x: (isAvailable && mouseArea.containsMouse) ? 2 : 0
                                        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                    }
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: isAvailable ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                onClicked: {
                                    if (isAvailable) {
                                        root.disciplineSelected(modelData.name)
                                    } else {
                                        comingSoonDialog.disciplineName = modelData.name
                                        comingSoonDialog.open()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
