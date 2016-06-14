// WODistributedNotification.h
// Synergy
//
// Copyright 2002-present Greg Hurrell. All rights reserved.

#import <Foundation/Foundation.h>

// Type so app and pane can each maintain state variable for the other's state
typedef enum WODNRunState {

    WODNStopped = 0,  // app or pane "stopped" (for state variable)
    WODNRunning = 1,  // app or pane "running" (for state variable)
    WODNUnknown = 2

} WODNRunState;

// used as an object parameter for postNotificationWithName: method - it ensures
// that we don't clash with any other apps using the shared default notification
// center object:
#define WODistributedNotificationIdentifier \
        @"WODistributedNotificationIdentifier"

#define WO_NEW_PREFS_FROM_APP_TO_PREFS @"com.wincent.SynergyPreferences.app.update"
#define WO_NEW_PREFS_FROM_PREFS_TO_APP @"com.wincent.SynergyPreferences.prefPane.update"

// this is the basic suite of messages that can be passed back and forth between
// the prefPane and application.
typedef enum WODistributedNotificationMessage {
    // Messages permitting app and prefPane to maintain state variables for the
    // other's state
    WODNPaneLaunched = 0,   // Notification that prefPane did launch
    WODNAppLaunched = 1,    // Notification that app did launch
    WODNPaneIsRunning = 2,  // Notification that prefPane is running
    WODNAppIsRunning = 3,   // Notification that app is running
    WODNPaneWillQuit = 4,   // Notification that prefPane is about to quit
    WODNAppWillQuit = 5,    // Notification that app is about to quit

    // Auxilliary messages for finding out about other's state
    WODNPaneStatus = 6,     // Request prefPane for status (are you running?)
    WODNAppStatus = 7,      // Request app for status (are you running?)

    // Directives requesting action on the part of the app
    WODNAppReadPrefs = 8,           // Tell app to (re)read the preferences file
    WODNAppQuit = 9,                // Tell app to quit
    WODNAppUnregisterHotkeys = 10,  // Tell app to unregister hotkeys
    WODNAppRegisterHotkeys = 11,    // Tell app to register hotkeys
    WODNAppNoFloater = 12,          // Tell app not to display floater
    WODNAppFloaterOK = 13,          // Tell app it is ok to display floater
    // these last messages (10, 11) useful for temporarily suspending and then
    // reinstating the capturing of global hotkey events (necessary when
    // prefPane is listening to hotKey events in order to capture user
    // preferences); and (12, 13) useful for temporarily suspending the display
    // of the floater (for use when previewing floater settings)

    // Directives requesting action on the part of the prefPane
    WODNPrefToggleSerialNoticePref = 14,    // Tell the pref to toggle the state of the serial notice pref
    WODNPrefNoteButtonSetLoaded = 15        // Tell the pref that the user double-clicked on a button set
} WODistributedNotificationMessage;

/* Notes on message passing between the app and the prefpane:

Common message sequences:

Opening: WODN(item)Launched           // this sequence ensures that both items
Response: WODN(counterpart)IsRunning  // have knowledge of the other's state

Opening: WODN(item)Status             // request for status
Response: WODN(item)IsRunning         // reply (state variables now updated)

Opening: WODNApp(Directive)           // request for action
Response: WODNAppIsRunning            // reply (state variable now updated)

Opening: WODN(item)WillQuit           // request to quit
Response: none                        // no reply needed, but receiver should
                                      // update state variable

These message sequences are designed so that message loops do not occur; there
is at most one response in any given message sequence. Yet the sequences permit
both items to have up-to-date information about the state of their counterpart.

*/

@interface WODistributedNotification : NSObject {

    NSDistributedNotificationCenter *notifyCenter;

    // state variable for app state: running, not running etc
    WODNRunState                    appState;

    // state variable for prefPane state: running, not running etc
    WODNRunState                    prefPaneState;

    // storage for tracking observers between adding and removing
    id                              _appObserver;
    id                              _prefPaneObserver;
}

// Do basic setup and return shared notification object

// set up notifications and makes sender a "prefPane observer" (listens to pref
// pane)
+ (id)makePrefPaneObserver:(id)theObserver selector:(SEL)theSelector;

// set up notifications and makes sender an "App observer" (listens to app)
+ (id)makeAppObserver:(id)theObserver selector:(SEL)theSelector;

// clean up routines to remove observers
- (void)removePrefPaneObserver;

- (void)removeAppObserver;

// send notification to the app
- (void)notifyApp:(WODistributedNotificationMessage)messageCode;

// send notification to the prefPane
- (void)notifyPrefPane:(WODistributedNotificationMessage)messageCode;

// send a prefs update to the prefPane
- (void)sendUpdatedPrefsToPrefPane:(NSDictionary *)newPrefs;

// send a prefs update to the app
- (void)sendUpdatedPrefsToApp:(NSDictionary *)newPrefs;

// passes setSuspended message onto notification center
- (void)setSuspended:(BOOL)theBool;

// accessor methods

- (void)setAppState:(WODNRunState)runState;
- (WODNRunState)appState;

- (void)setPrefPaneState:(WODNRunState)runState;
- (WODNRunState)prefPaneState;



@end
