import QtQuick
import QtQuick.Controls
import QtQuick3D
import QtQuick3D.Helpers

Window {
    id: dtmViewer
    width: 1200
    height: 900
    visible: true
    title: "3D DTM Viewer - Professional Terrain Visualization"
    color: "#1E1E1E"

    property var meshData: null

    // Load mesh data
    function loadMesh(data) {
        meshData = data
        console.log("3D Viewer: Loading", data.vertexCount, "vertices,", data.indexCount / 3, "triangles")
        terrainModel.visible = true
    }

    View3D {
        id: view3D
        anchors.fill: parent

        environment: SceneEnvironment {
            clearColor: "#1A1A2E"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        // Camera
        PerspectiveCamera {
            id: camera
            position: Qt.vector3d(0, 80, 120)
            eulerRotation.x: -35
            clipNear: 1
            clipFar: 5000
        }

        // Main light
        DirectionalLight {
            eulerRotation.x: -50
            eulerRotation.y: 30
            brightness: 1.5
            color: Qt.rgba(1, 1, 0.9, 1)
            castsShadow: false
        }

        // Fill light
        DirectionalLight {
            eulerRotation.x: 20
            eulerRotation.y: -60
            brightness: 0.6
            color: Qt.rgba(0.7, 0.8, 1, 1)
        }

        // Ambient
        DirectionalLight {
            eulerRotation.x: 90
            brightness: 0.4
            color: Qt.rgba(1, 1, 1, 1)
        }

        // Terrain Model with custom geometry
        Model {
            id: terrainModel
            visible: false

            geometry: GeometryView {
                id: geometryView
            }

            materials: [
                PrincipledMaterial {
                    lighting: PrincipledMaterial.FragmentLighting
                    baseColor: "#60A0D0"
                    metalness: 0.1
                    roughness: 0.8
                }
            ]
        }

        // Camera controller
        OrbitCameraController {
            origin: terrainModel
            camera: camera
            panEnabled: true
            xSpeed: 0.5
            ySpeed: 0.5
        }
    }

    // Custom geometry
    Component {
        id: geometryComponent

        GeometryView {
            property var meshData: dtmViewer.meshData
        }
    }

    // Geometry defined inline
    GeometryView {
        id: geometryView

        Component.onCompleted: {
            if (dtmViewer.meshData) {
                updateMesh()
            }
        }

        Connections {
            target: dtmViewer
            function onMeshDataChanged() {
                if (dtmViewer.meshData) {
                    geometryView.updateMesh()
                }
            }
        }

        function updateMesh() {
            var data =dtmViewer.meshData
            if (!data) return

            // Note: Qt Quick 3D requires C++ Geometry implementation
            // For now this is a placeholder - mesh won't render without C++ backend
            console.log("Geometry update requested for", data.vertexCount, "vertices")
        }
    }

    // Controls panel
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 15
        width: 220
        height: controlsColumn.height + 30
        color: "#2A2A3E"
        radius: 8
        border.color: "#3A3A4E"
        border.width: 2
        opacity: 0.95

        Column {
            id: controlsColumn
            anchors.centerIn: parent
            spacing: 12
            width: parent.width - 30

            Text {
                text: "🎮 Camera Controls"
                color: "#FFFFFF"
                font.bold: true
                font.pixelSize: 13
            }

            Text {
                text: "• Left Mouse: Orbit\n• Right Mouse: Pan\n• Wheel: Zoom"
                color: "#C0C0D0"
                font.pixelSize: 10
                lineHeight: 1.4
            }

            Rectangle { width: parent.width; height: 2; color: "#404050"; radius: 1 }

            Button {
                text: "↺ Reset View"
                width: parent.width
                onClicked: {
                    camera.position = Qt.vector3d(0, 80, 120)
                    camera.eulerRotation = Qt.vector3d(-35, 0, 0)
                }
            }

            Button {
                text: "⬇ Top View"
                width: parent.width
                onClicked: {
                    camera.position = Qt.vector3d(0, 150, 0)
                    camera.eulerRotation = Qt.vector3d(-90, 0, 0)
                }
            }
        }
    }

    // Info panel
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 15
        width: infoText.width + 30
        height: infoText.height + 24
        color: "#2A2A3E"
        radius: 8
        border.color: "#3A3A4E"
        border.width: 2
        opacity: 0.95

        Column {
            id: infoText
            anchors.centerIn: parent
            spacing: 6

            Text {
                color: "#FFFFFF"
                font.pixelSize: 11
                font.bold: true
                text: meshData ? "📊 Terrain Statistics" : "⏳ Loading..."
            }

            Text {
                color: "#C0C0D0"
                font.pixelSize: 10
                text: meshData ?
                      "Vertices: " + meshData.vertexCount + " | Triangles: " + (meshData.indexCount / 3) :
                      ""
                visible: meshData !== null
            }

            Text {
                color: "#C0C0D0"
                font.pixelSize: 10
                text: meshData && meshData.minElev !== undefined ?
                      "Elevation: " + meshData.minElev.toFixed(2) + "m - " + meshData.maxElev.toFixed(2) + "m" :
                      ""
                visible: meshData !== null && meshData.minElev !== undefined
            }
        }
    }

    // Warning message
    Rectangle {
        anchors.centerIn: parent
        width: warningText.width + 40
        height: warningText.height + 40
        color: "#3A3A4E"
        radius: 10
        border.color: "#FFA500"
        border.width: 3
        visible: terrainModel.visible && meshData !== null

        Text {
            id: warningText
            anchors.centerIn: parent
            color: "#FFD700"
            font.pixelSize: 14
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            text: "⚠️ Custom Geometry Requires C++ Implementation\n\n" +
                  "Qt Quick 3D needs a C++ QQuick3DGeometry class\n" +
                  "to render custom mesh data.\n\n" +
                  "Use 'Export DTM as 3D Mesh (OBJ)' menu option\n" +
                  "and open with MeshLab for full 3D visualization."
        }
    }
}
