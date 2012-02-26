#!/bin/sh

# Synergy is made up of three main components (preferences application,
# preference pane, background application) but we want them all to appear
# as a single entity for the purposes of keychain access (ie. so that a
# last.fm password can be set in the preferences and accessed transparently
# from the background app).
#
# We do this by using a shared identifier when code-signing. This
# identifier is set only in release builds, which means that signing only
# takes place in release builds.
if [ "$CODE_SIGNING_IDENTIFIER" ]; then
  # can't set CODE_SIGN_IDENTITY in the build settings because that appears
  # to be set up only for iPhone development; just hard-code the "wincent.com"
  # identity here instead
  codesign -s wincent.com -i "$CODE_SIGNING_IDENTIFIER" "$CODESIGNING_FOLDER_PATH"
fi
