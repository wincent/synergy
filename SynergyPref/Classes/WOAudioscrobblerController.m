// WOAudioscrobblerController.m
// Synergy
//
// Copyright 2006-2010 Wincent Colaiuta.

// class header
#import "WOAudioscrobblerController.h"

// system headers
#import <Security/Security.h>   /* keychain */

// WOPublic macro headers
#import "WOPublic/WOMemory.h"

#ifdef SYNERGY_PREF_BUILD
#import "OrgWincentSynergyPref.h"
#import "WOPreferences.h"
#endif

#pragma mark -
#pragma mark Macros

#define WO_AUDIOSCROBBLER_SERVICE_NAME "Audioscrobbler"

#pragma mark -
#pragma mark Functions

void WOAudioscrobblerLog(NSString *format, ...)
{
    if (!format) return;
    Boolean valid;
    // BUG: yes, hard-coding the bundle identifier here is evil, but necessary because this code can be called from the pref pane
    if (CFPreferencesGetAppBooleanValue(CFSTR("LogAudioscrobblerEvents"), CFSTR("org.wincent.Synergy"), &valid) && valid)
    {
        va_list args;
        va_start(args, format);
        NSLog(@"Audioscrobbler: %@", [[NSString alloc] initWithFormat:format arguments:args]);
        va_end(args);
    }
}

@interface WOAudioscrobblerController (WOPrivate)

- (void)handleKeychainEvent:(SecKeychainEvent)keychainEvent info:(SecKeychainCallbackInfo *)info;

#ifdef SYNERGY_PREF_BUILD
- (NSString *)getPasswordFromKeychain;
- (void)keychainStorePassword;
#endif /* SYNERGY_PREF_BUILD */

@end

@implementation WOAudioscrobblerController

#pragma mark -
#pragma mark Keychain helper methods

OSStatus WOKeychainCallback(SecKeychainEvent keychainEvent, SecKeychainCallbackInfo *info, void *context)
{
    WOAudioscrobblerController *controller = (WOAudioscrobblerController *)context;
    [controller handleKeychainEvent:keychainEvent info:info];
    return noErr;
}

- (void)handleKeychainEvent:(SecKeychainEvent)keychainEvent info:(SecKeychainCallbackInfo *)info
{
    switch (keychainEvent)
    {
        case kSecAddEvent:
        case kSecUpdateEvent:
        case kSecPasswordChangedEvent:
        {
#ifdef SYNERGY_PREF_BUILD
            // GCC bug?: GCC requires that these statements be enclosed in curly braces
            NSString *password = [self getPasswordFromKeychain];
            if (password)
                [passwordTextField setStringValue:password];
#endif
            break;
        }
        default:
            NSLog(@"warning: unrecognized SecKeychainEvent type (%lu)", keychainEvent);
    }
}

- (void)addKeychainCallback
{
    if (keychainCallbackAdded)
        return;

    // register for events that might provide a new or updated password
    OSStatus err = SecKeychainAddCallback
        (WOKeychainCallback, kSecAddEventMask | kSecUpdateEventMask | kSecPasswordChangedEventMask, self);
    if (err == noErr)
        keychainCallbackAdded = YES;
    else
        NSLog(@"error: SecKeychainAddCallback returned %ld", (long)err);
}

- (void)removeKeychainCallback
{
    if (!keychainCallbackAdded)
        return;
    OSStatus err = SecKeychainRemoveCallback(WOKeychainCallback);
    if (err != noErr)
        NSLog(@"error: SecKeychainRemoveCallback returned %ld", (long)err);
}

// this functionality factored out into a separate method so that the application can use it
// (preference pane uses getPasswordFromKeychain)
- (NSString *)getPasswordFromKeychainForUsername:(NSString *)username
{
    if (!username || [username isEqualToString:@""])
        return nil;
    const char  *service    = WO_AUDIOSCROBBLER_SERVICE_NAME;
    const char  *account    = [username UTF8String];
    UInt32      passwordLength;
    void        *passwordData;
    OSStatus err = SecKeychainFindGenericPassword
        (NULL, strlen(service), service, strlen(account), account, &passwordLength, &passwordData, NULL);
    switch (err)
    {
        case noErr:                 // success
            break;
        case errSecItemNotFound:    // harmless error
            return nil;
        default:
            return nil;
    }

    NSString *password = [[NSString alloc] initWithData:[NSData dataWithBytes:passwordData length:passwordLength]
                                               encoding:NSUTF8StringEncoding];
    err = SecKeychainItemFreeContent(NULL, passwordData);
    if (err != noErr)
        NSLog(@"error: SecKeychainItemFreeContent returned %ld", (long)err);
    return password;
}

#ifdef SYNERGY_PREF_BUILD
// returns nil if no password available
- (NSString *)getPasswordFromKeychain
{
    NSString    *username   = [usernameTextField stringValue];
    if (!username || [username isEqualToString:@""]) return nil;
    return [self getPasswordFromKeychainForUsername:username];
}

