// SynergyController.h
// Synergy
//
// Copyright 2002-2010 Wincent Colaiuta. All rights reserved.

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

#import "Growl/Growl.h"

// used to register Synergy Help with system
@class WOSynergyView, WOPreferences,
WODistributedNotification, WOSynergyFloaterController,
WOFeedbackController, WOAudioscrobblerController, WOAudioscrobbler;

// presets for internal iTunes state variable
#define ITUNES_PAUSED 0
#define ITUNES_PLAYING 1
#define ITUNES_STOPPED 2
#define ITUNES_NOT_RUNNING 3
#define ITUNES_ERROR 4
#define ITUNES_UNKNOWN 5

typedef enum WORepeatMode {

    WORepeatOff = 0,
    WORepeatOne = 1,
    WORepeatAll = 2,
    WORepeatUnknown = 3

} WORepeatMode;

typedef enum WOShuffleState {

    WOShuffleOff = 0,
    WOShuffleOn = 1,
    WOShuffleUnknown = 2

} WOShuffleState;

// This "singleton-like" class does all the real work: we instantiate it once at
// launch from the main nib
@interface SynergyController : NSObject <GrowlApplicationBridgeDelegate>
{
    BOOL waitingForITunesToLaunch;
    // custom view for display of control buttons in menu bar
    IBOutlet WOSynergyView *synergyMenuView;

    //
    WOSynergyFloaterController  *floaterController;

    WOFeedbackController        *feedbackController;

    // last known state of iTunes
    int iTunesState;
    int playerPosition;

    // last known shuffle state of iTunes
    WOShuffleState              shuffleState;

    // last known repeat mode of iTunes
    WORepeatMode                repeatMode;

    // state variable for shown/hidden menu bar controls: YES or NO
    NSNumber *controlButtonsHidden;

    // status item that contains all controls
    NSStatusItem *controlsStatusItem;

    // status item for the global menu
    NSStatusItem *globalMenuStatusItem;

    //image for "next track" button
    NSImage *nextImage;

    //image for "play/pause" button
    NSImage *playPauseImage;

    //image for "previous track" button
    NSImage *prevImage;

    //the menu attached to the status item
    IBOutlet NSMenu *synergyGlobalMenu;

    // convenience pointer for updating contents of iTunes submenu
    IBOutlet NSMenu *iTunesSubmenu;

    // convenience pointer for updating contents of playlists submenu
    IBOutlet NSMenu *playlistsSubmenu;

    // for updating "clear recent tracks"
    IBOutlet NSMenuItem *clearRecentTracksMenuItem;

    // convenience pointer, so we can insert submenus relative to this item
    IBOutlet NSMenuItem *synergyPreferencesMenuItem;

    IBOutlet NSMenuItem *turnFloaterOnOffMenuItem;
    IBOutlet NSMenuItem *toggleAudioscrobblerMenuItem;

    IBOutlet NSMenuItem *buyFromAmazonMenuItem;

    IBOutlet NSMenuItem *transferCoverArtMenuItem;

    // iTunes submenu
    IBOutlet NSMenuItem *shuffleMenuItem;
    IBOutlet NSMenuItem *repeatOffMenuItem;
    IBOutlet NSMenuItem *repeatAllMenuItem;
    IBOutlet NSMenuItem *repeatOneMenuItem;
    IBOutlet NSMenuItem *activateITunesMenuItem;
    IBOutlet NSMenuItem *launchQuitITunesMenuItem;

    //a timer which will let us check iTunes every 10 seconds
    NSTimer *mainTimer;

    //the script to get information from iTunes
    NSAppleScript *getSongInfoScript;

    WOPreferences *synergyPreferences;

    // distributed notifications object so we can communicate with prefPane
    WODistributedNotification *synergyPrefPane;

    //stores info about the songs iTunes has played
    NSMutableArray *songList;

    // used in timer routine to determine if timer loop is a user-generated one
    // eg. due to a button click/hotkey press. or a course-of-nature timer-
    // generated one
    BOOL buttonClickOccurred;

