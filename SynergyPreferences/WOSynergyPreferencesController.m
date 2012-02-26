// WOSynergyPreferencesController.m
// Synergy
//
// Copyright 2007-2010 Wincent Colaiuta. All rights reserved.

// class header
#import "WOSynergyPreferencesController.h"

// other headers
#import "WOPreferenceWindow.h"
#import "WOPreferences.h"

// WOPublic macro headers
#import "WOPublic/WOConvenienceMacros.h"
#import "WOPublic/WOMemory.h"

// WOPublic class headers
#import "WOPublic/WOLoginItem.h"
#import "WOPublic/WOLoginItemList.h"
#import "WOPublic/WOLogManager.h"

// WOPublic category headers
#import "WOPublic/NSDictionary+WOCreation.h"


#pragma mark -
#pragma mark Macros

#define GLOBAL_INSTALL_PATH             @"/Library/PreferencePanes/Synergy.prefPane"
#define LOCAL_INSTALL_PATH              [@"~/Library/PreferencePanes/Synergy.prefPane" stringByExpandingTildeInPath]

//! Preference key that prevents the "Old installation found" sheet from showing.
#define SUPPRESS_OLD_INSTALLATION_ALERT @"SuppressOldInstallationAlert"

@interface WOSynergyPreferencesController ()

- (void)checkInstallation;
- (void)quitOtherInstallation:(BOOL)immediately;
- (void)killRunningCopy;
- (void)showRunningCopyAlert;
- (void)checkLocalInstallation;
- (void)showOldInstallationAlertIsGlobal:(BOOL)isGlobal action:(SEL)selector;
- (void)checkGlobalInstallation;

@end

@implementation WOSynergyPreferencesController

#pragma mark -
#pragma mark NSObject overrides

+ (void)initialize
{
    // for adding new checkboxes the easiest thing is to just use
    // NSUserDefaultsController and the com.wincent.SynergyPreferences domain
    NSDictionary *defaults = WO_DICTIONARY(@"enableLastFm", WO_YES,
                                           @"hitAmazon",    WO_YES);
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
    [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:defaults];
}

- (void)finalize
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super finalize];
}

#pragma mark -

- (NSString *)synergyAppPath
{
    NSString *path = [[NSBundle mainBundle] bundlePath];
    path = [path stringByAppendingPathComponent:@"Contents"];
    path = [path stringByAppendingPathComponent:@"PreferencePanes"];
    path = [path stringByAppendingPathComponent:@"Synergy.prefPane"];
    path = [path stringByAppendingPathComponent:@"Contents"];
    path = [path stringByAppendingPathComponent:@"Helpers"];
    return [path stringByAppendingPathComponent:@"Synergy.app"];
}

