// SynergyController.m
// Copyright 2002-present Greg Hurrell. All rights reserved.

// system headers
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <sys/types.h>
#import <unistd.h>

// other headers
#import "iTunes.h"
#import "WOSynergyGlobal.h"
#import "SynergyController.h"
#import "HotkeyCapableApplication.h"
#import "WODebug.h"
#import "WODistributedNotification.h"
#import "WOPreferences.h"
#import "WOSynergyView.h"
#import "WOCarbonWrappers.h"
#import "WOSynergyFloaterController.h"
#import "WOFeedbackController.h"
#import "WOProcessManager.h"
#import "WOCoverDownloader.h"
#import "WOExceptions.h"
#import "WOSongInfo.h"
#import "WOAudioscrobblerController.h"

// categories
#import "NSAppleScript+WOAdditions.h"
#import "NSImage+WOAdditions.h"
#import "WONSFileManagerExtensions.h"
#import "WONSStringExtensions.h"
#import "SynergyController+WOAudioscrobbler.h"

#import "WOButtonSet.h"

// WOPublic macro headers
#import "WOPublic/WOConvenienceMacros.h"

// WOPublic category headers
#import "WOPublic/NSDictionary+WOCreation.h"

#pragma mark -
#pragma mark Macros

// macros for keys in a "songDictionary" (identifying info for a song)
#define WO_SONG_DICTIONARY_ID       @"_woSongDictionaryId"
#define WO_SONG_DICTIONARY_TITLE    @"_woSongDictionaryTitle"
#define WO_SONG_DICTIONARY_ARTIST   @"_woSongDictionaryArtist"

// added support for amazon.com "Buy now" link storage
#define WO_SONG_DICTIONARY_BUY_NOW  @"_woSongDictionaryBuyNow"
#define WO_SONG_DICTIONARY_SONGINFO @"_woSongDictionarySongInfo"

// preferences managed via Cocoa Bindings
#define WO_EXTRA_VISUAL_FEEDBACK_OTHER CFSTR("ExtraVisualFeedbackForOtherHotKeys")

// these are all stored in SynergyPreferences domain (corresponding to wrapper app)
#define WO_SYNERGY_PREFERENCES_DOMAIN CFSTR("com.wincent.SynergyPreferences")

#pragma mark -
#pragma mark Global variables

static id   _sharedSynergyController                = nil;
NSString    *applicationOpenFileValueReceivedEarly  = nil;

// and the variables used internally to hold the numbers
UInt32      quitCode;
UInt32      playCode;
UInt32      prevCode;
UInt32      nextCode;
UInt32      widthCode;

#pragma mark Private methods

@interface SynergyController ()

- (NSString *)audioscrobblerMenuTitleForState:(BOOL)enabled;

@end

#pragma mark -

// This "singleton-like" class does all the real work: we instantiate it once at
// launch-time from the main nib
@implementation SynergyController

// returns a pointer to our instantiation
+ (id) sharedInstance
{
    if (_sharedSynergyController != nil)
        // We should have already been allocated in the +initialize method
        return _sharedSynergyController;
    else
        // if not allocated, self-allocate now
        return        [self init];
}

// This method called on startup after "initialize", next comes "awakeFromNib"
- (id) init
{
    if (_sharedSynergyController == nil)
    {
        // First entry into init
        self = [super init];
        _sharedSynergyController = self;

        NSURL *url = [NSURL fileURLWithPath:
            [[[NSBundle mainBundle] resourcePath]
            stringByAppendingPathComponent:@"Scripts/getSongInfo.scpt"] ];

        getSongInfoScript = [[NSAppleScript alloc] initWithContentsOfURL:url error:nil];

        songList = [[NSMutableArray alloc] init];

        controlButtonsHidden = [NSNumber numberWithBool:YES];

        floaterController = [[WOSynergyFloaterController alloc] init];

        // this next line calls awakeFromNib on floaterController
        if(![NSBundle loadNibNamed:@"synergyFloater" owner:floaterController])
        {
            ELOG(@"An error occurred while trying to load the nib file for the "
                 @"floating notification window");
        };
        // so we now have an instance called floaterController to which we can
        // send messages

        feedbackController = [[WOFeedbackController alloc] init];

        // this next line calls awakeFromNib on feedbackController
        if (![NSBundle loadNibNamed:@"feedback" owner:feedbackController])
        {
            ELOG(@"An error occurred while trying to load the nib file for the "
                 @"feedback window");
        }

        // set iTunes state variable to "unknown" before firing timer for first time:
        iTunesState     = ITUNES_UNKNOWN;
        shuffleState    = WOShuffleUnknown;
        repeatMode      = WORepeatUnknown;

        Boolean keyExistsAndHasValidFormat;
        Boolean boolCF = CFPreferencesGetAppBooleanValue((CFStringRef)@"hitAmazon",
                                                         WO_SYNERGY_PREFERENCES_DOMAIN,
                                                         &keyExistsAndHasValidFormat);
        hitAmazon = !(keyExistsAndHasValidFormat && !boolCF);
        boolCF = CFPreferencesGetAppBooleanValue(WO_EXTRA_VISUAL_FEEDBACK_OTHER,
                                                 WO_SYNERGY_PREFERENCES_DOMAIN,
                                                 &keyExistsAndHasValidFormat);
        extraFeedback = !(keyExistsAndHasValidFormat && !boolCF);
    }
    else
        // init has been called more than once
        self = _sharedSynergyController;

    return self;
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    NSString *baseName = [[filename lastPathComponent] stringByDeletingPathExtension];

    switchToNewSet = YES;

    // check if button set of same name already in place
    if (![[WOButtonSet availableButtonSets] containsObject:baseName])
    {
        // attempt to copy to ~/Application Support/Synergy/Button Sets
        NSString *installPath = [WOButtonSet installPath];

        if (!installPath) return NO; // target dir couldn't be created

        NSString *destination = [installPath stringByAppendingPathComponent:[filename lastPathComponent]];
        switchToNewSet = [[NSFileManager defaultManager] copyItemAtPath:filename
                                                                 toPath:destination
                                                                  error:NULL];
    }

    if (switchToNewSet)
    {
        // try to set as current button set
        if (synergyPreferences) // have already gone thorough "awakeFromNib"
        {
            [synergyPreferences setObject:baseName forKey:_woButtonStylePrefKey flushImmediately:YES];

            // trick self into re-reading prefs
            [self processMessageFromPrefPane:
                [NSNotification notificationWithName:WODistributedNotificationIdentifier
                                              object:[NSString stringWithFormat:@"%d", WODNAppReadPrefs]]];

            [[NSDistributedNotificationCenter
                defaultCenter] postNotificationName:WODistributedNotificationIdentifier
                                             object:[NSString stringWithFormat:@"%d", WODNPrefNoteButtonSetLoaded]
                                           userInfo:[NSDictionary dictionaryWithObject:baseName forKey:@"setName"]];
        }
        else
            // store this in a global var for later
            applicationOpenFileValueReceivedEarly = [baseName copy];
    }

    return switchToNewSet;
}

- (void)awakeFromNib
{
    [self setTrackChangeLaunchItems:[self getTrackChangeItems]];

    // my testing shows that this method will be called before the corresponding method in HotKeyCapableApplication:
    // but shouldn't rely on that
    // this WOPreferences class is really just a dumb wrapper for NSUserDefaults; I'd be better off without it
    synergyPreferences = [WOPreferences sharedInstance];

    [synergyPreferences readPrefsFromWithinAppBundle];

    // now that we've read the prefs... make sure the menu bar controls are
    // going to use the correct button style
    NSString *newButtonSet;

    if ([[synergyPreferences objectOnDiskForKey:_woRandomButtonStylePrefKey] boolValue] == NO)
        // make sure we're using the correct button set
        newButtonSet = [synergyPreferences objectOnDiskForKey:_woButtonStylePrefKey];
    else
        // choose a random button set
        newButtonSet = [self chooseRandomButtonSet];

    // but check to see if a user double-clicked on a set in the Finder
    if (applicationOpenFileValueReceivedEarly)
    {
        newButtonSet = applicationOpenFileValueReceivedEarly;
        applicationOpenFileValueReceivedEarly = nil;
        [synergyPreferences setObject:newButtonSet forKey:_woButtonStylePrefKey flushImmediately:YES];
        [synergyPrefPane notifyPrefPane:WODNPrefNoteButtonSetLoaded];
    }

    if (newButtonSet != nil)
        [synergyMenuView setButtonSet:newButtonSet];
    else
        [synergyMenuView setButtonSet:WO_DEFAULT_BUTTON_SET];

    // set to starting values
    buttonClickOccurred = NO;
    sendMessagesToFloater = YES;
    segmentCount = 0;
    iTunesVolume = 0;
    [self setSongToPlayOnceLaunched:nil];
    floaterActive = YES;

    [self refreshPlaylistsSubmenu:nil];

    // use prefs read from disk to configure floater appearance
    [self configureFloater];

    // making ourself the NSApplication delegate enables us to receive
    // NSApplicationDidChangeScreenParametersNotification notifications
    [NSApp setDelegate:self];

    // coerce int to float
    communicationInterval =
        [[synergyPreferences objectOnDiskForKey:_woCommunicationIntervalPrefKey] floatValue];

    if (communicationInterval < WO_MIN_POLLING_INTERVAL)
        communicationInterval = WO_MIN_POLLING_INTERVAL;

    if (communicationInterval > WO_MAX_POLLING_INTERVAL)
        communicationInterval = WO_MAX_POLLING_INTERVAL;

    if ([self iTunesSendsNotifications])
    {
        [GrowlApplicationBridge setGrowlDelegate:self];

        // watch for launch/quit events of iTunes, seeing as we won't be polling
        NSNotificationCenter *center =
            [[NSWorkspace sharedWorkspace] notificationCenter];
        [center addObserver:self
                   selector:@selector(handleWorkspaceNotification:)
                       name:@"NSWorkspaceDidLaunchApplicationNotification"
                     object:nil];
        [center addObserver:self
                   selector:@selector(handleWorkspaceNotification:)
                       name:@"NSWorkspaceDidTerminateApplicationNotification"
                     object:nil];

        // keep timer intact, but with a ridiculously long interval
        communicationInterval = 60.0 * 60.0 * 24.0 * 30.0 ; // once per month
    }

    // register for notifications regardless
    [[NSDistributedNotificationCenter
        defaultCenter] addObserver:self
                          selector:@selector(handleNotification:)
                              name:@"com.apple.iTunes.playerInfo"
                            object:nil];

    mainTimer = [NSTimer scheduledTimerWithTimeInterval:communicationInterval
                                                  target:self
                                                selector:@selector(timer:)
                                                userInfo:nil
                                                 repeats:YES];



    globalMenuStatusItem = nil;


//    }

    // send this message regardless of whether global menu is a separate
    // NSStatusItem or integrated into play/pause button
    [synergyGlobalMenu setAutoenablesItems:NO];

    // always ghost the "Recent tracks" header; again this is ugly, will fix it later
    int indexOfRecentTracks = [synergyGlobalMenu indexOfItem:clearRecentTracksMenuItem];
    if (indexOfRecentTracks == 1)
        [[synergyGlobalMenu itemAtIndex:0] setEnabled:NO];

    [toggleAudioscrobblerMenuItem setTitle:[self audioscrobblerMenuTitleForState:[self audioscrobblerEnabled]]];

    if(([[synergyPreferences objectOnDiskForKey:_woPlayButtonInMenuPrefKey] boolValue] == NO) &&
       ([[synergyPreferences objectOnDiskForKey:_woPrevButtonInMenuPrefKey] boolValue] == NO) &&
       ([[synergyPreferences objectOnDiskForKey:_woNextButtonInMenuPrefKey] boolValue] == NO))
    {
        // user doesn't want to show any buttons
        if ([[synergyPreferences objectOnDiskForKey:_woGlobalMenuPrefKey] boolValue])
            // but they do want to show the global menu
            [self addGlobalMenu];
    }
    else
    {
        // user may wish to show global menu anyway:
        if (([[synergyPreferences objectOnDiskForKey:_woGlobalMenuPrefKey] boolValue]) &&
            ([[synergyPreferences objectOnDiskForKey:_woGlobalMenuOnlyWhenHiddenPrefKey] boolValue] == NO))
            [self addGlobalMenu];

        [self showControlsStatusItem];
    }

    // set up link with prefPane
    synergyPrefPane = [WODistributedNotification makePrefPaneObserver:self selector:@selector(processMessageFromPrefPane:)];

    // tell prefPane we're running (also happens when we fire timer)
    [synergyPrefPane notifyPrefPane:WODNAppLaunched];

    // update auto-connect setting
    [WOCoverDownloader setConnectOnDemand:[[synergyPreferences objectOnDiskForKey:_woAutoConnectTogglePrefKey] boolValue]];

    // update "pre-process" setting
    [WOCoverDownloader setPreprocess:[[synergyPreferences objectOnDiskForKey:_woPreprocessTogglePrefKey] boolValue]];

    // register for notifications of cover download completions
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(coverDownloadDone:)
                                                 name:WO_DOWNLOAD_DONE_NOTIFICATION
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(coverDownloadDone:)
                                                 name:WO_BUY_NOW_LINK_NOTIFICATION
                                               object:nil];

    [mainTimer fire];

    // let the category handle this
    [self audioscrobblerReadPreferences];
}

/*
 This is one hell of an ugly and long routine:

 to fix:

 make a category for NSMenu and/or NSMenuItem which enables easy:
 (or a subclass if necessary)

 hide/show of submenus
 hide/show of menuitems (as opposed to removing and destroying them, or ghosting them)

 "chaining" of items and separators
 eg. separator S, items X, Y, Z
 chain S to X-Y-Z
 so S will appear before X-Y-Z, or Y-Z, or X etc
 instead of all those complicated tests about whether stuff should be added...

 */
- (void)addGlobalMenu
{
    [synergyGlobalMenu setMenuChangedMessagesEnabled:NO];

    globalMenuStatusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];

    // may have to turn highlighting off and do own highlighting (because
    // currently the graphic remains black, instead of turning white like
    // NSMenuExtras do)
    [globalMenuStatusItem setHighlightMode:YES];

#ifdef WO_GLOBAL_MENU_USES_UNICODE_CHAR

    [globalMenuStatusItem setTitle:[NSString stringWithFormat:@"%C",WO_GLOBAL_MENU_UNICODE_CHAR]];

#else

    [globalMenuStatusItem setImage:[NSImage imageNamed:@"musicGlyph.png"]];

    // doesn't work! (yet another NSStatusItem/NSMenuExtra distinction)
    //[globalMenuStatusItem setAlternateImage:
    //    [NSImage imageNamed:@"musicGlyphSelected.png"]];

    // We have an (unpleasant) choice here:
    // 1. Do some nasty, undocumented hackery of the kind described here:
    //  http://cocoa.mamasam.com/COCOADEV/2003/02/1/56710.php
    // (posing as NSStatusBarButtonCell)
    //
    // 2. Break Apple's stuff and kludge Synergy to use NSMenuExtra instead
    // of NSStatusItem




#endif

    [globalMenuStatusItem setMenu:synergyGlobalMenu];
    [globalMenuStatusItem setEnabled:YES];

    // try this to make our disable/enabled changes stick:
    [synergyGlobalMenu setAutoenablesItems:NO];
    /*

     If autoenablesItems is left at the default value of YES, then Cocoa ignores
     any values set using setEnabled; an IB connection is enough to force an
     item to be always enabled.

     */

    // make sure "Recent tracks" label is disabled:
    [[[synergyGlobalMenu itemArray] objectAtIndex:0] setEnabled:NO];

    // find out the index of the playlists submenu (will be -1 if removed)
    int playlistsSubmenuIndex = [synergyGlobalMenu indexOfItemWithSubmenu:playlistsSubmenu];

    // pointer to the NSMenuItem containing our submenu; static because we want to use it across multiple invocations of this method
    static id playlistsMenuItem;

    // hide playlists Submenu if necessary
    if ([[synergyPreferences objectOnDiskForKey:_woPlaylistsSubmenuPrefKey] boolValue] == NO)
    {
        // test to see if we've already been removed on a previous pass
        if (playlistsSubmenuIndex != -1)
        {
            // we've been removed previously -- ok to proceed

            // this is a pointer to the NSMenu object that contains the submenu
            playlistsMenuItem = [synergyGlobalMenu itemAtIndex:playlistsSubmenuIndex];

            [synergyGlobalMenu removeItem:playlistsMenuItem];

            // remove separator above submenu if there is one there (and there always will be)
            if ([[synergyGlobalMenu itemAtIndex:(playlistsSubmenuIndex -1)] isSeparatorItem])
                [synergyGlobalMenu removeItem:[synergyGlobalMenu itemAtIndex:(playlistsSubmenuIndex -1)]];
        }
    }
    else
    {
        // prefs tell us to add submenu back in if it's been removed...

        // test to see if we've already been removed on a previous pass
        if (playlistsSubmenuIndex == -1)
        {
            // appear two places above prefs item if iTunes menu is present or one place above it if not
            int destinationIndex;

            if ([synergyGlobalMenu indexOfItemWithSubmenu:iTunesSubmenu] != -1)
                // bumped upwards by 1 for 2.9 ("Transfer cover to iTunes" menu item)
                destinationIndex = [synergyGlobalMenu indexOfItem:synergyPreferencesMenuItem] - 8;
            else
                // bumped upwards by 1 for 2.9 ("Transfer cover to iTunes" menu item)
                destinationIndex = [synergyGlobalMenu indexOfItem:synergyPreferencesMenuItem] - 7;

            // because of removal on previous pass, playlistsMenuItem will contain a pointer to the removed item
            [synergyGlobalMenu insertItem:playlistsMenuItem atIndex:destinationIndex];

            // restore separator (above submenu) as well if it is missing
            // note that we can always assume destinationIndex - 1 to be positive
            // because the first couple of slots are always the recent tracks and clear recent tracks items
            if([[synergyGlobalMenu itemAtIndex:(destinationIndex - 1)] isSeparatorItem] == NO)
                [synergyGlobalMenu insertItem:[NSMenuItem separatorItem] atIndex:destinationIndex];
        }
    }

    // find out the index of the iTunes submenu (will be -1 if removed)
    int iTunesSubmenuIndex = [synergyGlobalMenu indexOfItemWithSubmenu:iTunesSubmenu];

    // pointer to the NSMenuItem containing our submenu; static because we want to use it across multiple invocations of this method
    static id iTunesMenuItem;

    // hide iTunes submenu if necessary
    if ([[synergyPreferences objectOnDiskForKey:_woLaunchQuitItemsPrefKey] boolValue] == NO)
    {
        // test to see if we've already been removed on a previous pass
        if (iTunesSubmenuIndex != -1)
        {
            // we've been removed previously -- ok to proceed

            // this is a pointer to the NSMenu object that contains the submenu
            iTunesMenuItem = [synergyGlobalMenu itemAtIndex:iTunesSubmenuIndex];
            [synergyGlobalMenu removeItem:iTunesMenuItem];

            // remove separator above submenu if there is one there
            if ([[synergyGlobalMenu itemAtIndex:(iTunesSubmenuIndex - 1)] isSeparatorItem])
                [synergyGlobalMenu removeItem:[synergyGlobalMenu itemAtIndex:(iTunesSubmenuIndex - 1)]];
            /*

             or:

             action for removing either submenus:
             remove sep if there's a sep above

             action for adding playlists submenu:
             add sep if there isn't one above (there might be if iTunes add one before!)

             action called whenever iTunes sub is visible eg. when added, or when left on:
             add sep if there isn't one above & playlists sub is active

             */
        }
    }
    else
    {
        // prefs tell us to add submenu back in if it's been removed...

        // test to see if we've already been removed on a previous pass
        if (iTunesSubmenuIndex == - 1)
        {
            // appear one places above prefs item
            // bumped upwards by 1 for 2.9 ("Transfer cover to iTunes" menu item)
            int destinationIndex = ([synergyGlobalMenu indexOfItem:synergyPreferencesMenuItem] - 7);

            // because of removal on previous pass, iTunesMenuItem will contain a pointer to the removed item
            [synergyGlobalMenu insertItem:iTunesMenuItem atIndex:destinationIndex];
        }

        // update value of iTunesSubmenuIndex (will be different if we just re-inserted the menu)
        iTunesSubmenuIndex =
        [synergyGlobalMenu indexOfItemWithSubmenu:iTunesSubmenu];

        // make sure there's a separator above if one is required
        if (iTunesSubmenuIndex != -1)
        {
            // iTunes submenu is now present (either re-enabled, or still enabled)
            if (([synergyGlobalMenu indexOfItemWithSubmenu:playlistsSubmenu] == -1) &&
                ([[synergyGlobalMenu itemAtIndex:(iTunesSubmenuIndex - 1)] isSeparatorItem] == NO))
            {
                // iTunes menu is there, playlists submenu not there, and there is
                // no sep above, so add one
                [synergyGlobalMenu insertItem:[NSMenuItem separatorItem]
                                      atIndex:iTunesSubmenuIndex];

            }
        }
    }

    // need to make sure that changing the title of iTunes launched/not launched
    // doesn't crash us when the menu is in its removed state
    [synergyGlobalMenu setMenuChangedMessagesEnabled:YES];

    // this ensure things like our preferences for display/non-display of
    // recently-played tracks are picked up immediately.
    [self updateMenu];
}

- (void)removeGlobalMenu
{
    [[NSStatusBar systemStatusBar] removeStatusItem:globalMenuStatusItem];
    globalMenuStatusItem = nil;
}

