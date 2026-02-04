import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    // Expose dialog for external access from dashboard
    property alias addPersonnelDialog: addPersonnelDialog

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

    // Personnel data from database
    property var personnelList: Database.getPersonnel()

    function refreshPersonnel() {
        personnelList = Database.getPersonnel()
    }

    function getStatusColor(status) {
        switch(status) {
            case "On Site": return successColor
            case "Off Site": return warningColor
            case "On Leave": return infoColor
            case "Off Duty": return textSecondary
            default: return textSecondary
        }
    }

    function getRoleIcon(role) {
        switch(role) {
            case "Project Manager": return "\uf201"   // chart-line (management)
            case "Surveyor": return "\uf14e"          // compass
            case "Assistant": return "\uf4fc"          // user-tie
            case "Instrument Man": return "\uf1e5"    // binoculars
            case "Chainman": return "\uf546"          // ruler-combined
            case "Driver": return "\uf1b9"            // car
            default: return "\uf007"                   // user
        }
    }

    Rectangle {
        anchors.fill: parent
        color: bgColor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                spacing: 4

                Text {
                    text: "Personnel Management"
                    font.family: "Codec Pro"
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    color: textPrimary
                }

                Text {
                    text: "Manage team members and their assignments"
                    font.family: "Codec Pro"
                    font.pixelSize: 11
                    color: textSecondary
                }
            }

            Item { Layout.fillWidth: true }

            // Add Personnel Button
            Rectangle {
                width: addBtnRow.width + 24
                height: 32
                radius: 6
                color: addBtnMa.containsMouse ? Qt.darker(accentColor, 1.1) : accentColor
                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    id: addBtnRow
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "\uf067"
                        font.family: "Font Awesome 5 Pro Solid"
                        font.pixelSize: 10
                        color: "white"
                    }

                    Text {
                        text: "Add Personnel"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: "white"
                    }
                }

                MouseArea {
                    id: addBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: addPersonnelDialog.open()
                }
            }
        }

        // Stats Cards
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
                    { label: "Total", count: personnelList.length, icon: "\uf0c0", color: accentColor },        // users
                    { label: "On Site", count: personnelList.filter(p => p.status === "On Site").length, icon: "\uf3c5", color: successColor },   // map-marker-alt
                    { label: "Off Site", count: personnelList.filter(p => p.status === "Off Site").length, icon: "\uf015", color: warningColor }, // home
                    { label: "On Leave", count: personnelList.filter(p => p.status === "On Leave").length, icon: "\uf5a0", color: infoColor }    // calendar-alt
                ]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
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
                            color: Qt.lighter(modelData.color, 1.85)

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
                                text: modelData.count
                                font.family: "Codec Pro"
                                font.pixelSize: 16
                                font.weight: Font.Medium
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

        // Personnel Table
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
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
                anchors.fill: parent
                spacing: 0

                // Table Header
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: bgColor
                    radius: 6

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 0

                        Text {
                            Layout.preferredWidth: 250
                            text: "Name"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: textSecondary
                        }

                        Text {
                            Layout.preferredWidth: 150
                            text: "Role"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: textSecondary
                        }

                        Text {
                            Layout.preferredWidth: 120
                            text: "Status"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: textSecondary
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Contact"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: textSecondary
                        }

                        Text {
                            Layout.preferredWidth: 80
                            text: "Actions"
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: textSecondary
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // Table Content
                ListView {
                    id: personnelListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: personnelList

                    delegate: Rectangle {
                        width: personnelListView.width
                        height: 46
                        color: delegateMa.containsMouse ? Qt.lighter(bgColor, 1.02) : cardColor

                        MouseArea {
                            id: delegateMa
                            anchors.fill: parent
                            hoverEnabled: true
                        }

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
                            spacing: 0

                            // Name with avatar
                            RowLayout {
                                Layout.preferredWidth: 250
                                spacing: 12

                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: Qt.lighter(accentColor, 1.7)

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.name ? modelData.name.charAt(0).toUpperCase() : "?"
                                        font.family: "Codec Pro"
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: accentColor
                                    }
                                }

                                Text {
                                    text: modelData.name || "Unknown"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 11
                                    color: textPrimary
                                }
                            }

                            // Role
                            RowLayout {
                                Layout.preferredWidth: 150
                                spacing: 6

                                Text {
                                    text: getRoleIcon(modelData.role)
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 9
                                    color: textSecondary
                                }

                                Text {
                                    text: modelData.role || "—"
                                    font.family: "Codec Pro"
                                    font.pixelSize: 11
                                    color: textSecondary
                                }
                            }

                            // Status badge
                            Item {
                                Layout.preferredWidth: 120

                                Rectangle {
                                    width: statusText.width + 16
                                height: 20
                                radius: 10
                                    color: Qt.lighter(getStatusColor(modelData.status), 1.85)

                                    Text {
                                        id: statusText
                                        anchors.centerIn: parent
                                        text: modelData.status || "Off Duty"
                                        font.family: "Codec Pro"
                                        font.pixelSize: 9
                                        color: getStatusColor(modelData.status)
                                    }
                                }
                            }

                            // Contact
                            Text {
                                Layout.fillWidth: true
                                text: modelData.phone || modelData.email || "—"
                                font.family: "Codec Pro"
                                font.pixelSize: 10
                                color: textSecondary
                                elide: Text.ElideRight
                            }

                            // Actions
                            RowLayout {
                                Layout.preferredWidth: 80
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 8

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 6
                                    color: editMa.containsMouse ? bgColor : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf304"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 9
                                        color: accentColor
                                    }

                                    MouseArea {
                                        id: editMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            editPersonnelId = modelData.id
                                            editNameField.text = modelData.name || ""
                                            editRoleCombo.currentIndex = editRoleCombo.find(modelData.role) >= 0 ? editRoleCombo.find(modelData.role) : 0
                                            editStatusCombo.currentIndex = editStatusCombo.find(modelData.status) >= 0 ? editStatusCombo.find(modelData.status) : 0
                                            editPhoneField.text = modelData.phone || ""
                                            editPersonnelDialog.open()
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 6
                                    color: deleteMa.containsMouse ? Qt.lighter(dangerColor, 1.9) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf1f8"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 9
                                        color: dangerColor
                                    }

                                    MouseArea {
                                        id: deleteMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            deletePersonnelId = modelData.id
                                            deletePersonnelName = modelData.name
                                            deleteConfirmDialog.open()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Empty state
                    Rectangle {
                        anchors.centerIn: parent
                        visible: personnelList.length === 0
                        width: 260
                        height: 160

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 16

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 56
                                height: 56
                                radius: 28
                                color: bgColor

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf0c0"
                                    font.family: "Font Awesome 5 Pro Solid"
                                    font.pixelSize: 18
                                    color: textSecondary
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "No personnel added yet"
                                font.family: "Codec Pro"
                                font.pixelSize: 12
                                color: textPrimary
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Add team members to get started"
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

    // Add Personnel Dialog
    property int editPersonnelId: -1
    property int deletePersonnelId: -1
    property string deletePersonnelName: ""

    Dialog {
        id: addPersonnelDialog
        anchors.centerIn: parent
        width: 360
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

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "Add Personnel"
                font.family: "Codec Pro"
                font.pixelSize: 12
                font.weight: Font.Medium
                color: textPrimary
            }
        }

        contentItem: ScrollView {
            id: scrollView
            clip: true
            contentWidth: -1
            implicitHeight: Math.min(dialogCol.implicitHeight, 500)

            ColumnLayout {
                id: dialogCol
                width: scrollView.availableWidth
                spacing: 14

                Item { height: 4 }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 4

                    Text { text: "Full Name *"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }

                    TextField {
                        id: addNameField
                        Layout.fillWidth: true
                Layout.preferredHeight: 32
                        placeholderText: "Enter full name"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: textPrimary
                        placeholderTextColor: textSecondary
                        leftPadding: 10

                        background: Rectangle {
                            color: "#ffffff"
                            radius: 4
                            border.color: addNameField.activeFocus ? accentColor : borderColor
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 4

                    Text { text: "Role *"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }

                    ComboBox {
                        id: addRoleCombo
                        Layout.fillWidth: true
                Layout.preferredHeight: 32
                        model: ["Surveyor", "Assistant", "Instrument Man", "Chainman", "Driver", "Project Manager"]
                        font.family: "Codec Pro"
                        font.pixelSize: 11

                        contentItem: Text {
                            leftPadding: 10
                            text: addRoleCombo.displayText
                            font: addRoleCombo.font
                            color: textPrimary
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: "#ffffff"
                            radius: 4
                            border.color: borderColor
                        }

                        delegate: ItemDelegate {
                            width: addRoleCombo.width
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
                            highlighted: addRoleCombo.highlightedIndex === index
                        }

                        popup: Popup {
                            parent: Overlay.overlay
                            x: addRoleCombo.mapToItem(null, 0, 0).x
                            y: addRoleCombo.mapToItem(null, 0, addRoleCombo.height).y
                            width: addRoleCombo.width
                            implicitHeight: contentItem.implicitHeight > 200 ? 200 : contentItem.implicitHeight
                            padding: 1

                            contentItem: ListView {
                                clip: true
                                implicitHeight: contentHeight
                                model: addRoleCombo.popup.visible ? addRoleCombo.delegateModel : null
                                currentIndex: addRoleCombo.highlightedIndex
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

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 4

                    Text { text: "Status"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }

                    ComboBox {
                        id: addStatusCombo
                        Layout.fillWidth: true
                Layout.preferredHeight: 32
                        model: ["Off Duty", "On Site", "Off Site", "On Leave"]
                        font.family: "Codec Pro"
                        font.pixelSize: 11

                        contentItem: Text {
                            leftPadding: 10
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

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 4

                    Text { text: "Phone"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }

                    TextField {
                        id: addPhoneField
                        Layout.fillWidth: true
                Layout.preferredHeight: 32
                        placeholderText: "+263 7X XXX XXXX"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: textPrimary
                        placeholderTextColor: textSecondary
                        leftPadding: 10

                        background: Rectangle {
                            color: "#ffffff"
                            radius: 4
                            border.color: addPhoneField.activeFocus ? accentColor : borderColor
                        }
                    }
                }

                Item { height: 4 }
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

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 80
                    height: 30
                    radius: 6
                    color: "transparent"
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
                        onClicked: addPersonnelDialog.close()
                    }
                }

                Rectangle {
                    width: 80
                    height: 34
                    radius: 4
                    color: addNameField.text.length > 0 ? accentColor : Qt.lighter(accentColor, 1.4)

                    Text {
                        anchors.centerIn: parent
                        text: "Add"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: addNameField.text.length > 0 ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: {
                            if (addNameField.text.length > 0) {
                                Database.addPersonnel(
                                    addNameField.text,
                                    addRoleCombo.currentText,
                                    addStatusCombo.currentText,
                                    addPhoneField.text
                                )
                                addNameField.text = ""
                                addPhoneField.text = ""
                                addRoleCombo.currentIndex = 0
                                addStatusCombo.currentIndex = 0
                                addPersonnelDialog.close()
                                refreshPersonnel()
                            }
                        }
                    }
                }
            }
        }
    }

    // Edit Personnel Dialog
    Dialog {
        id: editPersonnelDialog
        anchors.centerIn: parent
        width: 360
        modal: true
        padding: 0
        clip: false

        Overlay.modal: Rectangle { color: "#80000000" }

        background: Rectangle {
            color: cardColor
            radius: 4
            border.color: borderColor
        }

        header: Rectangle {
            color: cardColor
            height: 50
            radius: 4

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: borderColor
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "Edit Personnel"
                font.family: "Codec Pro"
                font.pixelSize: 12
                font.weight: Font.Medium
                color: textPrimary
            }
        }

        contentItem: ColumnLayout {
            spacing: 14

            Item { height: 4 }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 4

                Text { text: "Full Name *"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }

                TextField {
                    id: editNameField
                    Layout.fillWidth: true
                Layout.preferredHeight: 32
                    font.family: "Codec Pro"
                    font.pixelSize: 11
                    color: textPrimary
                    leftPadding: 10

                    background: Rectangle {
                        color: "#ffffff"
                        radius: 4
                        border.color: editNameField.activeFocus ? accentColor : borderColor
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 4

                Text { text: "Role *"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }

                ComboBox {
                    id: editRoleCombo
                    Layout.fillWidth: true
                Layout.preferredHeight: 32
                    model: ["Surveyor", "Assistant", "Instrument Man", "Chainman", "Driver", "Project Manager"]
                    font.family: "Codec Pro"
                    font.pixelSize: 11

                    contentItem: Text {
                        leftPadding: 10
                        text: editRoleCombo.displayText
                        font: editRoleCombo.font
                        color: textPrimary
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: "#ffffff"
                        radius: 4
                        border.color: borderColor
                    }

                    delegate: ItemDelegate {
                        width: editRoleCombo.width
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
                        highlighted: editRoleCombo.highlightedIndex === index
                    }

                    popup: Popup {
                        y: editRoleCombo.height
                        width: editRoleCombo.width
                        implicitHeight: contentItem.implicitHeight > 200 ? 200 : contentItem.implicitHeight
                        padding: 1
                        z: 1000

                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: editRoleCombo.popup.visible ? editRoleCombo.delegateModel : null
                            currentIndex: editRoleCombo.highlightedIndex
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

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 4

                Text { text: "Status"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }

                ComboBox {
                    id: editStatusCombo
                    Layout.fillWidth: true
                Layout.preferredHeight: 32
                    model: ["Off Duty", "On Site", "Off Site", "On Leave"]
                    font.family: "Codec Pro"
                    font.pixelSize: 11

                    contentItem: Text {
                        leftPadding: 10
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

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 4

                Text { text: "Phone"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }

                TextField {
                    id: editPhoneField
                    Layout.fillWidth: true
                Layout.preferredHeight: 32
                    font.family: "Codec Pro"
                    font.pixelSize: 11
                    color: textPrimary
                    leftPadding: 10

                    background: Rectangle {
                        color: "#ffffff"
                        radius: 4
                        border.color: editPhoneField.activeFocus ? accentColor : borderColor
                    }
                }
            }

            Item { height: 4 }
        }

        footer: Rectangle {
            color: bgColor
            height: 56
            radius: 4

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

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 80
                    height: 34
                    radius: 4
                    color: "transparent"
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
                        onClicked: editPersonnelDialog.close()
                    }
                }

                Rectangle {
                    width: 80
                    height: 34
                    radius: 4
                    color: accentColor

                    Text {
                        anchors.centerIn: parent
                        text: "Save"
                        font.family: "Codec Pro"
                        font.pixelSize: 11
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Database.updatePersonnel(
                                editPersonnelId,
                                editNameField.text,
                                editRoleCombo.currentText,
                                editStatusCombo.currentText,
                                editPhoneField.text
                            )
                            editPersonnelDialog.close()
                            refreshPersonnel()
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
            radius: 4
            border.color: borderColor
        }

        contentItem: ColumnLayout {
            spacing: 16

            Item { height: 8 }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 52
                height: 52
                radius: 26
                color: Qt.lighter(dangerColor, 1.85)

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
                text: "Delete Personnel?"
                font.family: "Codec Pro"
                font.pixelSize: 12
                font.weight: Font.Medium
                color: textPrimary
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                text: "Are you sure you want to remove\n\"" + deletePersonnelName + "\"?"
                font.family: "Codec Pro"
                font.pixelSize: 11
                color: textSecondary
                horizontalAlignment: Text.AlignHCenter
            }

            Item { height: 4 }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 16
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 6
                    color: "transparent"
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
                    Layout.fillWidth: true
                    height: 32
                    radius: 6
                    color: dangerColor

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
                            Database.deletePersonnel(deletePersonnelId)
                            deleteConfirmDialog.close()
                            refreshPersonnel()
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: refreshPersonnel()
}
