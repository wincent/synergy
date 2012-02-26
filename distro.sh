#!/bin/sh -e

set -e

. "$BUILDTOOLS_DIR/Common.sh"

# extract marketing version; eg: 3.5.a2
WO_INFO_PLIST_VERSION=$(grep '#define WO_INFO_PLIST_VERSION' WOSynergy_Version.h | awk '{print $3}')

# extract build number; eg. 257953e
WO_BUILDNUMBER=$(grep 'WO_BUILDNUMBER' com.wincent.buildtools.gitrev.h | awk '{print $3}')

# sanity checks
test -n "$WO_INFO_PLIST_VERSION" || die "failed to determine WO_INFO_PLIST_VERSION"
test -n "$WO_BUILDNUMBER" || die "failed to determine WO_BUILDNUMBER"

# prepare the files to be distributed
DISTRIBUTION_FOLDER="Synergy $WO_INFO_PLIST_VERSION ($WO_BUILDNUMBER)"
rm -rf "$TARGET_BUILD_DIR/$DISTRIBUTION_FOLDER"
mkdir "$TARGET_BUILD_DIR/$DISTRIBUTION_FOLDER"

# note the order here required by ditto (you can only copy folder contents, not folders)
mv "$TARGET_BUILD_DIR/Synergy Preferences.app" "$TARGET_BUILD_DIR/$DISTRIBUTION_FOLDER"
ditto "$TARGET_BUILD_DIR/$DISTRIBUTION_FOLDER" "$TARGET_BUILD_DIR"
ditto "$SRCROOT/distribution" "$TARGET_BUILD_DIR/$DISTRIBUTION_FOLDER"

ZIP_NAME="synergy-$WO_INFO_PLIST_VERSION.zip"
(cd "$TARGET_BUILD_DIR" && zip -r "${ZIP_NAME}" "$DISTRIBUTION_FOLDER")

# Put a copy of the final zip name where the nightly script will find it
echo "${ZIP_NAME}" > "$TARGET_BUILD_DIR/SynergyDistributionInfo.txt"

# prepare code-level release notes for uploading to website (these don't get included in with the distribution)
# (note that this won't work in the nightlies because they are shallow clones and "git describe" doesn't work)
if $(git describe > /dev/null 2>&1); then
  # brief notes
  NOTES="$TARGET_BUILD_DIR/$DISTRIBUTION_FOLDER release notes.txt"
  "$BUILDTOOLS_DIR/ReleaseNotes.sh" > "$NOTES"
  echo -n "WOPublic: " >> "$NOTES"
  (cd "$SOURCE_ROOT/WOPublic" && "$BUILDTOOLS_DIR/ReleaseNotes.sh" --tag-prefix=Synergy- >> "$NOTES")
  echo -n "buildtools: " >> "$NOTES"
  (cd "$SOURCE_ROOT/buildtools" && "$BUILDTOOLS_DIR/ReleaseNotes.sh" --tag-prefix=Synergy- >> "$NOTES")

  # detailed notes
  NOTES="$TARGET_BUILD_DIR/$DISTRIBUTION_FOLDER release notes (detailed).txt"
  "$BUILDTOOLS_DIR/ReleaseNotes.sh" --long > "$NOTES"
  echo -n "WOPublic: " >> "$NOTES"
  (cd "$SOURCE_ROOT/WOPublic" && "$BUILDTOOLS_DIR/ReleaseNotes.sh" --long --tag-prefix=Synergy- >> "$NOTES")
  echo -n "buildtools: " >> "$NOTES"
  (cd "$SOURCE_ROOT/buildtools" && "$BUILDTOOLS_DIR/ReleaseNotes.sh" --long --tag-prefix=Synergy- >> "$NOTES")
fi