- (void)processMessageFromPrefPane:(NSNotification *)message
{
    if ([[message object] isEqualToString:[NSString stringWithFormat:@"%d", WODNAppStatus]])
    {
        // tell prefPane that we are running
        [synergyPrefPane notifyPrefPane:WODNAppIsRunning];

        // update state variable to reflect that the prefPane is also running
        [synergyPrefPane setPrefPaneState:WODNRunning];
    }

    if ([[message object] isEqualToString:[NSString stringWithFormat:@"%d", WODNPaneLaunched]])
    {
        // tell prefPane that we are running
        [synergyPrefPane notifyPrefPane:WODNAppIsRunning];

        // update state variable to reflect that the prefPane is also running
        [synergyPrefPane setPrefPaneState:WODNRunning];
    }

    if ([[message object] isEqualToString:[NSString stringWithFormat:@"%d", WODNPaneIsRunning]])
    {
        // update state variable to reflect that the prefPane is also running
        [synergyPrefPane setPrefPaneState:WODNRunning];
    }

    if ([[message object] isEqualToString:[NSString stringWithFormat:@"%d", WODNPaneWillQuit]])
    {
        // update state variable to reflect that the prefPane has quit
        [synergyPrefPane setPrefPaneState:WODNStopped];
    }

    if ([[message object] isEqualToString:[NSString stringWithFormat:@"%d", WODNAppReadPrefs]])
    {
        // tell prefPane that we are (still) running
        [synergyPrefPane notifyPrefPane:WODNAppIsRunning];

        // update state variable to reflect that the prefPane is also running
        [synergyPrefPane setPrefPaneState:WODNRunning];

        [NSApp unregisterHotkeys];

        // let the category handle this
        [self audioscrobblerReadPreferences];

        [self hideControlsStatusItem];

        if (globalMenuStatusItem != nil)
            [self removeGlobalMenu];

        /*
         I can write the new prefs out to disk and see them change by looking at the
         plist file; but when I look at the log output I see that the app
         rereads them only the first time and not subsequent times.
         */
        [synergyPreferences resetStandardUserDefaults]; // try to beat the cache problem (works)

        [synergyPreferences readPrefsFromWithinAppBundle]; // this class

        NSString *newButtonSet;

        // new: test switchToNewSet; fixes bug: http://wincent.com/a/support/bugs/show_bug.cgi?id=442
        if (([[synergyPreferences objectOnDiskForKey:_woRandomButtonStylePrefKey] boolValue] == NO) || switchToNewSet)
        {
            // make sure we're using the correct button set
            newButtonSet    = [synergyPreferences objectOnDiskForKey:_woButtonStylePrefKey];
            switchToNewSet  = NO;
        }
        else    // choose a random button set
            newButtonSet = [self chooseRandomButtonSet];

        [synergyMenuView setButtonSet:newButtonSet ? newButtonSet : WO_DEFAULT_BUTTON_SET];
        [WOCoverDownloader setConnectOnDemand:[[synergyPreferences objectOnDiskForKey:_woAutoConnectTogglePrefKey] boolValue]];
        [WOCoverDownloader setPreprocess:[[synergyPreferences objectOnDiskForKey:_woPreprocessTogglePrefKey] boolValue]];

        // only bother to show the status item if at least one button is enabled
        if(([[synergyPreferences objectOnDiskForKey:_woPlayButtonInMenuPrefKey] boolValue]) ||
           ([[synergyPreferences objectOnDiskForKey:_woPrevButtonInMenuPrefKey] boolValue]) ||
           ([[synergyPreferences objectOnDiskForKey:_woNextButtonInMenuPrefKey] boolValue]))
        {
            // if user wants the global menu at all times, show it
            if  ([[synergyPreferences objectOnDiskForKey:_woGlobalMenuPrefKey] boolValue] &&
                 ([[synergyPreferences objectOnDiskForKey:_woGlobalMenuOnlyWhenHiddenPrefKey] boolValue] == NO))
                [self addGlobalMenu];

            [self showControlsStatusItem];
        }
        else
        {
            // only show the global menu if the user wants it
            if ([[synergyPreferences objectOnDiskForKey:_woGlobalMenuPrefKey] boolValue])
                [self addGlobalMenu];
        }

        // reconfigure floater with current prefs vals
        [self configureFloater];

        // coerce int to float
        communicationInterval = [[synergyPreferences objectOnDiskForKey:_woCommunicationIntervalPrefKey] floatValue];

        if (communicationInterval < WO_MIN_POLLING_INTERVAL)
            communicationInterval = WO_MIN_POLLING_INTERVAL;

        if (communicationInterval > WO_MAX_POLLING_INTERVAL)
            communicationInterval = WO_MAX_POLLING_INTERVAL;

        if ([self iTunesSendsNotifications])
            // keep timer intact, but with a ridiculously long interval
            communicationInterval = 60.0 * 60.0 * 24.0 * 30.0 ; // once/month

        // change timer interval if necessary
        if ([mainTimer timeInterval] != communicationInterval)
        {
            // destroy the old timer
            [mainTimer invalidate];

            // and create a new one
            mainTimer = [NSTimer scheduledTimerWithTimeInterval:communicationInterval
                                                          target:self
                                                        selector:@selector(timer:)
                                                        userInfo:nil
                                                         repeats:YES];
        }

        [NSApp registerHotkeys];
    }

    if ([[message object] isEqualToString:[NSString stringWithFormat:@"%d", WODNAppQuit]])
    {
        [self cleanupBeforeExit]; // this will work
        exit(0); // this ugly old way...
    }

    if ([[message object] isEqualToString:[NSString stringWithFormat:@"%d", WODNAppUnregisterHotkeys]])
    {
        // tell prefPane that we are (still) running
        [synergyPrefPane notifyPrefPane:WODNAppIsRunning];

        // update state variable to reflect that the prefPane is also running
        [synergyPrefPane setPrefPaneState:WODNRunning];

        // unregister hotkeys
        [NSApp unregisterHotkeys];
    }

    if ([[message object] isEqualToString:[NSString stringWithFormat:@"%d", WODNAppRegisterHotkeys]])
    {
        // tell prefPane that we are (still) running
        [synergyPrefPane notifyPrefPane:WODNAppIsRunning];

        // update state variable to reflect that the prefPane is also running
        [synergyPrefPane setPrefPaneState:WODNRunning];

        // register hotkeys
        [NSApp registerHotkeys];
    }

    if ([[message object] isEqualToString:[NSString stringWithFormat:@"%d", WODNAppNoFloater]])
    {
        // tell prefPane that we are (still) running
        [synergyPrefPane notifyPrefPane:WODNAppIsRunning];

        // update state variable to reflect that prefPane is also running
        [synergyPrefPane setPrefPaneState:WODNRunning];

        // suspend floater use...
        sendMessagesToFloater = NO;

        // and remove any floater currently on screen
        [floaterController fadeWindowOut:self];

    }

    if ([[message object] isEqualToString:[NSString stringWithFormat:@"%d", WODNAppFloaterOK]])
    {
        // tell prefPane that we are (still) running
        [synergyPrefPane notifyPrefPane:WODNAppIsRunning];

        // update state variable to reflect that prefPane is also running
        [synergyPrefPane setPrefPaneState:WODNRunning];

        // reinstate floater use...
        sendMessagesToFloater = YES;
    }

    if ([[message name] isEqualToString:WO_NEW_PREFS_FROM_PREFS_TO_APP])
    {
        NSString *serializedPreferences = [message object];
        NSData *data = [serializedPreferences dataUsingEncoding:NSUTF8StringEncoding];
        NSString *error = nil;
        NSDictionary *newPrefs = [NSPropertyListSerialization propertyListFromData:data
                                                                  mutabilityOption:NSPropertyListImmutable
                                                                            format:NULL
                                                                  errorDescription:&error];
        if (error)
        {
            NSLog(@"+[NSPropertyListSerialization propertyListFromData:mutabilityOption:format:errorDescription:] reported error: %@", error);
            return;
        }
        if (!newPrefs)
        {
            NSLog(@"-[SynergyController processMessageFromPrefPane:] deserialization failed");
            return;
        }
        if ([newPrefs isKindOfClass:[NSDictionary class]])
        {
            // update menu item etc
            NSNumber *e = [newPrefs objectForKey:@"enableLastFm"];
            if (e)
            {
                BOOL newValue = [e boolValue];
                [self audioscrobblerUpdate:newValue];
                [toggleAudioscrobblerMenuItem setTitle:[self audioscrobblerMenuTitleForState:newValue]];
            }
            e = [newPrefs objectForKey:@"hitAmazon"];
            if (e)
                hitAmazon = [e boolValue];
            e = [newPrefs objectForKey:@"ExtraVisualFeedbackForOtherHotKeys"];
            if (e)
                extraFeedback = [e boolValue];
        }
    }
}

- (void)showHideHotKeyPressed
{
    /*

     It is necessary to keep two state variables for the showing/hiding of the
     control buttons. One for the user preference and one for the current
     state of the buttons.

     The buttons will show/hide as the result of two possible events:

     1. User activates the toggle hotkey
     2. iTunes state changes (eg. launches, quits etc)

     user shows and hides controls at will,
     and iTunes state changes will only trigger a show/hide operation if the
     state change is to/from a ITUNES_NOT_RUNNING state...

     */

    if ([controlButtonsHidden boolValue])
    {
        // controls are currently hidden: unhide them
        [self showControlsStatusItem];

        // does the user actually want to show any buttons?
        if(([[synergyPreferences objectOnDiskForKey:_woPlayButtonInMenuPrefKey] boolValue]) ||
           ([[synergyPreferences objectOnDiskForKey:_woPrevButtonInMenuPrefKey] boolValue]) ||
           ([[synergyPreferences objectOnDiskForKey:_woNextButtonInMenuPrefKey] boolValue]))
        {
            // could roll this into the if statement above, but leaving it here for readability
            if (globalMenuStatusItem &&
            [[synergyPreferences objectOnDiskForKey:_woGlobalMenuOnlyWhenHiddenPrefKey] boolValue])
            {
                // we were showing the global menu, but user wants to only show it when controls are hidden
                [self removeGlobalMenu];
            }
        }
    }
    else
    {
        // controls are currently visible: hide them
        [self hideControlsStatusItem];

        // if not already showing the global menu AND the user wants us to show it, show it
        if (!globalMenuStatusItem &&
            [[synergyPreferences objectOnDiskForKey:_woGlobalMenuPrefKey] boolValue])
            [self addGlobalMenu];
    }

    [mainTimer fire];
}

- (void)hideControlsStatusItem
{
    if (![controlButtonsHidden boolValue])
    {
        controlButtonsHidden = [NSNumber numberWithBool:YES];
        [[HotkeyCapableApplication sharedApplication] setNextResponder:nil];
        [[NSStatusBar systemStatusBar] removeStatusItem:controlsStatusItem];
        [synergyMenuView removeFromSuperview];
        controlsStatusItem = nil;
    }
}

- (void)showControlsStatusItem
{
    // only bother to show the status item if at least one button is enabled
    if([synergyPreferences objectOnDiskForKey:_woPlayButtonInMenuPrefKey] ||
       [synergyPreferences objectOnDiskForKey:_woPrevButtonInMenuPrefKey] ||
       [synergyPreferences objectOnDiskForKey:_woNextButtonInMenuPrefKey])
    {
        if ([controlButtonsHidden boolValue])
        {
            controlButtonsHidden = [NSNumber numberWithBool:NO];

            // adjust size of frame depending which buttons are displayed
            int totalWidth = [synergyMenuView calculateControlsStatusItemWidth];

            // it appears that when assigning a length to this statusItem we need to compensate for an
            // Apple bug. When I ask for a length of 100, I seem to only get something about 90 pixels
            // long!

            // the solution might be to let it auto-assign the length (with NSVariableStatusItemLength)
            // and just adjust the size of the view....

            controlsStatusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
            [controlsStatusItem setHighlightMode:NO];
            NSSize menuViewFrameSize = NSMakeSize(totalWidth,controlViewHeight);
            [synergyMenuView setFrameSize:menuViewFrameSize];
            if ([[synergyPreferences objectOnDiskForKey:_woNextButtonInMenuPrefKey] intValue])
                [self showNextButtonImage];
            else
                [self hideNextButtonImage];

            if ([[synergyPreferences objectOnDiskForKey:_woPrevButtonInMenuPrefKey] intValue])
                [self  showPrevButtonImage];
            else
                [self  hidePrevButtonImage];

            if ([[synergyPreferences objectOnDiskForKey:_woPlayButtonInMenuPrefKey] intValue])
                [self  showPlayPauseButtonImage];
            else
                [self  hidePlayPauseButtonImage];
            [controlsStatusItem setView:synergyMenuView];
        }
    }
}

// This routine called whenever a button added-to/removed-from the controlsStatusItem (verified works)
- (void) updateAndResizeControlsStatusItem
{
    int totalWidth = [synergyMenuView calculateControlsStatusItemWidth];

    NSSize menuViewFrameSize = NSMakeSize(totalWidth,controlViewHeight);
    [synergyMenuView setFrameSize:menuViewFrameSize];
    [controlsStatusItem setView:synergyMenuView];

    if ([[synergyPreferences objectOnDiskForKey:_woNextButtonInMenuPrefKey] intValue])
        [self  showNextButtonImage];
    else
        [self  hideNextButtonImage];

    if ([[synergyPreferences objectOnDiskForKey:_woPrevButtonInMenuPrefKey] intValue])
        [self  showPrevButtonImage];
    else
        [self  hidePrevButtonImage];

    if ([[synergyPreferences objectOnDiskForKey:_woPlayButtonInMenuPrefKey] intValue])
        [self  showPlayPauseButtonImage];
    else
        [self  hidePlayPauseButtonImage];
}

- (void) showPlayPauseButtonImage
{
    [synergyMenuView setGlobalMenu:synergyGlobalMenu];
    [synergyMenuView showPlayButton];
}

- (void) hidePlayPauseButtonImage
{
    [synergyMenuView hidePlayButton];
}

- (void) showPrevButtonImage
{
    [synergyMenuView showPrevButton];
    [synergyMenuView setPrevTooltip:NSLocalizedString(@"Previous track in iTunes",@"Previous track button tool-tip")];
}

- (void) hidePrevButtonImage
{
    [synergyMenuView hidePrevButton];
}

- (void) showNextButtonImage
{
    [synergyMenuView showNextButton];
    [synergyMenuView setNextTooltip:NSLocalizedString(@"Next track in iTunes",@"Next track button tool-tip")];
}

- (void) hideNextButtonImage
{
    [synergyMenuView hideNextButton];
}

- (void)updateMenu
{
    // has the effect of "batching" multiple changes to menu
    [synergyGlobalMenu setMenuChangedMessagesEnabled:NO];

    NSDictionary *song;
    /*

     We will remove the old list of songs from the menu (all of them) first and
     then re-add them. We do this because we do not know if any were deleted
     (nor where they were in the list).

     I could easily do that in the timer method to make it more efficient, only
     adding one song (and potentially deleting one song) per invocation.

     I think this might partially fix the glitch I see when iTunes changes
     tracks while the menu is down.

     */

    //remove songs from menu
    for (NSMenuItem *item in [synergyGlobalMenu itemArray])
    {
        if ([item action] == @selector(playSong:)) // ensures we only remove songs
            [synergyGlobalMenu removeItem:item];
    }


    //add songs from songList array to menu

    // make sure we don't exceed number of songs specified in
    // _woNumberOfRecentlyPlayedTracksPrefKey
    int permittedSongs = [[synergyPreferences objectOnDiskForKey:_woNumberOfRecentlyPlayedTracksPrefKey] intValue];

    // cast to int safe because count always < 50
    if ((int)[songList count] > permittedSongs)
    {
        // remove songs that exceed the number specified in the prefs
         NSRange objectsToDelete = NSMakeRange(permittedSongs, ([songList count] - permittedSongs));
         [songList removeObjectsInRange:objectsToDelete];
    }

    // enable "clear recent tracks" menu item if appropriate
    if ([songList count] > 0 && [synergyPreferences objectOnDiskForKey:_woRecentlyPlayedSubmenuPrefKey])
        // we have at least one "recent track"
        [clearRecentTracksMenuItem setEnabled:YES];
    else if (![[synergyPreferences objectOnDiskForKey:_woRecentlyPlayedSubmenuPrefKey] boolValue])
        // user doesn't want recent tracks menu -- hide those items?
        // ugly! this will require us to move everything else...
        [clearRecentTracksMenuItem setEnabled:NO];
    else
        // no recent tracks (although user does want recent tracks menu)
        [clearRecentTracksMenuItem setEnabled:NO];

    // if and only if user wants to keep list of recently played songs...
    if ([[synergyPreferences objectOnDiskForKey:_woRecentlyPlayedSubmenuPrefKey] boolValue])
    {
        // add songs back into menu
        NSEnumerator *enumerator = [songList reverseObjectEnumerator];
        NSMutableString *tempString = [NSMutableString string];
        while ((song = [enumerator nextObject]))
        {
            // start with two spaces for indenting
            [tempString setString:@"  "];

            // add track title
            [tempString appendString:[song objectForKey:WO_SONG_DICTIONARY_TITLE]];

            // add artist if present and the preferences require it
            if ([song objectForKey:WO_SONG_DICTIONARY_ARTIST] &&
                [[synergyPreferences objectOnDiskForKey:_woIncludeArtistInRecentTracksPrefKey] boolValue] &&
                ![[song objectForKey:WO_SONG_DICTIONARY_ARTIST] isEqualToString:@""])
            {
                [tempString appendString:@" - "];
                [tempString appendString:[song objectForKey:WO_SONG_DICTIONARY_ARTIST]];
            }

            // add the menu item
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:tempString action:@selector(playSong:) keyEquivalent:@""];
            [item setTarget:self];
            [synergyGlobalMenu insertItem:item atIndex:1];
        }
    }

    // heaps of redundancy between here and the addGlobal method...

    // find out the index of the playlists submenu (will be -1 if removed)
    int playlistsSubmenuIndex = [synergyGlobalMenu indexOfItemWithSubmenu:playlistsSubmenu];

    // pointer to the NSMenuItem containing our submenu -- static because we
    // want to use it across multiple invocations of this method
    static id playlistsMenuItem;

    // hide playlists Submenu if necessary
    if ([[synergyPreferences objectOnDiskForKey:_woPlaylistsSubmenuPrefKey] boolValue] == NO)
    {
        // test to see if we've already been removed on a previous pass
        if (playlistsSubmenuIndex != -1)
        {
            // we've been removed previously -- ok to proceed

            // this is a pointer to the NSMenu object that contains the submenu
            playlistsMenuItem = [synergyGlobalMenu itemAtIndex:playlistsSubmenuIndex];
            [synergyGlobalMenu removeItem:playlistsMenuItem];

            // remove separator above submenu if there is one there (and there always will be)
            if ([[synergyGlobalMenu itemAtIndex:(playlistsSubmenuIndex -1)] isSeparatorItem])
                [synergyGlobalMenu removeItem:[synergyGlobalMenu itemAtIndex:(playlistsSubmenuIndex -1)]];
        }
    }
    else
    {
        // prefs tell us to add submenu back in if it's been removed...

        // test to see if we've already been removed on a previous pass
        if (playlistsSubmenuIndex == -1)
        {
            // appear two places above prefs item if iTunes menu is present
            // or one place above it if not
            int destinationIndex;

            if ([synergyGlobalMenu indexOfItemWithSubmenu:iTunesSubmenu] != -1)
                // bumped upwards by 1 for 2.9 ("Transfer cover to iTunes" menu item)
                destinationIndex = [synergyGlobalMenu indexOfItem:synergyPreferencesMenuItem] - 8;
            else
                // bumped upwards by 1 for 2.9 ("Transfer cover to iTunes" menu item)
                destinationIndex = [synergyGlobalMenu indexOfItem:synergyPreferencesMenuItem] - 7;

            // because of removal on previous pass, playlistsMenuItem will
            // contain a pointer to the removed item
            [synergyGlobalMenu insertItem:playlistsMenuItem atIndex:destinationIndex];

            // restore separator (above submenu) as well if it is missing
            // note that we can always assume destinationIndex - 1 to be positive
            // because the first couple of slots are always the recent tracks and clear recent tracks items
            if(![[synergyGlobalMenu itemAtIndex:(destinationIndex - 1)] isSeparatorItem])
                [synergyGlobalMenu insertItem:[NSMenuItem separatorItem] atIndex:destinationIndex];
        }
    }

    // find out the index of the iTunes submenu (will be -1 if removed)
    int iTunesSubmenuIndex = [synergyGlobalMenu indexOfItemWithSubmenu:iTunesSubmenu];

    // pointer to the NSMenuItem containing our submenu -- static because we
    // want to use it across multiple invocations of this method
    static id iTunesMenuItem;

    // hide iTunes submenu if necessary
    if (![[synergyPreferences objectOnDiskForKey:_woLaunchQuitItemsPrefKey] boolValue])
    {
        // test to see if we've already been removed on a previous pass
        if (iTunesSubmenuIndex != -1)
        {
            // we've been removed previously -- ok to proceed
            // this is a pointer to the NSMenu object that contains the submenu
            iTunesMenuItem = [synergyGlobalMenu itemAtIndex:iTunesSubmenuIndex];
            [synergyGlobalMenu removeItem:iTunesMenuItem];

            // remove separator above submenu if there is one there
            if ([[synergyGlobalMenu itemAtIndex:(iTunesSubmenuIndex - 1)] isSeparatorItem])
                [synergyGlobalMenu removeItem:[synergyGlobalMenu itemAtIndex:(iTunesSubmenuIndex - 1)]];
        }
    }
    else
    {
        // prefs tell us to add submenu back in if it's been removed...
        // test to see if we've already been removed on a previous pass
        if (iTunesSubmenuIndex == - 1)
        {
            // appear one places above prefs item
            // bumped upwards by 1 for 2.9 ("Transfer cover to iTunes" menu item)
            int destinationIndex = [synergyGlobalMenu indexOfItem:synergyPreferencesMenuItem] - 7;

            // because of removal on previous pass, iTunesMenuItem will
            // contain a pointer to the removed item
            [synergyGlobalMenu insertItem:iTunesMenuItem atIndex:destinationIndex];
        }

        // update value of iTunesSubmenuIndex (will be different if we just re-inserted the menu)
        iTunesSubmenuIndex = [synergyGlobalMenu indexOfItemWithSubmenu:iTunesSubmenu];

        // make sure there's a separator above if one is required
        if (iTunesSubmenuIndex != -1)
        {
            // iTunes submenu is now present (either re-enabled, or still enabled)
            if ([synergyGlobalMenu indexOfItemWithSubmenu:playlistsSubmenu] == -1 &&
                ![[synergyGlobalMenu itemAtIndex:(iTunesSubmenuIndex - 1)] isSeparatorItem])
                // iTunes menu is there, playlists submenu not there, and there is no sep above, so add one
                [synergyGlobalMenu insertItem:[NSMenuItem separatorItem] atIndex:iTunesSubmenuIndex];
        }
    }

    // "Transfer cover to iTunes" menu
    [transferCoverArtMenuItem setEnabled:([floaterController coverImage] ? YES : NO)];

    // update iTunes submenu if it is visible
    if ([synergyGlobalMenu indexOfItemWithSubmenu:iTunesSubmenu] != -1)
    {
        // menu is enabled so perform update

        switch (shuffleState)
        {
            case WOShuffleOn:
                [shuffleMenuItem setState:NSOnState];
                break;

            case WOShuffleOff:
                [shuffleMenuItem setState:NSOffState];
                break;

            case WOShuffleUnknown:
                // do nothing
                break;

            default:
                // do nothing
                break;
        }

        switch (repeatMode)
        {
            case WORepeatAll:

                [repeatAllMenuItem setState:NSOnState];  // only this one is "on"
                [repeatOffMenuItem setState:NSOffState];
                [repeatOneMenuItem setState:NSOffState];

                break;

            case WORepeatOne:

                [repeatAllMenuItem setState:NSOffState];
                [repeatOffMenuItem setState:NSOffState];
                [repeatOneMenuItem setState:NSOnState]; // only this one is "on"

                break;

            case WORepeatOff:

                [repeatAllMenuItem setState:NSOffState];
                [repeatOffMenuItem setState:NSOnState]; // only this one is "on"
                [repeatOneMenuItem setState:NSOffState];

                break;

            case WORepeatUnknown:
                // do nothing
                break;

            default:
                // do nothing
                break;
        }

        if ((iTunesState == ITUNES_NOT_RUNNING) ||
            (iTunesState == ITUNES_UNKNOWN))
        {
            [launchQuitITunesMenuItem setTitle:
                NSLocalizedString(@"Launch iTunes",@"Launch iTunes menu command")];

            [activateITunesMenuItem setEnabled:NO];
            [shuffleMenuItem setEnabled:NO];
            [repeatOneMenuItem setEnabled:NO];
            [repeatAllMenuItem setEnabled:NO];
            [repeatOffMenuItem setEnabled:NO];
        }
        else
        {
            [launchQuitITunesMenuItem setTitle:
                NSLocalizedString(@"Quit iTunes",@"Quit iTunes menu command")];

            [activateITunesMenuItem setEnabled:YES];
            [shuffleMenuItem setEnabled:YES];
            [repeatOneMenuItem setEnabled:YES];
            [repeatAllMenuItem setEnabled:YES];
            [repeatOffMenuItem setEnabled:YES];
        }
    }

    [synergyGlobalMenu setMenuChangedMessagesEnabled:YES];
}


