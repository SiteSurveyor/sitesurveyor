import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs

Item {
    id: root

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

    // Settings properties (would be persisted via QSettings in production)
    property int distanceUnit: 0  // 0=Meters, 1=Feet, 2=US Survey Feet
    property int angleUnit: 0  // 0=Degrees, 1=Gradians, 2=DMS
    property int areaUnit: 0  // 0=Square Meters, 1=Hectares, 2=Acres
    property int decimalPlaces: 3



    function showSuccess(msg) {
        statusMessage.text = msg
        statusMessage.color = successColor
        statusMessage.visible = true
        hideTimer.restart()
    }

    function showError(msg) {
        statusMessage.text = msg
        statusMessage.color = dangerColor
        statusMessage.visible = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 3000
        onTriggered: statusMessage.visible = false
    }

    // Force Default Database
    Connections {
        target: root
        function onVisibleChanged() {
            if (root.visible && Database.databasePath !== Database.defaultDatabasePath()) {
                Database.changeDatabasePath(Database.defaultDatabasePath())
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: bgColor
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 20
        contentHeight: contentColumn.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: contentColumn
            width: parent.width
            spacing: 16

            // Page Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "Settings"
                    font.family: "Codec Pro"
                    font.pixelSize: 16
                    font.bold: true
                    color: textPrimary
                }

                Item { Layout.fillWidth: true }

                // Status message
                Text {
                    id: statusMessage
                    visible: false
                    font.family: "Codec Pro"
                    font.pixelSize: 10
                }
            }



            // ============ UNITS SETTINGS ============
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: unitsColumn.height + 40
                color: cardColor
                radius: 6
                border.color: borderColor

                ColumnLayout {
                    id: unitsColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 16

                    RowLayout {
                        spacing: 10
                        Rectangle {
                            width: 32; height: 32; radius: 6
                            color: Qt.lighter(infoColor, 1.85)
                            Text { anchors.centerIn: parent; text: "\uf545"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 11; color: infoColor }
                        }
                        Text { text: "Units & Precision"; font.family: "Codec Pro"; font.pixelSize: 12; font.bold: true; color: textPrimary }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 30
                        rowSpacing: 16

                        // Distance Units
                        ColumnLayout {
                            spacing: 6
                            Text { text: "Distance Units"; font.family: "Codec Pro"; font.pixelSize: 10; color: textSecondary }
                            ComboBox {
                                id: distanceCombo
                                Layout.preferredWidth: 200
                                model: ["Meters (m)", "Feet (ft)", "US Survey Feet"]
                                currentIndex: distanceUnit
                                onCurrentIndexChanged: distanceUnit = currentIndex

                                background: Rectangle {
                                    radius: 4
                                    color: "#f8f9fa"
                                    border.color: borderColor
                                }

                                contentItem: Text {
                                    leftPadding: 10
                                    text: distanceCombo.displayText
                                    font.family: "Codec Pro"
                                    font.pixelSize: 10
                                    color: textPrimary
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        // Angle Units
                        ColumnLayout {
                            spacing: 6
                            Text { text: "Angle Units"; font.family: "Codec Pro"; font.pixelSize: 10; color: textSecondary }
                            ComboBox {
                                id: angleCombo
                                Layout.preferredWidth: 200
                                model: ["Decimal Degrees (°)", "Gradians (gon)", "DMS (° ' \")"]
                                currentIndex: angleUnit
                                onCurrentIndexChanged: angleUnit = currentIndex

                                background: Rectangle {
                                    radius: 4
                                    color: "#f8f9fa"
                                    border.color: borderColor
                                }

                                contentItem: Text {
                                    leftPadding: 10
                                    text: angleCombo.displayText
                                    font.family: "Codec Pro"
                                    font.pixelSize: 10
                                    color: textPrimary
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        // Area Units
                        ColumnLayout {
                            spacing: 6
                            Text { text: "Area Units"; font.family: "Codec Pro"; font.pixelSize: 10; color: textSecondary }
                            ComboBox {
                                id: areaCombo
                                Layout.preferredWidth: 200
                                model: ["Square Meters (m²)", "Hectares (ha)", "Acres (ac)"]
                                currentIndex: areaUnit
                                onCurrentIndexChanged: areaUnit = currentIndex

                                background: Rectangle {
                                    radius: 4
                                    color: "#f8f9fa"
                                    border.color: borderColor
                                }

                                contentItem: Text {
                                    leftPadding: 10
                                    text: areaCombo.displayText
                                    font.family: "Codec Pro"
                                    font.pixelSize: 10
                                    color: textPrimary
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        // Decimal Places
                        ColumnLayout {
                            spacing: 6
                            Text { text: "Decimal Places"; font.family: "Codec Pro"; font.pixelSize: 10; color: textSecondary }
                            RowLayout {
                                spacing: 10
                                SpinBox {
                                    id: decimalSpin
                                    from: 0
                                    to: 8
                                    value: decimalPlaces
                                    onValueChanged: decimalPlaces = value

                                    background: Rectangle {
                                        radius: 4
                                        color: "#f8f9fa"
                                        border.color: borderColor
                                    }

                                    contentItem: Text {
                                        text: decimalSpin.value
                                        font.family: "Codec Pro"
                                        font.pixelSize: 10
                                        color: textPrimary
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                Text { text: "e.g. " + (123.456789).toFixed(decimalPlaces); font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary }
                            }
                        }
                    }
                }
            }



            // ============ DATABASE INFO ============
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: infoColumn.height + 40
                color: cardColor
                radius: 6
                border.color: borderColor

                ColumnLayout {
                    id: infoColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 16

                    RowLayout {
                        spacing: 10
                        Rectangle {
                            width: 32; height: 32; radius: 6
                            color: Qt.lighter(infoColor, 1.85)
                            Text { anchors.centerIn: parent; text: "\uf05a"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 11; color: infoColor }
                        }
                        Text { text: "Current Session"; font.family: "Codec Pro"; font.pixelSize: 12; font.bold: true; color: textPrimary }
                    }

                    GridLayout {
                        columns: 2
                        columnSpacing: 20
                        rowSpacing: 8

                        Text { text: "Connection:"; font.family: "Codec Pro"; font.pixelSize: 10; color: textSecondary }
                        Text { text: Database.isConnected ? "Connected" : "Disconnected"; font.family: "Codec Pro"; font.pixelSize: 10; font.weight: Font.Medium; color: Database.isConnected ? successColor : dangerColor }

                        Text { text: "Project:"; font.family: "Codec Pro"; font.pixelSize: 10; color: textSecondary }
                        Text { text: Database.currentProject || "None"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }

                        Text { text: "Discipline:"; font.family: "Codec Pro"; font.pixelSize: 10; color: textSecondary }
                        Text { text: Database.currentDiscipline || "None"; font.family: "Codec Pro"; font.pixelSize: 10; color: textPrimary }
                    }
                }
            }

            // ============ CLOUD SYNC ============
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: cloudColumn.height + 40
                color: cardColor
                radius: 6
                border.color: borderColor

                ColumnLayout {
                    id: cloudColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 16

                    RowLayout {
                        spacing: 10
                        Rectangle {
                            width: 32; height: 32; radius: 6
                            color: Qt.lighter(accentColor, 1.85)
                            Text { anchors.centerIn: parent; text: "\uf0c2"; font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 11; color: accentColor }
                        }
                        Text { text: "Cloud Sync"; font.family: "Codec Pro"; font.pixelSize: 12; font.bold: true; color: textPrimary }
                        Item { Layout.fillWidth: true }
                        // Status indicator
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: CloudSync.isSyncing ? warningColor : (CloudSync.isConfigured ? successColor : textSecondary)
                        }
                        Text {
                            text: CloudSync.isSyncing ? "Syncing..." : (CloudSync.isConfigured ? "Connected" : "Not configured")
                            font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary
                        }
                    }

                    // API Key configuration
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: !CloudSync.isConfigured

                        Text { text: "Bucket ID"; font.family: "Codec Pro"; font.pixelSize: 10; color: textSecondary }
                        TextField {
                            id: bucketIdField
                            Layout.fillWidth: true
                            placeholderText: "Enter your Appwrite Bucket ID (default: projects)"
                            text: CloudSync.bucketId
                            font.family: "Codec Pro"
                            font.pixelSize: 10
                            background: Rectangle {
                                radius: 4
                                color: "#f8f9fa"
                                border.color: borderColor
                            }
                        }

                        Text { text: "API Key"; font.family: "Codec Pro"; font.pixelSize: 10; color: textSecondary }
                        RowLayout {
                            spacing: 10
                            TextField {
                                id: apiKeyField
                                Layout.fillWidth: true
                                placeholderText: "Enter your Appwrite API key"
                                echoMode: TextInput.Password
                                font.family: "Codec Pro"
                                font.pixelSize: 10
                                background: Rectangle {
                                    radius: 4
                                    color: "#f8f9fa"
                                    border.color: borderColor
                                }
                            }
                            Button {
                                text: "Connect"
                                font.family: "Codec Pro"
                                font.pixelSize: 10
                                onClicked: {
                                    if (bucketIdField.text !== "") CloudSync.setBucketId(bucketIdField.text)
                                    CloudSync.setApiKey(apiKeyField.text)
                                    apiKeyField.text = ""
                                    showSuccess("Connected to cloud")
                                }
                                background: Rectangle {
                                    radius: 4
                                    color: accentColor
                                }
                                contentItem: Text {
                                    text: parent.text
                                    font: parent.font
                                    color: "white"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }

                    // Upload section (visible when configured)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: CloudSync.isConfigured

                        RowLayout {
                            spacing: 10
                            Button {
                                id: uploadBtn
                                text: CloudSync.isUploading ? "Uploading..." : "\uf0ee  Backup to Cloud"
                                enabled: !CloudSync.isSyncing
                                font.family: "Codec Pro"
                                font.pixelSize: 10
                                onClicked: CloudSync.uploadDatabase()
                                background: Rectangle {
                                    radius: 4
                                    color: uploadBtn.enabled ? accentColor : Qt.lighter(accentColor, 1.5)
                                }
                                contentItem: Text {
                                    text: parent.text
                                    font: parent.font
                                    color: "white"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            Button {
                                id: refreshBtn
                                text: "\uf021  Refresh"
                                enabled: !CloudSync.isSyncing
                                font.family: "Codec Pro"
                                font.pixelSize: 10
                                onClicked: CloudSync.listCloudBackups()
                                background: Rectangle {
                                    radius: 4
                                    color: "#f8f9fa"
                                    border.color: borderColor
                                }
                                contentItem: Text {
                                    text: parent.text
                                    font: parent.font
                                    color: textPrimary
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            Button {
                                text: "Disconnect"
                                font.family: "Codec Pro"
                                font.pixelSize: 10
                                onClicked: {
                                    CloudSync.setApiKey("")
                                    showSuccess("Disconnected")
                                }
                                background: Rectangle {
                                    radius: 4
                                    color: "#fff0f0"
                                    border.color: dangerColor
                                }
                                contentItem: Text {
                                    text: parent.text
                                    font: parent.font
                                    color: dangerColor
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                visible: CloudSync.lastSyncTime !== ""
                                text: "Last sync: " + CloudSync.lastSyncTime
                                font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary
                            }
                        }

                        // Progress bar
                        Rectangle {
                            Layout.fillWidth: true
                            height: 4
                            radius: 2
                            color: "#e5e7eb"
                            visible: CloudSync.isSyncing

                            Rectangle {
                                width: parent.width * (CloudSync.isUploading ? CloudSync.uploadProgress : CloudSync.downloadProgress)
                                height: parent.height
                                radius: 2
                                color: accentColor
                                Behavior on width { NumberAnimation { duration: 200 } }
                            }
                        }

                        // Error message
                        Text {
                            visible: CloudSync.errorMessage !== ""
                            text: CloudSync.errorMessage
                            font.family: "Codec Pro"; font.pixelSize: 9; color: dangerColor
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    // Cloud backups list
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: CloudSync.isConfigured

                        Text { text: "Cloud Backups"; font.family: "Codec Pro"; font.pixelSize: 10; font.bold: true; color: textPrimary }

                        ListView {
                            id: cloudBackupsList
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(contentHeight, 150)
                            clip: true
                            spacing: 4

                            model: ListModel { id: backupsModel }

                            delegate: Rectangle {
                                width: cloudBackupsList.width
                                height: 36
                                radius: 4
                                color: "#f8f9fa"
                                border.color: borderColor

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 10

                                    Text {
                                        text: model.name
                                        font.family: "Codec Pro"; font.pixelSize: 9; color: textPrimary
                                        Layout.fillWidth: true
                                        elide: Text.ElideMiddle
                                    }
                                    Text {
                                        text: (model.size / 1024).toFixed(1) + " KB"
                                        font.family: "Codec Pro"; font.pixelSize: 8; color: textSecondary
                                    }
                                    Text {
                                        text: "\uf019"
                                        font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 10; color: accentColor
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: CloudSync.downloadBackup(model.fileId, model.name)
                                        }
                                    }
                                    Text {
                                        text: "\uf2ed"
                                        font.family: "Font Awesome 5 Pro Solid"; font.pixelSize: 10; color: dangerColor
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: CloudSync.deleteCloudBackup(model.fileId)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: backupsModel.count === 0
                            text: "No cloud backups found. Click 'Refresh' to check."
                            font.family: "Codec Pro"; font.pixelSize: 9; color: textSecondary
                            font.italic: true
                        }
                    }

                    // Connections to update the list
                    Connections {
                        target: CloudSync
                        function onBackupsListReady(backups) {
                            backupsModel.clear()
                            for (var i = 0; i < backups.length; i++) {
                                backupsModel.append({
                                    fileId: backups[i].id,
                                    name: backups[i].name,
                                    size: backups[i].size,
                                    created: backups[i].created
                                })
                            }
                        }
                        function onUploadComplete(fileId) {
                            showSuccess("Backup uploaded successfully")
                            CloudSync.listCloudBackups()
                        }
                        function onDownloadComplete(localPath) {
                            showSuccess("Database restored from cloud backup")
                        }
                        function onDeleteComplete(fileId) {
                            showSuccess("Cloud backup deleted")
                            CloudSync.listCloudBackups()
                        }
                        function onSyncError(error) {
                            showError(error)
                        }
                    }

                    Component.onCompleted: {
                        if (CloudSync.isConfigured) {
                            CloudSync.listCloudBackups()
                        }
                    }
                }
            }

            // Spacer
            Item { Layout.preferredHeight: 20 }
        }
    }
}
