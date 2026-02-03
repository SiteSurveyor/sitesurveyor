import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs

Item {
    id: root

    // CoreUI Colors
    property color bgColor: "#ebedef"
    property color cardColor: "#ffffff"
    property color accentColor: "#321fdb"
    property color textPrimary: "#3c4b64"
    property color textSecondary: "#768192"
    property color borderColor: "#d8dbe0"
    property color successColor: "#2eb85c"
    property color warningColor: "#f9b115"
    property color dangerColor: "#e55353"
    property color infoColor: "#39f"

    // Settings properties (would be persisted via QSettings in production)
    property int distanceUnit: 0  // 0=Meters, 1=Feet, 2=US Survey Feet
    property int angleUnit: 0  // 0=Degrees, 1=Gradians, 2=DMS
    property int areaUnit: 0  // 0=Square Meters, 1=Hectares, 2=Acres
    property int decimalPlaces: 3



    function showSuccess(msg) {
        statusMessage.text = msg
        statusMessage.color = successColor
        statusMessage.visible = true
        hideTimer.restart()
    }

    function showError(msg) {
        statusMessage.text = msg
        statusMessage.color = dangerColor
        statusMessage.visible = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 3000
        onTriggered: statusMessage.visible = false
    }

    // Force Default Database
    Connections {
        target: root
        function onVisibleChanged() {
            if (root.visible && Database.databasePath !== Database.defaultDatabasePath) {
                Database.changeDatabasePath(Database.defaultDatabasePath)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: bgColor
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 20
        contentHeight: contentColumn.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: contentColumn
            width: parent.width
            spacing: 16

            // Page Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "Settings"
                    font.family: "Codec Pro"
                    font.pixelSize: 24
                    font.bold: true
                    color: textPrimary
                }

                Item { Layout.fillWidth: true }

                // Status message
                Text {
                    id: statusMessage
                    visible: false
                    font.family: "Codec Pro"
                    font.pixelSize: 12
                }
            }



            // ============ UNITS SETTINGS ============
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: unitsColumn.height + 40
                color: cardColor
                radius: 6
                border.color: borderColor

                ColumnLayout {
                    id: unitsColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 16

                    RowLayout {
                        spacing: 10
                        Rectangle {
                            width: 32; height: 32; radius: 6
                            color: Qt.lighter(infoColor, 1.85)
                            Text { anchors.centerIn: parent; text: "\uf545"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 14; color: infoColor }
                        }
                        Text { text: "Units & Precision"; font.family: "Codec Pro"; font.pixelSize: 16; font.bold: true; color: textPrimary }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 30
                        rowSpacing: 16

                        // Distance Units
                        ColumnLayout {
                            spacing: 6
                            Text { text: "Distance Units"; font.family: "Codec Pro"; font.pixelSize: 12; color: textSecondary }
                            ComboBox {
                                id: distanceCombo
                                Layout.preferredWidth: 200
                                model: ["Meters (m)", "Feet (ft)", "US Survey Feet"]
                                currentIndex: distanceUnit
                                onCurrentIndexChanged: distanceUnit = currentIndex

                                background: Rectangle {
                                    radius: 4
                                    color: "#f8f9fa"
                                    border.color: borderColor
                                }

                                contentItem: Text {
                                    leftPadding: 10
                                    text: distanceCombo.displayText
                                    font.family: "Codec Pro"
                                    font.pixelSize: 12
                                    color: textPrimary
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        // Angle Units
                        ColumnLayout {
                            spacing: 6
                            Text { text: "Angle Units"; font.family: "Codec Pro"; font.pixelSize: 12; color: textSecondary }
                            ComboBox {
                                id: angleCombo
                                Layout.preferredWidth: 200
                                model: ["Decimal Degrees (°)", "Gradians (gon)", "DMS (° ' \")"]
                                currentIndex: angleUnit
                                onCurrentIndexChanged: angleUnit = currentIndex

                                background: Rectangle {
                                    radius: 4
                                    color: "#f8f9fa"
                                    border.color: borderColor
                                }

                                contentItem: Text {
                                    leftPadding: 10
                                    text: angleCombo.displayText
                                    font.family: "Codec Pro"
                                    font.pixelSize: 12
                                    color: textPrimary
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        // Area Units
                        ColumnLayout {
                            spacing: 6
                            Text { text: "Area Units"; font.family: "Codec Pro"; font.pixelSize: 12; color: textSecondary }
                            ComboBox {
                                id: areaCombo
                                Layout.preferredWidth: 200
                                model: ["Square Meters (m²)", "Hectares (ha)", "Acres (ac)"]
                                currentIndex: areaUnit
                                onCurrentIndexChanged: areaUnit = currentIndex

                                background: Rectangle {
                                    radius: 4
                                    color: "#f8f9fa"
                                    border.color: borderColor
                                }

                                contentItem: Text {
                                    leftPadding: 10
                                    text: areaCombo.displayText
                                    font.family: "Codec Pro"
                                    font.pixelSize: 12
                                    color: textPrimary
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        // Decimal Places
                        ColumnLayout {
                            spacing: 6
                            Text { text: "Decimal Places"; font.family: "Codec Pro"; font.pixelSize: 12; color: textSecondary }
                            RowLayout {
                                spacing: 10
                                SpinBox {
                                    id: decimalSpin
                                    from: 0
                                    to: 8
                                    value: decimalPlaces
                                    onValueChanged: decimalPlaces = value

                                    background: Rectangle {
                                        radius: 4
                                        color: "#f8f9fa"
                                        border.color: borderColor
                                    }

                                    contentItem: Text {
                                        text: decimalSpin.value
                                        font.family: "Codec Pro"
                                        font.pixelSize: 12
                                        color: textPrimary
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                Text { text: "e.g. " + (123.456789).toFixed(decimalPlaces); font.family: "Codec Pro"; font.pixelSize: 11; color: textSecondary }
                            }
                        }
                    }
                }
            }



            // ============ DATABASE INFO ============
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: infoColumn.height + 40
                color: cardColor
                radius: 6
                border.color: borderColor

                ColumnLayout {
                    id: infoColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 16

                    RowLayout {
                        spacing: 10
                        Rectangle {
                            width: 32; height: 32; radius: 6
                            color: Qt.lighter(infoColor, 1.85)
                            Text { anchors.centerIn: parent; text: "\uf05a"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 14; color: infoColor }
                        }
                        Text { text: "Current Session"; font.family: "Codec Pro"; font.pixelSize: 16; font.bold: true; color: textPrimary }
                    }

                    GridLayout {
                        columns: 2
                        columnSpacing: 20
                        rowSpacing: 8

                        Text { text: "Connection:"; font.family: "Codec Pro"; font.pixelSize: 12; color: textSecondary }
                        Text { text: Database.isConnected ? "Connected" : "Disconnected"; font.family: "Codec Pro"; font.pixelSize: 12; font.weight: Font.Medium; color: Database.isConnected ? successColor : dangerColor }

                        Text { text: "Project:"; font.family: "Codec Pro"; font.pixelSize: 12; color: textSecondary }
                        Text { text: Database.currentProject || "None"; font.family: "Codec Pro"; font.pixelSize: 12; color: textPrimary }

                        Text { text: "Discipline:"; font.family: "Codec Pro"; font.pixelSize: 12; color: textSecondary }
                        Text { text: Database.currentDiscipline || "None"; font.family: "Codec Pro"; font.pixelSize: 12; color: textPrimary }
                    }
                }
            }

            // Spacer
            Item { Layout.preferredHeight: 20 }
        }
    }
}
