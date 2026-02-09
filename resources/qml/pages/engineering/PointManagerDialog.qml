import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: "Point Manager"
    width: 600
    height: 400
    modal: true
    standardButtons: Dialog.Close

    property var pointsModel: null // ListModel passed from parent
    signal zoomToRequested(var point)
    signal deleteRequested(int index)

    contentItem: ColumnLayout {
        spacing: 10

        // Header
        RowLayout {
            spacing: 10
            Text { text: "Name"; font.bold: true; Layout.preferredWidth: 80; color: "#E8E8E8" }
            Text { text: "Code"; font.bold: true; Layout.preferredWidth: 80; color: "#E8E8E8" }
            Text { text: "X"; font.bold: true; Layout.preferredWidth: 100; color: "#E8E8E8" }
            Text { text: "Y"; font.bold: true; Layout.preferredWidth: 100; color: "#E8E8E8" }
            Text { text: "Z"; font.bold: true; Layout.preferredWidth: 80; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }
        }

        Rectangle { height: 1; Layout.fillWidth: true; color: "#3A3A3A" }

        // List
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: pointsModel
            delegate: Rectangle {
                width: listView.width
                height: 36
                color: index % 2 === 0 ? "transparent" : "#2A2A2A"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    anchors.rightMargin: 5
                    spacing: 10

                    Text { text: model.name || ""; color: "#B0B0B0"; Layout.preferredWidth: 80; elide: Text.ElideRight }
                    Text { text: model.code || ""; color: "#B0B0B0"; Layout.preferredWidth: 80; elide: Text.ElideRight }
                    Text { text: model.x.toFixed(3); color: "#B0B0B0"; Layout.preferredWidth: 100 }
                    Text { text: model.y.toFixed(3); color: "#B0B0B0"; Layout.preferredWidth: 100 }
                    Text { text: model.z.toFixed(3); color: "#B0B0B0"; Layout.preferredWidth: 80 }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Zoom"
                        flat: true
                        Layout.preferredHeight: 24
                        onClicked: root.zoomToRequested(model)
                        background: Rectangle { color: "transparent"; border.color: "#5B7C99"; radius: 2 }
                        contentItem: Text { text: parent.text; color: "#5B7C99"; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }

                    Button {
                        text: "\uf2ed" // Trash icon
                        font.family: "Font Awesome 5 Pro Solid"
                        flat: true
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: 24
                        onClicked: root.deleteRequested(index)
                        background: Rectangle { color: "transparent" }
                        contentItem: Text { text: parent.text; color: "#FF5555"; font.family: parent.font.family; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
        }
    }

    background: Rectangle {
        color: "#1E1E1E"
        border.color: "#3A3A3A"
        radius: 4
    }
}
