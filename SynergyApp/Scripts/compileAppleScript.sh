#!/bin/sh
#
# IF YOU EDIT THIS SCRIPT, REMEMBER TO PLACE AN EDITED COPY IN THE TARGET/BUILD SETTINGS AREA
#
# this is ugly, but we override the default AppleScript compilation command in
# order to add this -x flag (save as execute only)

/bin/mkdir -p "${SRCROOT}/build/Synergy.app/Contents/Resources/Scripts"

/usr/bin/osacompile  -x -d \
    -i /System/Library/Frameworks/AppleScriptKit.framework \
    -U getSongInfo.applescript  \
    -o "${SRCROOT}/build/Synergy.app/Contents/Resources/Scripts/getSongInfo.scpt" \
       "${SRCROOT}/SynergyApp/Scripts/getSongInfo.applescript"

