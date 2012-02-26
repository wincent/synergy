//
//  WODistributedNotification.m
//  (Originally part of Synergy project)
//
//  Created by Wincent Colaiuta on Thu Nov 28 2002.
//  Copyright 2002-2008 Wincent Colaiuta.

#import "WODistributedNotification.h"
#import "WODebug.h"

@interface WODistributedNotification (_private)

- (void)_registerForNotificationsFromPrefPane:(id)theObserver
                                     selector:(SEL)theSelector;

- (void)_registerForNotificationsFromApp:(id)theObserver
                                selector:(SEL)theSelector;

@end

@implementation WODistributedNotification

// used to ensure we don't have multiple instantiations of this class:
static id _selfPointer = nil;

// set up notifications and makes sender a "prefPane observer" (listens to pref
// pane)
+ (id)makePrefPaneObserver:(id)theObserver selector:(SEL)theSelector
{
    if (_selfPointer == nil)
    {
        _selfPointer = [[self alloc] init];

        [_selfPointer _registerForNotificationsFromPrefPane:theObserver
                                                   selector:theSelector];
    }

    // initialise state variables
    [_selfPointer setAppState:WODNUnknown];
    [_selfPointer setPrefPaneState:WODNUnknown];

    return _selfPointer;
}

// set up notifications and makes sender an "App observer" (listens to app)
+ (id)makeAppObserver:(id)theObserver selector:(SEL)theSelector
{
    if (_selfPointer == nil)
    {
        _selfPointer = [[self alloc] init];

        [_selfPointer _registerForNotificationsFromApp:theObserver
                                              selector:theSelector];
    }

    // initialise state variables
    [_selfPointer setAppState:WODNUnknown];
    [_selfPointer setPrefPaneState:WODNUnknown];

    return _selfPointer;
}

// register for notifications sent from prefPane (to app)
- (void)_registerForNotificationsFromPrefPane:(id)theObserver selector:(SEL)theSelector
{
    notifyCenter = [NSDistributedNotificationCenter defaultCenter];

    // Messages permitting app and prefPane to maintain state variables for the
    // other's state
    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WODistributedNotificationIdentifier
                       object:[NSString stringWithFormat:@"%d",
                             WODNPaneLaunched]];

    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WODistributedNotificationIdentifier
                       object:[NSString stringWithFormat:@"%d",
                             WODNPaneIsRunning]];

    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WODistributedNotificationIdentifier
                       object:[NSString stringWithFormat:@"%d",
                             WODNPaneWillQuit]];

    // Auxilliary messages for finding out about other's state
    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WODistributedNotificationIdentifier
                       object:[NSString stringWithFormat:@"%d",
                             WODNAppStatus]];

    // Directives requesting action on the part of the app
    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WODistributedNotificationIdentifier
                       object:[NSString stringWithFormat:@"%d",
                             WODNAppReadPrefs]];

    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WODistributedNotificationIdentifier
                       object:[NSString stringWithFormat:@"%d",
                             WODNAppQuit]];

    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WODistributedNotificationIdentifier
                       object:[NSString stringWithFormat:@"%d",
                             WODNAppUnregisterHotkeys]];

    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WODistributedNotificationIdentifier
                       object:[NSString stringWithFormat:@"%d",
                             WODNAppRegisterHotkeys]];

    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WODistributedNotificationIdentifier
                       object:[NSString stringWithFormat:@"%d",
                             WODNAppNoFloater]];

    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WODistributedNotificationIdentifier
                       object:[NSString stringWithFormat:@"%d",
                             WODNAppFloaterOK]];

    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WO_NEW_PREFS_FROM_PREFS_TO_APP
                       object:nil];

    // store theObserver in an instance variable for later use by the
    // "removePrefPaneObserver" method
    _prefPaneObserver = theObserver;
}

// clean up routine to remove observer (of prefPane)
- (void)removePrefPaneObserver
{
    [notifyCenter removeObserver:_prefPaneObserver
                            name:WODistributedNotificationIdentifier
                          object:[NSString stringWithFormat:@"%d",
                                WODNPaneLaunched]];
    [notifyCenter removeObserver:_prefPaneObserver
                            name:WODistributedNotificationIdentifier
                          object:[NSString stringWithFormat:@"%d",
                                WODNPaneIsRunning]];
    [notifyCenter removeObserver:_prefPaneObserver
                            name:WODistributedNotificationIdentifier
                          object:[NSString stringWithFormat:@"%d",
                                WODNPaneWillQuit]];
    [notifyCenter removeObserver:_prefPaneObserver
                            name:WODistributedNotificationIdentifier
                          object:[NSString stringWithFormat:@"%d",
                                WODNAppStatus]];
    [notifyCenter removeObserver:_prefPaneObserver
                            name:WODistributedNotificationIdentifier
                          object:[NSString stringWithFormat:@"%d",
                                WODNAppReadPrefs]];
    [notifyCenter removeObserver:_prefPaneObserver
                            name:WODistributedNotificationIdentifier
                          object:[NSString stringWithFormat:@"%d",
                                WODNAppQuit]];
    [notifyCenter removeObserver:_prefPaneObserver
                            name:WODistributedNotificationIdentifier
                          object:[NSString stringWithFormat:@"%d",
                                WODNAppUnregisterHotkeys]];
    [notifyCenter removeObserver:_prefPaneObserver
                            name:WODistributedNotificationIdentifier
                          object:[NSString stringWithFormat:@"%d",
                                WODNAppRegisterHotkeys]];
    [notifyCenter removeObserver:_prefPaneObserver
                            name:WO_NEW_PREFS_FROM_PREFS_TO_APP
                          object:nil];
}

