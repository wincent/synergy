// SynergyPref.h
// Synergy
//
// Copyright 2002-present Greg Hurrell. All rights reserved.

#import "WOPreferencePane.h"

@class WOPreferences, WOSynergyView, WOKeyCaptureView, WODistributedNotification,
WOSynergyFloaterController, WOSynergyAnchorController, WOAudioscrobblerController;

// status codes for hot key sheet: ok button or cancel button clicked
#define SHEET_OK                                0
#define SHEET_CANCEL                            1

// codes to identify the method calling the hot key sheet
#define NEXT_KEY_METHOD                         1
#define PREV_KEY_METHOD                         2
#define PLAY_KEY_METHOD                         3
#define QUIT_KEY_METHOD                         4
#define SHOW_HIDE_KEY_METHOD                    5

// constants for the behaviour of the scrolling credits
#define WO_CREDITS_SCROLL_TIME_VALUE            0.025   /* every 25 milliseconds */
#define WO_CREDITS_SCROLL_PIXEL_JUMP            1.0     /* move 1 pixel per jump */
#define WO_CREDITS_SCROLL_PAUSE_TIME            5.0     /* pause at top for 5 sec */

// On Leopard we can no longer rely on NSPreferencePane because the PreferencePanes framework is not GC-enabled.
// Have no choice but to roll our own seeing as all the other code depends on GC.
@interface OrgWincentSynergyPref : WOPreferencePane <NSTextFieldDelegate>
{
    // Main view items:
    IBOutlet NSButton           *defaultsButton;
    IBOutlet NSButton           *revertButton;
    IBOutlet NSButton           *applyButton;
    IBOutlet NSTabView          *mainTabView;

    // "General" pane:
    IBOutlet NSButton           *startToggle;
    IBOutlet NSTextField        *startToggleDescription;
    IBOutlet NSButton           *launchAtLogin;
    IBOutlet NSButton           *extraFeedbackToggle;
    IBOutlet NSButton           *showNotificationWindow;
    IBOutlet NSSlider           *floaterDelaySlider;
    IBOutlet NSTextField        *floaterDelayTextField;
    IBOutlet NSSlider           *floaterTransparencySlider;
    IBOutlet NSSlider           *floaterSizeSlider;
    IBOutlet NSButton           *floaterPositionButton;
    IBOutlet NSButton           *includeAlbumInFloaterToggle;
    IBOutlet NSButton           *includeArtistInFloaterToggle;
    IBOutlet NSButton           *includeComposerInFloaterToggle;
    IBOutlet NSButton           *includeDurationInFloaterToggle;
    IBOutlet NSButton           *includeYearInFloaterToggle;
    IBOutlet NSButton           *includeRatingInFloaterToggle;
    IBOutlet NSPopUpButton      *graphicPopUpButton;

    // Floater position sheet:
    IBOutlet id                 floaterPositionSheet;

    // "Hot-keys" pane:
    IBOutlet NSButton           *globalHotKeysToggle;

    IBOutlet NSTextField        *nextKeySetting;
    IBOutlet NSTextField        *playKeySetting;
    IBOutlet NSTextField        *prevKeySetting;
    IBOutlet NSTextField        *quitKeySetting;
    IBOutlet NSTextField        *volumeUpSetting;
    IBOutlet NSTextField        *volumeDownSetting;
    IBOutlet NSTextField        *toggleMuteSetting;
    IBOutlet NSTextField        *toggleShuffleSetting;
    IBOutlet NSTextField        *setRepeatModeSetting;
    IBOutlet NSTextField        *showHideKeySetting;
    IBOutlet NSTextField        *showHideFloaterSetting;
    IBOutlet NSTextField        *rateAs0KeySetting;
    IBOutlet NSTextField        *rateAs1KeySetting;
    IBOutlet NSTextField        *rateAs2KeySetting;
    IBOutlet NSTextField        *rateAs3KeySetting;
    IBOutlet NSTextField        *rateAs4KeySetting;
    IBOutlet NSTextField        *rateAs5KeySetting;
    IBOutlet NSTextField        *activateITunesSetting;
    IBOutlet NSTextField        *decreaseRatingSetting;
    IBOutlet NSTextField        *increaseRatingSetting;