// Append passed text to Play/Pause button's Tool-tip, in brackets: ( )
- (void)updateTooltip:(NSString *)tooltipString
{
    NSString *beginTrackinfo            =  @"\n(";
    NSString *endTrackinfo              =    @")";

    NSString *trackinfoTooltip          =  [beginTrackinfo stringByAppendingString:tooltipString];
    NSString *completeTrackinfoTooltip  = [trackinfoTooltip stringByAppendingString:endTrackinfo];

    //NSString *playPauseTooltip;

    //if ([iTunesState intValue] == ITUNES_PLAYING)
    if (iTunesState == ITUNES_PLAYING)
    {
        NSString *playPauseTooltip = [
            NSLocalizedString(@"Pause iTunes",@"Pause button tool-tip")
                   stringByAppendingString:completeTrackinfoTooltip];
        //[playPauseStatusItem setToolTip:playPauseTooltip];
        [synergyMenuView setPlayPauseTooltip:playPauseTooltip];
    }
    //else if ([iTunesState intValue] == ITUNES_PAUSED)
    else if (iTunesState == ITUNES_PAUSED)
    {
        NSString *playPauseTooltip = [
            NSLocalizedString(@"Resume iTunes playback",@"Resume playback (play button) tool-tip")
            stringByAppendingString:completeTrackinfoTooltip];
        //[playPauseStatusItem setToolTip:playPauseTooltip];
        [synergyMenuView setPlayPauseTooltip:playPauseTooltip];
    }
    //else if ([iTunesState intValue] == ITUNES_STOPPED)
    else if (iTunesState == ITUNES_STOPPED)
    {
        NSString *playPauseTooltip = [
            NSLocalizedString(@"Play current iTunes track",@"Play button tool-tip")
            stringByAppendingString:completeTrackinfoTooltip];
        //[playPauseStatusItem setToolTip:playPauseTooltip];
        [synergyMenuView setPlayPauseTooltip:playPauseTooltip];
    }
    //else if ([iTunesState intValue] == ITUNES_UNKNOWN)
    else if (iTunesState == ITUNES_UNKNOWN)
    {
        NSString *playPauseTooltip = [
            NSLocalizedString(@"Play/Pause iTunes",@"Play/pause button tool-tip")
            stringByAppendingString:completeTrackinfoTooltip];
        //[playPauseStatusItem setToolTip:playPauseTooltip];
        [synergyMenuView setPlayPauseTooltip:playPauseTooltip];
    }
    //else if ([iTunesState intValue] == ITUNES_ERROR)
    else if (iTunesState == ITUNES_ERROR)
    {
        NSString *playPauseTooltip = [
            NSLocalizedString(@"Play/Pause iTunes",@"Play/pause button tool-tip")
            stringByAppendingString:completeTrackinfoTooltip];
        //[playPauseStatusItem setToolTip:playPauseTooltip];
        [synergyMenuView setPlayPauseTooltip:playPauseTooltip];
    }
    else
    {
        NSString *playPauseTooltip = [
            NSLocalizedString(@"Play/Pause iTunes",@"Play/pause button tool-tip")
            stringByAppendingString:completeTrackinfoTooltip];
        [synergyMenuView setPlayPauseTooltip:playPauseTooltip];
    }

}

- (void) switchToPlayImage
{
}

- (void) switchToPauseImage
{
}

- (void) switchToPlayPauseImage
{
}

- (void) hidePlayPauseButton
{
}

- (void) showPlayPauseButton
{
}

- (void) hidePrevButton
{
}

- (void) showPrevButton
{
}

- (void) hideNextButton
{
}

- (void) showNextButton
{
}

- (void) hideGlobalMenu
{
}

- (void) showGlobalMenu
{
}

/*

 This method is called on when control hiding is activated. It checks which
 buttons are active and disables them

 */
- (void)hideActiveControls
{
    if ([[synergyPreferences objectOnDiskForKey:_woPrevButtonInMenuPrefKey] boolValue])
        [self hidePrevButtonImage];

    if ([[synergyPreferences objectOnDiskForKey:_woPlayButtonInMenuPrefKey] boolValue])
        [self hidePlayPauseButtonImage];

    if ([[synergyPreferences objectOnDiskForKey:_woNextButtonInMenuPrefKey] boolValue])
        [self hideNextButtonImage];
}

/*

 This method is called on when control hiding is activated. It checks which
 buttons are active and enables (shows) them

 */
- (void)showActiveControls
{
    if ([[synergyPreferences objectOnDiskForKey:_woPrevButtonInMenuPrefKey] boolValue] == NO)
        [self showPrevButtonImage];

    if ([[synergyPreferences objectOnDiskForKey:_woPlayButtonInMenuPrefKey] boolValue] == NO)
        [self showPlayPauseButtonImage];

    if ([[synergyPreferences objectOnDiskForKey:_woNextButtonInMenuPrefKey] boolValue] == NO)
        [self showNextButtonImage];
}

