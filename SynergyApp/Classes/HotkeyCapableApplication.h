//
//  HotkeyCapableApplication.h
//  Synergy
//
//  Created by Wincent Colaiuta on Fri Nov 22 2002.
//  Copyright 2002-2008 Wincent Colaiuta.

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

@class WOPreferences, WOButtonState;

@interface HotkeyCapableApplication : NSApplication {

    // pointer to a WOPreferences object
    WOPreferences *synergyPreferences;

    // keycodes for which to trap (these come from preferences)
    UInt32 quitCode;
    UInt32 playCode;
    UInt32 prevCode;
    UInt32 nextCode;
    UInt32 showHideCode;
    UInt32 volumeUpCode;
    UInt32 volumeDownCode;
    UInt32 showHideFloaterCode;
    UInt32 rateAs0Code;
    UInt32 rateAs1Code;
    UInt32 rateAs2Code;
    UInt32 rateAs3Code;
    UInt32 rateAs4Code;
    UInt32 rateAs5Code;
    UInt32 toggleMuteCode;
    UInt32 toggleShuffleCode;
    UInt32 setRepeatModeCode;
    UInt32 activateITunesCode;

    UInt32 increaseRatingCode;
    UInt32 decreaseRatingCode;

    // for identifying "fast forward" (press+hold "next" hot key) operation
    WOButtonState *fastForward;

    // and for "rewind"
    WOButtonState *rewind;

    // and for "volume up"
    WOButtonState *volumeUp;

    // and for "volume down"
    WOButtonState *volumeDown;

    NSView        *newNextResponder;

    // remember whether hot keys have actually been registered
    BOOL            _hotkeysRegistered;
}

// We only define a few methods here, all related to management of global
// hot-keys (most of the real work is done in SynergyController).

- (void)sendEvent:(NSEvent *)theEvent;

- (void)bringSelfToFront;

- (void)closeDown;

- (void)closeDownWithConfirmation;

// stuff moved out of main SynergyController class
- (void)handleEvent:(NSEvent*)theEvent;
- (void)registerHotkeys;
- (void)unregisterHotkeys;

@end