- (void)defaultsDidChange:(NSNotification *)aNotification
{
    // must get this onto disk in order for the app to "see" them immediately
    (void)[[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark -
#pragma mark Uninstallation

// This is the first message in a chain:
//      -checkInstallation
//      -checkLocalInstallation
//      -showOldInstallationAlertIsGlobal:action:
//      -alertDidEnd:returnCode:contextInfo:
//      -removeLocalInstallation
//      -didPresentErrorWithRecovery:contextInfo: (only if an error occurred)
//      -checkGlobalInstallation
//      -showOldInstallationAlertIsGlobal:action:
//      -alertDidEnd:returnCode:contextInfo:
//      -removeGlobalInstallation
//      -didPresentErrorWithRecovery:contextInfo: (only if an error occurred)
// There are four possible points at which a sheet might be shown; at these points control passes back to the runloop and
// when the sheet is dismissed we perform the next selector in the chain (passed along in the contextInfo).
- (void)checkInstallation
{
    [self checkLocalInstallation];
    if (!haveQuitOtherVersions)
        [self quitOtherInstallation:NO];
}

- (void)quitOtherInstallation:(BOOL)immediately
{
    // look for a running Synergy process
    haveQuitOtherVersions   = YES; // only bother trying once
    PSN.highLongOfPSN       = 0;
    PSN.lowLongOfPSN        = kNoProcess;
    OSErr                   err;
    ProcessInfoRec          rec;
    while ((err = GetNextProcess(&PSN)) == noErr)
    {
        rec.processInfoLength   = sizeof(ProcessInfoRec);
        rec.processName         = NULL;
        rec.processAppSpec      = NULL;
        if ((err = GetProcessInformation(&PSN, &rec)) == noErr)
        {
            if (rec.processType == (UInt32)'APPL' &&
                rec.processSignature == (OSType)'Snrg')
                break; // match found!
        }
        else
        {
            NSLog(@"error: GetProcessInformation() returned %d", err);
            return; // bail
        }
    }
    if (err == procNotFound)
        return; // didn't find desired PSN

    // try to find out where its family lives
    NSDictionary *info = (NSDictionary *)WOMakeCollectable(ProcessInformationCopyDictionary(&PSN, kProcessDictionaryIncludeAllInformationMask));
    NSString *otherBundlePath = nil;
    if (info && (otherBundlePath = [info objectForKey:@"BundlePath"]) && otherBundlePath)
    {
        // could potentially use this to offer an uninstall, but for now just offer to quit
        if (![otherBundlePath isEqual:[self synergyAppPath]])
        {
            if (immediately)    // kill immediately without asking
                [self killRunningCopy];
            else                // ask for confirmation first, then if we get it...
                [self showRunningCopyAlert];
        }
    }
}

- (void)killRunningCopy
{
    OSErr err;
    if ((err = KillProcess(&PSN)) != noErr)
        NSLog(@"error: KillProcess() returned %d", err);
}

- (void)showRunningCopyAlert
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert setMessageText:@"An existing copy of Synergy is already running"];
    [alert setInformativeText:@"It is recommended that you quit the other copy of Synergy to avoid conflicts. Would you like to quit the other copy?"];
    [alert addButtonWithTitle:@"Quit Other Copy"];
    [alert addButtonWithTitle:@"Quit This Copy"];
    [alert addButtonWithTitle:@"Do Nothing"];
    [alert beginSheetModalForWindow:prefsWindow
                      modalDelegate:self
                     didEndSelector:@selector(runningCopyAlertDidEnd:returnCode:contextInfo:)
                        contextInfo:NULL];
}

- (void)runningCopyAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [[alert window] orderOut:self];
    if (returnCode == NSAlertFirstButtonReturn)         // "Quit Other Copy"
        [self killRunningCopy];
    else if (returnCode == NSAlertSecondButtonReturn)   // "Quit This Copy"
        [NSApp terminate:self];
}

- (void)checkLocalInstallation
{
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:LOCAL_INSTALL_PATH])
        [self showOldInstallationAlertIsGlobal:NO
                                        action:@selector(removeLocalInstallation)]; // will resume here after the alert sheet
    else
        [self checkGlobalInstallation];
}

- (void)removeLocalInstallation
{
    [self quitOtherInstallation:YES];
    NSString *local = LOCAL_INSTALL_PATH;
    NSError *error;
    NSLog(@"Removing local install at path: %@", local);
    if ([[NSFileManager defaultManager] removeItemAtPath:local error:&error])
        [self checkGlobalInstallation]; // no errors, proceed
    else
    {
        NSLog(@"An error occurred while removing item at path: %@", local);

        // On 10.5.1 the system supplies an error message like this:
        //      "Synergy.prefPane" could not be removed because you do not have appropriate access privileges.
        //      To view or change access privileges, select the item in Finder and choose File > Get Info.
        // If we supplement this just a little it becomes serviceable:
        NSMutableDictionary *info = [[error userInfo] mutableCopy];
        [info setObject:WO_STRING(@"%@ The item can be found at \"%@\".", [error localizedRecoverySuggestion], local)
                 forKey:NSLocalizedRecoverySuggestionErrorKey];
        [NSApp presentError:[NSError errorWithDomain:[error domain] code:[error code] userInfo:info]
             modalForWindow:prefsWindow
                   delegate:self
         didPresentSelector:@selector(didPresentErrorWithRecovery:contextInfo:)
                contextInfo:@selector(checkGlobalInstallation)]; // will resume here after the error sheet
    }
}

