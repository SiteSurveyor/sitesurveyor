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

    // Uniform sidebar background
    color: "#2C3E50"

    Layout.preferredWidth: collapsed ? 60 : 256
    Behavior on Layout.preferredWidth { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

    // Brand / Logo Area
    Rectangle {
        id: brand
        width: parent.width
        height: 64
        color: "#1A252F"
        z: 2

        RowLayout {
            anchors.centerIn: parent
            spacing: 10

            Image {
                source: "qrc:/logo/SiteSurveyor.png"
                sourceSize.height: 40
                fillMode: Image.PreserveAspectFit
                Layout.preferredHeight: 40
                Layout.preferredWidth: root.collapsed ? 40 : 180
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
                    radius: 8
                    color: "transparent"
                }

                // Left accent bar for selected and hover
                Rectangle {
                    id: accentBar
                    width: 3
                    height: (selected || ma.containsMouse) ? parent.height * 0.6 : 0
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 2
                    color: "#3498DB"

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
                            font.pixelSize: isSub ? 12 : 15
                            color: selected ? "#FFFFFF" : "#95A5A6"
                        }
                    }

                    Text {
                        text: label
                        font.family: "Codec Pro"
                        font.pixelSize: 13
                        color: selected ? "#FFFFFF" : "#BDC3C7"
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
                            font.pixelSize: 10
                            color: "#95A5A6"
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
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.5
                color: "#7F8C8D"
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