    IBOutlet NSButton           *setNextHotKeyButton;
    IBOutlet NSButton           *setPlayPauseHotKeyButton;
    IBOutlet NSButton           *setPrevHotKeyButton;
    IBOutlet NSButton           *setQuitHotKeyButton;
    IBOutlet NSButton           *setShowHideHotKeyButton;
    IBOutlet NSButton           *setVolumeUpHotKeyButton;
    IBOutlet NSButton           *setVolumeDownHotKeyButton;
    IBOutlet NSButton           *setToggleMuteHotKeyButton;
    IBOutlet NSButton           *setToggleShuffleHotKeyButton;
    IBOutlet NSButton           *setSetRepeatModeSettingHotKeyButton;
    IBOutlet NSButton           *setShowHideFloaterHotKeyButton;
    IBOutlet NSButton           *setRateAs0HotKeyButton;
    IBOutlet NSButton           *setRateAs1HotKeyButton;
    IBOutlet NSButton           *setRateAs2HotKeyButton;
    IBOutlet NSButton           *setRateAs3HotKeyButton;
    IBOutlet NSButton           *setRateAs4HotKeyButton;
    IBOutlet NSButton           *setRateAs5HotKeyButton;
    IBOutlet NSButton           *setActivateITunesHotKeyButton;
    IBOutlet NSButton           *setDecreaseRatingHotKeyButton;
    IBOutlet NSButton           *setIncreaseRatingHotKeyButton;

    // Hot-key customisation sheet:
    IBOutlet id                 hotKeySheet;
    IBOutlet NSButton           *hotKeySheetClearButton;
    IBOutlet NSTextField        *hotKeySheetDescriptionTextField;
    IBOutlet WOKeyCaptureView   *keyCaptureView;

    // "Menu Bar" pane:
    IBOutlet NSButton           *playPauseButtonToggle;
    IBOutlet NSButton           *prevButtonToggle;
    IBOutlet NSButton           *nextButtonToggle;
    IBOutlet NSButton           *controlHidingToggle;
    IBOutlet NSButton           *globalMenuToggle;
    IBOutlet NSButton           *globalMenuOnlyWhenControlsHiddenToggle;
    IBOutlet NSButton           *recentlyPlayedSubmenuToggle;
    IBOutlet NSPopUpButton      *recentlyPlayedPopUp;
    IBOutlet NSButton           *includeArtistInRecentTracksToggle;
    IBOutlet NSButton           *playlistSubmenuToggle;
    IBOutlet NSButton           *launchQuitItemsToggle;
    IBOutlet NSBox              *buttonSpacingBox;
    IBOutlet NSSlider           *buttonSpacingSlider;
    IBOutlet WOSynergyView      *synergyMenuView;
    IBOutlet NSPopUpButton      *buttonStylePopUpButton;

    // "Advanced" pane:
    IBOutlet NSButton           *prevActionToggle;
    IBOutlet NSButton           *randomButtonStyleToggle;
    IBOutlet NSButton           *autoConnectToggle;
    IBOutlet NSButton           *preprocessToggle;
    IBOutlet NSButton           *bringITunesToFrontToggle;
    IBOutlet NSButton           *useNSMenuExtraToggle;

    // "About" pane:
    IBOutlet id                 aboutField;
    IBOutlet NSButton           *payNowButton;
    IBOutlet NSButton           *serialButton;
    IBOutlet NSTextField        *serialStatusTextField;

    // serial number pane
    IBOutlet id                 serialPanel;
    IBOutlet NSButton           *serialPanelOKButton;
    IBOutlet NSTextField        *serialPanelEmailTextField;
    IBOutlet NSTextField        *serialPanelSerialTextField;

    WOPreferences               *synergyPreferences;
    WOSynergyFloaterController  *floaterController;
    WOSynergyAnchorController   *anchorController;

