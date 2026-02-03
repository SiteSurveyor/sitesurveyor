import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtLocation
import QtPositioning

Item {
    id: mapPicker

    // Gweru, Zimbabwe as default center
    property real defaultLatitude: -19.4500
    property real defaultLongitude: 29.8167

    // Selected coordinates (in WGS84)
    property real selectedLatitude: defaultLatitude
    property real selectedLongitude: defaultLongitude

    // Lo29 converted coordinates
    property real selectedY: 0  // Easting
    property real selectedX: 0  // Northing

    // Whether a location has been picked
    property bool locationPicked: false

    // Theme colors
    property color accentColor: "#321fdb"
    property color textPrimary: "#3c4b64"
    property color textSecondary: "#8a93a2"
    property color borderColor: "#d8dbe0"

    signal locationSelected(real lat, real lon, real y, real x)

    // Simple Lo29 approximation for Zimbabwe (Gauss-Kruger projection)
    function convertToLo29(lat, lon) {
        var a = 6378137.0;
        var f = 1/298.257223563;
        var k0 = 1.0;
        var lon0 = 29.0;

        var latRad = lat * Math.PI / 180.0;
        var lonRad = lon * Math.PI / 180.0;
        var lon0Rad = lon0 * Math.PI / 180.0;

        var e2 = 2*f - f*f;
        var N = a / Math.sqrt(1 - e2 * Math.sin(latRad) * Math.sin(latRad));
        var T = Math.tan(latRad) * Math.tan(latRad);
        var C = e2 / (1 - e2) * Math.cos(latRad) * Math.cos(latRad);
        var A = (lonRad - lon0Rad) * Math.cos(latRad);

        var M = a * ((1 - e2/4 - 3*e2*e2/64 - 5*e2*e2*e2/256) * latRad
                   - (3*e2/8 + 3*e2*e2/32 + 45*e2*e2*e2/1024) * Math.sin(2*latRad)
                   + (15*e2*e2/256 + 45*e2*e2*e2/1024) * Math.sin(4*latRad)
                   - (35*e2*e2*e2/3072) * Math.sin(6*latRad));

        var easting = k0 * N * (A + (1-T+C)*A*A*A/6 + (5-18*T+T*T+72*C-58*(e2/(1-e2)))*A*A*A*A*A/120);
        var northing = k0 * (M + N * Math.tan(latRad) * (A*A/2 + (5-T+9*C+4*C*C)*A*A*A*A/24));

        return {
            y: easting,
            x: -northing
        };
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Map container
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 150
            radius: 6
            border.color: borderColor
            border.width: 1
            clip: true

            Plugin {
                id: mapPlugin
                name: "osm"
                PluginParameter {
                    name: "osm.mapping.custom.host"
                    value: "https://tile.openstreetmap.org/"
                }
            }

            MapView {
                id: mapView
                anchors.fill: parent

                map.plugin: mapPlugin
                map.center: QtPositioning.coordinate(defaultLatitude, defaultLongitude)
                map.zoomLevel: 12
                map.minimumZoomLevel: 3
                map.maximumZoomLevel: 18

                // Marker for selected location
                MapQuickItem {
                    id: marker
                    visible: locationPicked
                    anchorPoint.x: markerIcon.width / 2
                    anchorPoint.y: markerIcon.height
                    coordinate: QtPositioning.coordinate(selectedLatitude, selectedLongitude)

                    sourceItem: Item {
                        width: 40
                        height: 50

                        Rectangle {
                            id: markerIcon
                            width: 32
                            height: 32
                            radius: 16
                            color: accentColor
                            anchors.horizontalCenter: parent.horizontalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "\uf3c5"
                                font.family: "Font Awesome 5 Pro Solid"
                                font.pixelSize: 16
                                color: "white"
                            }
                        }

                        Canvas {
                            width: 16
                            height: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: markerIcon.bottom
                            anchors.topMargin: -2

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.fillStyle = accentColor;
                                ctx.beginPath();
                                ctx.moveTo(0, 0);
                                ctx.lineTo(8, 10);
                                ctx.lineTo(16, 0);
                                ctx.closePath();
                                ctx.fill();
                            }
                        }
                    }
                }

                // Handle tap to place marker
                TapHandler {
                    onTapped: function(eventPoint) {
                        var coord = mapView.map.toCoordinate(eventPoint.position);
                        selectedLatitude = coord.latitude;
                        selectedLongitude = coord.longitude;
                        locationPicked = true;

                        var lo29 = convertToLo29(coord.latitude, coord.longitude);
                        selectedY = lo29.y;
                        selectedX = lo29.x;

                        locationSelected(selectedLatitude, selectedLongitude, selectedY, selectedX);
                    }
                }
            }

            // Zoom controls
            Column {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                spacing: 2
                z: 10

                Button {
                    width: 28
                    height: 28
                    text: "+"
                    font.pixelSize: 14
                    font.bold: true
                    padding: 0

                    background: Rectangle {
                        color: parent.pressed ? "#e0e0e0" : (parent.hovered ? "#f0f0f0" : "white")
                        radius: 3
                        border.color: borderColor
                    }

                    onClicked: mapView.map.zoomLevel = Math.min(mapView.map.zoomLevel + 1, 18)
                }

                Button {
                    width: 28
                    height: 28
                    text: "−"
                    font.pixelSize: 14
                    font.bold: true
                    padding: 0

                    background: Rectangle {
                        color: parent.pressed ? "#e0e0e0" : (parent.hovered ? "#f0f0f0" : "white")
                        radius: 3
                        border.color: borderColor
                    }

                    onClicked: mapView.map.zoomLevel = Math.max(mapView.map.zoomLevel - 1, 3)
                }

                Button {
                    width: 28
                    height: 28
                    padding: 0

                    Text {
                        anchors.centerIn: parent
                        text: "\uf015"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 10
                        color: textPrimary
                    }

                    background: Rectangle {
                        color: parent.pressed ? "#e0e0e0" : (parent.hovered ? "#f0f0f0" : "white")
                        radius: 3
                        border.color: borderColor
                    }

                    onClicked: {
                        mapView.map.center = QtPositioning.coordinate(defaultLatitude, defaultLongitude);
                        mapView.map.zoomLevel = 12;
                    }
                }
            }

            // Instructions overlay
            Rectangle {
                visible: !locationPicked
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 28
                color: Qt.rgba(0, 0, 0, 0.7)
                z: 10

                Text {
                    anchors.centerIn: parent
                    text: "Click on map to select location"
                    font.family: "Codec Pro"
                    font.pixelSize: 11
                    color: "white"
                }
            }
        }

        // Selected coordinates display - compact
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: locationPicked ? 50 : 32
            color: locationPicked ? Qt.lighter(accentColor, 1.9) : "#f8f9fa"
            radius: 4
            border.color: locationPicked ? accentColor : borderColor
            border.width: 1

            RowLayout {
                id: coordsLayout
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: locationPicked ? accentColor : textSecondary

                    Text {
                        anchors.centerIn: parent
                        text: "\uf3c5"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 10
                        color: "white"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: locationPicked ? "Y: " + selectedY.toFixed(1) + " | X: " + selectedX.toFixed(1) : "No Location"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: locationPicked ? textPrimary : textSecondary
                    }

                    Text {
                        visible: locationPicked
                        text: selectedLatitude.toFixed(5) + "°, " + selectedLongitude.toFixed(5) + "°"
                        font.family: "Codec Pro"
                        font.pixelSize: 10
                        color: textSecondary
                    }
                }

                Button {
                    visible: locationPicked
                    width: 24
                    height: 24
                    padding: 0

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 10
                        color: textSecondary
                    }

                    background: Rectangle {
                        color: parent.pressed ? "#e0e0e0" : (parent.hovered ? "#f0f0f0" : "transparent")
                        radius: 12
                    }

                    onClicked: {
                        locationPicked = false;
                        selectedLatitude = defaultLatitude;
                        selectedLongitude = defaultLongitude;
                        selectedY = 0;
                        selectedX = 0;
                        mapView.map.center = QtPositioning.coordinate(defaultLatitude, defaultLongitude);
                    }
                }
            }
        }
    }
}