- (void) timer:(NSTimer *)timer
{
    // this variable used as shorthand for floater "always on" status
    BOOL floaterAlways = (BOOL)([[synergyPreferences objectOnDiskForKey:_woFloaterDurationPrefKey] floatValue] > 21.0);

    // let prefPane know that we're still running
    [synergyPrefPane notifyPrefPane:WODNAppIsRunning];

    // this is what we are going to try and retrieve from iTunes
    NSString                *playerState  = nil;
    NSAppleEventDescriptor  *songId       = nil;
    NSString                *songTitle    = nil;
    NSString                *albumName    = nil;
    NSString                *artistName   = nil;
    NSString                *composerName = nil;
    NSString                *songDuration = nil;
    NSString                *year         = nil;

    WORatingCode            songRating    = WO0StarRating;

    NSMutableDictionary     *songDictionary = nil;

    // check if iTunes is running
    if ([WOProcessManager processRunningWithSignature:'hook'])
    {
        /*

         1. that it takes a second or two before the process manager sees that
         iTunes isn't running
         2. that Apple events sent to a non-running app have no effect -- presumably
         because the PSN isn't in use
         2b. when it's not running, no error is produced, so i can't test for
         error status in order to ascertain if it's working
         3. that events sent to a just-launched app will be queued until the app
         is eventually ready, and they get processed
         4. that apple events will never cause a respawn
         5. that apple script is the friggin culprit, because only the applescript
         cause the respawn
         6. that i should reimplement the getInfoScript as an AppleEvent request

         */

        if ([self iTunesReadyToReceiveAppleScript])
        {
            NSAppleEventDescriptor *descriptor = [getSongInfoScript executeAndReturnError:NULL];

            if (descriptor && [descriptor numberOfItems] == 1)
            {
                // result will be "error", "not running" or "not playing"
                playerState = [descriptor stringValue];
            }
            else if (descriptor && [descriptor numberOfItems] == 12)
            {
                // result should be "stopped", "playing" or "paused"

                // experimentation shows that if no selection the time the script
                // is first run, it will from then on return a human-readable string
                //
                // in the reverse case, it returns the non-human-readable version!

                // hack for inconsistent AppleScript behaviour:

                // GCC 3.3. warnings ("non-ASCII character in CFString literal")
                NSString *playingString = // build string: "«constant ****kPSP»"
                [NSString stringWithFormat:@"%Cconstant ****kPSP%C",
                    WO_LEFT_POINTING_DOUBLE_ANGLE_QUOTATION_MARK_UNICODE_CHAR,
                    WO_RIGHT_POINTING_DOUBLE_ANGLE_QUOTATION_MARK_UNICODE_CHAR];

                NSString *pausedString = // build string: "«constant ****kPSp»"
                    [NSString stringWithFormat:@"%Cconstant ****kPSp%C",
                        WO_LEFT_POINTING_DOUBLE_ANGLE_QUOTATION_MARK_UNICODE_CHAR,
                        WO_RIGHT_POINTING_DOUBLE_ANGLE_QUOTATION_MARK_UNICODE_CHAR];

                NSString *stoppedString = // build string: "«constant ****kPSS»"
                    [NSString stringWithFormat:@"%Cconstant ****kPSS%C",
                        WO_LEFT_POINTING_DOUBLE_ANGLE_QUOTATION_MARK_UNICODE_CHAR,
                        WO_RIGHT_POINTING_DOUBLE_ANGLE_QUOTATION_MARK_UNICODE_CHAR];

                if ([[[descriptor descriptorAtIndex:1] stringValue] isEqualToString:playingString])
                    playerState = @"playing";

                // for now, consider "stopped" to be equivalent to "paused"
                else if (([[[descriptor descriptorAtIndex:1] stringValue] isEqualToString:pausedString]) ||
                         ([[[descriptor descriptorAtIndex:1] stringValue] isEqualToString:stoppedString]) ||
                         ([[[descriptor descriptorAtIndex:1] stringValue] isEqualToString:@"stopped"]))
                    playerState = @"paused";

                else
                    // we got a literal string like "stopped", "playing" or "paused"
                    playerState = [[descriptor descriptorAtIndex:1] stringValue];


                // this is a descriptor containing a parameter of a form like:
                //  file track id 9227 of user playlist id 9213 of source id 33
                //  of application "iTunes"
                songId = [descriptor descriptorAtIndex:2];
                songTitle = [[descriptor descriptorAtIndex:3] stringValue];

                // even songTitle may be nil on Snow Leopard it would seem
                // see: https://wincent.com/issues/1381
                if (!songTitle)
                    songTitle = @"";

                // check for nil values here (eg. Internet radio with missing tags)

                albumName =
                    [[descriptor descriptorAtIndex:4] stringValue];

                if (!albumName)
                    albumName = @"";

                artistName =
                    [[descriptor descriptorAtIndex:5] stringValue];

                if (!artistName)
                    artistName = @"";

                composerName = [[descriptor descriptorAtIndex:6] stringValue];
                if (!composerName) composerName = @"";

                songDuration =
                    [[descriptor descriptorAtIndex:7] stringValue];

                if (!songDuration)
                    songDuration = @"";

                // year: equals "0" if not set
                if([[[descriptor descriptorAtIndex:8] stringValue] isEqualToString:@"0"])
                    year = @"";
                else
                {
                    year = [[descriptor descriptorAtIndex:8] stringValue];

                    if (year == nil)
                        year = @"";
                }

                // song rating: convert it from a 0-100 integer into a 0-5 star
                // rating
                NSString *unconvertedSongRating =
                    [NSString stringWithString:
                        [[descriptor descriptorAtIndex:9] stringValue]];
                int convertedRating = [unconvertedSongRating intValue];

                // http://wincent.com/a/support/bugs/show_bug.cgi?id=366
                if (convertedRating > 80)       songRating = WO5StarRating;
                else if (convertedRating > 60)  songRating = WO4StarRating;
                else if (convertedRating > 40)  songRating = WO3StarRating;
                else if (convertedRating > 20)  songRating = WO2StarRating;
                else if (convertedRating > 0)   songRating = WO1StarRating;
                else                            songRating = WO0StarRating;

                // repeat mode: should be "all", "one" or "off"
                NSString *tempRepeatMode =
                    [[descriptor descriptorAtIndex:10] stringValue];

                if ([tempRepeatMode isEqualToString:@"all"])
                    // just write it straight to our ivar
                    repeatMode = WORepeatAll;
                else if ([tempRepeatMode isEqualToString:@"one"])
                    repeatMode = WORepeatOne;
                else if ([tempRepeatMode isEqualToString:@"off"])
                    repeatMode = WORepeatOff;
                else
                    // temporarily commenting out this error msg (it is spewing
                    // out every time through the loop until I change the repeat
                    // mode once, then it stops)
                    repeatMode = WORepeatUnknown;

                // shuffle state: should be "true" or "false"
                NSString *tempShuffleState =
                    [[descriptor descriptorAtIndex:11] stringValue];

                if ([tempShuffleState isEqualToString:@"true"])
                    shuffleState = WOShuffleOn;
                else if ([tempShuffleState isEqualToString:@"false"])
                    shuffleState = WOShuffleOff;
                else
                    shuffleState = WOShuffleUnknown;

                // player position: integer 0, 1, 2 etc seconds
                playerPosition = [[descriptor descriptorAtIndex:12] int32Value];
            }
            else
            {
                playerState = [NSString stringWithString:@"error"];

                songId =
                    [NSAppleEventDescriptor descriptorWithString:@"error"];

                // set other variables to reasonable defaults
                songTitle     = @"";
                albumName     = @"";
                artistName    = @"";
                composerName  = @"";
                songDuration  = @"";
                year          = @"";
                songRating    = WO0StarRating;
                repeatMode    = WORepeatUnknown;
                shuffleState  = WOShuffleUnknown;
            }

        }
        else
        {
            // iTunes is NOT ready to receive the AppleScript!

            /*

             This is not considered grounds to classify iTunes as "not running"
             because there can be transitory failures in which iTunes will not
             respond to the Apple Event within the timeout simply because the
             user is dragging the window (or something similar).

             So in these cases we do NOT classify things as "not running" or
             because this could cause the Synergy
             controls to be removed from the menu bar which might not be the
             desired effect...

             */
            playerState = [NSString stringWithString:@"unknown"];
        }

    }
    else
    {
        // well, it's not running, so let's try and avoid triggering an
        // unwanted re-launch by pre-setting "result" as follows
        playerState = [NSString stringWithString:@"not running"];
    }

    // now we have all the info we need from iTunes, so time to start processing

    if([playerState isEqualToString:@"not running"])
    {
        NSString *errorMessage = [NSLocalizedString(@"Not running",
                                                    @"Not running tool-tip")
                                  stringByAppendingString:@""];

        // the new way... made in an effort to prevent these crashes

        // ALWAYS set state variable, not only on the first time we notice we're not running
        // the hideControlsStatusItem method is smart enough not to re-hide the controls,
        // even if we call it every single time the timer fires
        iTunesState = ITUNES_NOT_RUNNING;
        // but now we add another layer of conditionality to the removal of the controls
        // only do it if control hiding is on AND we didn't get here by a button click
        if (buttonClickOccurred == NO)
        {
            if ([[synergyPreferences objectOnDiskForKey:
                _woControlHidingPrefKey] intValue])
            {
                [self hideControlsStatusItem];

                if (!globalMenuStatusItem &&
                    [[synergyPreferences objectOnDiskForKey:_woGlobalMenuPrefKey] boolValue])
                    [self addGlobalMenu];
            }
        }

        [self updateTooltip:errorMessage];

        // and in the custom view:
        [synergyMenuView makePlayButtonShowPlayImage];

        // if there is a floater showing... fade it out immediately
        [floaterController fadeWindowOut:self];

        // apply ghosting to forward and back buttons
        //[synergyMenuView disableNextButton];
        //[synergyMenuView disablePrevButton];
        // I have decided to disable this feature because it could introduce a
        // nasty and annoying lag into the system: iTunes is quit; user launches
        // iTunes; buttons are ghosted and unusable for up to 10 seconds while
        // waiting for next run of this timer method.
    }
    else if([playerState isEqualToString:@"not playing"])
    {
        NSString *errorMessage = [NSLocalizedString(
                                                    @"Not playing",
                                                    @"iTunes not playing tool-tip")
                                  stringByAppendingString:@""];

        // update iTunes state variable
        if (iTunesState != ITUNES_STOPPED)
        {
            // if appropriate, show controls:
            if ([[synergyPreferences objectOnDiskForKey:
                _woControlHidingPrefKey] intValue]
                && ((iTunesState == ITUNES_NOT_RUNNING) || (iTunesState == ITUNES_UNKNOWN)))
            {
                // only show the controls if the user preferences dictate
                // AND the transition is from the "not running" state, or the "unknown" state
                // this method is smart enough not to re-show already shown controls...


                [self showControlsStatusItem];

                if(([[synergyPreferences objectOnDiskForKey:_woPlayButtonInMenuPrefKey] boolValue]) ||
                   ([[synergyPreferences objectOnDiskForKey:_woPrevButtonInMenuPrefKey] boolValue]) ||
                   ([[synergyPreferences objectOnDiskForKey:_woNextButtonInMenuPrefKey] boolValue]))
                {
                    // could roll this into the if statement above, but leaving it here for readability
                    if (globalMenuStatusItem &&
                        [[synergyPreferences objectOnDiskForKey:_woGlobalMenuOnlyWhenHiddenPrefKey] boolValue])
                    {
                        // we were showing the global menu, but user wants to only show it when controls are hidden
                        [self removeGlobalMenu];
                    }
                }

            }

            // if appropriate, update playlists submenu
            if ((iTunesState == ITUNES_NOT_RUNNING) ||
                (iTunesState == ITUNES_UNKNOWN))
                [self refreshPlaylistsSubmenu:nil];

            // only do this if floater is set to appear "always", and furthermore
            // by putting it in here, we make sure it only happens as we
            // transition into the ITUNES_STOPPED state, instead of every time
            // the timer fires
            // problem with this is that if i pause playback, and then skip tracks,
            // floater won't resize (? or does that occur in further down?)
            if (floaterAlways)
            {

                // make floater show: "Not playing" (will do same below for error condition)

                [floaterController setCurrentRating:WONoStarRatingDisplay];

                [self updateFloaterStrings:
                    NSLocalizedString(@"iTunes status: not playing",
                                      @"iTunes not playing floater status message")
                                     album:@" "
                                    artist:@" "
                                  composer:@" "];

                [floaterController setAlbumImagePath:nil];

                // special case to handle bug 45 (floater not resizing when turned off)
                // http://bugs.wincent.org/bugs/bug.php?op=show&bugid=45&pos=18
                if ([[synergyPreferences objectOnDiskForKey:_woShowNotificationWindowPrefKey] boolValue] == NO)
                {
                    // not sure I need this here, because it should always get
                    // resized below in the clickDrivenUpdate/timerDrivenUpdate
                    // calls below
                    [floaterController resizeInstantly];
                }

                // this will update/resize the floater, but it won't put it onscreen
                // if it is not already
                [floaterController tellViewItNeedsToDisplay:self];

                // make sure communications with floater aren't suspended
                if (sendMessagesToFloater && floaterActive == YES)
                {
                    // now send it all off to the notification window
                    if(buttonClickOccurred)
                        [floaterController clickDrivenUpdate];
                    else
                        [floaterController timerDrivenUpdate];
                }
            }

            iTunesState = ITUNES_STOPPED;
        }

        [self updateTooltip:errorMessage];

        // and in the custom view:
        [synergyMenuView makePlayButtonShowPlayImage];

        // remove ghosting from forward and back buttons
        //[synergyMenuView enableNextButton];
        //[synergyMenuView enablePrevButton];

    }
    else if([playerState isEqualToString:@"error"])
    {
        // we can get here when iTunes music store previews are playing, for example
        NSString *errorMessage = [NSLocalizedString(
                                                    @"Error",
                                                    @"Error talking to iTunes tool-tip")
                                  stringByAppendingString:@""];

        // update iTunes state variable

        if (iTunesState != ITUNES_ERROR)
        {


            iTunesState = ITUNES_ERROR;
        }
        [self updateTooltip:errorMessage];

        // and in the custom view:
        [synergyMenuView makePlayButtonShowPlayPauseImage];

        // apply ghosting to forward and back buttons
        //[synergyMenuView disableNextButton];
        //[synergyMenuView disablePrevButton];


    }
    else if (([playerState isEqualToString:@"playing"]) ||
             ([playerState isEqualToString:@"paused"]))
    {

        //         // this flag is used later on to determine if we are newly transitioning
        //         // into this state
        //         BOOL newTransitionToState;
        //
        //         if ((iTunesState != ITUNES_PAUSED) && (iTunesState != ITUNES_PLAYING))
        //         {
        //             newTransitionToState = YES;
        //         }
        //         else
        //         {
        //             newTransitionToState = NO;
        //         }

        // parts specific to playing and paused states:

        if ([playerState isEqualToString:@"paused"])
        {
            // update iTunes state variable
            if (iTunesState != ITUNES_PAUSED)
            {
                // if appropriate, show controls:
                if ([[synergyPreferences objectOnDiskForKey:
                    _woControlHidingPrefKey] intValue]
                    && ((iTunesState == ITUNES_NOT_RUNNING)||(iTunesState == ITUNES_UNKNOWN)))
                {
                    [self showControlsStatusItem];

                    if(([[synergyPreferences objectOnDiskForKey:_woPlayButtonInMenuPrefKey] boolValue]) ||
                       ([[synergyPreferences objectOnDiskForKey:_woPrevButtonInMenuPrefKey] boolValue]) ||
                       ([[synergyPreferences objectOnDiskForKey:_woNextButtonInMenuPrefKey] boolValue]))
                    {
                        // could roll this into the if statement above, but leaving it here for readability
                        if (globalMenuStatusItem &&
                            [[synergyPreferences objectOnDiskForKey:_woGlobalMenuOnlyWhenHiddenPrefKey] boolValue])
                        {
                            // we were showing the global menu, but user wants to only show it when controls are hidden
                            [self removeGlobalMenu];
                        }
                    }
                }

                // if appropriate, update playlists submenu
                if ((iTunesState == ITUNES_NOT_RUNNING) ||
                    (iTunesState == ITUNES_UNKNOWN))
                    [self refreshPlaylistsSubmenu:nil];

                iTunesState = ITUNES_PAUSED;
            }
            // and in the custom view:
            [synergyMenuView makePlayButtonShowPlayImage];
        }
        else
        {
            // update iTunes state variable
            if (iTunesState != ITUNES_PLAYING)
            {
                // if appropriate, show controls:
                if ([[synergyPreferences objectOnDiskForKey:
                    _woControlHidingPrefKey] intValue]
                    && ((iTunesState == ITUNES_NOT_RUNNING)||(iTunesState == ITUNES_UNKNOWN)))
                {
                    [self showControlsStatusItem];

                    if(([[synergyPreferences objectOnDiskForKey:_woPlayButtonInMenuPrefKey] boolValue]) ||
                       ([[synergyPreferences objectOnDiskForKey:_woPrevButtonInMenuPrefKey] boolValue]) ||
                       ([[synergyPreferences objectOnDiskForKey:_woNextButtonInMenuPrefKey] boolValue]))
                    {
                        // could roll this into the if statement above, but leaving it here for readability
                        if (globalMenuStatusItem &&
                            [[synergyPreferences objectOnDiskForKey:_woGlobalMenuOnlyWhenHiddenPrefKey] boolValue])
                        {
                            // we were showing the global menu, but user wants to only show it when controls are hidden
                            [self removeGlobalMenu];
                        }
                    }
                }

                // if appropriate, update playlists submenu
                if ((iTunesState == ITUNES_NOT_RUNNING) ||
                    (iTunesState == ITUNES_UNKNOWN))
                    [self refreshPlaylistsSubmenu:nil];

                iTunesState = ITUNES_PLAYING;
            }
            // and in the custom view:
            [synergyMenuView makePlayButtonShowPauseImage];
        }

        // parts shared between paused and playing states

        // construct songDictionary from components -- store just enough to
        // uniquely identify the song

        songDictionary =
        [NSMutableDictionary dictionaryWithCapacity:5];

        // track identifier
        [songDictionary setObject:songId
                           forKey:WO_SONG_DICTIONARY_ID];

        // title
        // was crashing here: https://wincent.com/issues/1381
        // should never be nil because I've added a check above,
        // but double-check it here to be defensive
        [songDictionary setObject:(songTitle ? songTitle : NSLocalizedString(@"Untitled", @"Untitled"))
                           forKey:WO_SONG_DICTIONARY_TITLE];

        // artist
        [songDictionary setObject:artistName
                           forKey:WO_SONG_DICTIONARY_ARTIST];

        // for now, shoehorning support for album cover downloads into place
        // by jamming in a WOSongInfo object

        // first, create the object
        WOSongInfo *songInfo =  [[WOSongInfo alloc] init];

        // populate it
        [songInfo setSong:songTitle];
        [songInfo setArtist:artistName];
        [songInfo setAlbum:albumName];

        // store it in songDictionary
        [songDictionary setObject:songInfo forKey:WO_SONG_DICTIONARY_SONGINFO];

        NSFileManager *manager = [NSFileManager defaultManager];

        // only attempt download if user preferences specify
        if ([[synergyPreferences objectOnDiskForKey:_woFloaterGraphicType] intValue] == WOFloaterIconAlbumCover)
        {
            BOOL artSentToFloater = NO;

            // check disk first
            NSString *filename = [songInfo filename];
            NSString *tempCoverPath = [[WOCoverDownloader tempAlbumCoversPath] stringByAppendingPathComponent:filename];
            NSString *coverPath = [[WOCoverDownloader albumCoversPath] stringByAppendingPathComponent:filename];

            if (filename)   // only do this if filename non-nil
            {
                if ([manager fileExistsAtPath:tempCoverPath])
                {
                    // notify floater
                    [floaterController setAlbumImagePath:tempCoverPath];
                    artSentToFloater = YES;
                }
                else if ([manager fileExistsAtPath:coverPath])
                {
                    // notify floater
                    [floaterController setAlbumImagePath:coverPath];
                    artSentToFloater = YES;
                }
            }

            // check if iTunes supplied cover art
            if (artSentToFloater == NO)
            {
                // enclose this in an exception handling block because I've heard reports that this can crash
                NS_DURING

                    // old implementation actually stored the cover art in
                    // the descriptor every time through the loop
                    // new implemenation only tries grabbing it on demand:

                    NSAppleEventDescriptor  *coverDescriptor = nil;
                    NSAppleScript           *coverScript;
                    static NSString         *coverScriptSource =
                        @"tell application \"iTunes\"\n"
                        @"  try\n"
                        @"    if data of the artworks of the current track exists then\n"
                        @"      return data of artwork 1 of current track as picture\n"
                        @"    else\n"
                        @"      return \"NO COVER\"\n"
                        @"    end if\n"
                        @"  on error\n"
                        @"    return \"NO COVER\"\n"
                        @"  end try\n"
                        @"end tell\n";

                    coverScript = [[NSAppleScript alloc] initWithSource:coverScriptSource];
                    coverDescriptor = [coverScript executeAndReturnError:NULL];
                    if (coverDescriptor && ![[coverDescriptor stringValue] isEqualToString:@"NO COVER"])
                    {
                        NSData *coverData = [coverDescriptor data];
                        NSImage *coverImage = nil;
                        if (coverData)
                            coverImage = [[NSImage alloc] initWithData:coverData];
                        if (!coverImage)
                            [NSException raise:WO_ITUNES_ALBUM_COVER_TRANSFER_FAILURE
                                        format:WO_ITUNES_ALBUM_COVER_TRANSFER_FAILURE_TEXT];

                        // save a copy to disk
                        NSData *coverDataAsTIFF = [coverImage TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0];
                        NSBitmapImageRep    *rep = [NSBitmapImageRep imageRepWithData:coverDataAsTIFF];
                        NSNumber            *quality = [NSNumber numberWithFloat:0.80];
                        NSDictionary        *properties = [NSDictionary dictionaryWithObject:quality
                                                                                      forKey:NSImageCompressionFactor];
                        NSData *coverDataAsJPEG = [rep representationUsingType:NSJPEGFileType properties:properties];

                        // actually write out to disk
                        if (![coverDataAsJPEG writeToFile:tempCoverPath atomically:YES])
                            [NSException raise:WO_ITUNES_ALBUM_COVER_TRANSFER_FAILURE
                                        format:WO_ITUNES_ALBUM_COVER_TRANSFER_FAILURE_TEXT];

                        // notify floater
                        [floaterController setAlbumImagePath:tempCoverPath];
                        artSentToFloater = YES;
                    }
                    NS_HANDLER
                        ELOG(@"Warning: Exception caught while attempting to process cover art data from iTunes");
                    NS_ENDHANDLER

            }

            // alternate method: try downloading from amazon.com
            if ((artSentToFloater == NO) && [WOCoverDownloader albumCoverExists:songInfo])
            {
                // notify floater
                [floaterController setAlbumImagePath:coverPath];
                artSentToFloater = YES;
            }

            if (artSentToFloater == NO)
                // notify floater
                [floaterController setAlbumImagePath:nil];
        }
        else
            // don't display album image (user doesn't want it)
            [floaterController setAlbumImagePath:nil];

        BOOL enableMenu = NO;

        // do we have a "buy now" link?
        if ([songInfo buyNowURL])
            // unghost the menu
            enableMenu = YES;
        else
        {
            // check to see if we have a "buy now" link stored on the disk for this song
            NSString *buyNowFile =
            [[[[WOCoverDownloader
                    albumCoversPath] stringByAppendingPathComponent:[songInfo filename]] stringByDeletingPathExtension] stringByAppendingPathExtension:@"plist"];

            NSDictionary *buyNowInfo = [[NSDictionary alloc] initWithContentsOfFile:buyNowFile];
            if (buyNowInfo)
            {
                // we have the info from the disk
                NSString *URLString = [buyNowInfo objectForKey:@"BuyNowLink"];

                // stick it in the songInfo obj
                if (URLString)
                {
                    [songInfo setBuyNowURL:[NSURL URLWithString:URLString]];

                    // unghost the menu
                    enableMenu = YES;
                }
            }
        }

        // somehow this wasn't getting set...
        [buyFromAmazonMenuItem setEnabled:enableMenu];

        NSString *extendedTitle;
        NSString *extendedAlbum;

        // if prefs say so, add duration after song title
        if ([[synergyPreferences objectOnDiskForKey:_woIncludeDurationInFloaterPrefKey] boolValue])
            extendedTitle = [[songTitle stringByAppendingString:@" - "] stringByAppendingString:songDuration];
        else
            extendedTitle = songTitle;

        // if prefs say so, add year after album
        if ([[synergyPreferences objectOnDiskForKey:_woIncludeYearInFloaterPrefKey] boolValue])
        {
            NSMutableString *bracketedYear;

            if ([year isEqualToString:@""])
                bracketedYear = [NSMutableString stringWithString:@""];
            else
            {
                bracketedYear = [NSMutableString stringWithString:@" ("];
                [bracketedYear appendString:year];
                [bracketedYear appendString:@")"];
            }
            extendedAlbum = [albumName stringByAppendingString:bracketedYear];
        }
        else
            extendedAlbum = albumName;

        // update star rating if the prefs say we should do so...
        if (![[synergyPreferences objectOnDiskForKey:_woIncludeStarRatingInFloaterPrefKey] boolValue])
            [floaterController setCurrentRating:WONoStarRatingDisplay];
        else
            [floaterController setCurrentRating:songRating];

        // necessary to update floater strings here, just in case we
        // have just started running and user presses "Show floater"
        // hotkey

        [self updateFloaterStrings:extendedTitle
                             album:extendedAlbum
                            artist:artistName
                          composer:composerName];

        // special case to handle bug 45 (floater not resizing when turned off)
        // http://bugs.wincent.org/bugs/bug.php?op=show&bugid=45&pos=18
        if (![[synergyPreferences objectOnDiskForKey:_woShowNotificationWindowPrefKey] boolValue])
            // doesn't show it... only resizes it
            [floaterController resizeInstantly];

        // that method will handle missing values and also user preferences
        // for display/non-display of specific parts

        // need to add a check here to stop us from running this every single frickin time through the loop
        if (floaterAlways)
        {
            // we're supposed to show floater "always"... so we'd best make sure that it's showing
            // make sure communications with floater aren't suspended
            if (sendMessagesToFloater && floaterActive)
            {
                // now send it all off to the notification window
                if (buttonClickOccurred)
                    [floaterController clickDrivenUpdate];
                else
                {
                    // if window is not yet fully faded in, fade it in...
                    // here's the problem: when the window is at full alpha,
                    // it never resizes...
                    if ([floaterController windowAlphaValue] < 1.0)
                        [floaterController timerDrivenUpdate];
                    else
                    {
                        // this cures the bug
                        BOOL oldAnimateWhileResizingValue = [floaterController animateWhileResizing];
                        [floaterController setAnimateWhileResizing:YES];
                        [floaterController resizeInstantly];
                        [floaterController setAnimateWhileResizing:oldAnimateWhileResizingValue];
                    }
                }
            }
        }

        // this will update/resize the floater, but it won't put it onscreen
        // if it is not already
        [floaterController tellViewItNeedsToDisplay:self];

        // use songDictionary to update songList array
        if ([songList count] == 0)
            // add first item to songlist
            [songList addObject:songDictionary];
        else
        {
            /*
             Check if title, artist or album have changed and update floater if necessary. This check is separate from the AppleEvent descriptor comparison that's used in the menu check immediately below, because otherwise we don't pick up track changes for Internet radio.
             */
            NSDictionary *previousTrack = [songList objectAtIndex:0];
            WOSongInfo *previousTrackInfo = [previousTrack objectForKey:WO_SONG_DICTIONARY_SONGINFO];

            if (![[songInfo song] isEqualToString:[previousTrackInfo song]] ||
                ![[songInfo artist] isEqualToString:[previousTrackInfo artist]] ||
                ![[songInfo album] isEqualToString:[previousTrackInfo album]])
            {
                // at least one of song, artist or album have changed

                // if we're supposed to show the floater AND it's not set to show "always" then
                if ([[synergyPreferences objectOnDiskForKey:_woShowNotificationWindowPrefKey] boolValue] && !floaterAlways)
                    // (the "always" case is handled above)
                {
                    // make sure communications with floater aren't suspended
                    if (sendMessagesToFloater && floaterActive)
                    {
                        if  (buttonClickOccurred)
                            [floaterController clickDrivenUpdate];
                        else
                            [floaterController timerDrivenUpdate];
                    }
                }
            }

            // add item to songlist, checking for duplicates
            if (![[[[songDictionary objectForKey:WO_SONG_DICTIONARY_ID] data] description] isEqualToString:
                  [[[previousTrack objectForKey:WO_SONG_DICTIONARY_ID] data] description]])
            {
                // Looks like it's not a dupe
                BOOL duplicateFound = NO;

                // cast to int safe because count always < 50
                for (int i = 0; i < (int)[songList count]; i++)
                {
                    if ([[[[[songList objectAtIndex:i] objectForKey:WO_SONG_DICTIONARY_ID] data] description] isEqualToString:
                         [[[songDictionary objectForKey:WO_SONG_DICTIONARY_ID] data] description]])
                    {
                        duplicateFound = YES;
                        id moveSong = [songList objectAtIndex:i];

                        // pull it from list
                        [songList removeObjectAtIndex:i];

                        // re-insert same object at head of list
                        [songList insertObject:moveSong atIndex:0];

                        // optimisation: can safely assume that never more than
                        // one duplicate here
                        break;
                    }
                }

                // if duplicate not found, add new entry
                if (!duplicateFound)
                    [songList insertObject:songDictionary atIndex:0];
            }
        }

        NSMutableString *tooltipString = [NSMutableString string];

        if ([songTitle length] > 0)
            [tooltipString setString:songTitle];

        if ([albumName length] > 0)
        {
            // append separator first if necessary
            if ([tooltipString length] > 0)
                [tooltipString appendString:@" - "];

            [tooltipString appendString:albumName];
        }

        if ([artistName length] > 0)
        {
            // append separator first if necessary
            if ([tooltipString length] > 0)
                [tooltipString appendString:@" - "];

            [tooltipString appendString:artistName];
        }

        // a test which should never really succeed
        if ([tooltipString length] == 0)
            // test if length of entire string is zero, so we have no song name,
            // and nothing for tool tip
            [tooltipString setString:NSLocalizedString(@"No track name available",@"No track name available")];

        [self updateTooltip:tooltipString];
    }
    else
    {
        // update iTunes state variable
        if (iTunesState != ITUNES_UNKNOWN)
            iTunesState = ITUNES_UNKNOWN;
        // do not update control hiding status here because app is in an unknown state

        [self updateTooltip:playerState];
    }

    [self updateMenu];

    // reset buttondriven flag
    buttonClickOccurred = NO;
}

- (void)updateFloaterStrings:(NSString *)songTitle
                       album:(NSString *)albumName
                      artist:(NSString *)artistName
                    composer:(NSString *)composerName
{
    NSString *tempAlbumName = @"";
    NSString *tempArtistName = @"";
    NSString *tempComposerName = @"";

    BOOL album = [[synergyPreferences objectOnDiskForKey:_woIncludeAlbumInFloaterPrefKey] boolValue];
    BOOL artist = [[synergyPreferences objectOnDiskForKey:_woIncludeArtistInFloaterPrefKey] boolValue];
    BOOL composer = [[synergyPreferences objectOnDiskForKey:_woIncludeComposerInFloaterPrefKey] boolValue];

    if (album && albumName)
        tempAlbumName = [NSString stringWithString:albumName];

    if (artist && artistName)
        tempArtistName = [NSString stringWithString:artistName];

    if (composer && composerName)
        tempComposerName = [NSString stringWithString:composerName];

    [floaterController setStrings:songTitle
                            album:tempAlbumName
                           artist:tempArtistName
                         composer:tempComposerName];
}

- (void) playPause:(id)sender
{
    [self tellITunesPlayPause];
}

- (void) nextTrack:(id)sender
{
    [self tellITunesNext];
}

/*
 Consider putting a mod in here to instantly update the image... I know that when the main
 timer fires it will get updated anyway, but this could make it appear more responsive.

 If do this then should also probably put a status check in the timer method so that it
 doesn't redundantly set the image... eg. if already set, then don't bother to set
 */

- (void) tellITunesPlayPause;
{
    // tell iTunes to play using Apple Events

    ProcessSerialNumber iTunesPSN = [WOProcessManager PSNForSignature:'hook'];

    if ([WOProcessManager PSNEqualsNoProcess:iTunesPSN])
    {
        // open iTunes using workspace; specifying .app here ensures that OS 9
        // iTunes doesn't get opened -- fixes:
        // http://bugs.wincent.org/bugs/bug.php?op=show&bugid=27
        if ([[NSWorkspace
            sharedWorkspace] launchApplication:@"iTunes.app"] == NO)
            ELOG(@"Error attempting to launch iTunes");
        else
        {
            // ask to be notified when iTunes finishes launching, and THEN tell
            // it to play
            waitingForITunesToLaunch = YES;

            if (![self iTunesSendsNotifications])
                [[[NSWorkspace sharedWorkspace]
                    notificationCenter] addObserver:self
                                           selector:@selector(iTunesDidLaunchNowPlay:)
                                               name:@"NSWorkspaceDidLaunchApplicationNotification"
                                             object:nil];
        }
    }
    else
        // Equivalent to: tell application "iTunes" to playpause
        [self sendAppleEventClass:'hook' ID:'PlPs'];

    buttonClickOccurred = YES; // a control button clicked?

    // but only fire main timer if iTunes was found in process list?
    [self timer:nil];
}