    //////////////////// OLD PREFERENCE MANAGEMENT CODE ////////////////////////
    // storage for the "old" preferences (from disk)
    NSDictionary                *oldPreferences;
    // for default preferences
    NSMutableDictionary         *defaultPreferences;
    // and "new" preferences (in memory)
    NSMutableDictionary         *newPreferences;
    // attempted workaround for bug in isEqualToDictionary
    NSMutableDictionary         *comparisonPreferences; // NSMutableDictionary copy of oldPrefernces
    //////////////////// END OLD PREFERENCE MANAGEMENT CODE ////////////////////

    // state of toggle switch: stopped = NO, started = YES
    BOOL                        startToggleState;

    // used to time delayed fadeout of floater preview
    NSTimer                     *delayedFadeOutTimer;

    // status of exit from hotkey sheet: button: SHEET_CANCEL or SHEET_OK
    int                         hotKeySheetExitStatus;

    // distributed notifications object so we can communicate with app
    WODistributedNotification   *synergyApp;

    // used for keeping local backup copy of floater position etc
    NSPoint                     localWindowOffsetBackup;
    int                         localXScreenSegmentBackup;
    int                         localYScreenSegmentBackup;
    int                         localScreenNumber;

    // for scrolling credits in "About" tab
    NSTimer                     *scrollTimer;
    float                       currentPoint;
    NSSize                      aboutStringSize;
    NSRect                      aboutFieldBounds;

    BOOL                        iTunesSendsNotifications;

    WOAudioscrobblerController  *audioscrobblerController;

    // work around for long-standing Cocoa bug
    BOOL                        enableLastFmLastValue;
    BOOL                        hitAmazonLastValue;
    BOOL                        extraVisualFeedbackForOtherHotKeysValue;
}

// Methods (NSPreferencePane overriddes)

// provide access to global
+ (WOPreferences *)prefs;

// the name says it all
- (void)updateButtonStylePopUp;

// called once view is ready for us to write to it
- (void)mainViewDidLoad;

// called when switching away from pane (via quit or other means)
- (WOPreferencePaneUnselectReply)shouldUnselect;

    //  Internal methods

    // called whenever user clicks "Apply" (in confirmation dialog or in main pane)
- (void) applyChanges;

- (void)calculateSizeAndLocationOfPreview;
- (void)resizeButtonPreview;

// apply preferences to the GUI according to submitted dictionary
- (void) matchInterfaceToDictionary:(NSDictionary*)submittedDictionary;

- (void)updateHotKeySettingControls;

- (void) disableApplyButton;

- (void) enableApplyButton;

- (void) updateApplyButton;

- (void) disableRevertButton;

- (void) enableRevertButton;

- (void) updateRevertButton;

- (void) disableDefaultsButton;

- (void) enableDefaultsButton;

- (void) updateDefaultsButton;

- (void) enablePayNowButton;

- (void) disablePayNowButton;

- (void) makeToggleShowStart;

- (void) makeToggleShowStarting;

- (void) makeToggleShowStop;

- (BOOL) isSynergyRunning;

// DEPRECATED
//- (void) restartSynergy;

- (void) launchSynergy;

- (void) stopSynergy;

// Ghost or enable controlHidingToggle switch depending on other settings
- (void) updateControlHidingToggleStatus;

// Ghost or enable Global Menu item toggles depending on other settings
- (void) updateGlobalMenuStatus;

// Ghost or enable floater-related items depending on floater setting
- (void)updateFloaterControls;

- (void)configureFloater;

//- (void) prepareForExit:(NSNotification*)aNotification;

    // handles user response to confirmation sheet
- (void) sheetButtonClicked:(NSWindow *)sheet
                 returnCode:(int)returnCode
                contextInfo:(void *)contextInfo;

    // Interface Builder connection methods

    // General pane
