// WOPreferences.h
//
// Copyright 2002-2010 Wincent Colaiuta.

#import <Foundation/Foundation.h>

// Key names (for plist file)
#define _woGlobalHotkeysPrefKey  \
@"Activate global hot-keys"

#define _woPrevActionSameAsITunesPrefKey \
@"Previous track action behaves like iTunes"

#define _woQuitKeycodePrefKey  \
@"Key code for quit operation"

#define _woPrevKeycodePrefKey  \
@"Key code for previous track operation"

#define _woNextKeycodePrefKey  \
@"Key code for next track operation"

#define _woPlayKeycodePrefKey    \
@"Key code for play/pause operation"

#define _woShowHideKeycodePrefKey   \
@"Key code for show/hide operation"

#define _woVolumeUpKeycodePrefKey \
@"Key code for volume up operation"

#define _woVolumeDownKeycodePrefKey \
@"Key code for volume down operation"

#define _woShowHideFloaterKeycodePrefKey \
@"Key code for the floater show/hide operation"

#define _woToggleMuteKeycodePrefKey \
@"Key code for the toggle mute operation"

#define _woToggleShuffleKeycodePrefKey \
@"Key code for the toggle shuffle operation"

#define _woSetRepeatModeKeycodePrefKey \
@"Key code for the set repeat mode operation"

#define _woIncreaseRatingKeycodePrefKey \
@"Key code for the increase rating operation"

#define _woDecreaseRatingKeycodePrefKey \
@"Key code for the decrease rating operation"

#define _woRateAs0KeycodePrefKey \
@"Key code for the rate as 0 star operation"

#define _woRateAs1KeycodePrefKey \
@"Key code for the rate as 1 star operation"

#define _woRateAs2KeycodePrefKey \
@"Key code for the rate as 2 star operation"

#define _woRateAs3KeycodePrefKey \
@"Key code for the rate as 3 star operation"

#define _woRateAs4KeycodePrefKey \
@"Key code for the rate as 4 star operation"

#define _woRateAs5KeycodePrefKey \
@"Key code for the rate as 5 star operation"

#define _woActivateITunesKeycodePrefKey \
@"Key code for the activate iTunes operation"

#define _woQuitUnicodePrefKey  \
@"Unicode for quit operation"

#define _woPrevUnicodePrefKey  \
@"Unicode for previous track operation"

#define _woNextUnicodePrefKey  \
@"Unicode for next track operation"

#define _woPlayUnicodePrefKey    \
@"Unicode for play/pause operation"

#define _woShowHideUnicodePrefKey   \
@"Unicode for show/hide operation"

#define _woVolumeUpUnicodePrefKey \
@"Unicode for volume up operation"

#define _woVolumeDownUnicodePrefKey \
@"Unicode for volume down operation"

#define _woShowHideFloaterUnicodePrefKey \
@"Unicode for the floater show/hide operation"

#define _woToggleMuteUnicodePrefKey \
@"Unicode for the toggle mute operation"

#define _woToggleShuffleUnicodePrefKey \
@"Unicode for the toggle shuffle operation"

#define _woSetRepeatModeUnicodePrefKey \
@"Unicode for the set repeat mode operation"

#define _woIncreaseRatingUnicodePrefKey \
@"Unicode for the increase rating operation"

#define _woDecreaseRatingUnicodePrefKey \
@"Unicode for the decrease rating operation"

#define _woRateAs0UnicodePrefKey \
@"Unicode for the rate as 0 star operation"

#define _woRateAs1UnicodePrefKey \
@"Unicode for the rate as 1 star operation"

#define _woRateAs2UnicodePrefKey \
@"Unicode for the rate as 2 star operation"

#define _woRateAs3UnicodePrefKey \
@"Unicode for the rate as 3 star operation"

#define _woRateAs4UnicodePrefKey \
@"Unicode for the rate as 4 star operation"

#define _woRateAs5UnicodePrefKey \
@"Unicode for the rate as 5 star operation"

#define _woActivateITunesUnicodePrefKey \
@"Unicode for the activate iTunes operation"

#define _woQuitModifierPrefKey   \
@"Modifier key for quit operation"

#define _woPrevModifierPrefKey  \
@"Modifier key for previous track operation"

#define _woNextModifierPrefKey  \
@"Modifier key for next track operation"

#define _woPlayModifierPrefKey  \
@"Modifier key for play/pause operation"

#define _woShowHideModifierPrefKey  \
@"Modifier key for show/hide operation"

#define _woVolumeUpModifierPrefKey \
@"Modifier key for volume up operation"

#define _woVolumeDownModifierPrefKey \
@"Modifier key for volume down operation"

#define _woShowHideFloaterModifierPrefKey \
@"Modifier for the floater show/hide operation"