- (void)iTunesDidLaunchNowPlay:(NSNotification *)notification
{
    // an application has launched... not necessarily iTunes, so check to make
    // sure that it has indeed launched

    // we could check this the using Carbon (via our WOProcessManager wrapper)
    // but I prefer to use NSWorkspace here because it is NSWorkspace that
    // posted the notification! (I have a suspicion that Carbon might be able
    // to "see" processes sooner than NSWorkspace, perhaps too soon for iTunes
    // to be actually ready to receive Apple Events)

    NSArray *launchedApplications =
    [[NSWorkspace sharedWorkspace] launchedApplications];

    NSEnumerator *appEnumerator = [launchedApplications objectEnumerator];
    id application;

    while ((application = [appEnumerator nextObject]))
    {
        if ([[application objectForKey:@"NSApplicationName"] isEqualToString:@"iTunes"])
        {
            if (![self iTunesSendsNotifications])
                [[[NSWorkspace sharedWorkspace]
                    notificationCenter] removeObserver:self
                                                  name:@"NSWorkspaceDidLaunchApplicationNotification"
                                                object:nil];

            if ([self songToPlayOnceLaunched])
            {
                // use special method (user probably selected from global menu)
                [self tellITunesToPlaySong:[self songToPlayOnceLaunched]];
                [self setSongToPlayOnceLaunched:nil];
            }
            else
            {
                // use generic method
                [self tellITunesPlayPause];
            }

            break;
        }
    }
}

// use: [self sendAppleEventClass:'hook' ID:'Next'];
- (void)sendAppleEventClass:(AEEventClass)eventClass ID:(AEEventID)eventID
{
    ProcessSerialNumber iTunesPSN = [WOProcessManager PSNForSignature:'hook'];
    if ([WOProcessManager PSNEqualsNoProcess:iTunesPSN] == NO)
    {
        AppleEvent  event, reply;
        AEDesc      descriptor;
        if (AECreateDesc(typeProcessSerialNumber, &iTunesPSN, sizeof(iTunesPSN), &descriptor) == noErr)
        {
            if (AECreateAppleEvent(eventClass, eventID, &descriptor, kAutoGenerateReturnID, kAnyTransactionID, &event) == noErr)
            {
                if (AESend(&event, &reply, kAENoReply, kAENormalPriority, kAEDefaultTimeout, nil, nil) == noErr)
                    AEDisposeDesc(&reply);
                else
                    ELOG(@"Error (%d) sending Apple Event", noErr);

                AEDisposeDesc(&event);
            }
            AEDisposeDesc(&descriptor);
        }
    }
}

// tell iTunes to go to "next"
- (void)tellITunesNext
{
    // Equivalent to: tell application "iTunes" next track
    [self sendAppleEventClass:'hook' ID:'Next'];
    buttonClickOccurred = YES; // a hot-key was pressed

    if (![self iTunesSendsNotifications])
        [mainTimer fire];
}

// this code almost identical to the previous method; should re-factor
- (void) tellITunesFastForward
{
    // Equivalent to: tell application "iTunes" fast forward
    // (opposite Apple Event is 'Rwnd')
    [self sendAppleEventClass:'hook' ID:'Fast'];
}

- (void)tellITunesPrev;
{
    // depending on user prefs, end either "back" or "prev"
    if ([[synergyPreferences objectOnDiskForKey:_woPrevActionSameAsITunesPrefKey] boolValue])
        // Equivalent to: tell application "iTunes" back track
        [self sendAppleEventClass:'hook' ID:'Back'];
    else
        // Equivalent to: tell application "iTunes" prev track
        [self sendAppleEventClass:'hook' ID:'Prev'];

    buttonClickOccurred = YES; // a control button clicked?
    if (![self iTunesSendsNotifications])
        [mainTimer fire];
}

// this code almost identical to the tellITunesNext method
- (void)tellITunesRewind
{
    [self sendAppleEventClass:'hook' ID:'Rwnd'];
}

//- (IBAction) prevTrack:(id)sender
- (void) prevTrack:(id)sender
{
    [self tellITunesPrev];
}

- (IBAction)clearRecentSongs:(id)sender
{
    [songList removeAllObjects];
    for (NSMenuItem *item in [synergyGlobalMenu itemArray])
    {
        if ([item action] == @selector(playSong:))
            [synergyGlobalMenu removeItem:item];
    }
    [mainTimer fire];
}

- (void) cleanupBeforeExit
{
    // break down link with app
    [synergyPrefPane notifyPrefPane:WODNAppWillQuit];
    [synergyPrefPane removePrefPaneObserver];
    floaterController = nil;

    if (controlsStatusItem != nil)
    {
        [self hideControlsStatusItem];
        controlsStatusItem = nil;
    }

    if (globalMenuStatusItem != nil)
        [self removeGlobalMenu];

    songList = nil;

    if (getSongInfoScript != nil)
        getSongInfoScript = nil;

    if (mainTimer != nil)
    {
        [mainTimer invalidate];
        mainTimer = nil;
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // clean out "Temporary Album Covers"
    if (![[NSFileManager defaultManager] removeItemAtPath:[WOCoverDownloader tempAlbumCoversPath]
                                                    error:NULL])
        NSLog(@"Error while cleaning out Synergy \"Temporary Album Covers\" folder");
}

-(IBAction)playSong:(id)sender
{
    NSAppleEventDescriptor *songId;

    // adjust this value by one because the first item is just the "Recent
    // tracks" label
    int index = ([[sender menu] indexOfItem:sender] - 1);

    songId = [[songList objectAtIndex:index] objectForKey:WO_SONG_DICTIONARY_ID];

    ProcessSerialNumber iTunesPSN = [WOProcessManager PSNForSignature:'hook'];

    //we'll have to launch iTunes if it's not running
    if ([WOProcessManager PSNEqualsNoProcess:iTunesPSN])
    {
        // open iTunes using workspace; specifying .app here ensures that OS 9
        // iTunes doesn't get opened -- attempted fix for:
        // http://bugs.wincent.org/bugs/bug.php?op=show&bugid=27
        if ([[NSWorkspace sharedWorkspace] launchApplication:@"iTunes.app"] == NO)
            ELOG(@"Error attempting to launch iTunes");
        else
        {
            // store song descriptor
            [self setSongToPlayOnceLaunched:songId];

            // ask to be notified when iTunes finishes launching, and THEN tell
            // it to play
            waitingForITunesToLaunch = YES;

            if (![self iTunesSendsNotifications])
                [[[NSWorkspace sharedWorkspace]
                    notificationCenter] addObserver:self
                                           selector:@selector(iTunesDidLaunchNowPlay:)
                                               name:@"NSWorkspaceDidLaunchApplicationNotification"
                                             object:nil];

        }
    }
    else
    {

        AppleEvent  event, reply;
        AEDesc      theDescriptor;

        // this method does no testing to see if iTunes is running -- that should
        // be done before calling!

        if (AECreateDesc(typeProcessSerialNumber, &iTunesPSN, sizeof(iTunesPSN),
                         &theDescriptor) == noErr)
        {
            // Equivalent to: tell application "iTunes" to play
            if (AECreateAppleEvent('hook', 'Play', &theDescriptor,
                                   kAutoGenerateReturnID, kAnyTransactionID,
                                   &event) == noErr)
            {
                const DescType keyword = keyDirectObject; // 'form'; was 'obj '
                const AEDesc *thePointer = [songId aeDesc];

                if ((AEPutParamDesc(&event, keyword, thePointer)) != noErr)
                    ELOG(@"Error putting parameter in Apple Event");
                else
                {
                    if (AESend(&event, &reply, kAENoReply, kAENormalPriority,
                                kAEDefaultTimeout, nil, nil) == noErr)
                        AEDisposeDesc(&reply);
                    else
                        ELOG(@"Error sending Apple Event");
                }
                AEDisposeDesc(&event);
            }
            AEDisposeDesc(&theDescriptor);
        }

        buttonClickOccurred = YES; // a menu item was chosen
        if (![self iTunesSendsNotifications])
            [mainTimer fire];
    }
}

- (void)tellITunesToPlaySong:(NSAppleEventDescriptor *)descriptor
{
    ProcessSerialNumber iTunesPSN = [WOProcessManager PSNForSignature:'hook'];

    if ([WOProcessManager PSNEqualsNoProcess:iTunesPSN] == NO)
    {
        // iTunes is running
        AppleEvent  event, reply;
        AEDesc      theDescriptor;

        // this method does no testing to see if iTunes is running -- that should
        // be done before calling!

        if (AECreateDesc(typeProcessSerialNumber, &iTunesPSN, sizeof(iTunesPSN),
                         &theDescriptor) == noErr)
        {
            // Equivalent to: tell application "iTunes" to play
            if (AECreateAppleEvent('hook', 'Play', &theDescriptor,
                                   kAutoGenerateReturnID,
                                   kAnyTransactionID, &event) == noErr)
            {
                const DescType keyword = keyDirectObject; // 'form'; was 'obj '
                const AEDesc *thePointer = [descriptor aeDesc];

                if (AEPutParamDesc(&event, keyword, thePointer) != noErr)
                    ELOG(@"Error putting parameter in Apple Event");

                if (AESend(&event, &reply, kAENoReply, kAENormalPriority,
                           kAEDefaultTimeout, nil, nil) == noErr)
                    AEDisposeDesc(&reply);
                else
                    ELOG(@"Error sending Apple Event");

                AEDisposeDesc(&event);
            }
            AEDisposeDesc(&theDescriptor);
        }

        buttonClickOccurred = YES; // a menu item was chosen
        if (![self iTunesSendsNotifications])
            [mainTimer fire];
    }
}

-(IBAction)clearRecentSongsMenuItem:(id)sender
{
    [songList removeAllObjects];
    [self updateMenu];
}

-(IBAction)openPrefsMenuItem:(id)sender
{
    // we start at something like:
    //      /Applications/
    //          Synergy Preferences.app/
    //              Contents/
    //                  PreferencePanes/
    //                      Synergy.prefPane/
    //                          Contents/
    //                              Helpers/
    //                                  Synergy.app
    // so want to strip off the last 6 path components to get the path to the
    // preferences app (/Applications/Synergy Preferences.app)
    NSString *path = [[NSBundle mainBundle] bundlePath];
    for (unsigned i = 0; i < 6; i++)
         path = [path stringByDeletingLastPathComponent];
    if (!path || [path length] == 0)
        NSLog(@"Unable to get path to preferences application");
    else if (![[NSWorkspace sharedWorkspace] openFile:path])
        NSLog(@"Error while launching path: %@", path);
}

- (void)launchITunes
{
    // open iTunes using workspace
    if ([[NSWorkspace sharedWorkspace] launchApplication:@"iTunes.app"] == NO)
        ELOG(@"Error attempting to launch iTunes");
}

- (IBAction)shuffleMenuItem:(id)sender
{
    // (double) check if iTunes is running
    if ([WOProcessManager processRunningWithSignature:'hook'])
    {
        NSAppleScript *script;
        NSString *result;

        if ([shuffleMenuItem state] == NSOffState)
        {
            // shuffle (menu) was off: turn it on

            static NSString *scriptSource =
            @"tell application \"iTunes\"\n"
            @"  try\n"
            @"    -- this will fail if iTunes has no current selection\n"
            @"    set currentPlaylist to the container of the current track\n"
            @"    set shuffle of currentPlaylist to true\n"
            @"    return \"SUCCESS\"\n"
            @"  on error\n"
            @"    return \"ERROR\"\n"
            @"  end try\n"
            @"end tell";

            script = [[NSAppleScript alloc] initWithSource:scriptSource];
            result = [[NSString alloc] initWithString:[[script executeAndReturnError:NULL] stringValue]];

            if (result && [result isEqualToString:@"SUCCESS"])
            {
                [shuffleMenuItem setState:NSOnState];
            }
            else if (result && [result isEqualToString:@"ERROR"])
                ELOG(@"Error setting iTunes shuffle setting to ON");
            else
                ELOG(@"Unknown error while setting iTunes shuffle setting to ON");
        }
        else
        {
            // shuffle (menu) was on: turn it off

            static NSString *scriptSource =
            @"tell application \"iTunes\"\n"
            @"  try\n"
            @"    -- this will fail if iTunes has no current selection\n"
            @"    set currentPlaylist to the container of the current track\n"
            @"    set shuffle of currentPlaylist to false\n"
            @"    return \"SUCCESS\"\n"
            @"  on error\n"
            @"    return \"ERROR\"\n"
            @"  end try\n"
            @"end tell";

            script = [[NSAppleScript alloc] initWithSource:scriptSource];
            result = [[NSString alloc] initWithString:[[script executeAndReturnError:NULL] stringValue]];
            if (result && [result isEqualToString:@"SUCCESS"])
                [shuffleMenuItem setState:NSOffState];
            else if (result && [result isEqualToString:@"ERROR"])
                ELOG(@"Error setting iTunes shuffle setting to OFF");
            else
                ELOG(@"Unknown error while setting iTunes shuffle setting to OFF");
        }
    }
}

- (IBAction)repeatOffMenuItem:(id)sender
{
    // (double) check if iTunes is running
    if ([WOProcessManager processRunningWithSignature:'hook'])
    {
        static NSString *scriptSource =
            @"tell application \"iTunes\"\n"
            @"  try\n"
            @"    -- this will fail if iTunes has no current selection\n"
            @"    set currentPlaylist to the container of the current track\n"
            @"    set song repeat of currentPlaylist to off\n"
            @"    return \"SUCCESS\"\n"
            @"  on error\n"
            @"    return \"ERROR\"\n"
            @"  end try\n"
            @"end tell";

        NSAppleScript   *script = [[NSAppleScript alloc] initWithSource:scriptSource];
        NSString        *result = [[NSString alloc] initWithString:[[script executeAndReturnError:NULL] stringValue]];

        if (result && [result isEqualToString:@"SUCCESS"])
        {
            [repeatAllMenuItem setState:NSOffState];
            [repeatOffMenuItem setState:NSOnState]; // only this one is "on"
            [repeatOneMenuItem setState:NSOffState];
        }
        else if (result && [result isEqualToString:@"ERROR"])
            ELOG(@"Error setting repeat mode to OFF");
        else
            ELOG(@"Unknown error while setting repeat mode to OFF");
    }
}

- (IBAction)repeatAllMenuItem:(id)sender
{
    // (double) check if iTunes is running
    if ([WOProcessManager processRunningWithSignature:'hook'])
    {
        NSAppleScript *script;
        NSString *result;

        static NSString *scriptSource =
            @"tell application \"iTunes\"\n"
            @"  try\n"
            @"    -- this will fail if iTunes has no current selection\n"
            @"    set currentPlaylist to the container of the current track\n"
            @"    set song repeat of currentPlaylist to all\n"
            @"    return \"SUCCESS\"\n"
            @"  on error\n"
            @"    return \"ERROR\"\n"
            @"  end try\n"
            @"end tell";

        script = [[NSAppleScript alloc] initWithSource:scriptSource];
        result = [[NSString alloc] initWithString:
            [[script executeAndReturnError:NULL] stringValue]];

        if (result && [result isEqualToString:@"SUCCESS"])
        {
            [repeatAllMenuItem setState:NSOnState];   // only this one is "on"
            [repeatOffMenuItem setState:NSOffState];
            [repeatOneMenuItem setState:NSOffState];
        }
        else if (result && [result isEqualToString:@"ERROR"])
            ELOG(@"Error setting repeat mode to ALL");
        else
            ELOG(@"Unknown error while setting repeat mode to ALL");
    }
}

- (IBAction)repeatOneMenuItem:(id)sender
{
    if ([WOProcessManager processRunningWithSignature:'hook'])      // (double) check if iTunes is running
    {
        NSAppleScript *script;
        NSString *result;

        static NSString *scriptSource =
            @"tell application \"iTunes\"\n"
            @"  try\n"
            @"    -- this will fail if iTunes has no current selection\n"
            @"    set currentPlaylist to the container of the current track\n"
            @"    set song repeat of currentPlaylist to one\n"
            @"    return \"SUCCESS\"\n"
            @"  on error\n"
            @"    return \"ERROR\"\n"
            @"  end try\n"
            @"end tell";

        script = [[NSAppleScript alloc] initWithSource:scriptSource];
        result = [[NSString alloc] initWithString:
            [[script executeAndReturnError:NULL] stringValue]];

        if (result && [result isEqualToString:@"SUCCESS"])
        {
            [repeatAllMenuItem setState:NSOffState];
            [repeatOffMenuItem setState:NSOffState];
            [repeatOneMenuItem setState:NSOnState]; // only this one is "on"
        }
        else if (result && [result isEqualToString:@"ERROR"])
            ELOG(@"Error setting repeat mode to ONE");
        else
            ELOG(@"Unknown error while setting repeat mode to ONE");
    }
}

- (IBAction)activateITunesMenuItem:(id)sender
{
    [self tellITunesActivate];
}

- (IBAction)quitLaunchITunesMenuItem:(id)sender
{
    // if iTunes is not launched, launch it
    if((iTunesState == ITUNES_NOT_RUNNING) || (iTunesState == ITUNES_UNKNOWN))
    {
        // open iTunes using workspace
        [self launchITunes];

        [launchQuitITunesMenuItem setTitle:
            NSLocalizedString(@"Quit iTunes",@"Quit iTunes menu command")];

        [activateITunesMenuItem setEnabled:YES];
        [shuffleMenuItem setEnabled:YES];
        [repeatOneMenuItem setEnabled:YES];
        [repeatAllMenuItem setEnabled:YES];
        [repeatOffMenuItem setEnabled:YES];
    }
    else
    {
        // if iTunes is running, quit it
        // (ie. STOPPED, PAUSED, PLAYING, ERROR)

        // tell iTunes to quit using Apple Events
        [self sendAppleEventClass:'aevt' ID:'quit'];
        [launchQuitITunesMenuItem setTitle:
            NSLocalizedString(@"Launch iTunes",@"Launch iTunes menu command")];

        [activateITunesMenuItem setEnabled:NO];
        [shuffleMenuItem setEnabled:NO];
        [repeatOneMenuItem setEnabled:NO];
        [repeatAllMenuItem setEnabled:NO];
        [repeatOffMenuItem setEnabled:NO];
    }


    // must update menu item here (rather than firing mainTimer to do it),
    // because if we call the timer straight away, iTunes will launch again
    // immediately


    // re-enable timer? -- or will it again fire too soon?
}

- (IBAction)refreshPlaylistsSubmenu:(id)sender
{
    // only do this is iTunes is running
    ProcessSerialNumber iTunesPSN = [WOProcessManager PSNForSignature:'hook'];

    // but allow user to force an update if the update is triggered by selecting a menu item
    BOOL forceUpdate = sender ? [sender isKindOfClass:[NSMenuItem class]] : NO;
    if ([WOProcessManager PSNEqualsNoProcess:iTunesPSN] && !forceUpdate)
    {
        // iTunes is not running
        //
        // effectively, this means that if the user launches Synergy and iTunes
        // is not running, then the playlists menu will contain only a separator
        // and a "Refresh" item
        //
        // if the menu has already been populated, then the pre-existing entries will remain
        //
        // if the menu is not populated, will remove the separator to make it look nice
        if ([playlistsSubmenu numberOfItems] == 2 && [[playlistsSubmenu itemAtIndex:0] isSeparatorItem])
            // we have only a separator and "Refresh", remove the separator
            [playlistsSubmenu removeItemAtIndex:0];
    }
    else    // iTunes is running: do a proper update
    {
        NSArray *names = nil;
        @try
        {
            // do this the hard way -- [[iTunes sources] objectWithName:@"Library"] -- only works in English
            iTunesApplication *iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
            iTunesSource *library = nil;
            for (iTunesSource *source in [iTunes sources])
            {
                if ([source kind] == iTunesESrcLibrary)
                {
                    library = source;
                    break;
                }
            }
            names = [[library playlists] arrayByApplyingSelector:@selector(name)];
        }
        @catch (id e)
        {
            // we don't want a mere Apple Event error like this one derailing the entire applicaton:
            // *** Terminating app due to uncaught exception 'NSGenericException',
            // reason: 'Apple event returned an error.  Event = 'core'\'cnte'{ '----':'null'(), 'kocl':'cSrc' }
            // Error info = { ErrorNumber = -609; }
            // incidentally, error 609 may be "connection is invalid" or a timeout ("Apple Event timed out")
            // "there's a glitch in Apple's APIs that cause timeouts to sometimes raise error -609 instead of the usual -1712"
            // see: http://discussions.apple.com/thread.jspa?messageID=6925244
            // and: http://developer.apple.com/documentation/AppleScript/Conceptual/AppleScriptLangGuide/index.html
            names = [NSArray array];
        }

        // clear out existing entries in playlist submenu
        for (NSMenuItem *item in [playlistsSubmenu itemArray])
        {
            // only remove playlist entries (not separators, "Refresh" etc)
            if ([item action] == @selector(selectPlaylist:))
                [playlistsSubmenu removeItem:item];
        }

        // make sure we have a separator, but only if we need one
        if ([playlistsSubmenu numberOfItems] == 1 && names.count > 0)
            [playlistsSubmenu insertItem:[NSMenuItem separatorItem] atIndex:0];

        // add back in new entries, building menu in reverse order (inserting items at the top of the menu)
        for (NSUInteger i = names.count; i > 0; i--)
        {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[names objectAtIndex:i - 1]
                                                          action:@selector(selectPlaylist:)
                                                   keyEquivalent:@""];
            [item setTarget:self];
            [playlistsSubmenu insertItem:item atIndex:0];
        }
    }
}

