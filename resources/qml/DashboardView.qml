import QtQuick
import 'components'

Item {
    id: root

    // Properties from Main.qml
    property string activeRoomLabel: 'Living'

    property real powerConsumed: 7354
    property real ambientTemperature: 22
    property real temperature: 26
    property real humidity: 47
    property real heating: 35
    property real water: 231
    property real lightIntensity: 45

    property var currentTime: new Date()

    // Theme properties mapped from parent or default
    property string bgGradientStart: '#ffffff'
    property string bgGradientStop: '#f0f0f0'

    QtObject {
        id: internal

        property real temperature: 26
        property real humidity: 47
        property real heating: 35
        property real water: 231
        property real lightIntensity: 45
        property real powerConsumed: 7354
        property real ambientTemperature: 22
    }

    ListModel {
        id: roomsModel
        ListElement {
            label: 'Living'
            icon: '\uf4b8'
            size: 28
            temperature: 26
            humidity: 47
            heating: 35
            water: 231
            lightIntensity: 45
        }

        ListElement {
            label: 'Kitchen'
            icon: '\uf79a'
            size: 22
            temperature: 32
            humidity: 67
            heating: 22
            water: 344
            lightIntensity: 78
        }

        ListElement {
            label: 'Bedroom'
            icon: '\uf236'
            size: 28
            temperature: 24
            humidity: 40
            heating: 40
            water: 304
            lightIntensity: 25
        }

        ListElement {
            label: 'Laundry'
            icon: '\uf553'
            size: 22
            temperature: 28
            humidity: 77
            heating: 56
            water: 430
            lightIntensity: 85
        }
    }

    // Expose roomsModel for children
    property alias roomsModel: roomsModel

    onActiveRoomLabelChanged: {
        for(var i=0; i<roomsModel.count; i++) {
            var obji = roomsModel.get(i)

            if(obji['label'] === activeRoomLabel) {
                internal.temperature = obji['temperature']
                internal.humidity = obji['humidity']
                internal.heating = obji['heating']
                internal.water = obji['water']
                internal.lightIntensity = obji['lightIntensity']

                break;
            }
        }
    }

    function getRandOffset(value, range=4) {
        return Math.round(value + range/2 - (Math.random(1) * range))
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            currentTime = new Date()
            ambientTemperature = getRandOffset(internal.ambientTemperature, 2)
            powerConsumed = getRandOffset(internal.powerConsumed, 2)
            temperature = getRandOffset(internal.temperature)
            humidity = getRandOffset(internal.humidity)
            heating = getRandOffset(internal.heating)
            water = getRandOffset(internal.water)
            lightIntensity = getRandOffset(internal.lightIntensity)
        }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: bgGradientStart }
            GradientStop { position: 1.0; color: bgGradientStop }
        }

        Item {
            anchors.fill: parent
            anchors.margins: 76.4

            LeftPane { id: leftItem }

            MiddlePane { id: middleItem }

            RightPane { id: rightItem }
        }
    }

    function commafy(value) {
        return value.toLocaleString()
    }
}
