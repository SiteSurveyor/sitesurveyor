import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: root

    property bool collapsed: false
    property string currentTab: "Dashboard"

    // Internal state for folders
    // Expanded by default so user sees items immediately
    property bool cogoExpanded: true

    signal toggleCollapse()
    signal tabSelected(string name)
    // Compact light theme
    property color bgColor: "#f6f7f9"
    property color cardColor: "#ffffff"
    property color borderColor: "#d0d7de"
    property color textPrimary: "#111827"
    property color textSecondary: "#6b7280"
    property color accentColor: "#2563eb"

    // Uniform sidebar background
    Rectangle {
        anchors.fill: parent
        color: cardColor
    }

    Layout.preferredWidth: collapsed ? 56 : 220
    Behavior on Layout.preferredWidth { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    // Right border
    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 1
        color: borderColor
    }

    // Brand / Logo Area
    Rectangle {
        id: brand
        width: parent.width
        height: 56
        color: cardColor
        z: 2

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: borderColor
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 10

            Image {
                source: "qrc:/logo/SiteSurveyor.png"
                sourceSize.height: 28
                fillMode: Image.PreserveAspectFit
                Layout.preferredHeight: 28
                Layout.preferredWidth: root.collapsed ? 28 : 160
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    ScrollView {
        anchors.top: brand.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: parent.width
            spacing: 0

            // -- Reusable Components --

            component NavItem : Rectangle {
                id: navItemRoot
                property string label: ""
                property string icon: ""
                property bool selected: false
                property bool isSub: false
                property bool hasArrow: false
                property bool arrowExpanded: false

                signal itemClicked()

                Layout.fillWidth: true
                Layout.preferredHeight: isSub ? 36 : 40
                color: "transparent"

                // Background with animations
                Rectangle {
                    id: bgRect
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    radius: 6
                    color: selected ? Qt.rgba(37/255, 99/255, 235/255, 0.12) :
                          (ma.containsMouse ? Qt.rgba(37/255, 99/255, 235/255, 0.06) : "transparent")

                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // Left accent bar for selected and hover
                Rectangle {
                    id: accentBar
                    width: (selected || ma.containsMouse) ? 2 : 0
                    height: parent.height * 0.5
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 2
                    color: accentColor

                    Behavior on height {
                        NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        navItemRoot.itemClicked()
                    }
                }

                RowLayout {
                    id: contentRow
                    anchors.fill: parent
                    anchors.leftMargin: isSub ? 44 : 24
                    anchors.rightMargin: 15
                    spacing: 12

                    transformOrigin: Item.Left

                    // Icon container with hover effect
                    Item {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24

                        Text {
                            id: iconText
                            anchors.centerIn: parent
                            text: icon
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: isSub ? 10 : 12
                            color: selected ? accentColor : textSecondary
                        }
                    }

                    Text {
                        text: label
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: selected ? textPrimary : textSecondary
                        visible: !root.collapsed

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Arrow for Folders with rotation animation
                    Item {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        Layout.alignment: Qt.AlignVCenter
                        visible: !root.collapsed && hasArrow

                        Text {
                            id: arrowIcon
                            anchors.centerIn: parent
                            text: "\uf054" // chevron-right
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 9
                            color: textSecondary
                            rotation: arrowExpanded ? 90 : 0

                            Behavior on rotation {
                                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }
                }
            }

            component SectionHeader : Text {
                property string title: ""
                text: title
                font.family: "Codec Pro"
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 1.2
                color: textSecondary
                leftPadding: 24
                topPadding: 14
                bottomPadding: 6
                visible: !root.collapsed
                Layout.fillWidth: true
            }

            // -- Navigation Items --

            SectionHeader { title: "MAIN" }

            // 1. Dashboard
            NavItem {
                label: "Dashboard"
                icon: "\uf0e4" // tachometer-alt (dashboard)
                selected: root.currentTab === "Dashboard"
                onItemClicked: root.tabSelected("Dashboard")
            }

            SectionHeader { title: "TOOLS" }

            // 2. COGO (Folder)
            NavItem {
                label: "COGO"
                icon: "\uf1ec" // calculator
                hasArrow: true
                arrowExpanded: root.cogoExpanded
                onItemClicked: root.cogoExpanded = !root.cogoExpanded
            }

            // COGO Sub-items
            ColumnLayout {
                visible: root.cogoExpanded && !root.collapsed
                Layout.fillWidth: true
                spacing: 0

                NavItem {
                    label: "Traverse"
                    icon: "\uf018"  // road (traverse path)
                    isSub: true
                    selected: root.currentTab === "Traverse"
                    onItemClicked: root.tabSelected("Traverse")
                }

                NavItem {
                    label: "Levelling"
                    icon: "\uf545"  // ruler-horizontal
                    isSub: true
                    selected: root.currentTab === "Levelling"
                    onItemClicked: root.tabSelected("Levelling")
                }
            }

            // 3. CAD Mode
            NavItem {
                label: "CAD Mode"
                icon: "\uf5ae"  // drafting-compass
                selected: root.currentTab === "CAD Mode"
                onItemClicked: root.tabSelected("CAD Mode")
            }

            SectionHeader { title: "MANAGEMENT" }

            // Personnel Management
            NavItem {
                label: "Personnel"
                icon: "\uf0c0"  // users
                selected: root.currentTab === "Personnel"
                onItemClicked: root.tabSelected("Personnel")
            }

            // Instruments Management
            NavItem {
                label: "Instruments"
                icon: "\uf1e5"  // binoculars (survey equipment)
                selected: root.currentTab === "Instruments"
                onItemClicked: root.tabSelected("Instruments")
            }

            SectionHeader { title: "SYSTEM" }

            // 4. Report
            NavItem {
                label: "Report"
                icon: "\uf1c1"  // file-alt (document)
                selected: root.currentTab === "Report"
                onItemClicked: root.tabSelected("Report")
            }

            // 5. Settings
            NavItem {
                label: "Settings"
                icon: "\uf013"  // cog
                selected: root.currentTab === "Settings"
                onItemClicked: root.tabSelected("Settings")
            }

            Item { Layout.fillHeight: true } // Spacer
        }
    }
}