#define _woToggleMuteModifierPrefKey \
@"Modifier for the toggle mute operation"

#define _woToggleShuffleModifierPrefKey \
@"Modifier for the toggle shuffle operation"

#define _woSetRepeatModeModifierPrefKey \
@"Modifier for the set repeat mode operation"

#define _woIncreaseRatingModifierPrefKey \
@"Modifier for the increase rating operation"

#define _woDecreaseRatingModifierPrefKey \
@"Modifier for the decrease rating operation"

#define _woRateAs0ModifierPrefKey \
@"Modifier for the rate as 0 star operation"

#define _woRateAs1ModifierPrefKey \
@"Modifier for the rate as 1 star operation"

#define _woRateAs2ModifierPrefKey \
@"Modifier for the rate as 2 star operation"

#define _woRateAs3ModifierPrefKey \
@"Modifier for the rate as 3 star operation"

#define _woRateAs4ModifierPrefKey \
@"Modifier for the rate as 4 star operation"

#define _woRateAs5ModifierPrefKey \
@"Modifier for the rate as 5 star operation"

#define _woActivateITunesModifierPrefKey \
@"Modifier for the activate iTunes operation"

#define _woLaunchAtLoginPrefKey  \
@"Launch at login"

#define _woButtonStylePrefKey \
@"Menu bar button style"

#define _woShowFeedbackWindowPrefKey \
@"Show extra feedback window"

#define _woShowNotificationWindowPrefKey \
@"Use floating notification window"

#define _woFloaterDurationPrefKey \
@"Delay before removing floater"

#define _woFloaterTransparencyPrefKey \
@"Floater transparency"

#define _woFloaterSizePrefKey \
@"Floater size"

#define _woFloaterHorizontalSegment \
@"Floater horizontal segment"

#define _woFloaterVerticalSegment \
@"Floater vertical segment"

#define _woFloaterHorizontalOffset \
@"Floater horizontal offset"

#define _woFloaterVerticalOffset \
@"Floater vertical offset"

// this one for people with multi-monitor setups
#define _woScreenIndex \
@"Index of screen on which floater lies"

#define _woYScreenOffset \
@"Floater screen vertical offset"

#define _woIncludeAlbumInFloaterPrefKey \
@"Include album in floater"

#define _woIncludeArtistInFloaterPrefKey \
@"Include artist in floater"

#define _woIncludeComposerInFloaterPrefKey      \
@"Include composer in floater"

#define _woIncludeDurationInFloaterPrefKey \
@"Include duration in floater"

#define _woIncludeYearInFloaterPrefKey \
@"Include year in floater"

#define _woIncludeStarRatingInFloaterPrefKey \
@"Include rating in floater"

#define _woFloaterGraphicType \
@"Floater graphic type"

#define _woPlayButtonInMenuPrefKey  \
@"Activate play/pause button"

#define _woPrevButtonInMenuPrefKey  \
@"Activate previous track button"

#define _woNextButtonInMenuPrefKey  \
@"Activate next track button"

#define _woControlHidingPrefKey  \
@"Display Menu Bar controls only when iTunes running"

#define _woGlobalMenuPrefKey  \
@"Activate global menu"

#define _woGlobalMenuOnlyWhenHiddenPrefKey \
@"Separate global menu only when controls hidden"

#define _woUseNSMenuExtraPrefKey \
@"Use NSMenuExtra API"

#define _woRecentlyPlayedSubmenuPrefKey  \
@"Include recently played tracks in menu"

#define _woNumberOfRecentlyPlayedTracksPrefKey \
@"Number of recently played tracks"

#define _woIncludeArtistInRecentTracksPrefKey   \
@"Include artist in recently played tracks"

#define _woPlaylistsSubmenuPrefKey  \
@"Include playlists submenu"

#define _woLaunchQuitItemsPrefKey  \
@"Include Launch and Quit iTunes menu items"

#define _woButtonSpacingPrefKey \
@"Pixel spacing between menu bar controls"

// as of version 0.9.7 this value is ignored
#define _woRegistrationFreePaidKey \
@"Registration fee paid"

// true if the user has been shown the notice that serial numbers are now
// required (only shown once, and only if they say they've paid)
#define _woSerialNumberNoticePrefKey \
@"Serial number notice"

#define _woSerialNumberPrefKey \
@"Serial number"

#define _woEmailAddressPrefKey \
@"Registered email address"

#define _woRandomButtonStylePrefKey \
@"Use random button style"

#define _woCommunicationIntervalPrefKey \
@"Communication interval between Synergy and iTunes"

#define _woAutoConnectTogglePrefKey \
@"Automatically connect to Internet"

#define _woPreprocessTogglePrefKey \
@"Preprocess ID3 tags before searching"

#define _woBringITunesToFrontPrefKey \
@"Bring iTunes to front when switching playlists"

