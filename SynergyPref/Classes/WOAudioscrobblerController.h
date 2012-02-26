//
//  WOAudioscrobblerController.h
//  Synergy
//
//  Created by Wincent Colaiuta on 7 November 2006.
//  Copyright 2006-2008 Wincent Colaiuta.

#import <Cocoa/Cocoa.h>

//! URL visited when user clicks help button
#define WO_AUDIOSCROBBLER_HELP_URL  @"http://www.last.fm/"

//! \name User defaults keys
//! Key names for preferences stored in user defaults
//! \startgroup

#define WO_AUDIOSCROBBLER_USERNAME                      @"AudioscrobblerUsername"

#define WO_STORE_AUDIOSCROBBLER_PASSWORD_IN_KEYCHAIN    @"StoreAudioscrobblerPasswordInKeychain"

//! \endgroup

//! \name Sheet info keys
//! Dictionary keys for use in the info dictionary passed to beginSheetModalForWindow:contextInfo:
//! \startgroup

//! A selector string
#define WO_SELECTOR     @"WOSelector"

#define WO_TARGET       @"WOTarget"

//! \endgroup

#pragma mark -
#pragma mark Functions

//! Logs to the console if and only if the LogAudioscrobblerEvents user default (in org.wincent.Synergy) is true
void WOAudioscrobblerLog(NSString *format, ...);

//! Simple controller class ("File's Owner") for audioscrobbler.nib
@interface WOAudioscrobblerController : NSObject {

#ifdef SYNERGY_PREF_BUILD
    // if this were 10.3+ could get rid of most of this by using Bindings and NSUserDefaultsController
    IBOutlet NSWindow           *accountWindow;
    IBOutlet NSTextField        *usernameTextField;
    IBOutlet NSSecureTextField  *passwordTextField;
    IBOutlet NSButton           *helpButton;
    IBOutlet NSButton           *keychainButton;
    IBOutlet NSButton           *saveButton;
#endif /* SYNERGY_PREF_BUILD */

    BOOL                        storeInKeychain;
    BOOL                        keychainCallbackAdded;
}

#pragma mark -
#pragma mark Keychain helper methods

//! Call from application to read from keychain
- (NSString *)getPasswordFromKeychainForUsername:(NSString *)username;

#ifdef SYNERGY_PREF_BUILD

#pragma mark -
#pragma mark Custom methods

//! Call from preference pane to handle sheet
- (void)beginSheetModalForWindow:(NSWindow *)aWindow contextInfo:(NSDictionary *)info;

#pragma mark -
#pragma mark IBActions

- (IBAction)helpButtonPressed:(id)sender;

- (IBAction)keychainButtonPressed:(id)sender;

- (IBAction)cancelButtonPressed:(id)sender;

- (IBAction)saveButtonPressed:(id)sender;

#endif  /* SYNERGY_PREF_BUILD */

#pragma mark -
#pragma mark Accessors

- (BOOL)storeInKeychain;
- (void)setStoreInKeychain:(BOOL)flag;

@end
