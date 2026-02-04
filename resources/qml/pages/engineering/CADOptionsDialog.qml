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
    padding: 0

    // Property bindings to the main CADPage state (to be injected)
    property var cadPage: null
    property color dialogBg: cadPage ? cadPage.darkCardBg : "#2b2b2b"
    property color panelBg: cadPage ? cadPage.canvasBg : "#1f1f1f"
    property color borderColor: cadPage ? "#3A3A3A" : "#444"
    property color textPrimary: cadPage ? cadPage.textPrimary : "#e8e8e8"
    property color textSecondary: cadPage ? cadPage.textSecondary : "#b0b0b0"
    property color accentColor: cadPage ? cadPage.accentColor : "#5B7C99"

    // Temporary state (guarded so the dialog can be constructed before cadPage is set)
    property int tempCrosshairSize: (cadPage && cadPage.crosshairSize !== undefined) ? cadPage.crosshairSize : 5
    property int tempPickboxSize: (cadPage && cadPage.pickboxSize !== undefined) ? cadPage.pickboxSize : 5
    property int tempSnapMarkerSize: (cadPage && cadPage.snapMarkerSize !== undefined) ? cadPage.snapMarkerSize : 10
    property int tempSelectedCRS: (cadPage && cadPage.selectedCRS !== undefined) ? cadPage.selectedCRS : 0
    property string tempCustomEpsg: (cadPage && cadPage.customEpsg !== undefined) ? cadPage.customEpsg : ""
    property string tempLineType: (cadPage && cadPage.currentLineType !== undefined) ? cadPage.currentLineType : "Continuous"
    property real tempLineTypeScale: (cadPage && cadPage.lineTypeScale !== undefined) ? cadPage.lineTypeScale : 1.0

    onOpened: {
        if (!cadPage)
            return

        tempCrosshairSize = cadPage.crosshairSize
        tempPickboxSize = cadPage.pickboxSize
        tempSnapMarkerSize = cadPage.snapMarkerSize
        tempSelectedCRS = cadPage.selectedCRS
        tempCustomEpsg = cadPage.customEpsg
        tempLineType = cadPage.currentLineType
        tempLineTypeScale = cadPage.lineTypeScale
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
        cadPage.currentLineType = tempLineType
        cadPage.lineTypeScale = tempLineTypeScale
        if (tempSelectedCRS === 4) {
             cadPage.customEpsg = tempCustomEpsg
        }
        console.log("Settings Applied")
    }

    background: Rectangle {
        color: dialogBg
        border.color: borderColor
        border.width: 1
        radius: 6
    }

    header: TabBar {
        id: optionsTabBar
        width: parent.width
        background: Rectangle { color: dialogBg }

        Repeater {
            model: ["Display", "Drafting", "Selection", "Geospatial"]
            TabButton {
                text: modelData
                width: implicitWidth + 20
                contentItem: Text {
                    text: parent.text
                    font.family: "Codec Pro"
                    font.pixelSize: 11
                    color: parent.checked ? textPrimary : textSecondary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.checked ? "#333" : "transparent"
                    border.color: borderColor
                    border.width: 1
                }
            }
        }
    }

    contentItem: Rectangle {
        color: dialogBg

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            RowLayout {
                spacing: 10
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: accentColor
                    Text {
                        anchors.centerIn: parent
                        text: "\uf013"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 12
                        color: "white"
                    }
                }
                ColumnLayout {
                    spacing: 2
                    Text { text: "CAD Settings"; font.family: "Codec Pro"; font.pixelSize: 13; font.weight: Font.Bold; color: textPrimary }
                    Text { text: "Configure drafting, selection, and geospatial options"; font.family: "Codec Pro"; font.pixelSize: 10; color: textSecondary }
                }
                Item { Layout.fillWidth: true }
            }

            Rectangle { height: 1; Layout.fillWidth: true; color: borderColor }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
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
                    background: Rectangle { color: panelBg; border.color: borderColor; radius: 4 }
                    label: Text { text: parent.title; color: textPrimary; font.pixelSize: 11; font.bold: true }

                    ColumnLayout {
                        spacing: 10
                        RowLayout {
                            Text { text: "Color Theme:"; color: textPrimary; font.pixelSize: 11 }
                            ComboBox {
                                model: ["Dark", "Light"]
                                currentIndex: 0 // Mockup
                                implicitWidth: 120
                                implicitHeight: 24
                            }
                        }
                        CheckBox { text: "Display Scrollbars in drawing window"; checked: true;
                                   contentItem: Text { text: parent.text; color: textPrimary; font.pixelSize: 11; leftPadding: 24 } }
                        CheckBox { text: "Use large buttons for Toolbars"; checked: false;
                                   contentItem: Text { text: parent.text; color: textPrimary; font.pixelSize: 11; leftPadding: 24 } }
                    }
                }

                GroupBox {
                    title: "Crosshair Size"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    background: Rectangle { color: panelBg; border.color: borderColor; radius: 4 }
                    label: Text { text: parent.title; color: textPrimary; font.pixelSize: 11; font.bold: true }

                    ColumnLayout {
                        Slider {
                            from: 1; to: 100
                            value: tempCrosshairSize
                            onValueChanged: tempCrosshairSize = value
                            Layout.fillWidth: true
                        }
                        Text { text: tempCrosshairSize.toString(); color: textPrimary; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
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
                    background: Rectangle { color: panelBg; border.color: borderColor; radius: 4 }
                    label: Text { text: parent.title; color: textPrimary; font.pixelSize: 11; font.bold: true }

                    ColumnLayout {
                        CheckBox { text: "Marker"; checked: true; contentItem: Text { text: parent.text; color: textPrimary; font.pixelSize: 11; leftPadding: 24 } }
                        CheckBox { text: "Magnet"; checked: true; contentItem: Text { text: parent.text; color: textPrimary; font.pixelSize: 11; leftPadding: 24 } }
                        CheckBox { text: "Display AutoSnap tooltip"; checked: true; contentItem: Text { text: parent.text; color: textPrimary; font.pixelSize: 11; leftPadding: 24 } }
                    }
                }

                GroupBox {
                    title: "AutoSnap Marker Size"
                    Layout.fillWidth: true
                     background: Rectangle { color: panelBg; border.color: borderColor; radius: 4 }
                    label: Text { text: parent.title; color: textPrimary; font.pixelSize: 11; font.bold: true }

                    ColumnLayout {
                        Slider { from: 1; to: 20; value: tempSnapMarkerSize; onValueChanged: tempSnapMarkerSize = value; Layout.fillWidth: true }

                        // Preview
                        Rectangle {
                            width: 100; height: 100; color: "#111"; border.color: borderColor
                            Layout.alignment: Qt.AlignHCenter
                            Rectangle {
                                width: tempSnapMarkerSize * 2; height: tempSnapMarkerSize * 2
                                color: "transparent"; border.color: "yellow"; border.width: 2
                                anchors.centerIn: parent
                            }
                        }
                    }
                }

                GroupBox {
                    title: "Line Type"
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    background: Rectangle { color: panelBg; border.color: borderColor; radius: 4 }
                    label: Text { text: parent.title; color: textPrimary; font.pixelSize: 11; font.bold: true }

                    ColumnLayout {
                        spacing: 10

                        RowLayout {
                            spacing: 10
                            Text { text: "Default line type:"; color: textPrimary; font.pixelSize: 11 }
                            ComboBox {
                                id: lineTypeCombo
                                model: cadPage && cadPage.lineTypeNames ? cadPage.lineTypeNames : ["Continuous", "Dashed", "Center", "Hidden"]
                                currentIndex: {
                                    var names = cadPage && cadPage.lineTypeNames ? cadPage.lineTypeNames : ["Continuous", "Dashed", "Center", "Hidden"]
                                    var idx = names.indexOf(tempLineType)
                                    return idx >= 0 ? idx : 0
                                }
                                onCurrentIndexChanged: {
                                    var names = cadPage && cadPage.lineTypeNames ? cadPage.lineTypeNames : ["Continuous", "Dashed", "Center", "Hidden"]
                                    tempLineType = names[currentIndex] || "Continuous"
                                }
                                implicitWidth: 160
                                implicitHeight: 24
                            }
                        }

                        RowLayout {
                            spacing: 10
                            Text { text: "Line type scale:"; color: textPrimary; font.pixelSize: 11 }
                            Slider {
                                from: 0.5; to: 5.0; stepSize: 0.1
                                value: tempLineTypeScale
                                onValueChanged: tempLineTypeScale = value
                                Layout.fillWidth: true
                            }
                            Text { text: tempLineTypeScale.toFixed(2); color: textPrimary; font.pixelSize: 11 }
                        }
                    }
                }
                Item { Layout.fillHeight: true; Layout.columnSpan: 2 }
            }

            // 3: Selection
            GroupBox {
                title: "Pickbox Size"
                background: Rectangle { color: panelBg; border.color: borderColor; radius: 4 }
                label: Text { text: parent.title; color: textPrimary; font.pixelSize: 11; font.bold: true }

                ColumnLayout {
                    Slider { from: 1; to: 50; value: tempPickboxSize; onValueChanged: tempPickboxSize = value; Layout.fillWidth: true }
                    Rectangle {
                        width: 100; height: 100; color: "#111"; border.color: borderColor
                        Layout.alignment: Qt.AlignHCenter
                        Rectangle {
                            width: tempPickboxSize * 2; height: tempPickboxSize * 2
                            color: "transparent"; border.color: accentColor; border.width: 1
                            anchors.centerIn: parent
                        }
                    }
                }
            }

            // 4: Geospatial (CRS)
            GroupBox {
                title: "Coordinate Reference System"
                background: Rectangle { color: panelBg; border.color: borderColor; radius: 4 }
                label: Text { text: parent.title; color: textPrimary; font.pixelSize: 11; font.bold: true }

                ColumnLayout {
                    spacing: 15
                    Text { text: "Assign a coordinate system to the current drawing."; color: textSecondary; font.pixelSize: 11 }

                    GridLayout {
                        columns: 2
                        Text { text: "System:"; color: textPrimary; font.pixelSize: 11 }
                        ComboBox {
                            model: ["Lo29 (Harare) - EPSG:22289", "Lo31 (Beitbridge) - EPSG:22291", "WGS 84 - EPSG:4326", "UTM Zone 36S - EPSG:32736", "Custom EPSG..."]
                            currentIndex: tempSelectedCRS
                            onCurrentIndexChanged: {
                                tempSelectedCRS = currentIndex
                            }
                            Layout.preferredWidth: 300
                        }
                        Text { text: "Custom EPSG:"; color: tempSelectedCRS === 4 ? textPrimary : textSecondary; font.pixelSize: 11 }
                        Text { text: "Custom EPSG:"; color: tempSelectedCRS === 4 ? "white" : "gray"; font.pixelSize: 11 }
                        TextField {
                            enabled: tempSelectedCRS === 4
                            text: tempCustomEpsg
                            placeholderText: "e.g. 32735"
                            onTextChanged: tempCustomEpsg = text
                            color: textPrimary
                            background: Rectangle { color: enabled ? "#1E1E1E" : "#2b2b2b"; border.color: borderColor; radius: 3 }
                        }
                    }
                }
            }
        }
    }
}
}
