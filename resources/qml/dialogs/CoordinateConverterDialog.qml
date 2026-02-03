import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: "Coordinate Converter"
    modal: true
    width: 500
    height: 450
    anchors.centerIn: parent
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 15
        
        // Source CRS Selection
        GroupBox {
            title: "Source Coordinate System"
            Layout.fillWidth: true
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                
                ComboBox {
                    id: sourceCRS
                    Layout.fillWidth: true
                    model: ["WGS84 (EPSG:4326)", "Lo29 (EPSG:22289)", "Lo31 (EPSG:22291)", "UTM 35S (EPSG:32735)", "UTM 36S (EPSG:32736)"]
                    currentIndex: 1 // Default to Lo29
                }
                
                RowLayout {
                    spacing: 10
                    
                    TextField {
                        id: sourceX
                        Layout.fillWidth: true
                        placeholderText: sourceCRS.currentIndex === 0 ? "Longitude" : "Easting (Y)"
                        validator: DoubleValidator {}
                    }
                    
                    TextField {
                        id: sourceY
                        Layout.fillWidth: true
                        placeholderText: sourceCRS.currentIndex === 0 ? "Latitude" : "Northing (X)"
                        validator: DoubleValidator {}
                    }
                }
                
                TextField {
                    id: sourceZ
                    Layout.fillWidth: true
                    placeholderText: "Elevation (optional)"
                    text: "0"
                    validator: DoubleValidator {}
                }
            }
        }
        
        // Target CRS Selection
        GroupBox {
            title: "Target Coordinate System"
            Layout.fillWidth: true
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                
                ComboBox {
                    id: targetCRS
                    Layout.fillWidth: true
                    model: ["WGS84 (EPSG:4326)", "Lo29 (EPSG:22289)", "Lo31 (EPSG:22291)", "UTM 35S (EPSG:32735)", "UTM 36S (EPSG:32736)"]
                    currentIndex: 0 // Default to WGS84
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: "#f5f5f5"
                    radius: 4
                    border.color: "#ddd"
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 5
                        
                        Label {
                            id: targetXLabel
                            text: targetCRS.currentIndex === 0 ? "Longitude:" : "Easting (Y):"
                            font.bold: true
                        }
                        
                        Label {
                            id: targetXValue
                            text: "-"
                            font.pixelSize: 14
                        }
                        
                        Label {
                            id: targetYLabel
                            text: targetCRS.currentIndex === 0 ? "Latitude:" : "Northing (X):"
                            font.bold: true
                        }
                        
                        Label {
                            id: targetYValue
                            text: "-"
                            font.pixelSize: 14
                        }
                        
                        Label {
                            id: targetZValue
                            text: "Elevation: -"
                            font.pixelSize: 12
                            color: "#666"
                        }
                    }
                }
            }
        }
        
        // Error Display
        Label {
            id: errorLabel
            Layout.fillWidth: true
            text: ""
            color: "red"
            wrapMode: Text.WordWrap
            visible: text !== ""
        }
        
        // Buttons
        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 10
            
            Button {
                text: "Convert"
                highlighted: true
                enabled: sourceX.text !== "" && sourceY.text !== ""
                onClicked: performConversion()
            }
            
            Button {
                text: "Clear"
                onClicked: clearForm()
            }
            
            Button {
                text: "Close"
                onClicked: root.close()
            }
        }
    }
    
    function getEPSGCode(index) {
        const epsgCodes = [4326, 22289, 22291, 32735, 32736];
        return epsgCodes[index];
    }
    
    function performConversion() {
        errorLabel.text = "";
        
        var sourceEPSG = getEPSGCode(sourceCRS.currentIndex);
        var targetEPSG = getEPSGCode(targetCRS.currentIndex);
        
        var x = parseFloat(sourceX.text);
        var y = parseFloat(sourceY.text);
        var z = parseFloat(sourceZ.text);
        
        if (isNaN(x) || isNaN(y) || isNaN(z)) {
            errorLabel.text = "Invalid numeric input";
            return;
        }
        
        var result = CoordTransform.transform(x, y, z, sourceEPSG, targetEPSG);
        
        if (result.success) {
            var precision = targetCRS.currentIndex === 0 ? 8 : 3; // 8 decimals for WGS84, 3 for metric
            targetXValue.text = result.x.toFixed(precision);
            targetYValue.text = result.y.toFixed(precision);
            targetZValue.text = "Elevation: " + result.z.toFixed(3);
        } else {
            errorLabel.text = "Transformation failed: " + result.error;
            targetXValue.text = "-";
            targetYValue.text = "-";
            targetZValue.text = "Elevation: -";
        }
    }
    
    function clearForm() {
        sourceX.text = "";
        sourceY.text = "";
        sourceZ.text = "0";
        targetXValue.text = "-";
        targetYValue.text = "-";
        targetZValue.text = "Elevation: -";
        errorLabel.text = "";
    }
    
    // Quick conversion helpers
    function quickLo29ToWGS84(easting, northing, elevation) {
        sourceX.text = easting.toString();
        sourceY.text = northing.toString();
        sourceZ.text = elevation !== undefined ? elevation.toString() : "0";
        sourceCRS.currentIndex = 1; // Lo29
        targetCRS.currentIndex = 0; // WGS84
        performConversion();
        open();
    }
    
    function quickWGS84ToLo29(lon, lat, elevation) {
        sourceX.text = lon.toString();
        sourceY.text = lat.toString();
        sourceZ.text = elevation !== undefined ? elevation.toString() : "0";
        sourceCRS.currentIndex = 0; // WGS84
        targetCRS.currentIndex = 1; // Lo29
        performConversion();
        open();
    }
}