- (void)keychainStorePassword
{
    NSString    *username   = [usernameTextField stringValue];
    if (!username || [username isEqualToString:@""]) return;
    NSString    *password   = [passwordTextField stringValue];
    if (!password || [password isEqualToString:@""]) return;
    const char *service = WO_AUDIOSCROBBLER_SERVICE_NAME;
    const char *account = [username UTF8String];
    NSData *data = [password dataUsingEncoding:NSUTF8StringEncoding];
    OSStatus err = SecKeychainAddGenericPassword
        (NULL,  strlen(service), service, strlen(account), account, [data length], [data bytes], NULL);
    switch (err)
    {
        case noErr:                 // success
            break;
        case errSecDuplicateItem:   // must manually update the keychain item
        {
            SecKeychainItemRef itemRef;
            err = SecKeychainFindGenericPassword(NULL, strlen(service), service, strlen(account), account, NULL, NULL, &itemRef);
            if (err != noErr)
                NSLog(@"error: SecKeychainFindGenericPassword returned %ld", (long)err);
            else
            {
                err = SecKeychainItemModifyAttributesAndData(itemRef, NULL, [data length], [data bytes]);
                if (err != noErr)
                    NSLog(@"error: SecKeychainItemModifyAttributesAndData returned %ld", (long)err);
            }
            break;
        }
        default:
            NSLog(@"error: SecKeychainAddGenericPassword returned %ld", (long)err);
    }
}

#endif /* SYNERGY_PREF_BUILD */

#pragma mark -
#pragma mark NSObject overrides

- (id)init
{
    if ((self = [super init]))
    {
        // if we don't store the password in the keychain, where do we store it? nowhere
        [self setStoreInKeychain:YES];
        [self addKeychainCallback];
    }
    return self;
}

- (void)finalize
{
    [self removeKeychainCallback];
    [super finalize];
}

#ifdef SYNERGY_PREF_BUILD

#pragma mark -
#pragma mark Custom methods

- (void)beginSheetModalForWindow:(NSWindow *)aWindow contextInfo:(NSDictionary *)info
{
    NSParameterAssert(aWindow != nil);

    // BUG: hard-coding the bundle ID here sucks, but necessary because we are a bundle loaded into System Preferences
    CFStringRef applicationID = CFSTR("org.wincent.Synergy");
    CFPreferencesAppSynchronize(applicationID);

    // get username from user defaults
    Boolean valid;
    BOOL store = CFPreferencesGetAppBooleanValue((CFStringRef)WO_STORE_AUDIOSCROBBLER_PASSWORD_IN_KEYCHAIN, applicationID, &valid);
    NSString *user = (NSString *)WOMakeCollectable(CFPreferencesCopyAppValue((CFStringRef)WO_AUDIOSCROBBLER_USERNAME, applicationID));
    if (user)
        [usernameTextField setStringValue:user];
    [keychainButton setState:store ? NSOnState : NSOffState];

    // try to get password from keychain
    NSString *password = [self getPasswordFromKeychain];
    if (password)
        [passwordTextField setStringValue:password];

    [NSApp beginSheet:accountWindow
       modalForWindow:aWindow
        modalDelegate:self
       didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
          contextInfo:info];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
    [sheet orderOut:self];

    // notify caller that we're done
    NSDictionary    *info       = (NSDictionary *)contextInfo;
    SEL             selector    = NSSelectorFromString([info objectForKey:WO_SELECTOR]);
    id              target      = [info objectForKey:WO_TARGET];
    if (returnCode == NSAlertDefaultReturn)
        [target performSelector:selector withObject:[NSNumber numberWithBool:YES]];
    else
        [target performSelector:selector withObject:[NSNumber numberWithBool:NO]];
}

#pragma mark -
#pragma mark IBActions

// got to audioscrobbler website?
- (IBAction)helpButtonPressed:(id)sender
{
    if (![[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:WO_AUDIOSCROBBLER_HELP_URL]])
        NSLog(@"error: failed to open URL %@", WO_AUDIOSCROBBLER_HELP_URL);
}

- (IBAction)keychainButtonPressed:(id)sender
{
    BOOL store = ([keychainButton state] == NSOnState) ? YES : NO;
    [self setStoreInKeychain:store];

    // BUG: hard-coding the bundle ID here sucks, but necessary because we are a bundle loaded into System Preferences
    CFStringRef applicationID = CFSTR("org.wincent.Synergy");
    CFPreferencesSetAppValue((CFStringRef)WO_STORE_AUDIOSCROBBLER_PASSWORD_IN_KEYCHAIN,
                             (CFNumberRef)[NSNumber numberWithBool:store], applicationID);
    if (!CFPreferencesSynchronize(applicationID, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost))
        NSLog(@"Error updating preferences");
}

- (IBAction)cancelButtonPressed:(id)sender
{
    // dismiss sheet and do nothing
    [NSApp endSheet:accountWindow returnCode:NSAlertAlternateReturn];
}

- (IBAction)saveButtonPressed:(id)sender
{
    NSString *username = [usernameTextField stringValue];

    // BUG: hard-coding this sucks, but a necessary evil
    [[OrgWincentSynergyPref prefs] setObject:username
                                      forKey:WO_AUDIOSCROBBLER_USERNAME
                            flushImmediately:YES];

    if ([self storeInKeychain])
        [self keychainStorePassword];

    // dismiss sheet and notify application
    [NSApp endSheet:accountWindow returnCode:NSAlertDefaultReturn];
}

#pragma mark -
#pragma mark NSControl delegate methods

- (void)controlTextDidChange:(NSNotification *)aNotification
{
    // consult keychain if username changes
    NSString *password = [self getPasswordFromKeychain];
    if (password)
        [passwordTextField setStringValue:password];
}

#endif /* SYNERGY_PREF_BUILD */

#pragma mark -
#pragma mark Accessors

- (BOOL)storeInKeychain
{
    return storeInKeychain;
}

- (void)setStoreInKeychain:(BOOL)flag
{
    storeInKeychain = flag;
}

@end
