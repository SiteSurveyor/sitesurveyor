import QtQuick

Item {
    id: leftItem
    width: 300
    height: parent.height
    anchors.left: parent.left

    Item {
        id: dateitem
        height: 110
        width: parent.width
        anchors.top: parent.top

        Text {
            text: Qt.formatDate(currentTime, 'yyyy-MM-dd')
            font.pixelSize: 12
            color: textColor
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.topMargin: 16
        }

        Text {
            text: Qt.formatDate(currentTime, 'ddd')
            font.pixelSize: 12
            color: textColor
            anchors.top: parent.top
            anchors.right: ampmtxt.right
            anchors.topMargin: 16
        }

        Text {
            id: timetxt
            text: Qt.formatTime(currentTime, 'hh:mm')
            font.pixelSize: 34
            color: textColor
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.bottomMargin: 14
        }

        Text {
            id: sectxt
            width: 50
            text: ':' + Qt.formatTime(currentTime, 'ss')
            font.pixelSize: 16
            color: textColor
            anchors.baseline: timetxt.baseline
            anchors.left: timetxt.right
        }

        Text {
            id: ampmtxt
            text: Qt.formatTime(currentTime, 'AP')
            font.pixelSize: 12
            color: textColor
            anchors.baseline: timetxt.baseline
            anchors.left: sectxt.right
            anchors.leftMargin: 8
        }
    }

    Rectangle {
        id: todaysweatheritem
        radius: 8
        width: parent.width
        color: glassyBgColor
        border.color: borderColor
        border.width: 1
        anchors.top: dateitem.bottom
        anchors.bottom: locationitem.top
        anchors.topMargin: 12
        anchors.bottomMargin: 12

        Text {
            text: qsTr('Today')
            font.pixelSize: 11
            color: textColor
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 16
        }

        Column {
            anchors.centerIn: parent
            spacing: 16

            Row {
                spacing: 16
                height: tmptxt.height
                anchors.horizontalCenter: parent.horizontalCenter

                IconLabel {
                    id: cloudicon
                    icon: '\uf746'
                    size: 18
                    color: textColor
                    anchors.baseline: tmptxt.baseline
                }

                Text {
                    id: tmptxt
                    text: ambientTemperature
                    font.pixelSize: 40
                    color: textColor

                    Text {
                        text: qsTr('°C')
                        font.pixelSize: 10
                        color: textColor
                        anchors.top: parent.top
                        anchors.left: parent.right
                    }
                }

                Text {
                    id: minmaxtxt
                    text: qsTr('24/16')
                    font.pixelSize: 11
                    color: textColor
                    anchors.baseline: tmptxt.baseline
                }
            }

            Text {
                id: weathercommentxt
                text: qsTr('Partially Clouded')
                font.pixelSize: 12
                color: textColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    Rectangle {
        id: locationitem
        radius: 8
        height: 90
        color: glassyBgColor
        border.color: borderColor
        border.width: 1
        width: parent.width
        anchors.bottom: parent.bottom

        Row {
            id: locationitempadded
            anchors.fill: parent
            anchors.margins: 16

            Repeater {
                id: locationrepeater
                model: roomsModel

                delegate: Item {
                    id: roomdelegateitem
                    height: locationitempadded.height
                    width: locationitempadded.width / locationrepeater.model.count

                    property string label
                    property bool isActive: label===activeRoomLabel
                    property alias icon: iconlabel.icon
                    property alias size: iconlabel.size

                    signal clicked()

                    label: model.label
                    icon: model.icon
                    size: model.size
                    onClicked: activeRoomLabel=label

                    Column {
                        anchors.fill: parent
                        spacing: 8

                        IconLabel {
                            id: iconlabel
                            width: parent.height * 0.5
                            height: width
                            anchors.horizontalCenter: parent.horizontalCenter
                            horizontalAlignment: IconLabel.AlignHCenter
                            verticalAlignment: IconLabel.AlignVCenter
                            opacity: roomdelegateitem.isActive ? 1 : 0.5

                            Behavior on opacity { NumberAnimation { duration: 300 }}
                        }

                        Text {
                            text: roomdelegateitem.label
                            font.pixelSize: 10
                            color: textColor
                            anchors.horizontalCenter: parent.horizontalCenter
                            opacity: roomdelegateitem.isActive ? 1 : 0.5

                            Behavior on opacity { NumberAnimation { duration: 300 }}

                            Rectangle {
                                width: parent.parent.width * 0.8
                                height: 3
                                radius: 2
                                color: textColor
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: -6
                                opacity: roomdelegateitem.isActive ? 1 : 0.5

                                Behavior on opacity { NumberAnimation { duration: 300 }}
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: roomdelegateitem.clicked()
                    }
                }
            }
        }
    }
}