// switches to a given playlist and starts playing
- (IBAction)selectPlaylist:(id)sender
{
    // note to self: do I have to strip out quote characters? escape them i mean
    // do I run into strife with foreign characters eg:
    // "Canciones españolas" returned as "Canciones espa\\361olas"

    // ensure sender is an NSMenuItem object
    if (![sender isKindOfClass:[NSMenuItem class]])
        return;

    NSAppleScript           *script = nil;
    NSAppleEventDescriptor  *result = nil;

    NSMutableString *playlistName =
        [NSMutableString stringWithString:[sender title]];

    // unfortunately the escaping in the following wreaks havoc with
    // Project Builder's auto-indenting:
    [playlistName replaceOccurrencesOfString:@"\""    /* replace " */
                                  withString:@"\\\""  /* with   \" */
                                     options:NSBackwardsSearch
                                       range:NSMakeRange(0, [playlistName length])];

NSString *activate;

// user prefs will dictate whether iTunes is brought to the front or not
if ([[synergyPreferences objectOnDiskForKey:_woBringITunesToFrontPrefKey] boolValue])
activate = @"activate";
else
activate = @"--activate";

    NSString *source =
        [NSString stringWithFormat:
            @"tell application \"iTunes\"\n"
            @"  try\n"
            @"    stop\n"
            @"    set thePlaylist to playlist \"%@\"\n"
            @"    %@\n"
            @"    set visible of browser window 1 to true\n"
            @"    set view of browser window 1 to thePlaylist\n"
            @"    play\n"
            @"    return \"SUCCESS\"\n"
            @"  on error\n"
            @"    return \"ERROR\"\n"
            @"  end try\n"
            @"end tell",
            playlistName,
            activate];

    script = [[NSAppleScript alloc] initWithSource:source];

    result = [script executeAndReturnError:NULL];

    if (!result)
    {
        // error
    }
    else
    {
        if ([[result stringValue] isEqualToString:@"ERROR"])
            ELOG(@"Warning: AppleScript error while attempting to switch to "
                 @"playlist \"%@\"", playlistName);
    }
}

- (IBAction)showAlbumCoversFolder:(id)sender
{
    NSString  *coversPath = [WOCoverDownloader albumCoversPath];
    NSURL     *coversURL  = [NSURL fileURLWithPath:coversPath];
    NSString  *albumPath  = [floaterController albumImagePath];

    // if we have an album cover image, reveal and select that
    if (albumPath)
        if ([[NSWorkspace sharedWorkspace] selectFile:albumPath
                             inFileViewerRootedAtPath:coversPath])
            return;

    // fallback case: just open the Album Covers folder
    if(![[NSWorkspace sharedWorkspace] openURL:coversURL])
        ELOG(@"Error: Could not open \"%@\"", coversPath);
}

- (IBAction)quitSynergyMenuItem:(id)sender
{
    [self cleanupBeforeExit];   // this will work
    exit(0);                    // this ugly old way...
}

// after reading preferences, tell floater how we want it to appear
- (void)configureFloater
{
    // if user hand-edits preferences plist and inserts non-numeric value
    // these calls won't work
    [floaterController setFloaterIconType:
        [[synergyPreferences objectOnDiskForKey:_woFloaterGraphicType] intValue]];

    [floaterController setDelayBeforeFade:
        [[synergyPreferences objectOnDiskForKey:_woFloaterDurationPrefKey] floatValue]];

    [floaterController setTransparency:
        [[synergyPreferences objectOnDiskForKey:_woFloaterTransparencyPrefKey] floatValue]];

    [floaterController setFgColor:[[synergyPreferences objectOnDiskForKey:_woFloaterForegroundColorPrefKey] floatValue]];

    [floaterController setBgColor:[[synergyPreferences objectOnDiskForKey:_woFloaterBackgroundColorPrefKey] floatValue]];

    //[floaterController setBgOpacity:[[synergyPreferences objectOnDiskForKey:_woFloaterBackgroundOpacityPrefKey] floatValue]];

    [floaterController setSize:
        [[synergyPreferences objectOnDiskForKey:_woFloaterSizePrefKey] intValue]];

    [floaterController setWindowOffset:
        NSMakePoint([[synergyPreferences objectOnDiskForKey:_woFloaterHorizontalOffset] floatValue],
                    [[synergyPreferences objectOnDiskForKey:_woFloaterVerticalOffset] floatValue])];

    [floaterController setXScreenSegment:
        [[synergyPreferences objectOnDiskForKey:_woFloaterHorizontalSegment] intValue]];

    [floaterController setYScreenSegment:
        [[synergyPreferences objectOnDiskForKey:_woFloaterVerticalSegment] intValue]];

    [floaterController setScreenNumber:
        [[synergyPreferences objectOnDiskForKey:_woScreenIndex] intValue]];

    // move the floater (doesn't display it, just moves it)
    [floaterController moveGivenOffset:NSMakePoint([[synergyPreferences objectOnDiskForKey:_woFloaterHorizontalOffset] floatValue],
                                                   [[synergyPreferences objectOnDiskForKey:_woFloaterVerticalOffset] floatValue])
                              xSegment:[[synergyPreferences objectOnDiskForKey:_woFloaterHorizontalSegment] intValue]
                              ySegment:[[synergyPreferences objectOnDiskForKey:_woFloaterVerticalSegment] intValue]];

    // just in case floater was set to "always" and it's been changed to something
    // less...
    if ([[synergyPreferences objectOnDiskForKey:_woFloaterDurationPrefKey] floatValue] < 21.0)
    {
        [floaterController fadeWindowOut:self];
    }

    // if floater display is set to "forever"... make sure it's on screen...
    [mainTimer fire]; // the timer routine will check
}

- (void)tellITunesActivate
{
    // new way (Apple Events)
    // based on "AEBuild*, AEPrint* and friends":
    //  http://developer.apple.com/technotes/tn/tn2045.html#dssyntaxcprgdb
    // and "Lazy AppleScript sending":
    //  http://www.unsanity.org/archives/000107.php#000107

    ProcessSerialNumber psn = [WOProcessManager PSNForSignature:'hook'];
    AppleEvent event;
    AEBuildError error;

    // provided iTunes is running proceed to send Apple event
    if (![WOProcessManager PSNEqualsNoProcess:psn])
    {

        // the business part of the event
        NSString* sendString=@"&subj:'null'()";

        OSStatus err = AEBuildAppleEvent('misc', 'actv',
                                         typeProcessSerialNumber,
                                         &psn, sizeof(ProcessSerialNumber),
                                         kAutoGenerateReturnID,
                                         kAnyTransactionID,
                                         &event, &error,
                                         [sendString UTF8String]);

        if (err)
        {
            // print the error and where it occurs
            ELOG(@"%lu:%lu error building \"%@\"", error.fError, error.fErrorPos,
                 [sendString substringToIndex:error.fErrorPos]);
        }
        else
        {
            AppleEvent reply;

            if (AESend(&event, &reply, kAENoReply, kAENormalPriority,
                       kAEDefaultTimeout, NULL, NULL) == noErr)
                AEDisposeDesc(&reply);

            AEDisposeDesc(&event);
        }
    }
    else
    {
        // iTunes is not running: do it the old way by firing off an AppleScript
        // this will have the effect of launching iTunes

        // old way (Apple Script)
        static NSString *scriptSource = @"tell application \"iTunes\" to activate";
        NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptSource];
        (void)[[NSString alloc] initWithString:[[script executeAndReturnError:NULL] stringValue]];
    }
}

// tell iTunes to up the volume by (approx) 6.25%
- (void)tellITunesVolumeUp
{
    // From the iTunes Scripting Dictionary:
    //
    // In "application" class:
    //     sound volume
    //         integer  -- the sound output volume (0 = minimum, 100 = maximum)
    //

    static NSString *scriptSource =
        @"tell application \"iTunes\"\n"
        @"  set currentVol to the sound volume as real\n"
        @"  set segmentNumber to ((currentVol / 6.25) div 1) as integer\n"
        @"  if segmentNumber is less than 15 then\n"
        @"    set segmentNumber to (segmentNumber + 1)\n"
        @"    set the sound volume to ((segmentNumber * 6.25) + 2)\n"
        @"  else\n"
        @"    set the sound volume to 100\n"
        @"  end if\n"
        @"  if the sound volume is 100 then\n"
        @"    return \"16\"\n"
        @"  else\n"
        @"    return segmentNumber as string\n"
        @"  end if\n"
        @"end tell";

    NSAppleScript   *script = [[NSAppleScript alloc] initWithSource:scriptSource];
    NSString        *result = [[script executeAndReturnError:NULL] stringValue];

    // update internal measure of which segments are "lit"
    if (result)
        segmentCount = [result intValue];
}

// tell iTunes to reduce the volume by 6.25%
- (void)tellITunesVolumeDown
{
    // Deduct 6 from the sound volume, down to a minimum of 6

    // tell application "iTunes"
    //   set currentVol to the sound volume as real
    //
    //   -- Special (boundary) cases
    //   -- 0 segments = 0 volume
    //   -- 16 segments = 100 volume
    //
    //   -- Other cases
    //   -- 15 segments
    //   -- 0.0 - 6.25 = 1st segment
    //   -- etc
    //   -- 93.75 - 100.0 = 15th segment
    //
    //   -- find out which segment we lie in
    //   set segmentNumber to ((currentVol / 6.25) div 1) as integer
    //
    //   -- reduce segment number
    //   if segmentNumber is greater than 1 then
    //     set segmentNumber to (segmentNumber - 1)
    //
    //     -- set sound volume according to new segment number
    //     -- add two to compensate for rounding down errors
    //     set the sound volume to ((segmentNumber * 6.25) + 2)
    //   else
    //     set the sound volume to 0
    //   end if
    //
    //   -- notify of new segment number, noting boundary cases
    //   if the sound volume is 0 then
    //     return 0
    //   else
    //     return segmentNumber
    //   end if
    // end tell

    NSAppleScript *script;
    NSString      *result;

    static NSString *scriptSource =
        @"tell application \"iTunes\"\n"
        @"  set currentVol to the sound volume as real\n"
        @"  set segmentNumber to ((currentVol / 6.25) div 1) as integer\n"
        @"  if segmentNumber is greater than 1 then\n"
        @"    set segmentNumber to (segmentNumber - 1)\n"
        @"    set the sound volume to ((segmentNumber * 6.25) + 2)\n"
        @"  else\n"
        @"    set the sound volume to 0\n"
        @"  end if\n"
        @"  if the sound volume is 0 then\n"
        @"    return \"0\"\n"
        @"  else\n"
        @"    return segmentNumber as string\n"
        @"  end if\n"
        @"end tell";

    script = [[NSAppleScript alloc] initWithSource:scriptSource];
    result = [[NSString alloc] initWithString:
        [[script executeAndReturnError:NULL] stringValue]];

    // update internal measure of which segments are "lit"
    if (result)
        segmentCount = [result intValue];
}

- (void)volumeUpHotKeyPressed
{
    // check if iTunes is running
    if ([WOProcessManager processRunningWithSignature:'hook'])
    {
        [feedbackController setBarEnabled:YES];
        [feedbackController setStarBarEnabled:NO];
        [feedbackController setIconType:WOFeedbackVolumeIcon];

        [self tellITunesVolumeUp];

        [feedbackController setEnabledSegments:segmentCount];
        if (extraFeedback)
        {
            [feedbackController showAtFullAlpha];
            [feedbackController delayedFadeOut];
        }
    }
}

- (void)volumeDownHotKeyPressed
{
    // check if iTunes is running
    if ([WOProcessManager processRunningWithSignature:'hook'])
    {
        [feedbackController setBarEnabled:YES];
        [feedbackController setStarBarEnabled:NO];
        [feedbackController setIconType:WOFeedbackVolumeIcon];

        [self tellITunesVolumeDown];

        [feedbackController setEnabledSegments:segmentCount];
        if (extraFeedback)
        {
            [feedbackController showAtFullAlpha];
            [feedbackController delayedFadeOut];
        }
    }
}

// called when user presses "Show floater" Hot Key
- (void)showHideFloaterHotKeyPressed
{
    // updated 6 April 2003 to make use of floaterActive bool value
    // http://bugs.wincent.org/bugs/bug.php?op=show&bugid=60&pos=21

    // if window is not already on screen AND at full alpha, show it
    if (!(([floaterController windowAlphaValue] == 1.0) &&
        ([floaterController windowIsVisible])))
    {
        [floaterController kickItClickStyle:self];

        if ([[synergyPreferences objectOnDiskForKey:_woFloaterDurationPrefKey] floatValue] > 21.0)
        {
            // if the floater is in "show always" mode, then pressing this
            // hot key is enough to make the changes permanent (otherwise only
            // way to permanently activate floater is to use Global menu)
            floaterActive = YES;

            [turnFloaterOnOffMenuItem setTitle:
                NSLocalizedString(@"Turn Floater off", @"'Turn Floater off' menuitem")];
        }
    }
    else
    {
        // if window is present and at full alpha, hide it (via a fade)
        [floaterController fadeWindowOut:self];

        // if floater is set to "show always", update menu item
        if ([[synergyPreferences objectOnDiskForKey:_woFloaterDurationPrefKey] floatValue] > 21.0)
        {
            // if the floater is in "show always" mode, then pressing this
            // hot key is enough to make the changes permanent (otherwise only
            // way to permanently dectivate floater is to use Global menu)
            floaterActive = NO;

            [turnFloaterOnOffMenuItem setTitle:
                NSLocalizedString(@"Turn Floater on", @"'Turn Floater on' menuitem")];
        }
    }
}

// these methods called so that we have a distinction between a button press
// and a hot key click
- (void)playPauseHotKeyPressed
{
    // save this for really slow machines (eg. Michael Simmons'!)
    // it might help us to guess the iTunes state if we can't get
    // it in the timer loop (because iTunes is too busy to reply to our
    // Apple Event)!
    int prevITunesState = iTunesState;

    [self tellITunesPlayPause]; // main timer will fire at the end of this...

    // in the case of the play/pause key, we have to wait until AFTER we hear
    // back from iTunes (and therefore know its state) before choosing the icon

    // only actually show the feedback window if user prefs say so
    if ([[synergyPreferences objectOnDiskForKey:_woShowFeedbackWindowPrefKey] boolValue] ==
        YES)
    {
        [feedbackController setBarEnabled:NO];
        [feedbackController setStarBarEnabled:NO];

        // special case for ITUNES_UNKNOWN (might be slow machines)
        if (iTunesState == ITUNES_UNKNOWN)
        {
            if (prevITunesState == ITUNES_UNKNOWN)
                // we didn't know before and we don't know now... great...
                [feedbackController setIconType:WOFeedbackPlayPauseIcon];
            else if (prevITunesState == ITUNES_PLAYING)
                // safe bet to show the pause icon: it's probably what the user
                // expects to see!
                [feedbackController setIconType:WOFeedbackPauseIcon];
            else if ((prevITunesState == ITUNES_PAUSED) ||
                     (prevITunesState == ITUNES_STOPPED) ||
                     (prevITunesState == ITUNES_NOT_RUNNING))
                // safe bet to show play icon: once again, it's probably what the
                // user expects to see!
                [feedbackController setIconType:WOFeedbackPlayIcon];
            else
                // probably was ITUNES_ERROR, best to just show safe icon:
                [feedbackController setIconType:WOFeedbackPlayPauseIcon];
        }
        // now we are out of the realm of speculation and into certainty!
        else if (iTunesState == ITUNES_PLAYING)
            [feedbackController setIconType:WOFeedbackPlayIcon];
        else if (iTunesState == ITUNES_PAUSED)
            [feedbackController setIconType:WOFeedbackPauseIcon];
        else if (iTunesState == ITUNES_STOPPED)
        {
            // now... why would the state be "stopped" if we just pressed play/
            // pause?
            if (prevITunesState == ITUNES_NOT_RUNNING)
                // safe bet that we were launched and aren't playing yet
                // user probably expects to see play icon
                [feedbackController setIconType:WOFeedbackPlayIcon];
            else
                // I'm not game to take a guess at this
                [feedbackController setIconType:WOFeedbackPlayPauseIcon];
        }
        else // back into the world of uncertainty!
            // if all else fails, fall back on this one!
            [feedbackController setIconType:WOFeedbackPlayPauseIcon];

        [feedbackController showAtFullAlpha];
        [feedbackController delayedFadeOut];
    }
}

- (void)rewindHotKeyPressed
{
    // user is pressing+holding the "prev" hot key, so initiate a rewind

    // only actually show the feedback window if the user prefs say so
    if ([[synergyPreferences objectOnDiskForKey:_woShowFeedbackWindowPrefKey] boolValue])
    {
        [feedbackController setBarEnabled:NO];
        [feedbackController setStarBarEnabled:NO];
        [feedbackController setIconType:WOFeedbackPrevIcon];
        [feedbackController showAtFullAlpha];

        // do not initiate fadeout until user releases the hot key!
    }
    [self audioscrobblerUserDidSkip];
    [self tellITunesRewind];
}

- (void)rewindHotKeyReleased
{
    // fade out the window if appropriate
    if ([[synergyPreferences objectOnDiskForKey:_woShowFeedbackWindowPrefKey] boolValue])
        [feedbackController delayedFadeOut];

    [self tellITunesResume];
}

- (void)fastForwardHotKeyPressed
{
    // user is pressing+holding the "next" hot key, so initiate a fast forward

    // only actually show the feedback window if the user prefs say so
    if ([[synergyPreferences objectOnDiskForKey:_woShowFeedbackWindowPrefKey] boolValue])
    {
        [feedbackController setBarEnabled:NO];
        [feedbackController setStarBarEnabled:NO];
        [feedbackController setIconType:WOFeedbackNextIcon];
        [feedbackController showAtFullAlpha];

        // do not initiate fadeout until user releases the hot key!
    }
    [self audioscrobblerUserDidSkip];
    [self tellITunesFastForward];
}

- (void)fastForwardHotKeyReleased
{
    // fade out the window if appropriate
    if ([[synergyPreferences objectOnDiskForKey:_woShowFeedbackWindowPrefKey] boolValue])
        [feedbackController delayedFadeOut];

    [self tellITunesResume];
}

// this code almost identical to the tellITunesFastForward method
- (void)tellITunesResume
{
    [self sendAppleEventClass:'hook' ID:'Resu'];
}

- (void)nextHotKeyPressed
{
    // only actually show the feedback window if the user prefs say so
    if ([[synergyPreferences objectOnDiskForKey:_woShowFeedbackWindowPrefKey] boolValue]==
        YES)
    {
        // additional layer of checking: show window only if iTunes is running
        // (if not running, hot key will have no effect anyway)
        ProcessSerialNumber iTunesPSN = [WOProcessManager PSNForSignature:'hook'];

        if ([WOProcessManager PSNEqualsNoProcess:iTunesPSN] == NO)
        {
            [feedbackController setBarEnabled:NO];
            [feedbackController setStarBarEnabled:NO];
            [feedbackController setIconType:WOFeedbackNextIcon];
            [feedbackController showAtFullAlpha];

            [self tellITunesNext];

            [feedbackController delayedFadeOut];
        }
    }
    else
        [self tellITunesNext];
}

- (void)prevHotKeyPressed
{
    // only actually show the feedback window if the user prefs say so
    if ([[synergyPreferences objectOnDiskForKey:_woShowFeedbackWindowPrefKey] boolValue] ==
        YES)
    {
        // additional layer of checking: show window only if iTunes is running
        // (if not running, hot key will have no effect anyway)
        ProcessSerialNumber iTunesPSN = [WOProcessManager PSNForSignature:'hook'];

        if ([WOProcessManager PSNEqualsNoProcess:iTunesPSN] == NO)
        {
            [feedbackController setBarEnabled:NO];
            [feedbackController setStarBarEnabled:NO];
            [feedbackController setIconType:WOFeedbackPrevIcon];
            [feedbackController showAtFullAlpha];

            [self tellITunesPrev];

            [feedbackController delayedFadeOut];
        }
    }
    else
        [self tellITunesPrev];
}

- (void)decreaseRatingHotKeyPressed
{
    // check if iTunes is running
    if ([WOProcessManager processRunningWithSignature:'hook'])
    {
        [feedbackController setBarEnabled:NO];
        [feedbackController setIconType:WOFeedbackVolumeIcon];
        [feedbackController setStarBarEnabled:YES];

        NSAppleScript *script;
        NSString *result;

        static NSString *scriptSource =
            @"tell application \"iTunes\"\n"
            @"  try\n"
            @"    set oldRating to rating of current track\n"
            @"    if oldRating > 80 then\n"
            @"      set rating of current track to 80\n"
            @"      return \"80\"\n"
            @"    else if oldRating > 60 then\n"
            @"      set rating of current track to 60\n"
            @"      return \"60\"\n"
            @"    else if oldRating > 40 then\n"
            @"      set rating of current track to 40\n"
            @"      return \"40\"\n"
            @"    else if oldRating > 20 then\n"
            @"      set rating of current track to 20\n"
            @"      return \"20\"\n"
            @"    else\n"
            @"      set rating of current track to 0\n"
            @"      return \"0\"\n"
            @"    end if\n"
            @"  on error\n"
            @"    return \"ERROR\"\n"
            @"  end try\n"
            @"end tell";

        script = [[NSAppleScript alloc] initWithSource:scriptSource];
        result = [[NSString alloc] initWithString:[[script executeAndReturnError:NULL] stringValue]];

        if (result && [result isEqualToString:@"80"])
        {
            [feedbackController setEnabledStars:4];

            if (extraFeedback)
            {
                [feedbackController showAtFullAlpha];
                [feedbackController delayedFadeOut];
            }

            // fire the timer here... this will have the effect of updating the floater
            // if it is already on screen and user preferences are set to "include
            // rating"
            if (![self iTunesSendsNotifications])
                [mainTimer fire];
        }
        else if (result && [result isEqualToString:@"60"])
        {
            [feedbackController setEnabledStars:3];
            if (extraFeedback)
            {
                [feedbackController showAtFullAlpha];
                [feedbackController delayedFadeOut];
            }
            if (![self iTunesSendsNotifications])
                [mainTimer fire];
        }
        else if (result && [result isEqualToString:@"40"])
        {
            [feedbackController setEnabledStars:2];
            if (extraFeedback)
            {
                [feedbackController showAtFullAlpha];
                [feedbackController delayedFadeOut];
            }
            if (![self iTunesSendsNotifications])
                [mainTimer fire];
        }
        else if (result && [result isEqualToString:@"20"])
        {
            [feedbackController setEnabledStars:1];
            if (extraFeedback)
            {
                [feedbackController showAtFullAlpha];
                [feedbackController delayedFadeOut];
            }
            if (![self iTunesSendsNotifications])
                [mainTimer fire];
        }
        else if (result && [result isEqualToString:@"0"])
        {
            [feedbackController setEnabledStars:0];
            if (extraFeedback)
            {
                [feedbackController showAtFullAlpha];
                [feedbackController delayedFadeOut];
            }
            if (![self iTunesSendsNotifications])
                [mainTimer fire];
        }
        else if (result && [result isEqualToString:@"ERROR"])
            // this usually means that iTunes is running but there is no current selection
            LOG(@"Error while decreasing song rating");
        else
            ELOG(@"Unknown error while decreasing song rating");
    }
}

