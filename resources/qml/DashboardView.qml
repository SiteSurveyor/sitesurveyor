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
    // Compact light theme (consistent with discipline selection + project management)
    property color bgColor: "#f6f7f9"
    property color cardColor: "#ffffff"
    property color borderColor: "#d0d7de"
    property color textPrimary: "#111827"
    property color textSecondary: "#6b7280"
    property color accentColor: "#2563eb"

    // Back-compat bindings for child components
    property color textColor: textPrimary
    property color glassyBgColor: cardColor

    property string bgGradientStart: "#f6f7f9"
    property string bgGradientStop: "#eef1f5"

    property int pageMargin: Math.max(16, Math.min(32, Math.round(Math.min(width, height) * 0.04)))

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
            size: 20
            temperature: 26
            humidity: 47
            heating: 35
            water: 231
            lightIntensity: 45
        }

        ListElement {
            label: 'Kitchen'
            icon: '\uf79a'
            size: 18
            temperature: 32
            humidity: 67
            heating: 22
            water: 344
            lightIntensity: 78
        }

        ListElement {
            label: 'Bedroom'
            icon: '\uf236'
            size: 20
            temperature: 24
            humidity: 40
            heating: 40
            water: 304
            lightIntensity: 25
        }

        ListElement {
            label: 'Laundry'
            icon: '\uf553'
            size: 18
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
            anchors.margins: pageMargin
            opacity: root.introProgress
            transform: Translate { y: (1 - root.introProgress) * 8 }

            LeftPane { id: leftItem }

            MiddlePane { id: middleItem }

            RightPane { id: rightItem }
        }
    }

    function commafy(value) {
        return value.toLocaleString()
    }
}
