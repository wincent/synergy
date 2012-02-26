#!/bin/sh
#
# IF YOU EDIT THIS SCRIPT, REMEMBER TO PLACE AN EDITED COPY IN THE TARGET/BUILD SETTINGS AREA
#

# update Localizable.strings for the English version (output to app bundle itself)
cd "${SRCROOT}/SynergyApp/Classes"
/usr/bin/genstrings -o "${SRCROOT}/build/Synergy.app/Contents/Resources/English.lproj" *.m

# place updated copy in source tree also
/bin/cp "${SRCROOT}/build/Synergy.app/Contents/Resources/English.lproj/Localizable.strings" "${SRCROOT}/SynergyApp/Resources/English.lproj/"

# update build number
#cd "${SRCROOT}"
#/Developer/Tools/agvtool next-version -all
# Can't do this from within Project Builder... need to do it from command line
# when project file is closed.

# Remove pbdevelopment.plist file
/bin/rm "${SRCROOT}/build/Synergy.app/Contents/pbdevelopment.plist"