- (void)checkGlobalInstallation
{
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:GLOBAL_INSTALL_PATH])
        return;
    [self showOldInstallationAlertIsGlobal:YES
                                    action:@selector(removeGlobalInstallation)]; // will resume here after the alert sheet is shown
}

- (void)removeGlobalInstallation
{
    [self quitOtherInstallation:YES];
    NSString *global = GLOBAL_INSTALL_PATH;
    AuthorizationRef ref;
    OSStatus err = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &ref);
    if (err != errAuthorizationSuccess)
        goto presentError;

    // authorize
    AuthorizationItem   item    = { kAuthorizationRightExecute, 0, NULL, 0 };
    AuthorizationRights rights  = { 1, &item };
    AuthorizationFlags  flags   = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed |
        kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    err = AuthorizationCopyRights(ref, &rights, NULL, flags, NULL);
    if (err != errAuthorizationSuccess)
    {
        NSLog(@"error: AuthorizationCopyRights returned %ld", (long)err);
        if (err == errAuthorizationDenied || err == errAuthorizationCanceled)
            goto freeRef; // got password three times or cancelled, don't show error sheet
        else
            goto presentError;
    }

    // try to remove
    NSLog(@"Removing global install at path: %@", global);
    char *arguments[]   = { "-rf", (char *)[global fileSystemRepresentation], NULL};
    FILE *pipe          = NULL;
    err = AuthorizationExecuteWithPrivileges(ref, "/bin/rm", kAuthorizationFlagDefaults, arguments, &pipe);

    // unfortunately there is no kludgeless way to get the actual exit code of the tool using this API, so hope it worked
    if (err == errAuthorizationToolExecuteFailure)
        // not strictly an authorization failure (authorization succeeded but the tool failed to execute)
        NSLog(@"error: AuthorizationExecuteWithPrivileges returned %ld (tool failed to execute)", (long)err);
    else if (err != errAuthorizationSuccess)
        NSLog(@"error: AuthorizationExecuteWithPrivileges returned %ld", (long)err);

presentError:
    if (err != errAuthorizationSuccess)
    {
        NSString *description = WO_STRING(@"An error occurred while trying to remove \"%@\".", [global lastPathComponent]);
        NSString *suggestion = WO_STRING(@"Try removing it manually using the Finder. The item can be found at \"%@\".", global);
        NSDictionary *info = WO_DICTIONARY(NSLocalizedDescriptionKey,               description,
                                           NSFilePathErrorKey,                      global,
                                           NSLocalizedRecoverySuggestionErrorKey,   suggestion);
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:info];
        [NSApp presentError:error
             modalForWindow:prefsWindow
                   delegate:self
         didPresentSelector:@selector(didPresentErrorWithRecovery:contextInfo:)
                contextInfo:NULL];
    }

freeRef:
    (void)AuthorizationFree(ref, kAuthorizationFlagDefaults);
}

- (void)showOldInstallationAlertIsGlobal:(BOOL)isGlobal action:(SEL)selector
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:SUPPRESS_OLD_INSTALLATION_ALERT])
        return;

    NSAlert *alert = [[NSAlert alloc] init];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert setMessageText:@"An older Synergy installation was found on your system"];

    NSString *path = LOCAL_INSTALL_PATH;
    NSString *privileges = @"";
    if (isGlobal)
    {
        path = GLOBAL_INSTALL_PATH;
        privileges = @" (An administrator username and password will be required.)";
    }
    NSString *info = WO_STRING(@"The installation was found at \"%@\". Would you like to remove it?%@", path, privileges);
    [alert setInformativeText:info];
    [alert addButtonWithTitle:@"Remove"];
    [alert addButtonWithTitle:@"Don't Remove"];
    [alert setShowsSuppressionButton:YES];
    [alert beginSheetModalForWindow:prefsWindow
                      modalDelegate:self
                     didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                        contextInfo:selector];
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [[alert window] orderOut:self];
    if ([[alert suppressionButton] state] == NSOnState)
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setBool:YES forKey:SUPPRESS_OLD_INSTALLATION_ALERT];
    }

    if (returnCode == NSAlertFirstButtonReturn)
        [self performSelector:(SEL)contextInfo];
}

