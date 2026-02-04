import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    // Expose dialog for external access from dashboard
    property alias addInstrumentDialog: addInstrumentDialog

    // Compact light theme
    property color bgColor: "#f6f7f9"
    property color cardColor: "#ffffff"
    property color accentColor: "#2563eb"
    property color textPrimary: "#111827"
    property color textSecondary: "#6b7280"
    property color borderColor: "#d0d7de"
    property color successColor: "#16a34a"
    property color warningColor: "#f59e0b"
    property color dangerColor: "#dc2626"
    property color infoColor: "#0ea5e9"

    // Card styling
    property color glassBg: cardColor
    property color glassBorder: borderColor
    property int glassRadius: 6

    // Instruments data from database
    property var instrumentsList: Database.getInstruments()

    function refreshInstruments() {
        instrumentsList = Database.getInstruments()
    }

    function getStatusColor(status) {
        switch(status) {
            case "Available": return successColor
            case "In Use": return infoColor
            case "Calibration": return warningColor
            case "Maintenance": return dangerColor
            case "Out of Service": return textSecondary
            default: return textSecondary
        }
    }

    function getTypeIcon(type) {
        switch(type) {
            case "Total Station": return "\uf05b"   // crosshairs
            case "GNSS Receiver": return "\uf7bf"   // satellite
            case "Level": return "\uf545"           // ruler-horizontal
            case "Theodolite": return "\uf1e5"      // binoculars
            case "Laser Scanner": return "\uf390"   // cube (3d)
            case "Drone": return "\uf5b0"           // helicopter/plane
            case "Measuring Tape": return "\uf546"  // ruler-combined
            case "Tripod": return "\uf0b2"          // arrows-alt
            case "Prism": return "\uf5c3"           // gem
            default: return "\uf0ad"                // wrench
        }
    }

    Rectangle {
        anchors.fill: parent
        color: bgColor
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 16
        contentHeight: contentColumn.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: contentColumn
            width: parent.width
            spacing: 16

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "Instruments"
                    font.family: "Codec Pro"
                    font.pixelSize: 16
                    font.bold: true
                    color: textPrimary
                }

                Item { Layout.fillWidth: true }

                // Search Box
                Rectangle {
                    Layout.preferredWidth: 250
                    height: 32
                    color: cardColor
                    radius: 6
                    border.color: borderColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: "\uf002"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 10
                            color: textSecondary
                        }

                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            placeholderText: "Search instruments..."
                            font.family: "Codec Pro"
                            font.pixelSize: 11
                            color: textPrimary
                            placeholderTextColor: textSecondary
                            background: Rectangle { color: "transparent" }
                        }
                    }
                }

                // Status Filter
                Rectangle {
                    Layout.preferredWidth: 150
                    height: 32
                    color: cardColor
                    radius: 6
                    border.color: borderColor

                    ComboBox {
                        id: statusFilter
                        anchors.fill: parent
                        model: ["All Status", "Available", "In Use", "Calibration", "Maintenance", "Out of Service"]
                        font.family: "Codec Pro"
                        font.pixelSize: 11

                        contentItem: Text {
                            leftPadding: 12
                            text: statusFilter.displayText
                            font: statusFilter.font
                            color: textPrimary
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: "transparent"
                        }

                        delegate: ItemDelegate {
                            width: statusFilter.width
                            height: 36
                            contentItem: Text {
                                text: modelData
                                font.family: "Codec Pro"
                                font.pixelSize: 11
                                color: textPrimary
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 8
                            }
                            background: Rectangle {
                                color: highlighted ? Qt.lighter(accentColor, 1.8) : cardColor
                            }
                            highlighted: statusFilter.highlightedIndex === index
                        }

                        popup: Popup {
                            y: statusFilter.height
                            width: statusFilter.width
                            implicitHeight: contentItem.implicitHeight > 200 ? 200 : contentItem.implicitHeight
                            padding: 1
                            z: 1000

                            contentItem: ListView {
                                clip: true
                                implicitHeight: contentHeight
                                model: statusFilter.popup.visible ? statusFilter.delegateModel : null
                                currentIndex: statusFilter.highlightedIndex
                                ScrollIndicator.vertical: ScrollIndicator { }
                            }

                            background: Rectangle {
                                border.color: borderColor
                                radius: 4
                                color: cardColor
                            }
                        }
                    }
                }

                // Add Button
                Rectangle {
                    Layout.preferredWidth: 140
                    height: 32
                    color: accentColor
                    radius: 6
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "\uf067"
                            font.family: "Font Awesome 5 Pro Solid"
                            font.pixelSize: 10
                            color: "white"
                        }

                        Text {
                            text: "Add Instrument"
                            font.family: "Codec Pro"
                            font.pixelSize: 11
                            color: "white"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addInstrumentDialog.open()
                    }
                }
            }

            // Stats Cards Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                // Entry Animation
                opacity: 0
                transform: Translate {
                    y: 20
                    NumberAnimation on y { to: 0; duration: 500; easing.type: Easing.OutCubic }
                }
                NumberAnimation on opacity { to: 1; duration: 500; easing.type: Easing.OutCubic }

                Repeater {
                    model: [
                        { label: "Total", value: instrumentsList.length, color: accentColor, icon: "\uf1e5" },         // binoculars
                        { label: "Available", value: instrumentsList.filter(i => i.status === "Available").length, color: successColor, icon: "\uf058" },  // check-circle
                        { label: "In Use", value: instrumentsList.filter(i => i.status === "In Use").length, color: infoColor, icon: "\uf0c0" },          // users
                        { label: "Maintenance", value: instrumentsList.filter(i => i.status === "Maintenance" || i.status === "Calibration").length, color: warningColor, icon: "\uf0ad" }  // wrench
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        height: 64
                        color: glassBg
                        radius: glassRadius
                        border.color: glassBorder

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Rectangle {
                                width: 36
                                height: 36
                                radius: 18
                                color: Qt.lighter(modelData.color, 1.7)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 13
                                    color: modelData.color
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.value
                                    font.family: "Codec Pro"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: textPrimary
                                }

                                Text {
                                    text: modelData.label
                                    font.family: "Codec Pro"
                                    font.pixelSize: 10
                                    color: textSecondary
                                }
                            }
                        }
                    }
                }
            }

            // Instruments Grid
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: instrumentsGrid.height + 40
                color: glassBg
                radius: glassRadius
                border.color: glassBorder

                // Entry Animation
                opacity: 0
                transform: Translate {
                    y: 30
                    SequentialAnimation on y {
                        PauseAnimation { duration: 150 }
                        NumberAnimation { to: 0; duration: 600; easing.type: Easing.OutCubic }
                    }
                }
                SequentialAnimation on opacity {
                    PauseAnimation { duration: 150 }
                    NumberAnimation { to: 1; duration: 600; easing.type: Easing.OutCubic }
                }

                ColumnLayout {
                    id: instrumentsGrid
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 12

                    // Table Header
                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        color: bgColor
                        radius: 6

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 16

                            Text {
                                Layout.preferredWidth: 200
                                text: "Name"
                                font.family: "Codec Pro"
                                font.pixelSize: 10
                                font.bold: true
                                color: textSecondary
                            }

                            Text {
                                Layout.preferredWidth: 150
                                text: "Type"
                                font.family: "Codec Pro"
                                font.pixelSize: 10
                                font.bold: true
                                color: textSecondary
                            }

                            Text {
                                Layout.preferredWidth: 150
                                text: "Serial Number"
                                font.family: "Codec Pro"
                                font.pixelSize: 10
                                font.bold: true
                                color: textSecondary
                            }

                            Text {
                                Layout.preferredWidth: 100
                                text: "Status"
                                font.family: "Codec Pro"
                                font.pixelSize: 10
                                font.bold: true
                                color: textSecondary
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Actions"
                                font.family: "Codec Pro"
                                font.pixelSize: 10
                                font.bold: true
                                color: textSecondary
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    // Table Rows
                    Repeater {
                        model: {
                            var filtered = instrumentsList
                            if (searchField.text.length > 0) {
                                var search = searchField.text.toLowerCase()
                                filtered = filtered.filter(i =>
                                    i.name.toLowerCase().includes(search) ||
                                    i.type.toLowerCase().includes(search) ||
                                    i.serial.toLowerCase().includes(search)
                                )
                            }
                            if (statusFilter.currentIndex > 0) {
                                var status = statusFilter.currentText
                                filtered = filtered.filter(i => i.status === status)
                            }
                            return filtered
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 46
                            color: index % 2 === 0 ? "transparent" : Qt.lighter(bgColor, 1.02)
                            radius: 6

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 16

                                // Name with icon
                                RowLayout {
                                    Layout.preferredWidth: 200
                                    spacing: 12

                                    Rectangle {
                                        width: 30
                                        height: 30
                                        radius: 15
                                        color: Qt.lighter(accentColor, 1.7)

                                        Text {
                                            anchors.centerIn: parent
                                            text: getTypeIcon(modelData.type)
                                            font.family: "Font Awesome 5 Pro Solid"
                                            font.pixelSize: 11
                                            color: accentColor
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        font.family: "Codec Pro"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: textPrimary
                                        elide: Text.ElideRight
                                    }
                                }

                                // Type
                                Text {
                                    Layout.preferredWidth: 150
                                    text: modelData.type
                                    font.family: "Codec Pro"
                                    font.pixelSize: 11
                                    color: textSecondary
                                    elide: Text.ElideRight
                                }

                                // Serial
                                Text {
                                    Layout.preferredWidth: 150
                                    text: modelData.serial || "-"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 11
                                    color: textSecondary
                                    elide: Text.ElideRight
                                }

                                // Status Badge
                                Rectangle {
                                    Layout.preferredWidth: 100
                                    width: statusText.width + 16
                                    height: 20
                                    radius: 10
                                    color: Qt.lighter(getStatusColor(modelData.status), 1.7)

                                    Text {
                                        id: statusText
                                        anchors.centerIn: parent
                                        text: modelData.status
                                        font.family: "Codec Pro"
                                        font.pixelSize: 9
                                        color: getStatusColor(modelData.status)
                                    }
                                }

                                // Actions
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignRight
                                    spacing: 8

                                    // Edit Button
                                    Rectangle {
                                        width: 26
                                        height: 26
                                        radius: 6
                                        color: mouseAreaEdit.containsMouse ? Qt.lighter(accentColor, 1.8) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf044"
                                            font.family: "Font Awesome 5 Pro Solid"
                                            font.pixelSize: 11
                                            color: accentColor
                                        }

                                        MouseArea {
                                            id: mouseAreaEdit
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onClicked: {
                                                editInstrumentId = modelData.id
                                                editNameField.text = modelData.name
                                                editTypeCombo.currentIndex = editTypeCombo.model.indexOf(modelData.type)
                                                editSerialField.text = modelData.serial || ""
                                                editStatusCombo.currentIndex = editStatusCombo.model.indexOf(modelData.status)
                                                editInstrumentDialog.open()
                                            }
                                        }
                                    }

                                    // Delete Button
                                    Rectangle {
                                        width: 26
                                        height: 26
                                        radius: 6
                                        color: mouseAreaDelete.containsMouse ? Qt.lighter(dangerColor, 1.8) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf1f8"
                                            font.family: "Font Awesome 5 Pro Solid"
                                            font.pixelSize: 11
                                            color: dangerColor
                                        }

                                        MouseArea {
                                            id: mouseAreaDelete
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onClicked: {
                                                deleteInstrumentId = modelData.id
                                                deleteInstrumentName = modelData.name
                                                deleteConfirmDialog.open()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Empty State
                    Rectangle {
                        Layout.fillWidth: true
                        height: 160
                        visible: instrumentsList.length === 0
                        color: "transparent"

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 16

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 64
                                height: 64
                                radius: 32
                                color: Qt.lighter(accentColor, 1.8)

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf0ad"
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 16
                                    color: accentColor
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "No instruments found"
                                font.family: "Codec Pro"
                                font.pixelSize: 12
                                font.bold: true
                                color: textPrimary
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Add instruments to get started"
                                font.family: "Codec Pro"
                                font.pixelSize: 11
                                color: textSecondary
                            }
                        }
                    }
                }
            }
        }
    }

    // Properties for dialogs
    property int editInstrumentId: -1
    property int deleteInstrumentId: -1
    property string deleteInstrumentName: ""

    // Add Instrument Dialog
    Dialog {
        id: addInstrumentDialog
        anchors.centerIn: parent
        width: 380
        modal: true
        padding: 0
        clip: false

        Overlay.modal: Rectangle { color: "#80000000" }

        background: Rectangle {
            color: cardColor
            radius: 6
            border.color: borderColor
        }

        header: Rectangle {
            color: cardColor
            height: 44
            radius: 6

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: borderColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Text {
                    text: "Add New Instrument"
                    font.family: "Codec Pro"
                    font.pixelSize: 12
                    font.bold: true
                    color: textPrimary
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "\uf00d"
                    font.family: "Font Awesome 5 Pro Solid"
                    font.pixelSize: 12
                    color: textSecondary

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addInstrumentDialog.close()
                    }
                }
            }
        }

        contentItem: ScrollView {
            id: scrollView
            clip: true
            contentWidth: -1
            implicitHeight: Math.min(dialogCol.implicitHeight, 550)

            ColumnLayout {
                id: dialogCol
                width: scrollView.availableWidth
                spacing: 12

            Item { height: 4 }

            // Name Field
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 6

                Text { text: "Instrument Name *"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }

                TextField {
                    id: addNameField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    placeholderText: "e.g., Leica TS16"
                    font.family: "Codec Pro"
                    font.pixelSize: 11
                    color: textPrimary
                    placeholderTextColor: textSecondary
                    leftPadding: 12

                    background: Rectangle {
                        color: "#ffffff"
                        radius: 4
                        border.color: addNameField.activeFocus ? accentColor : borderColor
                    }
                }
            }

            // Type Field
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 6

                Text { text: "Type *"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }

                ComboBox {
                    id: addTypeCombo
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    model: ["Total Station", "GNSS Receiver", "Level", "Theodolite", "Laser Scanner", "Drone", "Measuring Tape", "Tripod", "Prism", "Other"]
                    font.family: "Codec Pro"
                    font.pixelSize: 11

                    contentItem: Text {
                        leftPadding: 12
                        text: addTypeCombo.displayText
                        font: addTypeCombo.font
                        color: textPrimary
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: "#ffffff"
                        radius: 4
                        border.color: borderColor
                    }

                    delegate: ItemDelegate {
                        width: addTypeCombo.width
                        height: 32
                        contentItem: Text {
                            text: modelData
                            font.family: "Codec Pro"
                            font.pixelSize: 11
                            color: textPrimary
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 8
                        }
                        background: Rectangle {
                            color: highlighted ? Qt.lighter(accentColor, 1.8) : cardColor
                        }
                        highlighted: addTypeCombo.highlightedIndex === index
                    }

                    popup: Popup {
                        parent: Overlay.overlay
                        x: addTypeCombo.mapToItem(null, 0, 0).x
                        y: addTypeCombo.mapToItem(null, 0, addTypeCombo.height).y
                        width: addTypeCombo.width
                        implicitHeight: contentItem.implicitHeight > 200 ? 200 : contentItem.implicitHeight
                        padding: 1
                        z: 1000

                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: addTypeCombo.popup.visible ? addTypeCombo.delegateModel : null
                            currentIndex: addTypeCombo.highlightedIndex
                            ScrollIndicator.vertical: ScrollIndicator { }
                        }

                        background: Rectangle {
                            border.color: borderColor
                            radius: 4
                            color: cardColor
                        }
                    }
                }
            }

            // Serial Number Field
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                spacing: 6

                Text { text: "Serial Number"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }

                TextField {
                    id: addSerialField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    placeholderText: "e.g., SN-2024-001"
                    font.family: "Codec Pro"
                    font.pixelSize: 11
                    color: textPrimary
                    placeholderTextColor: textSecondary
                    leftPadding: 12

                    background: Rectangle {
                        color: "#ffffff"
                        radius: 4
                        border.color: addSerialField.activeFocus ? accentColor : borderColor
                    }
                }
            }

            // Status Field
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                spacing: 6

                Text { text: "Status"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }

                ComboBox {
                    id: addStatusCombo
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    model: ["Available", "In Use", "Calibration", "Maintenance", "Out of Service"]
                    font.family: "Codec Pro"
                    font.pixelSize: 11

                    contentItem: Text {
                        leftPadding: 12
                        text: addStatusCombo.displayText
                        font: addStatusCombo.font
                        color: textPrimary
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: "#ffffff"
                        radius: 4
                        border.color: borderColor
                    }

                    delegate: ItemDelegate {
                        width: addStatusCombo.width
                        height: 32
                        contentItem: Text {
                            text: modelData
                            font.family: "Codec Pro"
                            font.pixelSize: 11
                            color: textPrimary
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 8
                        }
                        background: Rectangle {
                            color: highlighted ? Qt.lighter(accentColor, 1.8) : cardColor
                        }
                        highlighted: addStatusCombo.highlightedIndex === index
                    }

                    popup: Popup {
                        parent: Overlay.overlay
                        x: addStatusCombo.mapToItem(null, 0, 0).x
                        y: addStatusCombo.mapToItem(null, 0, addStatusCombo.height).y
                        width: addStatusCombo.width
                        implicitHeight: contentItem.implicitHeight > 200 ? 200 : contentItem.implicitHeight
                        padding: 1
                        z: 1000

                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: addStatusCombo.popup.visible ? addStatusCombo.delegateModel : null
                            currentIndex: addStatusCombo.highlightedIndex
                            ScrollIndicator.vertical: ScrollIndicator { }
                        }

                        background: Rectangle {
                            border.color: borderColor
                            radius: 4
                            color: cardColor
                        }
                    }
                }
            }

            Item { height: 8 }
        }
    }

        footer: Rectangle {
            color: bgColor
            height: 48
            radius: 6

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: borderColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 90
                    height: 30
                    color: cardColor
                    radius: 6
                    border.color: borderColor

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addInstrumentDialog.close()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 120
                    height: 30
                    radius: 6
                    color: addNameField.text.length > 0 ? accentColor : Qt.lighter(accentColor, 1.4)

                    Text {
                        anchors.centerIn: parent
                        text: "Add Instrument"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: addNameField.text.length > 0 ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: {
                            if (addNameField.text.length > 0) {
                                Database.addInstrument(
                                    addNameField.text,
                                    addTypeCombo.currentText,
                                    addSerialField.text,
                                    addStatusCombo.currentText
                                )
                                addNameField.text = ""
                                addSerialField.text = ""
                                addTypeCombo.currentIndex = 0
                                addStatusCombo.currentIndex = 0
                                addInstrumentDialog.close()
                                refreshInstruments()
                            }
                        }
                    }
                }
            }
        }
    }

    // Edit Instrument Dialog
    Dialog {
        id: editInstrumentDialog
        anchors.centerIn: parent
        width: 380
        modal: true
        padding: 0
        clip: false

        Overlay.modal: Rectangle { color: "#80000000" }

        background: Rectangle {
            color: cardColor
            radius: 6
            border.color: borderColor
        }

        header: Rectangle {
            color: cardColor
            height: 44
            radius: 6

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: borderColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Text {
                    text: "Edit Instrument"
                    font.family: "Codec Pro"
                    font.pixelSize: 12
                    font.bold: true
                    color: textPrimary
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "\uf00d"
                    font.family: "Font Awesome 5 Pro Solid"
                    font.pixelSize: 12
                    color: textSecondary

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editInstrumentDialog.close()
                    }
                }
            }
        }

        contentItem: ColumnLayout {
            spacing: 12

            Item { height: 4 }

            // Name Field
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                spacing: 6

                Text { text: "Instrument Name *"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }

                TextField {
                    id: editNameField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    font.family: "Codec Pro"
                    font.pixelSize: 11
                    color: textPrimary
                    leftPadding: 12

                    background: Rectangle {
                        color: "#ffffff"
                        radius: 4
                        border.color: editNameField.activeFocus ? accentColor : borderColor
                    }
                }
            }

            // Type Field
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                spacing: 6

                Text { text: "Type *"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }

                ComboBox {
                    id: editTypeCombo
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    model: ["Total Station", "GNSS Receiver", "Level", "Theodolite", "Laser Scanner", "Drone", "Measuring Tape", "Tripod", "Prism", "Other"]
                    font.family: "Codec Pro"
                    font.pixelSize: 11

                    contentItem: Text {
                        leftPadding: 12
                        text: editTypeCombo.displayText
                        font: editTypeCombo.font
                        color: textPrimary
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: "#ffffff"
                        radius: 4
                        border.color: borderColor
                    }

                    delegate: ItemDelegate {
                        width: editTypeCombo.width
                        height: 32
                        contentItem: Text {
                            text: modelData
                            font.family: "Codec Pro"
                            font.pixelSize: 11
                            color: textPrimary
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 8
                        }
                        background: Rectangle {
                            color: highlighted ? Qt.lighter(accentColor, 1.8) : cardColor
                        }
                        highlighted: editTypeCombo.highlightedIndex === index
                    }

                    popup: Popup {
                        y: editTypeCombo.height
                        width: editTypeCombo.width
                        implicitHeight: contentItem.implicitHeight > 200 ? 200 : contentItem.implicitHeight
                        padding: 1
                        z: 1000

                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: editTypeCombo.popup.visible ? editTypeCombo.delegateModel : null
                            currentIndex: editTypeCombo.highlightedIndex
                            ScrollIndicator.vertical: ScrollIndicator { }
                        }

                        background: Rectangle {
                            border.color: borderColor
                            radius: 4
                            color: cardColor
                        }
                    }
                }
            }

            // Serial Number Field
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                spacing: 6

                Text { text: "Serial Number"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }

                TextField {
                    id: editSerialField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    font.family: "Codec Pro"
                    font.pixelSize: 11
                    color: textPrimary
                    leftPadding: 12

                    background: Rectangle {
                        color: "#ffffff"
                        radius: 4
                        border.color: editSerialField.activeFocus ? accentColor : borderColor
                    }
                }
            }

            // Status Field
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                spacing: 6

                Text { text: "Status"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }

                ComboBox {
                    id: editStatusCombo
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    model: ["Available", "In Use", "Calibration", "Maintenance", "Out of Service"]
                    font.family: "Codec Pro"
                    font.pixelSize: 11

                    contentItem: Text {
                        leftPadding: 12
                        text: editStatusCombo.displayText
                        font: editStatusCombo.font
                        color: textPrimary
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: "#ffffff"
                        radius: 4
                        border.color: borderColor
                    }

                    delegate: ItemDelegate {
                        width: editStatusCombo.width
                        height: 32
                        contentItem: Text {
                            text: modelData
                            font.family: "Codec Pro"
                            font.pixelSize: 11
                            color: textPrimary
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 8
                        }
                        background: Rectangle {
                            color: highlighted ? Qt.lighter(accentColor, 1.8) : cardColor
                        }
                        highlighted: editStatusCombo.highlightedIndex === index
                    }

                    popup: Popup {
                        y: editStatusCombo.height
                        width: editStatusCombo.width
                        implicitHeight: contentItem.implicitHeight > 200 ? 200 : contentItem.implicitHeight
                        padding: 1
                        z: 1000

                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: editStatusCombo.popup.visible ? editStatusCombo.delegateModel : null
                            currentIndex: editStatusCombo.highlightedIndex
                            ScrollIndicator.vertical: ScrollIndicator { }
                        }

                        background: Rectangle {
                            border.color: borderColor
                            radius: 4
                            color: cardColor
                        }
                    }
                }
            }

            Item { height: 8 }
        }

        footer: Rectangle {
            color: bgColor
            height: 48
            radius: 6

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: borderColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 90
                    height: 30
                    color: cardColor
                    radius: 6
                    border.color: borderColor

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editInstrumentDialog.close()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 120
                    height: 30
                    radius: 6
                    color: accentColor

                    Text {
                        anchors.centerIn: parent
                        text: "Save Changes"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Database.updateInstrument(
                                editInstrumentId,
                                editNameField.text,
                                editTypeCombo.currentText,
                                editSerialField.text,
                                editStatusCombo.currentText
                            )
                            editInstrumentDialog.close()
                            refreshInstruments()
                        }
                    }
                }
            }
        }
    }

    // Delete Confirmation Dialog
    Dialog {
        id: deleteConfirmDialog
        anchors.centerIn: parent
        width: 320
        modal: true
        padding: 0

        Overlay.modal: Rectangle { color: "#80000000" }

        background: Rectangle {
            color: cardColor
            radius: 6
            border.color: borderColor
        }

        contentItem: ColumnLayout {
            spacing: 20

            Item { height: 8 }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 52
                height: 52
                radius: 26
                color: Qt.lighter(dangerColor, 1.7)

                Text {
                    anchors.centerIn: parent
                    text: "\uf1f8"
                    font.family: "Font Awesome 5 Pro Solid"
                    font.pixelSize: 16
                    color: dangerColor
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Delete Instrument?"
                font.family: "Codec Pro"
                font.pixelSize: 13
                font.bold: true
                color: textPrimary
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: 30
                Layout.rightMargin: 30
                text: "Are you sure you want to delete \"" + deleteInstrumentName + "\"? This action cannot be undone."
                font.family: "Codec Pro"
                font.pixelSize: 11
                color: textSecondary
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 20
                spacing: 12

                Rectangle {
                    width: 100
                    height: 32
                    color: cardColor
                    radius: 6
                    border.color: borderColor

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: deleteConfirmDialog.close()
                    }
                }

                Rectangle {
                    width: 100
                    height: 38
                    color: dangerColor
                    radius: 6

                    Text {
                        anchors.centerIn: parent
                        text: "Delete"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Database.deleteInstrument(deleteInstrumentId)
                            deleteConfirmDialog.close()
                            refreshInstruments()
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: refreshInstruments()
}
