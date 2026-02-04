import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtLocation
import QtPositioning
import "components"

Item {
    id: root

    property bool sidebarCollapsed: false
    property string activeTab: "Dashboard"

    signal exitRequested()

    // Get current project details from database
    property var projectInfo: Database.currentProjectDetails()
    property string projectName: projectInfo.name || "Unknown Project"
    property string projectDescription: projectInfo.description || ""
    property real projectY: projectInfo.centerY || 0
    property real projectX: projectInfo.centerX || 0
    property int projectSrid: projectInfo.srid || 4326

    // Convert Lo29 back to approximate WGS84 for map display
    // This is a simplified inverse transformation
    function lo29ToWgs84(y, x) {
        // Approximate inverse for Lo29 (Zimbabwe)
        // Y = Easting, X = -Northing (negative because southern hemisphere)
        var a = 6378137.0;
        var f = 1/298.257223563;
        var k0 = 1.0;
        var lon0 = 29.0;

        var e2 = 2*f - f*f;

        // Approximate latitude from X (northing)
        var M = -x;  // Undo the negation
        var mu = M / (a * (1 - e2/4 - 3*e2*e2/64 - 5*e2*e2*e2/256));
        var lat = mu + (3*e2/2 - 27*e2*e2*e2/32) * Math.sin(2*mu)
                     + (21*e2*e2/16 - 55*e2*e2*e2/32) * Math.sin(4*mu);

        // Approximate longitude from Y (easting)
        var lon = lon0 + (y / (a * Math.cos(lat))) * 180 / Math.PI;
        lat = lat * 180 / Math.PI;

        return { latitude: lat, longitude: lon };
    }

    property var wgs84Coords: (projectY !== 0 || projectX !== 0) ? lo29ToWgs84(projectY, projectX) : { latitude: -19.45, longitude: 29.82 }

    // Real-time stats from database
    property var personnelList: Database.getPersonnel()
    property var instrumentsList: Database.getInstruments()
    property var surveyPoints: Database.getPointsInBounds(-90, -180, 90, 180)  // Get all points

    // Computed stats
    property int totalPersonnel: personnelList ? personnelList.length : 0
    property int onSitePersonnel: personnelList ? personnelList.filter(p => p.status === "On Site").length : 0
    property int totalInstruments: instrumentsList ? instrumentsList.length : 0
    property int availableInstruments: instrumentsList ? instrumentsList.filter(i => i.status === "Available").length : 0
    property int inUseInstruments: instrumentsList ? instrumentsList.filter(i => i.status === "In Use").length : 0
    property int totalPoints: surveyPoints ? surveyPoints.length : 0

    // Refresh data function
    function refreshDashboardData() {
        personnelList = Database.getPersonnel()
        instrumentsList = Database.getInstruments()
        surveyPoints = Database.getPointsInBounds(-90, -180, 90, 180)
        projectInfo = Database.currentProjectDetails()
    }

    // Weather data from Open-Meteo API (free, no API key required)
    property real weatherTemp: 0
    property string weatherCondition: "Loading..."
    property string weatherIcon: "\uf185"  // Default sun icon
    property real windSpeed: 0
    property string windDirection: ""
    property string lastUpdated: ""
    property bool weatherLoading: true

    // Recent Activity tracking
    property var recentActivities: ListModel {
        id: activityModel
    }

    // Add activity entry
    function addActivity(action, detail, color) {
        var now = new Date();
        var timeStr = now.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
        activityModel.insert(0, {
            action: action,
            detail: detail,
            time: timeStr,
            color: color,
            timestamp: now.getTime()
        });
        // Keep only last 10 activities
        while (activityModel.count > 10) {
            activityModel.remove(activityModel.count - 1);
        }
    }

    // Format relative time
    function getRelativeTime(timestamp) {
        var now = new Date().getTime();
        var diff = now - timestamp;
        var minutes = Math.floor(diff / 60000);
        var hours = Math.floor(diff / 3600000);
        var days = Math.floor(diff / 86400000);

        if (minutes < 1) return "Just now";
        if (minutes < 60) return minutes + " min ago";
        if (hours < 24) return hours + " hr" + (hours > 1 ? "s" : "") + " ago";
        if (days === 1) return "Yesterday";
        return days + " days ago";
    }

    // Weather code to icon and description mapping
    function getWeatherInfo(code) {
        // WMO Weather interpretation codes
        var weatherMap = {
            0: { icon: "\uf185", desc: "Clear sky" },
            1: { icon: "\uf6c4", desc: "Mainly clear" },
            2: { icon: "\uf6c4", desc: "Partly cloudy" },
            3: { icon: "\uf0c2", desc: "Overcast" },
            45: { icon: "\uf75f", desc: "Foggy" },
            48: { icon: "\uf75f", desc: "Depositing rime fog" },
            51: { icon: "\uf73d", desc: "Light drizzle" },
            53: { icon: "\uf73d", desc: "Moderate drizzle" },
            55: { icon: "\uf73d", desc: "Dense drizzle" },
            61: { icon: "\uf73d", desc: "Slight rain" },
            63: { icon: "\uf740", desc: "Moderate rain" },
            65: { icon: "\uf740", desc: "Heavy rain" },
            71: { icon: "\uf2dc", desc: "Slight snow" },
            73: { icon: "\uf2dc", desc: "Moderate snow" },
            75: { icon: "\uf2dc", desc: "Heavy snow" },
            80: { icon: "\uf740", desc: "Rain showers" },
            81: { icon: "\uf740", desc: "Moderate showers" },
            82: { icon: "\uf740", desc: "Violent showers" },
            95: { icon: "\uf76c", desc: "Thunderstorm" },
            96: { icon: "\uf76c", desc: "Thunderstorm + hail" },
            99: { icon: "\uf76c", desc: "Severe thunderstorm" }
        };
        return weatherMap[code] || { icon: "\uf185", desc: "Unknown" };
    }

    function getWindDirection(degrees) {
        var dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
        var index = Math.round(degrees / 45) % 8;
        return dirs[index];
    }

    function fetchWeather() {
        var xhr = new XMLHttpRequest();
        var lat = wgs84Coords.latitude;
        var lon = wgs84Coords.longitude;
        var url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat +
                  "&longitude=" + lon +
                  "&current=temperature_2m,weather_code,wind_speed_10m,wind_direction_10m" +
                  "&timezone=auto";

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                weatherLoading = false;
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText);
                        var current = data.current;
                        weatherTemp = current.temperature_2m;
                        var weatherInfo = getWeatherInfo(current.weather_code);
                        weatherCondition = weatherInfo.desc;
                        weatherIcon = weatherInfo.icon;
                        windSpeed = current.wind_speed_10m;
                        windDirection = getWindDirection(current.wind_direction_10m);

                        var now = new Date();
                        lastUpdated = now.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
                        console.log("Weather updated:", weatherTemp + "°C", weatherCondition);
                    } catch (e) {
                        console.log("Weather parse error:", e);
                        weatherCondition = "Error";
                    }
                } else {
                    console.log("Weather fetch failed:", xhr.status);
                    weatherCondition = "Offline";
                }
            }
        };

        xhr.open("GET", url);
        xhr.send();
    }

    // Fetch weather on load and every 10 minutes
    Component.onCompleted: {
        fetchWeather()
        refreshDashboardData()
        // Add initial activity
        addActivity("Dashboard opened", projectName, accentColor)
    }

    Timer {
        interval: 600000  // 10 minutes
        running: true
        repeat: true
        onTriggered: fetchWeather()
    }

    // Connect to database signals to refresh data
    Connections {
        target: Database
        function onPersonnelChanged() { personnelList = Database.getPersonnel() }
        function onInstrumentsChanged() { instrumentsList = Database.getInstruments() }
        function onPointsChanged() { surveyPoints = Database.getPointsInBounds(-90, -180, 90, 180) }
        function onProjectChanged() { projectInfo = Database.currentProjectDetails() }
    }

    // Compact light theme
    property color bgColor: "#f6f7f9"
    property color cardColor: "#ffffff"
    property color borderColor: "#d0d7de"
    property color textPrimary: "#111827"
    property color textSecondary: "#6b7280"
    property color accentColor: "#2563eb"
    property color successColor: "#16a34a"
    property color warningColor: "#f59e0b"
    property color dangerColor: "#dc2626"
    property color infoColor: "#0ea5e9"
    property color sidebarColor: cardColor
    property color headerColor: cardColor

    // Card styling
    property color glassBg: cardColor
    property color glassBorder: borderColor
    property int glassRadius: 6

    // Responsive breakpoints - based on root width to avoid feedback loop
    property real contentWidth: root.width
    property bool isCompact: contentWidth < 800
    property bool isMedium: contentWidth >= 800 && contentWidth < 1200
    property bool isWide: contentWidth >= 1200

    Rectangle {
        id: bg
        anchors.fill: parent
        color: bgColor
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Sidebar
        SideBar {
            id: sidebar
            collapsed: root.sidebarCollapsed || root.isCompact
            currentTab: root.activeTab
            Layout.fillHeight: true
            bgColor: root.bgColor
            cardColor: root.cardColor
            borderColor: root.borderColor
            textPrimary: root.textPrimary
            textSecondary: root.textSecondary
            accentColor: root.accentColor
            onTabSelected: (name) => { root.activeTab = name }
        }

        // Main Content Column
        ColumnLayout {
            id: mainContent
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Top Header
            Header {
                id: header
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                title: root.activeTab
                bgColor: root.bgColor
                cardColor: root.cardColor
                borderColor: root.borderColor
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                accentColor: root.accentColor
                dangerColor: root.dangerColor
                onToggleSidebar: root.sidebarCollapsed = !root.sidebarCollapsed
                onExitRequested: {
                    console.log("Header exit signal received in Dashboard")
                    root.exitRequested()
                }
            }

            // Content Pages Stack
            StackLayout {
                id: pageStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.activeTab === "Personnel" ? 1 :
                              root.activeTab === "Instruments" ? 2 :
                              root.activeTab === "Report" ? 3 :
                              root.activeTab === "Traverse" ? 4 :
                              root.activeTab === "Traversing" ? 4 :
                              root.activeTab === "Levelling" ? 5 :
                              root.activeTab === "Settings" ? 6 : 0

                // Dashboard Content (index 0)
                Flickable {
                    id: contentFlickable
                    clip: true
                    contentWidth: width
                    contentHeight: contentColumn.height + 60
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    ColumnLayout {
                        id: contentColumn
                        width: contentFlickable.width - (isCompact ? 24 : 40)
                        x: isCompact ? 12 : 20
                        y: isCompact ? 12 : 20
                        spacing: isCompact ? 12 : 20

                    // Top Stats - Responsive Grid with Real Data
                    GridLayout {
                        Layout.fillWidth: true
                        columns: isCompact ? 2 : (isMedium ? 2 : 4)
                        rowSpacing: isCompact ? 8 : 16
                        columnSpacing: isCompact ? 8 : 16

                        // Animations
                        // Animations
                        opacity: 0
                        transform: Translate {
                            y: 20
                            NumberAnimation on y { to: 0; duration: 600; easing.type: Easing.OutCubic }
                        }
                        NumberAnimation on opacity { to: 1; duration: 600; easing.type: Easing.OutCubic }

                        StatTile {
                            label: "Personnel"
                            value: totalPersonnel + " Team" + (totalPersonnel !== 1 ? "s" : "")
                            subValue: onSitePersonnel + " On Site"
                            icon: "\uf500"  // users (user-friends)
                            iconColor: "#5B7C99"  // Steel blue
                            Layout.fillWidth: true
                            Layout.preferredHeight: isCompact ? 62 : 76
                            bgColor: glassBg; borderColor: glassBorder; radius: glassRadius
                        }



                        StatTile {
                            label: "Instruments"
                            value: totalInstruments + " Total"
                            subValue: availableInstruments + " Available, " + inUseInstruments + " In Use"
                            icon: "\uf1e5"  // binoculars (survey instruments)
                            iconColor: "#B8956A"  // Muted amber
                            Layout.fillWidth: true
                            Layout.preferredHeight: isCompact ? 62 : 76
                            bgColor: glassBg; borderColor: glassBorder; radius: glassRadius
                        }

                        StatTile {
                            label: "Project Status"
                            value: projectInfo.status || "Active"
                            icon: "\uf058"  // check-circle
                            iconColor: "#6B8E7F"  // Muted green
                            Layout.fillWidth: true
                            Layout.preferredHeight: isCompact ? 62 : 76
                            bgColor: glassBg; borderColor: glassBorder; radius: glassRadius
                        }
                    }

                    // Dashboard Cards - Responsive Grid
                    GridLayout {
                        Layout.fillWidth: true
                        columns: isCompact ? 1 : (isMedium ? 2 : 3)
                        rowSpacing: isCompact ? 8 : 16
                        columnSpacing: isCompact ? 8 : 16

                        // Weather Box - Real-time from Open-Meteo API
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: isCompact ? 130 : 160
                            color: glassBg
                            radius: glassRadius
                            border.color: glassBorder

                            // Entry Animation
                            opacity: 0
                            transform: Translate {
                                y: 30
                                SequentialAnimation on y {
                                    PauseAnimation { duration: 100 }
                                    NumberAnimation { to: 0; duration: 700; easing.type: Easing.OutCubic }
                                }
                            }
                            SequentialAnimation on opacity {
                                PauseAnimation { duration: 100 }
                                NumberAnimation { to: 1; duration: 700; easing.type: Easing.OutCubic }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: isCompact ? 15 : 20
                                spacing: isCompact ? 8 : 12

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "\uf3c5"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: isCompact ? 10 : 11
                                        color: accentColor
                                    }
                                    Text {
                                        text: projectName
                                        font.family: "Codec Pro"
                                        font.pixelSize: isCompact ? 10 : 11
                                        font.weight: Font.Medium
                                        color: textPrimary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    // Refresh button
                                    Rectangle {
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: refreshMa.containsMouse ? "#f0f0f0" : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf2f1"
                                            font.family: "Font Awesome 5 Pro Solid"
                                            font.pixelSize: 9
                                            color: weatherLoading ? accentColor : textSecondary

                                            RotationAnimation on rotation {
                                                running: weatherLoading
                                                from: 0
                                                to: 360
                                                duration: 1000
                                                loops: Animation.Infinite
                                            }
                                        }

                                        MouseArea {
                                            id: refreshMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                weatherLoading = true;
                                                fetchWeather();
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 15

                                    Text {
                                        text: weatherIcon
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: isCompact ? 16 : 18
                                        color: weatherCondition.indexOf("Rain") >= 0 ? "#3399ff" :
                                               weatherCondition.indexOf("Cloud") >= 0 ? textSecondary :
                                               weatherCondition.indexOf("Thunder") >= 0 ? "#9933ff" : "#f9b115"
                                    }

                                    ColumnLayout {
                                        spacing: 2
                                        Text {
                                            text: weatherLoading ? "--°C" : Math.round(weatherTemp) + "°C"
                                            font.family: "Codec Pro"
                                            font.pixelSize: isCompact ? 14 : 18
                                            font.weight: Font.Bold
                                            color: textPrimary
                                        }
                                        Text {
                                            text: weatherCondition
                                            font.family: "Codec Pro"
                                            font.pixelSize: isCompact ? 9 : 10
                                            color: textSecondary
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "\uf72e"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: isCompact ? 10 : 11
                                        color: textSecondary
                                    }
                                    Text {
                                        text: weatherLoading ? "-- km/h" : Math.round(windSpeed) + " km/h " + windDirection
                                        font.family: "Codec Pro"
                                        font.pixelSize: isCompact ? 9 : 10
                                        color: textPrimary
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: lastUpdated || "--:--"
                                        font.family: "Codec Pro"
                                        font.pixelSize: isCompact ? 8 : 9
                                        color: textSecondary
                                    }
                                }
                            }
                        }

                        // Quick Actions Box
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: isCompact ? 150 : 180
                            color: glassBg
                            radius: glassRadius
                            border.color: glassBorder

                            // Entry Animation
                            opacity: 0
                            transform: Translate {
                                y: 30
                                SequentialAnimation on y {
                                    PauseAnimation { duration: 200 }
                                    NumberAnimation { to: 0; duration: 700; easing.type: Easing.OutCubic }
                                }
                            }
                            SequentialAnimation on opacity {
                                PauseAnimation { duration: 200 }
                                NumberAnimation { to: 1; duration: 700; easing.type: Easing.OutCubic }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: isCompact ? 15 : 20
                                spacing: isCompact ? 8 : 12

                                Text {
                                    text: "Quick Actions"
                                    font.family: "Codec Pro"
                                    font.pixelSize: isCompact ? 10 : 11
                                    font.bold: true
                                    color: textPrimary
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    columns: 2
                                    rowSpacing: isCompact ? 6 : 10
                                    columnSpacing: isCompact ? 6 : 10

                                    // Add Personnel Action
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 4
                                        color: "#E8EBF0"

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: isCompact ? 4 : 6
                                            Text {
                                                text: "\uf234"  // user-plus
                                                font.family: "Font Awesome 5 Pro Solid"
                                                font.pixelSize: isCompact ? 9 : 10
                                                color: "#5A6C7D"
                                            }
                                            Text {
                                                text: "Add Personnel"
                                                font.family: "Codec Pro"
                                                font.pixelSize: isCompact ? 8 : 9
                                                color: "#5A6C7D"
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.activeTab = "Personnel";
                                                personnelPage.addPersonnelDialog.open();
                                            }
                                        }
                                    }

                                    // Add Instrument Action
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 4
                                        color: "#E8EBF0"

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: isCompact ? 4 : 6
                                            Text {
                                                text: "\uf0ad"  // wrench
                                                font.family: "Font Awesome 5 Pro Solid"
                                                font.pixelSize: isCompact ? 9 : 10
                                                color: "#5A6C7D"
                                            }
                                            Text {
                                                text: "Add Instrument"
                                                font.family: "Codec Pro"
                                                font.pixelSize: isCompact ? 8 : 9
                                                color: "#5A6C7D"
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.activeTab = "Instruments";
                                                instrumentsPage.addInstrumentDialog.open();
                                            }
                                        }
                                    }

                                    // Manage Personnel Action
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 4
                                        color: "#E8EBF0"

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: isCompact ? 4 : 6
                                            Text {
                                                text: "\uf0c0"  // users
                                                font.family: "Font Awesome 5 Pro Solid"
                                                font.pixelSize: isCompact ? 9 : 10
                                                color: "#5A6C7D"
                                            }
                                            Text {
                                                text: "Personnel"
                                                font.family: "Codec Pro"
                                                font.pixelSize: isCompact ? 8 : 9
                                                color: "#5A6C7D"
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.activeTab = "Personnel"
                                        }
                                    }

                                    // Settings Action
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 4
                                        color: "#E8EBF0"

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: isCompact ? 4 : 6
                                            Text {
                                                text: "\uf013"  // cog
                                                font.family: "Font Awesome 5 Pro Solid"
                                                font.pixelSize: isCompact ? 9 : 10
                                                color: "#5A6C7D"
                                            }
                                            Text {
                                                text: "Settings"
                                                font.family: "Codec Pro"
                                                font.pixelSize: isCompact ? 8 : 9
                                                color: "#5A6C7D"
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.activeTab = "Settings"
                                        }
                                    }
                                }
                            }
                        }

                        // Recent Activity Box
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: isCompact ? 150 : 180
                            Layout.columnSpan: isCompact ? 1 : (isMedium ? 2 : 1)
                            color: glassBg
                            radius: glassRadius
                            border.color: glassBorder

                            // Entry Animation
                            opacity: 0
                            transform: Translate {
                                y: 30
                                SequentialAnimation on y {
                                    PauseAnimation { duration: 300 }
                                    NumberAnimation { to: 0; duration: 700; easing.type: Easing.OutCubic }
                                }
                            }
                            SequentialAnimation on opacity {
                                PauseAnimation { duration: 300 }
                                NumberAnimation { to: 1; duration: 700; easing.type: Easing.OutCubic }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: isCompact ? 15 : 20
                                spacing: isCompact ? 6 : 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "Recent Activity"
                                        font.family: "Codec Pro"
                                        font.pixelSize: isCompact ? 10 : 11
                                        font.bold: true
                                        color: textPrimary
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: activityModel.count > 0 ? "" : "No activity yet"
                                        font.family: "Codec Pro"
                                        font.pixelSize: isCompact ? 8 : 9
                                        color: textSecondary
                                        visible: activityModel.count === 0
                                    }
                                }

                                // Activity list (scrollable)
                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    model: activityModel
                                    clip: true
                                    spacing: isCompact ? 4 : 6

                                    delegate: RowLayout {
                                        width: ListView.view.width
                                        spacing: 10

                                        Rectangle {
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: model.color
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                text: model.action
                                                font.family: "Codec Pro"
                                                font.pixelSize: isCompact ? 9 : 10
                                                font.bold: true
                                                color: textPrimary
                                            }
                                            Text {
                                                text: model.detail
                                                font.family: "Codec Pro"
                                                font.pixelSize: isCompact ? 8 : 9
                                                color: textSecondary
                                            }
                                        }

                                        Text {
                                            text: getRelativeTime(model.timestamp)
                                            font.family: "Codec Pro"
                                            font.pixelSize: isCompact ? 8 : 9
                                            color: textSecondary
                                        }
                                    }
                                }
                            }
                        }

                        // Project Location Map (compact)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: isCompact ? 150 : 180
                            color: glassBg
                            radius: glassRadius
                            border.color: glassBorder

                            // Entry Animation
                            opacity: 0
                            transform: Translate {
                                y: 30
                                SequentialAnimation on y {
                                    PauseAnimation { duration: 400 }
                                    NumberAnimation { to: 0; duration: 700; easing.type: Easing.OutCubic }
                                }
                            }
                            SequentialAnimation on opacity {
                                PauseAnimation { duration: 400 }
                                NumberAnimation { to: 1; duration: 700; easing.type: Easing.OutCubic }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: isCompact ? 10 : 12
                                spacing: 10

                                // Mini Map with real OSM tiles
                                Rectangle {
                                    Layout.preferredWidth: isCompact ? 100 : 140
                                    Layout.fillHeight: true
                                    radius: 4
                                    color: "#f0f4f8"
                                    clip: true

                                    Plugin {
                                        id: miniMapPlugin
                                        name: "osm"
                                        PluginParameter {
                                            name: "osm.mapping.custom.host"
                                            value: "https://tile.openstreetmap.org/"
                                        }
                                    }

                                    MapView {
                                        id: miniMapView
                                        anchors.fill: parent
                                        anchors.margins: 2

                                        map.plugin: miniMapPlugin
                                        map.center: QtPositioning.coordinate(wgs84Coords.latitude, wgs84Coords.longitude)
                                        map.zoomLevel: 14
                                        map.minimumZoomLevel: 3
                                        map.maximumZoomLevel: 18

                                        // Disable copyrights for cleaner preview
                                        map.copyrightsVisible: false

                                        // Project location pin marker
                                        MapQuickItem {
                                            id: projectMarker
                                            coordinate: QtPositioning.coordinate(wgs84Coords.latitude, wgs84Coords.longitude)
                                            anchorPoint.x: pinMarker.width / 2
                                            anchorPoint.y: pinMarker.height

                                            sourceItem: Item {
                                                id: pinMarker
                                                width: 32
                                                height: 42

                                                // Drop shadow
                                                Rectangle {
                                                    x: 2
                                                    y: 2
                                                    width: 28
                                                    height: 28
                                                    radius: 14
                                                    color: "#40000000"
                                                }

                                                // Pin head (circle)
                                                Rectangle {
                                                    id: pinHead
                                                    width: 28
                                                    height: 28
                                                    radius: 14
                                                    color: dangerColor
                                                    border.color: "white"
                                                    border.width: 3

                                                    // Inner dot
                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: 10
                                                        height: 10
                                                        radius: 5
                                                        color: "white"
                                                    }
                                                }

                                                // Pin tail (triangle pointing down)
                                                Canvas {
                                                    id: pinTail
                                                    anchors.top: pinHead.bottom
                                                    anchors.topMargin: -4
                                                    anchors.horizontalCenter: pinHead.horizontalCenter
                                                    width: 16
                                                    height: 18

                                                    onPaint: {
                                                        var ctx = getContext("2d");
                                                        ctx.clearRect(0, 0, width, height);
                                                        ctx.beginPath();
                                                        ctx.moveTo(0, 0);
                                                        ctx.lineTo(width, 0);
                                                        ctx.lineTo(width / 2, height);
                                                        ctx.closePath();
                                                        ctx.fillStyle = dangerColor;
                                                        ctx.fill();
                                                        ctx.strokeStyle = "white";
                                                        ctx.lineWidth = 2;
                                                        ctx.stroke();
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Zoom controls overlay
                                    Column {
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 6
                                        spacing: 2
                                        z: 100

                                        // Zoom In button
                                        Rectangle {
                                            width: 24
                                            height: 24
                                            radius: 4
                                            color: zoomInMa.containsMouse ? "#f0f0f0" : "white"
                                            border.color: borderColor

                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uf067"
                                                font.family: "Font Awesome 5 Pro Solid"
                                                font.pixelSize: 9
                                                color: textPrimary
                                            }

                                            MouseArea {
                                                id: zoomInMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (miniMapView.map.zoomLevel < 18) {
                                                        miniMapView.map.zoomLevel += 1;
                                                    }
                                                }
                                            }
                                        }

                                        // Zoom Out button
                                        Rectangle {
                                            width: 24
                                            height: 24
                                            radius: 4
                                            color: zoomOutMa.containsMouse ? "#f0f0f0" : "white"
                                            border.color: borderColor

                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uf068"
                                                font.family: "Font Awesome 5 Pro Solid"
                                                font.pixelSize: 9
                                                color: textPrimary
                                            }

                                            MouseArea {
                                                id: zoomOutMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (miniMapView.map.zoomLevel > 3) {
                                                        miniMapView.map.zoomLevel -= 1;
                                                    }
                                                }
                                            }
                                        }

                                        // Center on project button
                                        Rectangle {
                                            width: 24
                                            height: 24
                                            radius: 4
                                            color: centerMa.containsMouse ? "#f0f0f0" : "white"
                                            border.color: borderColor

                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uf05b"
                                                font.family: "Font Awesome 5 Pro Solid"
                                                font.pixelSize: 9
                                                color: accentColor
                                            }

                                            MouseArea {
                                                id: centerMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    miniMapView.map.center = QtPositioning.coordinate(wgs84Coords.latitude, wgs84Coords.longitude);
                                                    miniMapView.map.zoomLevel = 14;
                                                }
                                            }
                                        }
                                    }
                                }

                                // Location Info
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 4

                                    RowLayout {
                                        Text {
                                            text: "\uf5a0"
                                            font.family: "Font Awesome 5 Pro Solid"
                                            font.pixelSize: 10
                                            color: accentColor
                                        }
                                        Text {
                                            text: "Project Location"
                                            font.family: "Codec Pro"
                                            font.pixelSize: isCompact ? 9 : 10
                                            font.weight: Font.Medium
                                            color: textPrimary
                                        }


                                    }

                                    Text {
                                        text: projectName
                                        font.family: "Codec Pro"
                                        font.pixelSize: isCompact ? 9 : 9
                                        color: textSecondary
                                    }

                                    Item { Layout.fillHeight: true }

                                    ColumnLayout {
                                        spacing: 2

                                        RowLayout {
                                            spacing: 8
                                            Text {
                                                text: "Y:"
                                                font.family: "Codec Pro"
                                                font.pixelSize: 8
                                                color: textSecondary
                                            }
                                            Text {
                                                text: projectY.toFixed(3) + " m"
                                                font.family: "Codec Pro"
                                                font.pixelSize: 8
                                                color: textPrimary
                                            }
                                        }

                                        RowLayout {
                                            spacing: 8
                                            Text {
                                                text: "X:"
                                                font.family: "Codec Pro"
                                                font.pixelSize: 8
                                                color: textSecondary
                                            }
                                            Text {
                                                text: projectX.toFixed(3) + " m"
                                                font.family: "Codec Pro"
                                                font.pixelSize: 8
                                                color: textPrimary
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Personnel Management
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: isCompact ? 160 : 200
                            color: cardColor
                            radius: 6
                            border.color: borderColor

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: isCompact ? 12 : 15
                                spacing: isCompact ? 8 : 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "\uf0c0"
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 11
                                        color: accentColor
                                    }
                                    Text {
                                        text: "Personnel Management"
                                        font.family: "Codec Pro"
                                        font.pixelSize: isCompact ? 10 : 11
                                        font.bold: true
                                        color: textPrimary
                                    }
                                    Item { Layout.fillWidth: true }
                                    Rectangle {
                                        width: addPersonnelRow.width + 12
                                        height: 22
                                        radius: 4
                                        color: Qt.lighter(accentColor, 1.85)

                                        RowLayout {
                                            id: addPersonnelRow
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text {
                                                text: "\uf067"
                                                font.family: "Font Awesome 5 Pro Solid"
                                                font.pixelSize: 8
                                                color: accentColor
                                            }
                                            Text {
                                                text: "Add"
                                                font.family: "Codec Pro"
                                                font.pixelSize: 8
                                                color: accentColor
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: personnelPage.addPersonnelDialog.open()
                                        }
                                    }
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 6

                                    model: personnelList

                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index
                                        width: ListView.view.width
                                        height: 36
                                        radius: 4
                                        color: index % 2 === 0 ? Qt.lighter(cardColor, 1.02) : cardColor

                                        property color statusColor: {
                                            switch(modelData.status) {
                                                case "On Site": return successColor
                                                case "Off Site": return warningColor
                                                case "On Leave": return infoColor
                                                case "Off Duty": return textSecondary
                                                default: return textSecondary
                                            }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 10

                                            Rectangle {
                                                width: 28
                                                height: 28
                                                radius: 14
                                                color: Qt.lighter(accentColor, 1.7)

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.name ? modelData.name.charAt(0) : "?"
                                                    font.family: "Codec Pro"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    color: accentColor
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text {
                                                    text: modelData.name
                                                    font.family: "Codec Pro"
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                    color: textPrimary
                                                }
                                                Text {
                                                    text: modelData.role
                                                    font.family: "Codec Pro"
                                                    font.pixelSize: 8
                                                    color: textSecondary
                                                }
                                            }

                                            Rectangle {
                                                width: personnelStatusText.width + 12
                                                height: 18
                                                radius: 9
                                                color: Qt.lighter(statusColor, 1.7)

                                                Text {
                                                    id: personnelStatusText
                                                    anchors.centerIn: parent
                                                    text: modelData.status
                                                    font.family: "Codec Pro"
                                                    font.pixelSize: 8
                                                    color: statusColor
                                                }
                                            }
                                        }
                                    }

                                    // Empty state
                                    Rectangle {
                                        visible: personnelList.length === 0
                                        anchors.centerIn: parent
                                        width: parent.width
                                        height: 60
                                        color: "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "No personnel added yet"
                                            font.family: "Codec Pro"
                                            font.pixelSize: 10
                                            color: textSecondary
                                        }
                                    }
                                }
                            }
                        }

                        // Instruments Management
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: isCompact ? 180 : 220
                            color: "white"
                            radius: 4
                            border.color: borderColor

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: isCompact ? 12 : 15
                                spacing: isCompact ? 8 : 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "\uf1e5"  // binoculars - matches stat tile
                                        font.family: "Font Awesome 5 Pro Solid"
                                        font.pixelSize: 11
                                        color: dangerColor
                                    }
                                    Text {
                                        text: "Instruments Management"
                                        font.family: "Codec Pro"
                                        font.pixelSize: isCompact ? 10 : 11
                                        font.bold: true
                                        color: textPrimary
                                    }
                                    Item { Layout.fillWidth: true }
                                    Rectangle {
                                        width: addInstrumentRow.width + 12
                                        height: 22
                                        radius: 4
                                        color: Qt.lighter(dangerColor, 1.85)

                                        RowLayout {
                                            id: addInstrumentRow
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text {
                                                text: "\uf067"
                                                font.family: "Font Awesome 5 Pro Solid"
                                                font.pixelSize: 8
                                                color: dangerColor
                                            }
                                            Text {
                                                text: "Add"
                                                font.family: "Codec Pro"
                                                font.pixelSize: 8
                                                color: dangerColor
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: instrumentsPage.addInstrumentDialog.open()
                                        }
                                    }
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 6

                                    model: instrumentsList

                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index
                                        width: ListView.view.width
                                        height: 36
                                        radius: 4
                                        color: index % 2 === 0 ? "#f9f9f9" : "white"

                                        property color statusColor: {
                                            switch(modelData.status) {
                                                case "Available": return "#2eb85c"
                                                case "In Use": return "#39f"
                                                case "Calibration": return "#f9b115"
                                                case "Maintenance": return dangerColor
                                                default: return textSecondary
                                            }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 10

                                            Rectangle {
                                                width: 28
                                                height: 28
                                                radius: 6
                                                color: Qt.lighter(dangerColor, 1.7)

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf542"
                                                    font.family: "Font Awesome 5 Pro Solid"
                                                    font.pixelSize: 9
                                                    color: dangerColor
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text {
                                                    text: modelData.name
                                                    font.family: "Codec Pro"
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                    color: textPrimary
                                                }
                                                RowLayout {
                                                    spacing: 8
                                                    Text {
                                                        text: modelData.type
                                                        font.family: "Codec Pro"
                                                        font.pixelSize: 8
                                                        color: textSecondary
                                                    }
                                                    Text {
                                                        text: "•"
                                                        font.pixelSize: 8
                                                        color: borderColor
                                                    }
                                                    Text {
                                                        text: modelData.serial || "-"
                                                        font.family: "Codec Pro"
                                                        font.pixelSize: 8
                                                        color: textSecondary
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: instrumentStatusText.width + 12
                                                height: 18
                                                radius: 9
                                                color: Qt.lighter(statusColor, 1.7)

                                                Text {
                                                    id: instrumentStatusText
                                                    anchors.centerIn: parent
                                                    text: modelData.status
                                                    font.family: "Codec Pro"
                                                    font.pixelSize: 8
                                                    color: statusColor
                                                }
                                            }
                                        }
                                    }

                                    // Empty state
                                    Rectangle {
                                        visible: instrumentsList.length === 0
                                        anchors.centerIn: parent
                                        width: parent.width
                                        height: 60
                                        color: "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "No instruments added yet"
                                            font.family: "Codec Pro"
                                            font.pixelSize: 10
                                            color: textSecondary
                                        }
                                    }
                                }
                            }
                        }
                    }
                } // end contentColumn
            } // end Flickable

                // Personnel Page (index 1)
                PersonnelPage {
                    id: personnelPage
                }

                // Instruments Page (index 2)
                InstrumentsPage {
                    id: instrumentsPage
                }

                // Report Page (index 3)
                ReportPage {
                    id: reportPage
                }

                // Traversing Page (index 4)
                TraversingPage {
                    id: traversingPage
                }



                // Levelling Page (index 7)
                LevellingPage {
                    id: levellingPage
                }

                // Settings Page (index 8)
                SettingsPage {
                    id: settingsPage
                }
            }
        }
    }

    // CAD Window (separate window, not in stack)
    CADPage {
        id: cadWindow
    }

    // Handle CAD Mode - open separate window
    onActiveTabChanged: {
        if (activeTab === "CAD Mode") {
            cadWindow.visible = true
            cadWindow.raise()
            cadWindow.requestActivate()
            // Reset to dashboard after opening CAD
            activeTab = "Dashboard"
        }
    }
}