- (IBAction)applyButtonClicked:(id)sender;
- (IBAction)defaultsButtonClicked:(id)sender;
- (IBAction)launchAtLoginClicked:(id)sender;
- (IBAction)extraFeedbackToggleClicked:(id)sender;
- (IBAction)revertButtonClicked:(id)sender;
- (IBAction)showNotificationClicked:(id)sender;
- (IBAction)startToggleClicked:(id)sender;
- (IBAction)floaterDelaySliderMoved:(id)sender;
- (IBAction)floaterTransparencySliderMoved:(id)sender;
- (IBAction)floaterSizeSliderMoved:(id)sender;
- (IBAction)floaterPositionButtonClicked:(id)sender;
- (IBAction)includeAlbumInFloaterToggleClicked:(id)sender;
- (IBAction)includeArtistInFloaterToggleClicked:(id)sender;
- (IBAction)includeComposerInFloaterToggleClicked:(id)sender;
- (IBAction)includeDurationInFloaterToggleClicked:(id)sender;
- (IBAction)includeYearInFloaterToggleClicked:(id)sender;
- (IBAction)includeRatingInFloaterToggleClicked:(id)sender;
//- (IBAction)colorSchemePopUpButtonChanged:(id)sender;
- (IBAction)buttonStylePopUpButtonChanged:(id)sender;
- (IBAction)graphicPopUpButtonChanged:(id)sender;

// Floater position sheet
- (IBAction)floaterPositionSheetOKButtonClicked:(id)sender;
- (IBAction)floaterPositionSheetCancelButtonClicked:(id)sender;

    // Hot-keys pane
- (IBAction)setNextKeyClicked:(id)sender;
- (IBAction)setPlayKeyClicked:(id)sender;
- (IBAction)setPrevKeyClicked:(id)sender;
- (IBAction)setQuitKeyClicked:(id)sender;
- (IBAction)setShowHideKeyClicked:(id)sender;
- (IBAction)globalHotKeysToggleClicked:(id)sender;
- (IBAction)setVolumeUpKeyClicked:(id)sender;
- (IBAction)setVolumeDownKeyClicked:(id)sender;
- (IBAction)setToggleMuteHotKeyButtonClicked:(id)sender;
- (IBAction)setToggleShuffleHotKeyButtonClicked:(id)sender;
- (IBAction)setSetRepeatModeSettingHotKeyButtonClicked:(id)sender;
- (IBAction)setShowHideFloaterKeyClicked:(id)sender;
- (IBAction)setRateAs0HotKeyButtonClicked:(id)sender;
- (IBAction)setRateAs1HotKeyButtonClicked:(id)sender;
- (IBAction)setRateAs2HotKeyButtonClicked:(id)sender;
- (IBAction)setRateAs3HotKeyButtonClicked:(id)sender;
- (IBAction)setRateAs4HotKeyButtonClicked:(id)sender;
- (IBAction)setRateAs5HotKeyButtonClicked:(id)sender;
- (IBAction)setActivateITunesHotKeyButtonClicked:(id)sender;
- (IBAction)setDecreaseRatingHotKeyButtonClicked:(id)sender;
- (IBAction)setIncreaseRatingHotKeyButtonClicked:(id)sender;

   // Hot-key customisation sheet:
- (IBAction)hotKeySheetCancelButtonClicked:(id)sender;
- (IBAction)hotKeySheetOKButtonClicked:(id)sender;
- (IBAction)hotKeySheetClearButtonClicked:(id)sender;

// serial panel (sheet)
- (IBAction)serialPanelOKButtonClicked:(id)sender;
- (IBAction)serialPanelCancelButtonClicked:(id)sender;
- (void)processSerialPanelResult:(id)panel
                      returnCode:(int)returnCode;

    // and relatedly
- (IBAction)serialButtonClicked:(id)sender;

// delegate methods for serial panel
- (void)controlTextDidChange:(NSNotification *)notification;

// non-IB methods related to the hot-key customisation sheet:
- (void)startHotKeySheet:(id)callingMethod;
- (void)endHotKeySheet;

    // wrapper method for preparing and then showing a hot key sheet; makes the
    // code more readable
- (void)prepareHotKeySheet:(NSString *)identifier
               description:(NSString *)action
           modifierPrefKey:(NSString *)modifier
            keycodePrefKey:(NSString *)keycode
            unicodePrefKey:(NSString *)unicode;

    // another readability method... no functionality, just makes the source look
    // better
