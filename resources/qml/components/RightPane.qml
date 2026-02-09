import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

Item {
    id: rightItem
    height: parent.height
    anchors.left: middleItem.right
    anchors.right: parent.right
    anchors.leftMargin: 24

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Rectangle {
            color: glassyBgColor
            radius: 8
            border.color: borderColor
            border.width: 1
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                anchors.fill: parent
                anchors.margins: 16

                property real maxcircularbarwidth: Math.min(width, height) - 16

                CircularProgressBar {
                    width: parent.maxcircularbarwidth
                    height: parent.maxcircularbarwidth
                    anchors.centerIn: parent
                    knobBackgroundColor: '#48709F'
                    knobColor: '#5CE1E6'
                    from: 0
                    to: 100
                    value: 50
                    lineWidth: 10

                    Item {
                        anchors.fill: parent
                        anchors.margins: 12

                        Text {
                            text: commafy(powerConsumed)
                            font.pixelSize: 28
                            color: textColor
                            anchors.centerIn: parent

                            Text {
                                text: qsTr('Power')
                                font.pixelSize: 12
                                color: textColor

                                anchors.bottom: parent.top
                                anchors.bottomMargin: 8
                                anchors.left: parent.left
                            }

                            Text {
                                text: qsTr('kW')
                                font.pixelSize: 11
                                color: textColor

                                anchors.top: parent.bottom
                                anchors.right: parent.right
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            color: glassyBgColor
            radius: 8
            border.color: borderColor
            border.width: 1
            Layout.fillWidth: true
            Layout.preferredHeight: lightswitchescol.height + 36

            Item {
                anchors.fill: parent
                anchors.margins: 16
                height: lightswitchescol.height

                Column {
                    id: lightswitchescol
                    width: parent.width
                    spacing: 12

                    RightPaneLightSwitchComponent {
                        label: qsTr('Windows')
                        checked: true
                    }

                    RightPaneLightSwitchComponent {
                        label: qsTr('Blinders')
                        checked: true
                    }

                    RightPaneLightSwitchComponent {
                        label: qsTr('Curtains')
                        checked: false
                    }
                }
            }
        }

        Rectangle {
            color: glassyBgColor
            radius: 8
            border.color: borderColor
            border.width: 1
            Layout.fillWidth: true
            Layout.preferredHeight: lightintensityitemcol.height + 36

            Item {
                anchors.fill: parent
                anchors.margins: 16
                height: lightintensityitemcol.height

                Column {
                    id: lightintensityitemcol
                    width: parent.width
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        height: 20

                        Text {
                            text: qsTr('Light Intensity')
                            font.pixelSize: 11
                            color: textColor
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Switch {
                            checked: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    Progressbar {
                        id: pb
                        width: parent.width
                        value: lightIntensity/100
                    }

                    Text {
                        text: Math.round(pb.value * 100)
                        font.pixelSize: 11
                        color: textColor
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
