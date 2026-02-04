import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: "Options"
    modal: true
    width: 800
    height: 600
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    standardButtons: Dialog.Ok | Dialog.Cancel | Dialog.Apply

    // Property bindings to the main CADPage state (to be injected)
    property var cadPage: null

    // Temporary state (guarded so the dialog can be constructed before cadPage is set)
    property int tempCrosshairSize: (cadPage && cadPage.crosshairSize !== undefined) ? cadPage.crosshairSize : 5
    property int tempPickboxSize: (cadPage && cadPage.pickboxSize !== undefined) ? cadPage.pickboxSize : 5
    property int tempSnapMarkerSize: (cadPage && cadPage.snapMarkerSize !== undefined) ? cadPage.snapMarkerSize : 10
    property int tempSelectedCRS: (cadPage && cadPage.selectedCRS !== undefined) ? cadPage.selectedCRS : 0
    property string tempCustomEpsg: (cadPage && cadPage.customEpsg !== undefined) ? cadPage.customEpsg : ""

    onOpened: {
        if (!cadPage)
            return

        tempCrosshairSize = cadPage.crosshairSize
        tempPickboxSize = cadPage.pickboxSize
        tempSnapMarkerSize = cadPage.snapMarkerSize
        tempSelectedCRS = cadPage.selectedCRS
        tempCustomEpsg = cadPage.customEpsg
    }

    onApplied: applySettings()
    onAccepted: applySettings()

    function applySettings() {
        if (!cadPage)
            return

        cadPage.crosshairSize = tempCrosshairSize
        cadPage.pickboxSize = tempPickboxSize
        cadPage.snapMarkerSize = tempSnapMarkerSize
        cadPage.selectedCRS = tempSelectedCRS
        if (tempSelectedCRS === 4) {
             cadPage.customEpsg = tempCustomEpsg
        }
        console.log("Settings Applied")
    }

    background: Rectangle {
        color: "#2b2b2b"
        border.color: "#444"
    }

    header: TabBar {
        id: optionsTabBar
        width: parent.width
        background: Rectangle { color: "#2b2b2b" }

        Repeater {
            model: ["Display", "Drafting", "Selection", "Geospatial"]
            TabButton {
                text: modelData
                width: implicitWidth + 20
                contentItem: Text {
                    text: parent.text
                    font.family: "Codec Pro"
                    font.pixelSize: 11
                    color: parent.checked ? "white" : "#aaa"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.checked ? "#444" : "transparent"
                    border.color: "#111"
                    border.width: 1
                }
            }
        }
    }

    contentItem: Rectangle {
        color: "#2b2b2b"

        StackLayout {
            anchors.fill: parent
            anchors.margins: 10
            currentIndex: optionsTabBar.currentIndex

            // 1: Display
            GridLayout {
                columns: 2
                columnSpacing: 20
                rowSpacing: 20

                GroupBox {
                    title: "Window Elements"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    background: Rectangle { color: "transparent"; border.color: "#555"; radius: 2 }
                    label: Text { text: parent.title; color: "white"; font.pixelSize: 11; font.bold: true }

                    ColumnLayout {
                        spacing: 10
                        RowLayout {
                            Text { text: "Color Theme:"; color: "white"; font.pixelSize: 11 }
                            ComboBox {
                                model: ["Dark", "Light"]
                                currentIndex: 0 // Mockup
                                implicitWidth: 120
                                implicitHeight: 24
                            }
                        }
                        CheckBox { text: "Display Scrollbars in drawing window"; checked: true;
                                   contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 11; leftPadding: 24 } }
                        CheckBox { text: "Use large buttons for Toolbars"; checked: false;
                                   contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 11; leftPadding: 24 } }
                    }
                }

                GroupBox {
                    title: "Crosshair Size"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    background: Rectangle { color: "transparent"; border.color: "#555"; radius: 2 }
                    label: Text { text: parent.title; color: "white"; font.pixelSize: 11; font.bold: true }

                    ColumnLayout {
                        Slider {
                            from: 1; to: 100
                            value: tempCrosshairSize
                            onValueChanged: tempCrosshairSize = value
                            Layout.fillWidth: true
                        }
                        Text { text: tempCrosshairSize.toString(); color: "white"; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
                    }
                }

                Item { Layout.fillHeight: true; Layout.columnSpan: 2 }
            }

            // 2: Drafting
            GridLayout {
                columns: 2
                columnSpacing: 20

                GroupBox {
                    title: "AutoSnap Settings"
                    Layout.fillWidth: true
                    background: Rectangle { color: "transparent"; border.color: "#555"; radius: 2 }
                    label: Text { text: parent.title; color: "white"; font.pixelSize: 11; font.bold: true }

                    ColumnLayout {
                        CheckBox { text: "Marker"; checked: true; contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 11; leftPadding: 24 } }
                        CheckBox { text: "Magnet"; checked: true; contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 11; leftPadding: 24 } }
                        CheckBox { text: "Display AutoSnap tooltip"; checked: true; contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 11; leftPadding: 24 } }
                    }
                }

                GroupBox {
                    title: "AutoSnap Marker Size"
                    Layout.fillWidth: true
                     background: Rectangle { color: "transparent"; border.color: "#555"; radius: 2 }
                    label: Text { text: parent.title; color: "white"; font.pixelSize: 11; font.bold: true }

                    ColumnLayout {
                        Slider { from: 1; to: 20; value: tempSnapMarkerSize; onValueChanged: tempSnapMarkerSize = value; Layout.fillWidth: true }

                        // Preview
                        Rectangle {
                            width: 100; height: 100; color: "black"; border.color: "gray"
                            Layout.alignment: Qt.AlignHCenter
                            Rectangle {
                                width: tempSnapMarkerSize * 2; height: tempSnapMarkerSize * 2
                                color: "transparent"; border.color: "yellow"; border.width: 2
                                anchors.centerIn: parent
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true; Layout.columnSpan: 2 }
            }

            // 3: Selection
            GroupBox {
                title: "Pickbox Size"
                background: Rectangle { color: "transparent"; border.color: "#555"; radius: 2 }
                label: Text { text: parent.title; color: "white"; font.pixelSize: 11; font.bold: true }

                ColumnLayout {
                    Slider { from: 1; to: 50; value: tempPickboxSize; onValueChanged: tempPickboxSize = value; Layout.fillWidth: true }
                    Rectangle {
                        width: 100; height: 100; color: "black"; border.color: "gray"
                        Layout.alignment: Qt.AlignHCenter
                        Rectangle {
                            width: tempPickboxSize * 2; height: tempPickboxSize * 2
                            color: "transparent"; border.color: "white"; border.width: 1
                            anchors.centerIn: parent
                        }
                    }
                }
            }

            // 4: Geospatial (CRS)
            GroupBox {
                title: "Coordinate Reference System"
                background: Rectangle { color: "transparent"; border.color: "#555"; radius: 2 }
                label: Text { text: parent.title; color: "white"; font.pixelSize: 11; font.bold: true }

                ColumnLayout {
                    spacing: 15
                    Text { text: "Assign a coordinate system to the current drawing."; color: "#ccc"; font.pixelSize: 11 }

                    GridLayout {
                        columns: 2
                        Text { text: "System:"; color: "white"; font.pixelSize: 11 }
                        ComboBox {
                            model: ["Lo29 (Harare) - EPSG:22289", "Lo31 (Beitbridge) - EPSG:22291", "WGS 84 - EPSG:4326", "UTM Zone 36S - EPSG:32736", "Custom EPSG..."]
                            currentIndex: tempSelectedCRS
                            onCurrentIndexChanged: {
                                tempSelectedCRS = currentIndex
                            }
                            Layout.preferredWidth: 300
                        }

                        Text { text: "Custom EPSG:"; color: tempSelectedCRS === 4 ? "white" : "gray"; font.pixelSize: 11 }
                        TextField {
                            enabled: tempSelectedCRS === 4
                            text: tempCustomEpsg
                            placeholderText: "e.g. 32735"
                            onTextChanged: tempCustomEpsg = text
                            color: "black"
                            background: Rectangle { color: enabled ? "white" : "#aaa"; radius: 2 }
                        }
                    }
                }
            }
        }
    }
}