- (void)increaseRatingHotKeyPressed
{
    // check if iTunes is running
    if ([WOProcessManager processRunningWithSignature:'hook'])
    {
        [feedbackController setBarEnabled:NO];
        [feedbackController setIconType:WOFeedbackVolumeIcon];
        [feedbackController setStarBarEnabled:YES];

        NSAppleScript *script;
        NSString *result;

        static NSString *scriptSource =
            @"tell application \"iTunes\"\n"
            @"  try\n"
            @"    set oldRating to rating of current track\n"
            @"    if oldRating < 20 then\n"
            @"      set rating of current track to 20\n"
            @"      return \"20\"\n"
            @"    else if oldRating < 40 then\n"
            @"      set rating of current track to 40\n"
            @"      return \"40\"\n"
            @"    else if oldRating < 60 then\n"
            @"      set rating of current track to 60\n"
            @"      return \"60\"\n"
            @"    else if oldRating < 80 then\n"
            @"      set rating of current track to 80\n"
            @"      return \"80\"\n"
            @"    else\n"
            @"      set rating of current track to 100\n"
            @"      return \"100\"\n"
            @"    end if\n"
            @"  on error\n"
            @"    return \"ERROR\"\n"
            @"  end try\n"
            @"end tell";

        script = [[NSAppleScript alloc] initWithSource:scriptSource];
        result = [[NSString alloc] initWithString:
            [[script executeAndReturnError:NULL] stringValue]];

        if (result && [result isEqualToString:@"20"])
        {
            [feedbackController setEnabledStars:1];
            if (extraFeedback)
            {
                [feedbackController showAtFullAlpha];
                [feedbackController delayedFadeOut];
            }
            // fire the timer here... this will have the effect of updating the floater
            // if it is already on screen and user preferences are set to "include
            // rating"
            if (![self iTunesSendsNotifications])
                [mainTimer fire];
        }
        else if (result && [result isEqualToString:@"40"])
        {
            [feedbackController setEnabledStars:2];
            if (extraFeedback)
            {
                [feedbackController showAtFullAlpha];
                [feedbackController delayedFadeOut];
            }
            if (![self iTunesSendsNotifications])
                [mainTimer fire];
        }
        else if (result && [result isEqualToString:@"60"])
        {
            [feedbackController setEnabledStars:3];
            if (extraFeedback)
            {
                [feedbackController showAtFullAlpha];
                [feedbackController delayedFadeOut];
            }
            if (![self iTunesSendsNotifications])
                [mainTimer fire];
        }
        else if (result && [result isEqualToString:@"80"])
        {
            [feedbackController setEnabledStars:4];
            if (extraFeedback)
            {
                [feedbackController showAtFullAlpha];
                [feedbackController delayedFadeOut];
            }
            if (![self iTunesSendsNotifications])
                [mainTimer fire];
        }
        else if (result && [result isEqualToString:@"100"])
        {
            [feedbackController setEnabledStars:5];
            if (extraFeedback)
            {
                [feedbackController showAtFullAlpha];
                [feedbackController delayedFadeOut];
            }
            if (![self iTunesSendsNotifications])
                [mainTimer fire];
        }
        else if (result && [result isEqualToString:@"ERROR"])
            // this usually means that iTunes is running but there is no current selection
            LOG(@"Error while increasing song rating");
        else
            ELOG(@"Unknown error while increasing song rating");
    }
}

- (void)rateAs0HotKeyPressed
{
    // check if iTunes is running
    if ([WOProcessManager processRunningWithSignature:'hook'])
    {
        [feedbackController setBarEnabled:NO];
        [feedbackController setIconType:WOFeedbackVolumeIcon];
        [feedbackController setStarBarEnabled:YES];
        [feedbackController setEnabledStars:0];

        // show feedback only if rating successfully set
        if ([self setRating:0] && extraFeedback)
        {
            [feedbackController showAtFullAlpha];
            [feedbackController delayedFadeOut];
        }

    }
}

- (void)rateAs1HotKeyPressed
{
    // check if iTunes is running
    if ([WOProcessManager processRunningWithSignature:'hook'])
    {
        [feedbackController setBarEnabled:NO];
        [feedbackController setIconType:WOFeedbackVolumeIcon];
        [feedbackController setStarBarEnabled:YES];
        [feedbackController setEnabledStars:1];

        // show feedback only if rating successfully set
        if ([self setRating:20] && extraFeedback)
        {
            [feedbackController showAtFullAlpha];
            [feedbackController delayedFadeOut];
        }

    }
}

- (BOOL)setRating:(int)newRating
{
    BOOL returnValue = NO;
    // abort if we get an illegal parameter
    if ((newRating < 0) || (newRating > 100))
    {
        ELOG(@"Out-of-range parameter submitted while setting song rating");
        return returnValue;
    }

    NSAppleScript *script;
    NSString *result;

    NSString *scriptSource = [NSString stringWithFormat:
        @"tell application \"iTunes\"\n"
        @"  try\n"
        @"    set rating of current track to %d\n"
        @"    return \"SUCCESS\"\n"
        @"  on error\n"
        @"    return \"ERROR\"\n"
        @"  end try\n"
        @"end tell",
        newRating];

    script = [[NSAppleScript alloc] initWithSource:scriptSource];
    result = [[NSString alloc] initWithString:
        [[script executeAndReturnError:NULL] stringValue]];

    if (result && [result isEqualToString:@"SUCCESS"])
    {
        // fire the timer here... this will have the effect of updating the floater
        // if it is already on screen and user preferences are set to "include
        // rating"
        if (![self iTunesSendsNotifications])
            [mainTimer fire];

        returnValue = YES;
    }
    else if (result && [result isEqualToString:@"ERROR"])
    {
        // this usually means that iTunes is running but there is no current
        // selection

        // return NO (don't show floater)
        returnValue = NO;

    }
    else
    {
        ELOG(@"Unknown error while setting song rating to %d", newRating);

        returnValue = NO; // (don't show floater)
    }
    return returnValue;
}

- (void)tellITunesToggleMute
{
    static NSString *scriptSource =
        @"tell application \"iTunes\"\n"
        @"  try\n"
        @"    if mute is true then\n"
        @"      set mute to false\n"
        @"      set currentVol to the sound volume as real\n"
        @"      set segmentNumber to ((currentVol / 6.25) div 1) as integer\n"
        @"      if the sound volume is 100 then\n"
        @"        return \"16\"\n"
        @"      else\n"
        @"        return segmentNumber as string\n"
        @"      end if\n"
        @"    else\n"
        @"      set mute to true\n"
        @"      return \"ON\"\n"
        @"    end if\n"
        @"  on error\n"
        @"    return \"ERROR\"\n"
        @"  end try\n"
        @"end tell";

    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptSource];
    NSString *result = [[NSString alloc] initWithString:[[script executeAndReturnError:NULL] stringValue]];

    [feedbackController setBarEnabled:YES];
    [feedbackController setStarBarEnabled:NO];
    [feedbackController setIconType:WOFeedbackVolumeIcon];

    if (result && [result isEqualToString:@"ON"])
        segmentCount = 0;
    else if (result && [result isEqualToString:@"ERROR"])
        ELOG(@"Error while toggling iTunes mute setting");
        // don't update segment count!
    else
        // result supposedly contains the segment count!
        segmentCount = [result intValue];

    [feedbackController setEnabledSegments:segmentCount];
    if (extraFeedback)
    {
        [feedbackController showAtFullAlpha];
        [feedbackController delayedFadeOut];
    }
}

- (void)tellITunesToggleShuffle
{
    BOOL error = NO;  // let's start off optimistic
    NSAppleScript *script;
    NSString *result;

    static NSString *scriptSource =
        @"tell application \"iTunes\"\n"
        @"  try\n"
        @"    -- this will fail if iTunes has no current selection\n"
        @"    set currentPlaylist to the container of the current track\n"
        @"    if shuffle of currentPlaylist is true then\n"
        @"      set shuffle of currentPlaylist to false\n"
        @"      return \"OFF\"\n"
        @"    else\n"
        @"      set shuffle of currentPlaylist to true\n"
        @"      return \"ON\"\n"
        @"    end if\n"
        @"  on error\n"
        @"    return \"ERROR\"\n"
        @"  end try\n"
        @"end tell";

    script = [[NSAppleScript alloc] initWithSource:scriptSource];
    result = [[NSString alloc] initWithString:
        [[script executeAndReturnError:NULL] stringValue]];

    [feedbackController setBarEnabled:NO];
    [feedbackController setStarBarEnabled:NO];

    if (result && [result isEqualToString:@"ON"])
    {
        [feedbackController setIconType:WOFeedbackShuffleOnIcon];
        [shuffleMenuItem setState:NSOnState];
    }
    else if (result && [result isEqualToString:@"OFF"])
    {
        [feedbackController setIconType:WOFeedbackShuffleOffIcon];
        [shuffleMenuItem setState:NSOffState];

    }
    else if (result && [result isEqualToString:@"ERROR"])
    {
        ELOG(@"Error while toggling iTunes shuffle setting");
        error = YES;
    }
    else
    {
        ELOG(@"Unknown error while toggling iTunes shuffle setting");
        error = YES;
    }

    if (!error && extraFeedback)
    {
        [feedbackController showAtFullAlpha];
        [feedbackController delayedFadeOut];
    }
}

- (void)tellITunesSetRepeatMode
{
    BOOL error = NO;
    NSAppleScript *script;
    NSString *result;

    static NSString *scriptSource =
        @"tell application \"iTunes\"\n"
        @"  try\n"
        @"    -- this will fail if iTunes has no current selection\n"
        @"    set currentPlaylist to the container of the current track\n"
        @"    -- cycle through in this order: off, all, one\n"
        @"    if song repeat of currentPlaylist is off then\n"
        @"      set song repeat of currentPlaylist to all\n"
        @"      return \"ALL\"\n"
        @"    else\n"
        @"      if song repeat of currentPlaylist is all then\n"
        @"        set song repeat of currentPlaylist to one\n"
        @"        return \"ONE\"\n"
        @"      else\n"
        @"        set song repeat of currentPlaylist to off\n"
        @"        return \"OFF\"\n"
        @"      end if\n"
        @"    end if\n"
        @"  on error\n"
        @"    return \"ERROR\"\n"
        @"  end try\n"
        @"end tell";

        script = [[NSAppleScript alloc] initWithSource:scriptSource];
    result = [[NSString alloc] initWithString:
        [[script executeAndReturnError:NULL] stringValue]];

    [feedbackController setBarEnabled:NO];
    [feedbackController setStarBarEnabled:NO];

    if (result && [result isEqualToString:@"ALL"])
    {
        [feedbackController setIconType:WOFeedbackRepeatAllIcon];

        [repeatAllMenuItem setState:NSOnState];  // only this one is "on"
        [repeatOffMenuItem setState:NSOffState];
        [repeatOneMenuItem setState:NSOffState];
    }
    else if (result && [result isEqualToString:@"ONE"])
    {
        [feedbackController setIconType:WOFeedbackRepeatOneIcon];

        [repeatAllMenuItem setState:NSOffState];
        [repeatOffMenuItem setState:NSOffState];
        [repeatOneMenuItem setState:NSOnState]; // only this one is "on"
    }
    else if (result && [result isEqualToString:@"OFF"])
    {
        [feedbackController setIconType:WOFeedbackRepeatOffIcon];

        [repeatAllMenuItem setState:NSOffState];
        [repeatOffMenuItem setState:NSOnState]; // only this one is "on"
        [repeatOneMenuItem setState:NSOffState];
    }
    else if (result && [result isEqualToString:@"ERROR"])
    {
        ELOG(@"Error while cycling to next iTunes repeat mode");

        error = YES;

        // all off!
        [repeatAllMenuItem setState:NSOffState];
        [repeatOffMenuItem setState:NSOffState];
        [repeatOneMenuItem setState:NSOffState];
    }
    else
    {
        ELOG(@"Unknown error while cycling to next iTunes repeat mode");

        error = YES;

        // all off!
        [repeatAllMenuItem setState:NSOffState];
        [repeatOffMenuItem setState:NSOffState];
        [repeatOneMenuItem setState:NSOffState];
    }

    if (!error && extraFeedback)
    {
        [feedbackController showAtFullAlpha];
        [feedbackController delayedFadeOut];
    }
}

- (void)toggleMuteHotKeyPressed
{
    if ([WOProcessManager processRunningWithSignature:'hook'])
        [self tellITunesToggleMute];
}

- (void)toggleShuffleHotKeyPressed
{
    if ([WOProcessManager processRunningWithSignature:'hook'])
        [self tellITunesToggleShuffle];
}

- (void)setRepeatModeHotKeyPressed
{
    if ([WOProcessManager processRunningWithSignature:'hook'])
        [self tellITunesSetRepeatMode];
}

- (void)rateAs2HotKeyPressed
{
    if ([WOProcessManager processRunningWithSignature:'hook'])
    {
        [feedbackController setBarEnabled:NO];
        [feedbackController setIconType:WOFeedbackVolumeIcon];
        [feedbackController setStarBarEnabled:YES];
        [feedbackController setEnabledStars:2];

        // show feedback only if rating successfully set
        if ([self setRating:40] && extraFeedback)
        {
            [feedbackController showAtFullAlpha];
            [feedbackController delayedFadeOut];
        }

    }
}

- (void)rateAs3HotKeyPressed
{
    if ([WOProcessManager processRunningWithSignature:'hook'])
    {
        [feedbackController setBarEnabled:NO];
        [feedbackController setIconType:WOFeedbackVolumeIcon];
        [feedbackController setStarBarEnabled:YES];
        [feedbackController setEnabledStars:3];

        // show feedback only if rating successfully set
        if ([self setRating:60] && extraFeedback)
        {
            [feedbackController showAtFullAlpha];
            [feedbackController delayedFadeOut];
        }

    }
}

- (void)rateAs4HotKeyPressed
{
    if ([WOProcessManager processRunningWithSignature:'hook'])
    {
        [feedbackController setBarEnabled:NO];
        [feedbackController setIconType:WOFeedbackVolumeIcon];
        [feedbackController setStarBarEnabled:YES];
        [feedbackController setEnabledStars:4];

        // show feedback only if rating successfully set
        if ([self setRating:80] && extraFeedback)
        {
            [feedbackController showAtFullAlpha];
            [feedbackController delayedFadeOut];
        }
    }
}

- (void)rateAs5HotKeyPressed
{
    if ([WOProcessManager processRunningWithSignature:'hook'])
    {
        [feedbackController setBarEnabled:NO];
        [feedbackController setIconType:WOFeedbackVolumeIcon];
        [feedbackController setStarBarEnabled:YES];
        [feedbackController setEnabledStars:5];

        // show feedback only if rating successfully set
        if ([self setRating:100] && extraFeedback)
        {
            [feedbackController showAtFullAlpha];
            [feedbackController delayedFadeOut];
        }

    }
}

- (void)activateITunesHotKeyPressed
{
    // if iTunes is running Carbon Process Manager AND frontmost (again, CPM),
    // hide it
    // else bring it to front...
    // although we can't be sure iTunes is running, it's an acceptable to run
    // the risk of being mistaken because this is a hot-key-initiated action,
    // not a timer-driven one...

    // find out frontmost process:
    ProcessSerialNumber frontPID;
    OSErr errCode;

    errCode = GetFrontProcess(&frontPID);

    if (errCode == noErr)
    {
        // we have the PID for the frontmost process

        // get iTunes PID
        ProcessSerialNumber iTunesPID;
        iTunesPID = [WOProcessManager PSNForSignature:'hook'];

        if(([WOProcessManager processRunningWithSignature:'hook']) &&
           ([WOProcessManager process:iTunesPID
                             isSameAs:frontPID]))
        {
            // iTunes is running and it is frontmost
            [self hideITunes];
        }
        else
        {
            // iTunes is either not running, or not frontmost; in both cases, bring
            // it to the front
            [self tellITunesActivate];
        }
    }
    else
        ELOG(@"Error getting frontmost process");
}

- (void)hideITunes
{
    NSAppleScript   *script;
    NSString        *result;

    static NSString *scriptSource =
        @"tell application \"System Events\"\n"
        @"  try\n"
        @"    set visible of process \"iTunes\" to false\n"
        @"    return \"SUCCESS\"\n"
        @"  on error\n"
        @"    return \"ERROR\"\n"
        @"  end try\n"
        @"end tell";

    script = [[NSAppleScript alloc] initWithSource:scriptSource];
    result = [[NSString alloc] initWithString:
        [[script executeAndReturnError:NULL] stringValue]];

    if (result && [result isEqualToString:@"SUCCESS"])
    {
        //VLOG(@"Successfully issued \"hide iTunes\" directive");
    }
    else if (result && [result isEqualToString:@"ERROR"])
        ELOG(@"Error while issuing \"hide iTunes\" directive");
    else
        ELOG(@"Unknown error while issuing \"hide iTunes\" directive");
}

// make sure iTunes is running and ready to process Apple Events before firing
// off our status script
- (BOOL)iTunesReadyToReceiveAppleScript
/*"
 This is the fix for the iTunes "unwanted respawn" bug in which iTunes lingers
 on in the list of running processes for as long as 2 seconds after exiting, and
 an unwanted respawn results on sending it an AppleScript because all "tell"
 statements include an implicit "run".

 The workaround is to try to send an Apple Event which requires a reply, and
 test to see if a timeout is exceeded. If the timeout is exceeded then we assume
 that iTunes is not ready to receive the AppleScript, and in fact it is probably
 not running.

 We send the 'doex' Apple Event (equivalent to the "exists" AppleScript keyword)
 as this will have no undesired side-effects in the event that the event does
 make it through.

 We ignore the Apple documentation which requires us to implement an "idle
 handler" when using the kAEWaitReply mode; there do not appear to be any
 harmful side-effects.
"*/
{
    BOOL readyToReceiveAppleScript = NO;

    ProcessSerialNumber iTunesPSN = [WOProcessManager PSNForSignature:'hook'];

    // make sure iTunes is running
    if ([WOProcessManager PSNEqualsNoProcess:iTunesPSN] == NO)
    {
        AppleEvent  event, reply;
        AEDesc      AEdescriptor;

        if (AECreateDesc(typeProcessSerialNumber, &iTunesPSN, sizeof(iTunesPSN),
                         &AEdescriptor) == noErr)
        {
            if (AECreateAppleEvent('hook', 'doex', &AEdescriptor,
                                   kAutoGenerateReturnID, kAnyTransactionID,
                                   &event) == noErr)
            {
                if (AESend(&event, &reply, kAEWaitReply, kAEHighPriority,
                           kAEDefaultTimeout, nil, nil) == noErr)
                {
                    AEDisposeDesc(&reply);  // this was a leak
                    readyToReceiveAppleScript = YES;
                }

                AEDisposeDesc(&event);
            }
            AEDisposeDesc(&AEdescriptor);
        }
    }
    return readyToReceiveAppleScript;
}

- (NSString *)chooseRandomButtonSet
{
    NSArray *buttonSets     = [WOButtonSet availableButtonSets];
    int     buttonSetIndex  = [WOButtonSet randomButtonSetMin:0 max:([buttonSets count] - 1)];
    return [buttonSets objectAtIndex:buttonSetIndex];
}

- (IBAction)turnFloaterOnOff:(id)sender
{
    if (floaterActive)
    {
        // toggle floater off
        floaterActive = NO;

        // fade immediately
        [floaterController fadeWindowOut:self];

        // update menu item
        [turnFloaterOnOffMenuItem setTitle:NSLocalizedString(@"Turn Floater on", @"'Turn Floater on' menuitem")];
    }
    else
    {
        // toggle floater back on
        floaterActive = YES;

        // fade it in, provided it's not already onscreen
        if (!(([floaterController windowAlphaValue] == 1.0) && ([floaterController windowIsVisible])))
            [floaterController kickItClickStyle:self];

        // update menu item
        [turnFloaterOnOffMenuItem setTitle:NSLocalizedString(@"Turn Floater off", @"'Turn Floater off' menuitem")];
    }
}

