#!/bin/bash
# SiteSurveyor Run Script with CSV Import Support

# Enable XMLHttpRequest file reading for CSV import
export QML_XHR_ALLOW_FILE_READ=1

# Run the application
cd /home/console2/sitesurveyor/build
./linux-debug/SiteSurveyor "$@"