- (void)setNewHotKeyPrefWithModifierKey:(NSString *)modifier
                             keycodeKey:(NSString *)keycode
                             unicodeKey:(NSString *)unicode;

    // another readability method... no functionality, just makes the source
    // look better, and less error-prone...
- (void)checkForDuplicateAgainstHotKey:(unsigned int)modifierFlags
                               keycode:(unsigned short)keycode
                       modifierPrefKey:(NSString *)modifierPrefKey
                        keycodePrefKey:(NSString *)keycodePrefKey
                        unicodePrefKey:(NSString *)unicodePrefKey
                         callingMethod:(NSString *)callingMethod
                      comparisonMethod:(NSString *)comparisonMethod
                    targetSettingField:(NSTextField *)targetField;

// method to process the results of the hot-key setting sheet
// check for duplicates, update preferences etc
- (void)processHotKeySheetResult:(id)sheet
                  withReturnCode:(int)returnCode
               fromCallingMethod:(id)callingMethod;

- (void)processMessageFromApp:(NSNotification *)message;

    // Menu Bar pane
    // Menu Bar control buttons:
- (IBAction)playPauseButtonToggleClicked:(id)sender;
- (IBAction)prevButtonToggleClicked:(id)sender;
- (IBAction)nextButtonToggleClicked:(id)sender;
- (IBAction)controlHidingToggleClicked:(id)sender;
- (IBAction)buttonSpacingSliderMoved:(id)sender;
- (IBAction)recentlyPlayedSubmenuToggleClicked:(id)sender;
- (IBAction)recentlyPlayedPopUpChanged:(id)sender;
- (IBAction)includeArtistInRecentTracksToggleClicked:(id)sender;
- (IBAction)playlistSubmenuToggleClicked:(id)sender;
- (IBAction)launchQuitItemsToggleClicked:(id)sender;
- (IBAction)getMoreButtonSets:(id)sender;

    // "Advanced" pane
- (IBAction)prevActionToggleClicked:(id)sender;
- (IBAction)randomButtonStyleToggleClicked:(id)sender;
- (IBAction)autoConnectToggleClicked:(id)sender;
- (IBAction)preprocessToggleClicked:(id)sender;
- (IBAction)bringITunesToFrontToggleClicked:(id)sender;
- (IBAction)audioscrobblerButtonClicked:(id)sender;

// About pane
- (IBAction)weblinkClicked:(id)sender;
- (IBAction)helpButtonClicked:(id)sender;
- (IBAction)payNowButtonClicked:(id)sender;

// generic toggle-handling method
// (all NSButton toggles should pass through this method so as to reduce
// number of methods/connections in Interface Builder)
- (IBAction)toggleClicked:(id)sender;

    // updates the serial, unregister, serial status etc fields
- (void)updateRegistrationObjects;

// stuff that should really be elsewhere!

// eventually move this into another class and make it a factory method
- (unsigned short)unsignedShortValueForHexString:(NSString *)theString;


- (void)setUpDelayedFadeOut;
- (void)cancelDelayedFadeOut;
- (void)performDelayedFadeOut:(NSTimer *)timer;

- (void)processFloaterPositionSheetResult:(id)sheet
                               returnCode:(int)returnCode;

// stores values from preferences in the floater position ivars
- (void)updateFloaterPositionIVars;

// reads vales from floater position ivars and stores them in the preferences
- (void)getFloaterPositionIVars;

// forces the MenuView to adjust to accomodate the new button style...
- (void)changeButtonStyle;

- (void)updateFloaterTooltip;

- (void)enableButtonStylePopUp;
- (void)disableButtonStylePopUp;

    // timer-driven method for scrolling credits in the About Tab
- (void)scrollCredits:(NSTimer *)timer;

// timer-driven check to see if Synergy is still running (updates "Start/Stop"
// button)
- (void)checkSynergyRunning:(NSTimer *)timer;

// check to see if iTunes 4.7 or greater is running
- (BOOL)iTunesSendsNotifications;

@end