#pragma mark -
#pragma mark NSErrorRecoveryAttempting informal protocol

- (void)didPresentErrorWithRecovery:(BOOL)didRecover contextInfo:(void *)contextInfo
{
    if (!contextInfo)
        return;
    [self performSelector:(SEL)contextInfo];
}

#pragma mark -
#pragma mark Login items

- (void)updateLoginItems
{
    WOLoginItemList *items  = [WOLoginItemList sessionLoginItems];
    [items removeItemsWithName:@"Synergy.app"];

    Boolean existsAndIsValid;
    if (CFPreferencesGetAppBooleanValue((CFStringRef)_woLaunchAtLoginPrefKey, CFSTR("org.wincent.Synergy"), &existsAndIsValid))
        [items addItem:[WOLoginItem loginItemWithName:nil path:[self synergyAppPath] hidden:NO global:NO]];
}

#pragma mark -
#pragma mark Launch services

// workaround for a hard-to-reproduce Tiger bug; not sure if still present in Leopard, but err on the safe side
- (void)refreshLaunchServices
{
    CFURLRef ref = CFURLCreateWithFileSystemPath(NULL, (CFStringRef)[self synergyAppPath], kCFURLPOSIXPathStyle, true);
    if (ref)
    {
        (void)LSRegisterURL(ref, false);
        CFRelease(ref);
    }
}

#pragma mark -
#pragma mark Interface Builder actions

- (IBAction)showPrefsWindow:(id)sender
{
    [prefsWindow orderFront:sender];
}

- (IBAction)showHelp:(id)sender
{
    // TODO: embed help in application
    NSURL *URL = [NSURL URLWithString:@"http://synergy.wincent.com/"];
    if (![[NSWorkspace sharedWorkspace] openURL:URL])
        [WOLog err:@"-[NSWorkspace openURL:] failed for URL %@", [URL absoluteString]];
}

#pragma mark -
#pragma mark NSNibAwaking protocol

- (void)awakeFromNib
{
    // auto-launch Synergy if alt is held down
    if ([NSEvent modifierFlags] & NSAlternateKeyMask)
    {
        if ([[NSWorkspace sharedWorkspace] openFile:[self synergyAppPath]])
        {
            [NSApp terminate:self];
            return;
        }
    }

    [NSApp setDelegate:self];
    prefsWindow = [WOPreferenceWindow windowForPane:@"Synergy"];
    [prefsWindow setReleasedWhenClosed:NO];
    NSString *title = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleExecutableKey];
    [prefsWindow setTitle:title];
    [self showPrefsWindow:self];

    // Worst-case scenario here is that we show 4 sheets in a row:
    // - local installation found, plus error on removing it
    // - global installation found, plus error on removing it
    // But this is actually ok because it is an exceptional case; the most common case there will only be one sheet
    // (one installation found, no error) and the user has the option of suppressing the reminders anyway
    [self checkInstallation];

    [self updateLoginItems];
    [self refreshLaunchServices];

    // will flush changes to disk as soon as user clicks so app can "see" them
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(defaultsDidChange:)
                                                 name:NSUserDefaultsDidChangeNotification
                                               object:nil];
}

#pragma mark -
#pragma mark NSApplication delegate methods

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    // if unsaved changes, user has already dismissed the "Apply/Don't Apply" sheet
    // set prefsWindow to nil to avoid the sheet from being thrown back up again (when applicationShouldTerminate: is called)
    prefsWindow = nil;
    return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    // let the preference window handle this
    return prefsWindow ? [prefsWindow applicationShouldTerminate:sender] : NSTerminateNow;
}

@end