    // used in timer routine -- when YES, send messages to floater (an easy
    // way to turn off floater when requested by prefPane is just to set this
    // to NO).
    BOOL sendMessagesToFloater;

    // used when floater is in "always" on mode to ensure that floater stays
    // off (or stays on) when user presses show/hide hot key
    // set ON/OFF as user presses show/hide hot key
    BOOL floaterActive;

    // internal record of how many segments are "lit" in the volume feedback
    int segmentCount;
    int iTunesVolume;

    // number of seconds between polling iTunes
    float communicationInterval; // use a float here because that's what NSTimer wants

    // temporary storage if user tries to play a song and iTunes not running
    NSAppleEventDescriptor  *songToPlayOnceLaunched;

    // true for iTunes 4.7 and up
    BOOL iTunesSendsNotifications;

    NSString *lastKnownTrackIdentifier;

    NSArray *trackChangeLaunchItems;

    //! Set to YES when user double-clicks a button set in the Finder
    BOOL    switchToNewSet;

    //! handles reading in account creditials from disk etc
    WOAudioscrobblerController  *audioscrobblerController;

    //! object that serves as a proxy for communicating with last.fm
    WOAudioscrobbler            *audioscrobbler;

    // new in 4.2b
    BOOL                        hitAmazon;

    // new in 4.4b
    BOOL                        extraFeedback;
}

// returns a pointer to our instantiation (created in Interface Builder)
+ (id)sharedInstance;

- (void)processMessageFromPrefPane:(NSNotification *)message;

//called when mainTimer fires, handles periodic communication with iTunes
- (void)timer:(NSTimer *)timer;

// methods for telling iTunes to perform an action
- (void)tellITunesPlayPause;
- (void)tellITunesNext;
- (void)tellITunesFastForward;
- (void)tellITunesRewind;
- (void)tellITunesPrev;
- (void)tellITunesResume;

// tell iTunes to up the volume by 10%
- (void)tellITunesVolumeUp;

// tell iTunes to reduce the volume by 10%
- (void)tellITunesVolumeDown;

- (void)updateTooltip:(NSString *)tooltipString;

- (void)switchToPauseImage;
- (void)switchToPlayImage;
- (void)switchToPlayPauseImage;

- (void)hidePlayPauseButton;
- (void)showPlayPauseButton;

- (void)hidePrevButton;
- (void)showPrevButton;

- (void)hideNextButton;
- (void)showNextButton;

- (void)hideGlobalMenu;
- (void)showGlobalMenu;

- (void)showHideHotKeyPressed;

- (void)volumeUpHotKeyPressed;

- (void)volumeDownHotKeyPressed;

// called when user presses "Show floater" Hot Key
- (void)showHideFloaterHotKeyPressed;

- (void)hideControlsStatusItem;
- (void)showControlsStatusItem;
- (void)updateAndResizeControlsStatusItem;

- (void)showPlayPauseButtonImage;
- (void)hidePlayPauseButtonImage;

- (void)showPrevButtonImage;
- (void)hidePrevButtonImage;

- (void)showNextButtonImage;
- (void)hideNextButtonImage;

//sync songList and theMenu
- (void)updateMenu;

- (void)addGlobalMenu;
- (void)removeGlobalMenu;

//tells iTunes to play song that the user selected from the menu
- (IBAction)playSong:(id)sender;

//clears songs from theMenu and songList
- (IBAction)clearRecentSongsMenuItem:(id)sender;

//opens the preferences window (System Preferences app)
- (IBAction)openPrefsMenuItem:(id)sender;

- (IBAction)shuffleMenuItem:(id)sender;
- (IBAction)repeatOffMenuItem:(id)sender;
- (IBAction)repeatAllMenuItem:(id)sender;
- (IBAction)repeatOneMenuItem:(id)sender;

- (IBAction)activateITunesMenuItem:(id)sender;