// won't implement these until I can do it properly. eg. not just greyscale
// float storage for colours; instead properly serialize NSColor objects and
// store them using NSData (or similar)
#define _woFloaterForegroundColorPrefKey \
@"Floater foreground color"

#define _woFloaterBackgroundColorPrefKey \
@"Floater background color"

// numbers used in calculating dimensions of custom control NSView, frames etc

/*" Number of pixels of padding at either end of control button view. "*/
#define leftAndRightControlPadding 0

/*" Number of pixels at bottom of menu bar beneath each control. "*/
#define bottomControlPadding  0

/*" Height of "hot spot" (active clickable area) on controls."*/
#define controlHotSpotHeight 22

/*" Total height of the controlView (in general, equal to menu bar height). "*/
#define controlViewHeight 22

/*" Width in pixels of the "Previous track" button."*/
#define prevButtonWidth  13

/*" Width in pixels of the "Play/Pause" button."*/
#define playButtonWidth 12

/*" Width in pixels of the "Next track" button."*/
#define nextButtonWidth 13

/*" Number of seconds between each iTunes poll. There is a strong argument for
 keeping this value at 10 seconds or more: the polling action can cause iTunes to
 relaunch if it is in the process of shutting down when the message is received.
 To minimise the likelihood of such an undesired effect the interval should be
 kept at a reasonable level (although too high) will cause the updating of tool
 tips and so forth to lag. "*/
#define synergyTimerInterval 3.0


#define synergyAppSignature  'Snrg'

// Class for accessing user defaults from within an app or prefPane bundle
@interface WOPreferences : NSObject {

@private

    NSMutableDictionary *_woDefaultPreferences;
    /*"
     (Private) The default settings as defined in the defaults.plist file. These
     will be used in the absence of user-specified preferences.
    "*/

    NSMutableDictionary *_woPreferencesOnDisk;
    /*"
     (Private) Preferences as read from the disk, and valid at the time of last
     disk access. Any unset values will be supplied from the default
     preferences.
    "*/

@protected

    NSMutableDictionary *woNewPreferences;
    /*"
     The current state of the preferences, which may be modified from their
     original state as read from the disk or supplied by the default preferences
     (hence the name "new").
    "*/
}

//! This is a singleton class and the only supported way of accessing the preferences.
+ (WOPreferences *)sharedInstance;

/*

 Setting up and initialising preferences:

 */

// Reset standardUserDefaults (good to call this before reading from disk)
- (void)resetStandardUserDefaults;

// Initialise defaults reading from "defaults.plist" file in app bundle
- (void)initialiseDefaultsDictionaryFromWithinAppBundle;

// Initialise defaults reading from "defaults.plist" file in prefPane bundle
- (void)initialiseDefaultsDictionaryFromWithinPrefPaneBundle;

// Register the defaults defined in this file with the system
- (void)registerStoredDefaultsWithSystem;

// Read the preferences from the disk (called from inside app bundle)
- (void)readPrefsFromWithinAppBundle;

// Read the preferences from the disk (called from inside prefPane bundle)
- (void)readPrefsFromWithinPrefPaneBundle;

/*

 Writing preferences to disk:

 */

// Flush the preferences to the disk (called from inside prefPane bundle)
- (void)writePrefsFromPrefPaneBundle;

// Flush preferences to disk (called from app... should rarely need to do this!)
- (void)writePrefsFromAppBundle;

/*

 Getting and setting individual objects in preferences:

 */

// Returns (possibly stale) value for to "keyName" (from _woPreferencesOnDisk)
- (id)objectOnDiskForKey:(NSString *)keyName;

// Returns the value from woNewPreferences
- (id)objectForKey:(NSString *)keyName;

// Sets new value in woNewPreferences (syntax identical to NSMutableDictionary)
- (void)setObject:(NSObject *)newObject forKey:(NSString *)newObjectKey;

// As above, sets new value, but flushes it immediately to disk
- (void)setObject:(NSObject *)newObject
           forKey:(NSString *)newObjectKey
 flushImmediately:(BOOL)flush;

/*

 Resetting and manipulating preference dictionaries en masse:

 */

// make "newPreferences" equal to "defaultPreferences"
- (void)resetToDefaults;

// make "newPreferences" equal to "preferencesOnDisk"
- (void)revertToSaved;

/*

 Tests for equality

 */

// test for equality between "newPreferences" and "preferencesOnDisk"
- (BOOL)unsavedChanges;

// test for equality between "newPreferences" and "defaultPreferences"
- (BOOL)preferencesEqualDefaults;

/*

 Low-level accessor methods:

 */
- (NSMutableDictionary *) _woPreferencesOnDisk;
- (NSMutableDictionary *)woNewPreferences;

@end
