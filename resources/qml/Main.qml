import QtQuick
import QtQuick.Controls

Window {
    width: 1024
    height: 768
    visible: true
    title: qsTr("SiteSurveyor 2.0")

    property string bgGradientStart: '#ffffff'
    property string bgGradientStop: '#f0f0f0'
    property string textColor: '#333333'
    property color glassyBgColor: hex_to_RGBA('#ffffff', 0.9)
    property alias fontawesomefontloader: fontawesomefontloader

    // Helper functions needed globally (passed down or used by others if needed)
    function hex_to_RGB(hex) {
        hex = hex.toString();
        var m = hex.match(/^#?([\da-f]{2})([\da-f]{2})([\da-f]{2})$/i);
        return Qt.rgba(parseInt(m[1], 16)/255.0, parseInt(m[2], 16)/255.1, parseInt(m[3], 16)/255.0, 1);
    }

    function hex_to_RGBA(hex, opacity=1) {
        hex = hex.toString();
        opacity = opacity > 1 ? 1 : opacity // Opacity should be 0 - 1
        var m = hex.match(/^#?([\da-f]{2})([\da-f]{2})([\da-f]{2})$/i);
        return Qt.rgba(parseInt(m[1], 16)/255.0, parseInt(m[2], 16)/255.1, parseInt(m[3], 16)/255.0, opacity);
    }

    FontLoader {
        id: fontawesomefontloader
        source: "qrc:/assets/fonts/fontawesome.otf"
    }

    FontLoader {
        id: codecProFontLoader
        source: "qrc:/assets/fonts/CodecPro-Regular.ttf"
    }

    // Provide global access to font name if needed, or rely on id scope
    property alias fontAwesomeName: fontawesomefontloader.name
    property alias codecProName: codecProFontLoader.name

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: "qrc:/qml/DisciplineSelectionView.qml"

        // Custom push transition
        pushEnter: Transition {
            PropertyAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 200
            }
        }
        pushExit: Transition {
            PropertyAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 200
            }
        }

        // Custom pop transition
        popEnter: Transition {
            PropertyAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 200
            }
        }
        popExit: Transition {
            PropertyAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 200
            }
        }
    }

    // Connect to the loaded item's signal if possible, or use Component on push
    Connections {
        target: stackView.currentItem
        ignoreUnknownSignals: true // Safe because target changes

        function onDisciplineSelected(name) {
            console.log("Selected discipline: " + name)
            Database.setCurrentDiscipline(name)
            stackView.push("qrc:/qml/ProjectManagementView.qml", { "discipline": name })
        }

        function onProjectSelected(projectId, projectName) {
            console.log("Selected project: " + projectName + " (ID: " + projectId + ")")
            var discipline = Database.currentDiscipline

            if (discipline === "Engineering Surveying") {
                stackView.push("qrc:/qml/pages/engineering/EngineeringDashboard.qml")
            } else if (discipline === "Mining Surveying") {
                stackView.push("qrc:/qml/DashboardView.qml", { "activeRoomLabel": "Mining" })
            } else if (discipline === "Geodetic Surveying") {
                stackView.push("qrc:/qml/DashboardView.qml", { "activeRoomLabel": "Geodetic" })
            } else if (discipline === "Cadastral Surveying") {
                stackView.push("qrc:/qml/DashboardView.qml", { "activeRoomLabel": "Cadastral" })
            } else if (discipline === "Remote Sensing") {
                stackView.push("qrc:/qml/DashboardView.qml", { "activeRoomLabel": "Remote Sensing" })
            } else if (discipline === "Topographic Surveying") {
                stackView.push("qrc:/qml/DashboardView.qml", { "activeRoomLabel": "Topographic" })
            } else {
                stackView.push("qrc:/qml/DashboardView.qml", { "activeRoomLabel": "Map" })
            }
        }

        function onBackRequested() {
            console.log("Back requested - popping stack")
            stackView.pop()
        }

        function onExitRequested() {
            console.log("Exit requested from dashboard - popping stack")
            console.log("Stack depth before pop: " + stackView.depth)
            stackView.pop()
            console.log("Stack depth after pop: " + stackView.depth)
        }
    }

    SplashScreen {
        id: splash
        anchors.fill: parent
        z: 999 // Ensure it's on top

        // When splash timeout adds up, we check if loader is ready.
        // Actually, we want to start fading out only when BOTH timeout AND loader is ready.
        property bool timeIsUp: false

        onTimeout: {
            timeIsUp = true
            checkReady()
        }

        function checkReady() {
            // Check if stackView has an item loaded
            if (timeIsUp && stackView.currentItem) {
                splashFadeOut.start()
            }
        }

        Connections {
            target: stackView
            function onCurrentItemChanged() {
                 splash.checkReady()
            }
        }

        OpacityAnimator {
            id: splashFadeOut
            target: splash
            from: 1.0
            to: 0.0
            duration: 800 // Slower fade for smoother reveal
            onFinished: splash.visible = false
        }
    }
}