// register for notifications sent from app (to pref pane)
- (void)_registerForNotificationsFromApp:(id)theObserver selector:(SEL)theSelector
{
    notifyCenter = [NSDistributedNotificationCenter defaultCenter];

    // Messages permitting app and prefPane to maintain state variables for the
    // other's state
    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WODistributedNotificationIdentifier
                       object:[NSString stringWithFormat:@"%d",
                             WODNAppLaunched]];

    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WODistributedNotificationIdentifier
                       object:[NSString stringWithFormat:@"%d",
                             WODNAppIsRunning]];

    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WODistributedNotificationIdentifier
                       object:[NSString stringWithFormat:@"%d",
                             WODNAppWillQuit]];

    // Auxilliary messages for finding out about other's state
    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WODistributedNotificationIdentifier
                       object:[NSString stringWithFormat:@"%d",
                             WODNPaneStatus]];

    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WODistributedNotificationIdentifier
                       object:[NSString stringWithFormat:@"%d",
                             WODNPrefToggleSerialNoticePref]];

    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WODistributedNotificationIdentifier
                       object:[NSString stringWithFormat:@"%d",
                             WODNPrefNoteButtonSetLoaded]];

    [notifyCenter addObserver:theObserver
                     selector:theSelector
                         name:WO_NEW_PREFS_FROM_APP_TO_PREFS
                       object:nil];

    // store theObserver in an instance variable for later use by the
    // "removeAppObserver" method
    _appObserver = theObserver;
}

// clean up routine to remove observer (of app)
- (void)removeAppObserver
{
    [notifyCenter removeObserver:_appObserver
                            name:WODistributedNotificationIdentifier
                          object:[NSString stringWithFormat:@"%d",
                                WODNAppLaunched]];
    [notifyCenter removeObserver:_appObserver
                            name:WODistributedNotificationIdentifier
                          object:[NSString stringWithFormat:@"%d",
                                WODNAppIsRunning]];
    [notifyCenter removeObserver:_appObserver
                            name:WODistributedNotificationIdentifier
                          object:[NSString stringWithFormat:@"%d",
                                WODNAppWillQuit]];
    [notifyCenter removeObserver:_appObserver
                            name:WODistributedNotificationIdentifier
                          object:[NSString stringWithFormat:@"%d",
                                WODNPaneStatus]];
    [notifyCenter removeObserver:_appObserver
                            name:WODistributedNotificationIdentifier
                          object:[NSString stringWithFormat:@"%d",
                                WODNPrefToggleSerialNoticePref]];
    [notifyCenter removeObserver:_appObserver
                            name:WODistributedNotificationIdentifier
                          object:[NSString stringWithFormat:@"%d",
                                WODNPrefNoteButtonSetLoaded]];
    [notifyCenter removeObserver:_appObserver
                            name:WO_NEW_PREFS_FROM_APP_TO_PREFS
                          object:nil];
}

// send notification to the app
- (void) notifyApp:(WODistributedNotificationMessage)messageCode
{
    [notifyCenter postNotificationName:WODistributedNotificationIdentifier
                                object:[NSString stringWithFormat:@"%d", messageCode]];
}

// send notification to the prefPane
- (void) notifyPrefPane:(WODistributedNotificationMessage)messageCode
{
    [notifyCenter postNotificationName:WODistributedNotificationIdentifier
                                object:[NSString stringWithFormat:@"%d", messageCode]];
}

- (NSString *)serializedPreferences:(NSDictionary *)prefs
{
    if (!prefs)
        return nil;
    NSString *error = nil;
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:prefs
                                                              format:NSPropertyListXMLFormat_v1_0
                                                    errorDescription:&error];
    if (error)
    {
        NSLog(@"+[NSPropertyListSerialization dataFromPropertyList:format:errorDescription: failed (%@)", error);
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

// send a prefs update to the prefPane
- (void)sendUpdatedPrefsToPrefPane:(NSDictionary *)newPrefs
{
    NSString *serializedPreferences = [self serializedPreferences:newPrefs];
    if (!serializedPreferences)
    {
        NSLog(@"-[WODistributedNotification sendUpdatedPrefsToPrefPane:] failed to serialize");
        return;
    }
    [notifyCenter postNotificationName:WO_NEW_PREFS_FROM_APP_TO_PREFS
                                object:serializedPreferences];
}

// send a prefs update to the prefPane
- (void)sendUpdatedPrefsToApp:(NSDictionary *)newPrefs
{
    NSString *serializedPreferences = [self serializedPreferences:newPrefs];
    if (!serializedPreferences)
    {
        NSLog(@"-[WODistributedNotification sendUpdatedPrefsToApp:] failed to serialize");
        return;
    }
    [notifyCenter postNotificationName:WO_NEW_PREFS_FROM_PREFS_TO_APP
                                object:serializedPreferences];
}

- (void)setSuspended:(BOOL)theBool
{
    [notifyCenter setSuspended:theBool];
}

// accessor methods
- (void)setAppState:(WODNRunState)runState
{
    appState = runState;
}

- (WODNRunState)appState
{
    return appState;
}

- (void)setPrefPaneState:(WODNRunState)runState
{
    prefPaneState = runState;
}

- (WODNRunState)prefPaneState
{
    return prefPaneState;
}

@end
