import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property color cardColor: "#ffffff"
    property color borderColor: "#d0d7de"
    property color textPrimary: "#111827"
    property color textSecondary: "#6b7280"
    property color accentColor: "#2563eb"

    color: cardColor
    radius: 6
    border.color: borderColor
    border.width: 1
    
    property int maxProjects: 5
    signal projectClicked(int projectId, string projectName)
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10
        
        // Header
        RowLayout {
            Layout.fillWidth: true
            
            Label {
                text: "Recent Projects"
                font.pixelSize: 13
                font.bold: true
                color: textPrimary
            }
            
            Item { Layout.fillWidth: true }
            
            ToolButton {
                text: "⟳"
                font.pixelSize: 12
                contentItem: Text {
                    text: parent.text
                    font.pixelSize: parent.font.pixelSize
                    color: accentColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: refreshProjects()
                ToolTip.text: "Refresh"
                ToolTip.visible: hovered
            }
        }
        
        // Projects List
        ListView {
            id: projectsListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            
            model: ListModel {
                id: recentProjectsModel
            }
            
            delegate: Rectangle {
                width: projectsListView.width
                height: 70
                color: mouseArea.containsMouse ? Qt.lighter(cardColor, 0.98) : "transparent"
                radius: 4
                border.color: mouseArea.containsMouse ? accentColor : borderColor
                border.width: 1
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12
                    
                    // Project Icon
                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        radius: 21
                        color: getDisciplineColor(model.discipline)
                        
                        Label {
                            anchors.centerIn: parent
                            text: model.name.substring(0, 1).toUpperCase()
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                    
                    // Project Info
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        
                        Label {
                            text: model.name
                            font.pixelSize: 11
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            color: textPrimary
                        }
                        
                        Label {
                            text: model.discipline || "Engineering"
                            font.pixelSize: 9
                            color: textSecondary
                        }
                        
                        Label {
                            text: formatLastAccessed(model.lastAccessed)
                            font.pixelSize: 8
                            color: textSecondary
                        }
                    }
                    
                    // Open Button
                    Label {
                        text: "→"
                        font.pixelSize: 16
                        color: accentColor
                    }
                }
                
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.projectClicked(model.id, model.name);
                    }
                }
            }
            
            // Empty state
            Label {
                anchors.centerIn: parent
                text: "No recent projects\n\nOpen a project to see it here"
                font.pixelSize: 10
                color: textSecondary
                horizontalAlignment: Text.AlignHCenter
                visible: projectsListView.count === 0
            }
        }
    }
    
    Component.onCompleted: {
        refreshProjects();
    }
    
    Connections {
        target: Database
        function onProjectChanged() {
            refreshProjects();
        }
    }
    
    function refreshProjects() {
        recentProjectsModel.clear();
        var projects = Database.getRecentProjects(root.maxProjects);
        
        for (var i = 0; i < projects.length; i++) {
            recentProjectsModel.append(projects[i]);
        }
    }
    
    function getDisciplineColor(discipline) {
        switch(discipline) {
            case "Engineering": return "#2196F3";
            case "Architecture": return "#4CAF50";
            case "Construction": return "#FF9800";
            default: return "#9C27B0";
        }
    }
    
    function formatLastAccessed(timestamp) {
        if (!timestamp) return "Never accessed";
        
        var date = new Date(timestamp);
        var now = new Date();
        var diffMs = now - date;
        var diffMins = Math.floor(diffMs / 60000);
        var diffHours = Math.floor(diffMs / 3600000);
        var diffDays = Math.floor(diffMs / 86400000);
        
        if (diffMins < 1) return "Just now";
        if (diffMins < 60) return diffMins + " minute" + (diffMins > 1 ? "s" : "") + " ago";
        if (diffHours < 24) return diffHours + " hour" + (diffHours > 1 ? "s" : "") + " ago";
        if (diffDays < 7) return diffDays + " day" + (diffDays > 1 ? "s" : "") + " ago";
        
        return Qt.formatDate(date, "MMM d, yyyy");
    }
}