- (IBAction)quitLaunchITunesMenuItem:(id)sender;
- (IBAction)refreshPlaylistsSubmenu:(id)sender;
- (IBAction)quitSynergyMenuItem:(id)sender;

- (IBAction)turnFloaterOnOff:(id)sender;
- (IBAction)toggleAudioscrobbler:(id)sender;
- (IBAction)buyFromAmazon:(id)sender;

- (IBAction)showAlbumCoversFolder:(id)sender;

- (void)playPause:(id)sender;

//tell iTunes to play the next track
- (void)nextTrack:(id)sender;

//tell iTunes to play the previous track
- (void)prevTrack:(id)sender;

// after reading preferences, tell floater how we want it to appear
- (void)configureFloater;

// House-keeping prior to exit
- (void)cleanupBeforeExit;

- (void)launchITunes;

- (void)iTunesDidLaunchNowPlay:(NSNotification *)notification;

- (void)updateFloaterStrings:(NSString *)songTitle
                       album:(NSString *)albumName
                      artist:(NSString *)artistName
                    composer:(NSString *)composerName;

// these methods called so that we have a distinction between a button press
// and a hot key click
- (void)playPauseHotKeyPressed;
- (void)nextHotKeyPressed;
- (void)prevHotKeyPressed;

- (void)fastForwardHotKeyPressed;
- (void)fastForwardHotKeyReleased;
- (void)rewindHotKeyPressed;
- (void)rewindHotKeyReleased;

- (void)rateAs0HotKeyPressed;
- (void)rateAs1HotKeyPressed;
- (void)rateAs2HotKeyPressed;
- (void)rateAs3HotKeyPressed;
- (void)rateAs4HotKeyPressed;
- (void)rateAs5HotKeyPressed;

- (void)toggleMuteHotKeyPressed;
- (void)toggleShuffleHotKeyPressed;
- (void)setRepeatModeHotKeyPressed;

- (void)activateITunesHotKeyPressed;

- (void)decreaseRatingHotKeyPressed;
- (void)increaseRatingHotKeyPressed;

// slave method that does all the heavy lifting for setting song ratings
- (BOOL)setRating:(int)newRating;

- (void)tellITunesToPlaySong:(NSAppleEventDescriptor *)descriptor;

- (void)tellITunesToggleMute;
- (void)tellITunesToggleShuffle;
- (void)tellITunesSetRepeatMode;

// for bringing iTunes to the front or hiding it
- (void)tellITunesActivate;
- (void)hideITunes;

// make sure iTunes is running and ready to process Apple Events before firing
// off our status script
- (BOOL)iTunesReadyToReceiveAppleScript;

- (NSString *)chooseRandomButtonSet;

// called when download is completed in separate thread
- (void)coverDownloadDone:(NSNotification *)notification;

// true for iTunes 4.7 and up
- (BOOL)iTunesSendsNotifications;

// track change launch items support
- (NSString *)applicationSupportPath:(int)domain;
- (NSArray *)getTrackChangeItems:(int)domain;
- (NSArray *)getTrackChangeItems;
- (void)launchTrackChangeItems:(NSArray *)paths;

- (IBAction)transferCoverArtToITunes:(id)sender;

// accessors

- (BOOL)hitAmazon;

// temporary storage for song id (used while waiting for iTunes to launch)
- (void)setSongToPlayOnceLaunched:(NSAppleEventDescriptor *)songId;
- (NSAppleEventDescriptor *)songToPlayOnceLaunched;

- (NSArray *)trackChangeLaunchItems;
- (void)setTrackChangeLaunchItems:(NSArray *)aTrackChangeLaunchItems;

// refactoring for sending simple Apple Events to iTunes
- (void)sendAppleEventClass:(AEEventClass)eventClass ID:(AEEventID)eventID;

#pragma mark GrowlApplicationBridgeDelegate protocol

- (NSDictionary *)registrationDictionaryForGrowl;

#pragma mark -

@end