- (NSString *)audioscrobblerMenuTitleForState:(BOOL)enabled
{
    if (enabled)
        return NSLocalizedString(@"Disable last.fm submissions",
                                 @"Disable last.fm submissions");
    else
        return NSLocalizedString(@"Enable last.fm submissions",
                                 @"Enable last.fm submissions");
}

- (IBAction)toggleAudioscrobbler:(id)sender
{
    BOOL enabled = [self audioscrobblerEnabled];
    if (enabled)
        [self audioscrobblerDisable];
    else
        [self audioscrobblerEnable];
    [toggleAudioscrobblerMenuItem setTitle:[self audioscrobblerMenuTitleForState:!enabled]];
    [synergyPrefPane sendUpdatedPrefsToPrefPane:WO_DICTIONARY(@"enableLastFm", WO_BOOL(!enabled))];
}

- (IBAction)buyFromAmazon:(id)sender
{
    // menu item should be ghosted when no result for currently playing song
    // found on amazon... no....

    // two options here: construct another query and just send that off to
    // browser, or cache the URLs along with the songs (in the same way we
    // cache info for the recently played list in the Global menu)
    // and of course, the compromise case would be needed anyway:
    // if no URL found in cache, do a search anyway
    // if menu were ghosted out in this case, users would see it as a bug,
    // better to allow them to always select it, even if the search results
    // produce nothing
    // this could happen relatively often because the URLs will only be in the
    // cache according to the number of "recent tracks" allowed by user prefs.
    // and if the album cover is already downloaded on a previous run, no
    // connection will be made to amazon.com at all.
    // alternative ideas: store url in file along with image in cache folder
    // (I like it)... same filename, just with .plist extension
    // downside: lots of disk access if skipping tracks fast
    // workaround: combine on disk and in-memory caches ie. not only read info
    // from disk, but store it in global song list as well, so if it is there
    // that value is used first. only if not there do we look on disk, and if
    // no value found in either place then we construct a search string for the
    // link.
    //
    // Naturally, the cache idea is more elegant: and we can just add another
    // key/value pair to the songInfo dictionary for each song.
    // this will be tricky, because we'll need a thread-safe accessor here to
    // the global songList array (stored here in main thread). Each thread
    // will have to do a thread-safe implementation of NSObject's
    // peformSelectorOnMainThread so as to update the array (if possible!)

    id currentSong = [songList objectAtIndex:0];

    if (!currentSong)
    {
        ELOG(@"No current song information available!");

        return;
    }

    // get the URL
    NSURL *buyURL = [[currentSong objectForKey:WO_SONG_DICTIONARY_SONGINFO] performSelector:@selector(buyNowURL)];

    if ([[NSWorkspace sharedWorkspace] openURL:buyURL] == NO)
        ELOG(@"Failed opening \"buy now\" link in default browser");
}

// called when download is completed in separate thread
- (void)coverDownloadDone:(NSNotification *)notification
{
    // make sure this is a type of notification we understand
    if ([[notification name] isEqualToString:WO_DOWNLOAD_DONE_NOTIFICATION])
    {
        WOSongInfo *completedSong =
        [[notification userInfo] objectForKey:WO_DOWNLOADED_SONG_ID];

        // make sure we can identify the song that was completed
        if(!completedSong)
            return;

        if ((id)[songList objectAtIndex:0] == (id)completedSong)
        {
            // append filename to Album Covers folder path
            NSString *tempString = [[WOCoverDownloader albumCoversPath] stringByAppendingPathComponent:[completedSong filename]];

            // notify floater
            [floaterController setAlbumImagePath:tempString];
        }
    }
    else if ([[notification name] isEqualToString:WO_BUY_NOW_LINK_NOTIFICATION])
    {
        WOSongInfo *buyNowLinkSong =
        [[notification userInfo] objectForKey:WO_BUY_NOW_LINK_SONG_ID];

        // make sure we can id the song for which we now have a link
        if (!buyNowLinkSong)
            return;

        // also: by now has written to a file in Album Covers folder (except in
        // the event of an error)

        // just unghost the appropriate menu item if songId
        // matches head of song list...

        if ((id)[songList objectAtIndex:0] == (id)buyNowLinkSong)
        {
            // unghost menu
            [buyFromAmazonMenuItem setEnabled:YES];
        }
    }
}

#pragma mark -
#pragma mark NSApplication delegate methods
#pragma mark -

- (void)applicationDidChangeScreenParameters:(NSNotification *)aNotification
{
    // must notify feedback floater so that it can re-calculate its geometry
    [feedbackController applicationDidChangeScreenParameters:aNotification];
}

#pragma mark -
#pragma mark Methods written with some clue
#pragma mark -

- (BOOL)iTunesSendsNotifications
{
    static BOOL firstRun = YES;
    if (!firstRun) return iTunesSendsNotifications;
    firstRun = NO;

    NSWorkspace *workspace  = [NSWorkspace sharedWorkspace];
    NSString    *path       = [workspace fullPathForApplication:@"iTunes.app"];
    if (path)
    {
        NSBundle     *bundle     = [NSBundle bundleWithPath:path];
        NSDictionary *info       = [bundle infoDictionary];
        NSString     *version    = [info objectForKey:@"CFBundleVersion"];
        NSArray      *components = [version componentsSeparatedByString:@"."];
        if (components && ([components count] >= 2))
        {
            int majorVersion, minorVersion;
            NSScanner *scanner1 = [NSScanner scannerWithString:[components objectAtIndex:0]];
            NSScanner *scanner2 = [NSScanner scannerWithString:[components objectAtIndex:1]];
            if ([scanner1 scanInt:&majorVersion] && [scanner2 scanInt:&minorVersion])
            {
                if (((majorVersion == 4) && (minorVersion >= 7)) || (majorVersion > 4))
                    iTunesSendsNotifications = YES;
            }
        }
    }

    return iTunesSendsNotifications;
}

- (void)handleNotification:(NSNotification *)aNotification
{
    if ([@"com.apple.iTunes.playerInfo" isEqual:[aNotification name]] ||
        [@"com.apple.iTunes.player" isEqual:[aNotification object]])
    {
        [self launchTrackChangeItems:[self trackChangeLaunchItems]]; // new in 1.7

        NSDictionary *userInfo = [aNotification userInfo];
        if (!userInfo || ![userInfo isKindOfClass:[NSDictionary class]])
            return;

        //NSString *grouping = [userInfo objectForKey:@"Grouping"];
        NSString *name = [userInfo objectForKey:@"Name"];

        // "Playing", "Stopped", "Paused"
        NSString *playerState = [userInfo objectForKey:@"Player State"];

        if (!playerState || ![playerState isKindOfClass:[NSString class]])
            playerState = @"Unknown state";

        // http://wincent.com/a/support/bugs/show_bug.cgi?id=142
        if ([playerState isEqualToString:@"Stopped"] && !name)
            return;

        // hopefully fix this by moving this here (ie. don't update floater if iTunes has just exited; it will get updated in handleWorkspaceNotification)
        // http://wincent.com/a/support/bugs/show_bug.cgi?id=188
        [self timer:nil]; // update the floater etc

        // int (milliseconds)
        NSNumber *totalTime = [userInfo objectForKey:@"Total Time"];
        NSString *album = [userInfo objectForKey:@"Album"];
        NSString *artist = [userInfo objectForKey:@"Artist"];
        // "file://localhost..." (local file)
        // "http://pri.kts-af.net/redir/index..." (Internet radio)
        NSString *location = [userInfo objectForKey:@"Location"];

        // Audioscrobbler support; new in 3.1
        WOAudioscrobblerLog(@"Received notification from iTunes");
        if (!totalTime || ([totalTime unsignedIntValue] < (30 * 1000)))
            [self audioscrobblerCurrentTrackIsTooShort];
        else if (!location || ![location hasPrefix:@"file://"])
            [self audioscrobblerCurrentTrackIsNotRegularFile];
        else if ([playerState isEqualToString:@"Playing"])
            [self audioscrobblerUpdateWithSong:name artist:artist album:album length:[totalTime unsignedIntValue]];
        else
            [self audioscrobblerNotPlaying:name artist:artist album:album length:[totalTime unsignedIntValue]];

        // Growl support; also new in 1.7
        // might be able to save some cycles here by calling isGrowlInstalled
        // and isGrowlRunning before proceeding
        NSNumber *year = [userInfo objectForKey:@"Year"];       // int
        NSString *composer = [userInfo objectForKey:@"Composer"];
        NSNumber *rating = [userInfo objectForKey:@"Rating"];   // int (0 - 100)

        // build description string
        NSMutableString *workString = [NSMutableString string];
        NSString *timeString = @"";

        NSNumber *pref = [synergyPreferences objectOnDiskForKey:_woIncludeAlbumInFloaterPrefKey];
        if (pref && [pref boolValue] && album && [album isKindOfClass:[NSString class]])
        {
            [workString appendFormat:@"%@", album];

            pref = [synergyPreferences objectOnDiskForKey:_woIncludeYearInFloaterPrefKey];
            if (pref && [pref boolValue] && year && [year isKindOfClass:[NSNumber class]])
                [workString appendFormat:@" (%d)\n", [year intValue]];
            else
                [workString appendString:@"\n"];
        }

        BOOL showArtist = NO;
        BOOL showComposer = NO;

        pref = [synergyPreferences objectOnDiskForKey:_woIncludeArtistInFloaterPrefKey];
        if (pref && [pref boolValue])
            showArtist = YES;

        pref = [synergyPreferences objectOnDiskForKey:_woIncludeComposerInFloaterPrefKey];
        if (pref && [pref boolValue])
            showComposer = YES;

        NSString *artistOrComposer = @"Unknown artist";
        if (showArtist && showComposer)
        {
            if (artist && composer)
                artistOrComposer =
                [NSString stringWithFormat:@"%@ (%@)", artist, composer];
            else if (artist)
                artistOrComposer = artist;
            else if (composer)
                artistOrComposer = composer;
            [workString appendFormat:@"%@\n", artistOrComposer];
        }
        else if (showArtist)
        {
            if (artist)
                artistOrComposer = artist;
            [workString appendFormat:@"%@\n", artistOrComposer];
        }
        else if (showComposer)
        {
            if (composer)
                artistOrComposer = composer;
            [workString appendFormat:@"%@\n", artistOrComposer];
        }

        pref = [synergyPreferences objectOnDiskForKey:_woIncludeStarRatingInFloaterPrefKey];
        if (pref && [pref boolValue] && rating && [rating isKindOfClass:[NSNumber class]])
        {
            unichar star = WO_ALT_RATING_STAR;
            NSString *ratingString = @"";
            int ratingNumber = [rating intValue];
            if (ratingNumber > 80)
                ratingString = [NSString stringWithFormat:@"%C%C%C%C%C",
                                star, star,
                                star, star,
                                star];
            else if (ratingNumber > 60)
                ratingString = [NSString stringWithFormat:@"%C%C%C%C",
                                star, star,
                                star, star];
            else if (ratingNumber > 40)
                ratingString = [NSString stringWithFormat:@"%C%C%C",
                                star, star,
                                star];
            else if (ratingNumber > 20)
                ratingString = [NSString stringWithFormat:@"%C%C",
                                star, star];
            else if (ratingNumber > 0)
                ratingString = [NSString stringWithFormat:@"%C", star];

            [workString appendFormat:@"%@\n", ratingString];
        }

        pref = [synergyPreferences objectOnDiskForKey:_woIncludeDurationInFloaterPrefKey];
        if (pref && [pref boolValue] && totalTime && [totalTime isKindOfClass:[NSNumber class]])
        {
            int seconds = [totalTime intValue] / 1000;
            int days = seconds / 86400;
            int hours = (seconds - (days * 86400)) / 3600;
            int minutes = (seconds - (days * 86400) - (hours * 3600)) / 60;
            seconds = seconds - (days * 86400) - (hours * 3600) - (minutes * 60);

            if (days > 0)
                timeString = [NSString stringWithFormat:
                              @" (%02d:%02d:%02d:%02d)", days, hours, minutes, seconds];
            else if (hours > 0)
                timeString =
                [NSString stringWithFormat:@" (%02d:%02d:%02d)", hours, minutes, seconds];
            else
                timeString =
                [NSString stringWithFormat:@" (%02d:%02d)", minutes, seconds];
        }

        // if iconData is nil, Growl will display Synergy icon instead
        NSData *iconData = [[floaterController coverImage] TIFFRepresentation];
        NSString *growlTitle = [NSString stringWithFormat:@"%@: %@%@", playerState, name, timeString];
        NSString *growlDescription = [NSString stringWithString:workString];

        // new for 2.0: coalesce Growl notications
        NSDictionary *d = nil;
        if (iconData)
            d = [NSDictionary dictionaryWithObjectsAndKeys:
                 @"Synergy",                         GROWL_APP_NAME,
                 @"iTunes update",                   GROWL_NOTIFICATION_NAME,
                 growlTitle,                         GROWL_NOTIFICATION_TITLE,
                 growlDescription,                   GROWL_NOTIFICATION_DESCRIPTION,
                 iconData,                           GROWL_NOTIFICATION_ICON,
                 [NSNumber numberWithInt:0],         GROWL_NOTIFICATION_PRIORITY,
                 [NSNumber numberWithBool:NO],       GROWL_NOTIFICATION_STICKY,
                 @"Click",                           GROWL_NOTIFICATION_CLICK_CONTEXT,
                 @"CoalescedSynergyNotification",    GROWL_NOTIFICATION_IDENTIFIER,
                 nil];
        else
            d = [NSDictionary dictionaryWithObjectsAndKeys:
                 @"Synergy",                         GROWL_APP_NAME,
                 @"iTunes update",                   GROWL_NOTIFICATION_NAME,
                 growlTitle,                         GROWL_NOTIFICATION_TITLE,
                 growlDescription,                   GROWL_NOTIFICATION_DESCRIPTION,
                 [NSNumber numberWithInt:0],         GROWL_NOTIFICATION_PRIORITY,
                 [NSNumber numberWithBool:NO],       GROWL_NOTIFICATION_STICKY,
                 @"Click",                           GROWL_NOTIFICATION_CLICK_CONTEXT,
                 @"CoalescedSynergyNotification",    GROWL_NOTIFICATION_IDENTIFIER,
                 nil];
        [GrowlApplicationBridge notifyWithDictionary:d];
    }
}

// watch for iTunes launch/quit events
- (void)handleWorkspaceNotification:(NSNotification *)aNotification
{
    NSString *identifier = [[aNotification userInfo] objectForKey:@"NSApplicationBundleIdentifier"];

    if ([identifier isEqualToString:@"com.apple.iTunes"])
    {
        if ([[aNotification name] isEqualToString:@"NSWorkspaceDidLaunchApplicationNotification"])
        {
            // even if iTunes isn't ready at this point, it will send a notification on the first status change
            [self timer:nil];

            if (waitingForITunesToLaunch)   // jam in old code
            {
                waitingForITunesToLaunch = NO;
                [self iTunesDidLaunchNowPlay:aNotification];
            }
        }
        else if ([[aNotification name] isEqualToString:@"NSWorkspaceDidTerminateApplicationNotification"])
        {
            // taken straight out of timer method but rewritten with some "clue"
            [self updateTooltip:NSLocalizedString(@"Not running", @"Not running tool-tip")];
            iTunesState = ITUNES_NOT_RUNNING;   // update state variable

            if (!buttonClickOccurred)
            {
                if ([[synergyPreferences objectOnDiskForKey:_woControlHidingPrefKey] intValue])
                {
                    [self hideControlsStatusItem];
                    if (!globalMenuStatusItem && [[synergyPreferences objectOnDiskForKey:_woGlobalMenuPrefKey] boolValue])
                        [self addGlobalMenu];
                }
            }
            [synergyMenuView makePlayButtonShowPlayImage];
            [floaterController fadeWindowOut:self];
        }
    }
}

- (NSString *)applicationSupportPath:(int)domain
{
    // get path to "Application Support"
    NSString    *path       = nil;
    int         folderType  = kApplicationSupportFolderType;
    Boolean     createFlag  = kDontCreateFolder;
    FSRef       folderRef;

    if (FSFindFolder(domain, folderType, createFlag, &folderRef) == noErr)
    {
        CFURLRef url = CFURLCreateFromFSRef(kCFAllocatorDefault, &folderRef);
        if (url)
        {
            path = [(NSURL *)url path];
            CFMakeCollectable(url);
        }
    }
    return path;
}

- (NSArray *)getTrackChangeItems:(int)domain
{
    NSString *applicationSupport = [self applicationSupportPath:domain];
    NSString *path = [[applicationSupport stringByAppendingPathComponent:@"Synergy"]
            stringByAppendingPathComponent:@"Track Change Items"];
    NSFileManager   *defaultManager = [NSFileManager defaultManager];
    NSArray         *items = [defaultManager contentsOfDirectoryAtPath:path
                                                                 error:NULL];
    NSMutableArray  *workingArray = [NSMutableArray array];
    NSEnumerator    *enumerator = [items objectEnumerator];
    NSString        *itemName;

    while ((itemName = [enumerator nextObject]))
    {
        if ([itemName hasPrefix:@"."]) continue;
        NSString *itemPath = [path stringByAppendingPathComponent:itemName];
        [workingArray addObject:itemPath];
    }
    return workingArray;
}

- (NSArray *)getTrackChangeItems
{
    // first get items in home directory (~/Library/Application Support...)
    NSMutableArray *workingArray = [NSMutableArray arrayWithArray:[self getTrackChangeItems:kUserDomain]];

    // now add items from /Library/Application Support...
    [workingArray addObjectsFromArray:[self getTrackChangeItems:kLocalDomain]];

    return workingArray;
}

- (void)launchTrackChangeItems:(NSArray *)paths
{
    NSWorkspace     *sharedWorkspace    = [NSWorkspace sharedWorkspace];
    NSEnumerator    *enumerator         = [paths objectEnumerator];
    NSString        *path;
    while ((path = [enumerator nextObject]))
    {
        // parent folder must be good
        NSString *parent = [path stringByDeletingLastPathComponent];
        if (![parent pathIsOwnedByCurrentUser] || ![parent pathIsWritableOnlyByCurrentUser])
        {
            NSLog(@"Warning: item \"%@\" not launched because parent path must be owned and writable only by the current user",
                  path);
            continue;
        }

        // item itself must be good
        if (![path pathIsOwnedByCurrentUser] || ![path pathIsWritableOnlyByCurrentUser])
        {
            NSLog(@"Warning: item \"%@\" not launched (must be owned and writable only by the current user)", path);
            continue;
        }

        if ([sharedWorkspace openFile:path])
            NSLog(@"Auto-launched item \"%@\"", path);
        else
            NSLog(@"Error auto-launching item \"%@\"", path);
    }
}

// new for Synergy 2.9
- (IBAction)transferCoverArtToITunes:(id)sender
{
    if (![WOProcessManager processRunningWithSignature:'hook'])
        return; // (double) check that iTunes is running

    // cannot just call coverImage because floater will return scaled art!
    NSString *artPath = [floaterController albumImagePath];
    if (!artPath)
        return;
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:artPath];
    NSData *PICTData = [image PICTRepresentation];
    if (!PICTData)
        return;

    // was bug: had to change descriptor type from 'JFIF' to 'PICT' (iTunes 9?)
    // error was -2003: QuickTime cantFindHandler
    // see: https://wincent.com/issues/1412
    NSArray *parameters = [NSArray arrayWithObject:[NSAppleEventDescriptor descriptorWithDescriptorType:'PICT' data:PICTData]];

    NSString *source =
        @"on open args\n"
        @"  try\n"
        @"    set coverData to item 1 of args\n"
        @"    tell application \"iTunes\"\n"
        @"      with timeout of 15 seconds\n"
        @"        set data of front artwork of current track to coverData\n"
        @"      end timeout\n"
        @"    end tell\n"
        @"    return true\n"
        @"  on error\n"
        @"    return false\n"
        @"  end try\n"
        @"end open";

    NSAppleScript           *script = [[NSAppleScript alloc] initWithSource:source];
    NSDictionary            *error  = nil;
    NSAppleEventDescriptor  *result = [script executeWithParameters:parameters error:&error];
    if (!result || ![result booleanValue])
        ELOG(@"Error transferring cover art");
    else if (error)
        ELOG(@"Error transferring cover art: %@", error);
}

#pragma mark GrowlApplicationBridgeDelegate protocol

- (NSDictionary *)registrationDictionaryForGrowl
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
        [NSArray arrayWithObject:@"iTunes update"], GROWL_NOTIFICATIONS_ALL,
        [NSArray arrayWithObject:@"iTunes update"], GROWL_NOTIFICATIONS_DEFAULT,
        nil];
}

#pragma mark -

#pragma mark Optional Growl delegate methods

- (NSString *)applicationNameForGrowl
{
    return @"Synergy";
}

- (void) growlNotificationWasClicked:(id)clickContext
{
    [self tellITunesActivate]; // bring iTunes to the front
}

#pragma mark -

#pragma mark -
#pragma mark Accessors
#pragma mark -

- (void)setSongToPlayOnceLaunched:(NSAppleEventDescriptor *)songId
{
    songToPlayOnceLaunched = songId;
}

- (NSAppleEventDescriptor *)songToPlayOnceLaunched
{
    return songToPlayOnceLaunched;
}

- (NSArray *)trackChangeLaunchItems
{
    return trackChangeLaunchItems;
}

- (void)setTrackChangeLaunchItems:(NSArray *)aTrackChangeLaunchItems
{
    if (trackChangeLaunchItems != aTrackChangeLaunchItems)
        trackChangeLaunchItems = aTrackChangeLaunchItems;
}

- (BOOL)hitAmazon
{
    return hitAmazon;
}

@end
