// HotkeyCapableApplication.m
// Synergy
//
// Copyright 2002-2010 Wincent Colaiuta. All rights reserved.

#import <Carbon/Carbon.h>

// In the future, will re-impliment this idea as a WOApplication class which
// allows you to set a delegate for handling hot key events.
//
// ie. you make a main controller class, but you set WOApplication as your
// NSPrincipalClass... from the controller, you set the controller as the delegate
// and perhaps I can make a WOHotKeyHandler class to encapsulate each hot key
// (or something similar)
// you can exit the app by just calling (from anywhere)
// [[WOApplication sharedApplication] terminate];
//
// with this system the WOApplication class will provide equivalent
// functionality to the present system, but without the need to ever edit this
// file

#import "WODebug.h"
#import "WOPopUpButton.h"
#import "WOPreferences.h"
#import "HotkeyCapableApplication.h"
#import "SynergyController.h"
#import "WOButtonState.h"
#import "WOSynergyGlobal.h"

// We subclass NSApplication so that we can use Carbon calls to intercept global hot-key events
@implementation HotkeyCapableApplication

// Method for registering and intercepting global hot-key events (Carbon)
// based on http://www.unsanity.org/archives/000045.php

enum {
    // NSEvent subtypes for hotkey events (undocumented).
    kEventHotKeyPressedSubtype = 6,
    kEventHotKeyReleasedSubtype = 9,
};

// move this stuff somewhere more sensible:
EventHotKeyRef quitHotKeyRef;
EventHotKeyRef playHotKeyRef;
EventHotKeyRef prevHotKeyRef;
EventHotKeyRef nextHotKeyRef;
EventHotKeyRef showHideHotKeyRef;
EventHotKeyRef volumeUpHotKeyRef;
EventHotKeyRef volumeDownHotKeyRef;
EventHotKeyRef showHideFloaterHotKeyRef;

EventHotKeyRef rateAs0HotKeyRef;
EventHotKeyRef rateAs1HotKeyRef;
EventHotKeyRef rateAs2HotKeyRef;
EventHotKeyRef rateAs3HotKeyRef;
EventHotKeyRef rateAs4HotKeyRef;
EventHotKeyRef rateAs5HotKeyRef;

EventHotKeyRef toggleMuteHotKeyRef;
EventHotKeyRef toggleShuffleHotKeyRef;
EventHotKeyRef setRepeatModeHotKeyRef;

EventHotKeyRef activateITunesHotKeyRef;

EventHotKeyRef increaseRatingHotKeyRef;
EventHotKeyRef decreaseRatingHotKeyRef;

// other classes can call [NSApp respondsToSelector:@selector(isSynergyApp)]
// to find out if running from app or from prefPane
- (BOOL)isSynergyApp
{
    return YES;
}

// we are not registering the hotkeys... where to do it? we only want to do it once the buttons
// are in view...
// do it here for now... in future will have to wait for Synergy.app to launch
- (void) awakeFromNib
{
    synergyPreferences = [WOPreferences sharedInstance];

    // ensure these are a "safe" values
    fastForward         = nil;
    rewind              = nil;
    volumeUp            = nil;
    volumeDown          = nil;
    newNextResponder    = nil;

    [self registerHotkeys];

    // if the user presses a hot key before SynergyController has set itself up, then
    // I don't know what will happen....
    // eg. it could do a [mainTimer fire] before mainTimer has been set up...
    // or it could fail to even make the call
}


- (void)sendEvent:(NSEvent *)theEvent
{
    NSEventType eventType = [theEvent type];
    if (eventType == NSSystemDefined)
    {
        short subtype = [theEvent subtype];
        if (subtype == kEventHotKeyPressedSubtype ||
            subtype == kEventHotKeyReleasedSubtype)
        {
            [self handleEvent:theEvent];    // a hot key has been pressed (or released)
            [super sendEvent:theEvent];     // we were swallowing these events (oops) up until 1.0a8!
        }
    }

    // special case -- work around for apparent bug which prevents NSRightMouseDown from getting transmitted to our NSStatusItem
    if ([[self nextResponder] isKindOfClass:[WOPopUpButton class]] &&
        eventType == NSRightMouseDown)
    {
        // dispatch the event directly
        WOPopUpButton   *responderView      = (WOPopUpButton *)[self nextResponder];

        // must use [NSEvent mouseLocation] because [theEvent window] can return nil and therefore cannot be used for calculations
        NSPoint         globalMouseLoc      = [NSEvent mouseLocation];
        NSPoint         internalMouseLoc    = [[responderView window] convertScreenToBase:globalMouseLoc];
        NSRect          responderBounds     = [responderView frame];

        if(NSMouseInRect(internalMouseLoc, responderBounds, NO))
            [[self nextResponder] rightMouseDown:theEvent];
    }
    else
        // pass the event through the usual channels
        [super sendEvent:theEvent];
}

- (void)closeDown
{
    [[SynergyController sharedInstance] cleanupBeforeExit]; // have to cleanup manually
    exit(0); // nasty
}

- (void)bringSelfToFront
{
    ProcessSerialNumber myPID;
    OSErr errCode = GetCurrentProcess(&myPID);
    if (errCode == noErr)
        (void)SetFrontProcess(&myPID);
    else
        ELOG(@"Unable to determine current process ID");
}

/*
 Need to add a check in here to ensure Synergy.prefPane isn't being displayed, because we will
 behave differently if it is:
 -- if Synergy.prefPane is running -- we can display dialog and quit, BUT on quit tell prefPane
 to update its stop/start button
 -- if it is not running, just quit as normal
 */
- (void) closeDownWithConfirmation
{
    // only display this if we are quitting due to a hotkey press
    NSString *title = NSLocalizedString(@"Are you sure you want to quit Synergy?",@"Ask for confirmation before quitting");
    NSString *message = NSLocalizedString(@"If you quit Synergy its iTunes control buttons will be removed from the menubar.",@"Quit confirmation explanation");
    NSString *defaultButton = NSLocalizedString(@"Quit",@"Quit button");
    NSString *alternateButton = NSLocalizedString(@"Cancel",@"Cancel button");
    NSString *otherButton = nil;


    // find out frontmost process
    ProcessSerialNumber frontPID;
    OSErr errCode = GetFrontProcess(&frontPID);

    [self bringSelfToFront];

    int status = NSRunAlertPanel(title, message, defaultButton, alternateButton, otherButton);

    // restore frontmost process
    if (errCode == noErr)
        (void)SetFrontProcess(&frontPID);
    else
        ELOG(@"Unable to determine frontmost process ID");

    if ( status == NSAlertDefaultReturn )
        // trying to clean up another object's garbage, which is a no-no in Cocoa... bad practice.
        [self closeDown];
}


- (void)handleEvent:(NSEvent*)theEvent
{
    // we get in here on keydown, not keyup
    if ([[synergyPreferences objectOnDiskForKey:_woGlobalHotkeysPrefKey] boolValue] == NO)
        return; // global hotkey handling is turned off, so return immediately
    else
    {
        EventHotKeyRef hotKeyRef;
        hotKeyRef= (EventHotKeyRef)[theEvent data1]; //data1 is our hot key ref

        // differentiate between hot key press and hot key release for certain
        // events where a hold-operation will have a special effect
        // eg. prev/next held down = rewind/fast forward
        // vol up/down held down = continual volume up/down
        // rating up/down held down = continual rating increase/decrease
        short subtype = [theEvent subtype];
        if (subtype == kEventHotKeyPressedSubtype)
        {
            // all these get handled the standard way
            if (hotKeyRef != nil )
            {
                if (hotKeyRef == quitHotKeyRef)
                {
                    // unregister the hotkeys to prevent their use while displaying the quit confirmation dialog
                    [self unregisterHotkeys];
                    [self closeDownWithConfirmation];
                    [self registerHotkeys];
                }
                else if (hotKeyRef == playHotKeyRef)
                    [[SynergyController sharedInstance] playPauseHotKeyPressed];
                else if (hotKeyRef == prevHotKeyRef)
                    rewind = [[WOButtonState alloc] initWithTarget:[SynergyController sharedInstance]
                                                          selector:@selector(rewindHotKeyPressed)];
                else if (hotKeyRef == nextHotKeyRef)
                    fastForward = [[WOButtonState alloc] initWithTarget:[SynergyController sharedInstance]
                                                               selector:@selector(fastForwardHotKeyPressed)];
                else if (hotKeyRef == showHideHotKeyRef)
                    [[SynergyController sharedInstance] showHideHotKeyPressed];
                else if (hotKeyRef == volumeUpHotKeyRef)
                    [[SynergyController sharedInstance] volumeUpHotKeyPressed];
                else if (hotKeyRef == volumeDownHotKeyRef)
                    [[SynergyController sharedInstance] volumeDownHotKeyPressed];
                else if (hotKeyRef == showHideFloaterHotKeyRef)
                    [[SynergyController sharedInstance] showHideFloaterHotKeyPressed];
                else if (hotKeyRef == rateAs0HotKeyRef)
                    [[SynergyController sharedInstance] rateAs0HotKeyPressed];
                else if (hotKeyRef == rateAs1HotKeyRef)
                    [[SynergyController sharedInstance] rateAs1HotKeyPressed];
                else if (hotKeyRef == rateAs2HotKeyRef)
                    [[SynergyController sharedInstance] rateAs2HotKeyPressed];
                else if (hotKeyRef == rateAs3HotKeyRef)
                    [[SynergyController sharedInstance] rateAs3HotKeyPressed];
                else if (hotKeyRef == rateAs4HotKeyRef)
                    [[SynergyController sharedInstance] rateAs4HotKeyPressed];
                else if (hotKeyRef == rateAs5HotKeyRef)
                    [[SynergyController sharedInstance] rateAs5HotKeyPressed];
                else if (hotKeyRef == toggleMuteHotKeyRef)
                    [[SynergyController sharedInstance] toggleMuteHotKeyPressed];
                else if (hotKeyRef == toggleShuffleHotKeyRef)
                    [[SynergyController sharedInstance] toggleShuffleHotKeyPressed];
                else if (hotKeyRef == setRepeatModeHotKeyRef)
                    [[SynergyController sharedInstance] setRepeatModeHotKeyPressed];
                else if (hotKeyRef == activateITunesHotKeyRef)
                    [[SynergyController sharedInstance] activateITunesHotKeyPressed];
                else if (hotKeyRef == increaseRatingHotKeyRef)
                    [[SynergyController sharedInstance] increaseRatingHotKeyPressed];
                else if (hotKeyRef == decreaseRatingHotKeyRef)
                    [[SynergyController sharedInstance] decreaseRatingHotKeyPressed];
                else
                    ELOG(@"Unknown HotKeyRef received."); // shouldn't happen
            }
        }
        else if (subtype == kEventHotKeyReleasedSubtype)
        {
            // special cases here (items which behave differently on hot key release)

            if (hotKeyRef != nil )
            {
                if (hotKeyRef == prevHotKeyRef)
                {
                    // make sure we have a WOButtonState object
                    if (rewind)
                    {
                        // "prev" hot key released... check to see if timer expired
                        if ([rewind timerRunning])
                        {
                            // timer still running, so this isn't a "click+hold"
                            [rewind cancelTimer];

                            // tell iTunes to go to prev track
                            [[SynergyController sharedInstance] prevHotKeyPressed];
                        }
                        else
                        {
                            // it was a "click+hold", so tell iTunes to resume
                            [[SynergyController sharedInstance] rewindHotKeyReleased];
                        }

                        // clean up WOButtonState object
                        rewind = nil;
                    }
                }
                else if (hotKeyRef == nextHotKeyRef)
                {
                    // make sure we have a WOButtonState object
                    if (fastForward)
                    {
                        // "next" hot key released... check to see if timer expired
                        if ([fastForward timerRunning])
                        {
                            // timer still running, so this isn't a "click+hold"
                            [fastForward cancelTimer];

                            // tell iTunes to go to next track
                            [[SynergyController sharedInstance] nextHotKeyPressed];
                        }
                        else
                        {
                            // it was a "click+hold", so tell iTunes to resume
                            [[SynergyController sharedInstance] fastForwardHotKeyReleased];
                        }

                        // clean up WOButtonState object
                        fastForward = nil;
                    }
                }
            }
        }
    }
}

- (void) registerHotkeys
{
    // we've been asked to register the hot keys
    if ([[synergyPreferences objectOnDiskForKey:_woGlobalHotkeysPrefKey] boolValue] == NO)
        return;  // do nothing...

    // else, note that we have registered them...
    _hotkeysRegistered = YES;

    unsigned int quitModifier = [[synergyPreferences objectOnDiskForKey:_woQuitModifierPrefKey] unsignedIntValue];
    unsigned int playModifier = [[synergyPreferences objectOnDiskForKey:_woPlayModifierPrefKey] unsignedIntValue];
    unsigned int prevModifier = [[synergyPreferences objectOnDiskForKey:_woPrevModifierPrefKey] unsignedIntValue];
    unsigned int nextModifier = [[synergyPreferences objectOnDiskForKey:_woNextModifierPrefKey] unsignedIntValue];
    unsigned int showHideModifier = [[synergyPreferences objectOnDiskForKey:_woShowHideModifierPrefKey] unsignedIntValue];
    unsigned int volumeUpModifier = [[synergyPreferences objectOnDiskForKey:_woVolumeUpModifierPrefKey] unsignedIntValue];
    unsigned int volumeDownModifier = [[synergyPreferences objectOnDiskForKey:_woVolumeDownModifierPrefKey] unsignedIntValue];
    unsigned int showHideFloaterModifier = [[synergyPreferences objectOnDiskForKey:_woShowHideFloaterModifierPrefKey] unsignedIntValue];
    unsigned int rateAs0Modifier = [[synergyPreferences objectOnDiskForKey:_woRateAs0ModifierPrefKey] unsignedIntValue];
    unsigned int rateAs1Modifier = [[synergyPreferences objectOnDiskForKey:_woRateAs1ModifierPrefKey] unsignedIntValue];
    unsigned int rateAs2Modifier = [[synergyPreferences objectOnDiskForKey:_woRateAs2ModifierPrefKey] unsignedIntValue];
    unsigned int rateAs3Modifier = [[synergyPreferences objectOnDiskForKey:_woRateAs3ModifierPrefKey] unsignedIntValue];
    unsigned int rateAs4Modifier = [[synergyPreferences objectOnDiskForKey:_woRateAs4ModifierPrefKey] unsignedIntValue];
    unsigned int rateAs5Modifier = [[synergyPreferences objectOnDiskForKey:_woRateAs5ModifierPrefKey] unsignedIntValue];
    unsigned int toggleMuteModifier = [[synergyPreferences objectOnDiskForKey:_woToggleMuteModifierPrefKey] unsignedIntValue];
    unsigned int toggleShuffleModifier = [[synergyPreferences objectOnDiskForKey:_woToggleShuffleModifierPrefKey] unsignedIntValue];
    unsigned int setRepeatModeModifier = [[synergyPreferences objectOnDiskForKey:_woSetRepeatModeModifierPrefKey] unsignedIntValue];
    unsigned int activateITunesModifier = [[synergyPreferences objectOnDiskForKey:_woActivateITunesModifierPrefKey] unsignedIntValue];
    unsigned int increaseRatingModifier = [[synergyPreferences objectOnDiskForKey:_woIncreaseRatingModifierPrefKey] unsignedIntValue];
    unsigned int decreaseRatingModifier = [[synergyPreferences objectOnDiskForKey:_woDecreaseRatingModifierPrefKey] unsignedIntValue];

    quitCode = [[synergyPreferences objectOnDiskForKey:_woQuitKeycodePrefKey] intValue];
    playCode = [[synergyPreferences objectOnDiskForKey:_woPlayKeycodePrefKey] intValue];
    prevCode = [[synergyPreferences objectOnDiskForKey:_woPrevKeycodePrefKey] intValue];
    nextCode = [[synergyPreferences objectOnDiskForKey:_woNextKeycodePrefKey] intValue];
    showHideCode = [[synergyPreferences objectOnDiskForKey:_woShowHideKeycodePrefKey] intValue];
    volumeUpCode = [[synergyPreferences objectOnDiskForKey:_woVolumeUpKeycodePrefKey] intValue];
    volumeDownCode = [[synergyPreferences objectOnDiskForKey:_woVolumeDownKeycodePrefKey] intValue];
    showHideFloaterCode = [[synergyPreferences objectOnDiskForKey:_woShowHideFloaterKeycodePrefKey] intValue];
    rateAs0Code = [[synergyPreferences objectOnDiskForKey:_woRateAs0KeycodePrefKey] intValue];
    rateAs1Code = [[synergyPreferences objectOnDiskForKey:_woRateAs1KeycodePrefKey] intValue];
    rateAs2Code = [[synergyPreferences objectOnDiskForKey:_woRateAs2KeycodePrefKey] intValue];
    rateAs3Code = [[synergyPreferences objectOnDiskForKey:_woRateAs3KeycodePrefKey] intValue];
    rateAs4Code = [[synergyPreferences objectOnDiskForKey:_woRateAs4KeycodePrefKey] intValue];
    rateAs5Code = [[synergyPreferences objectOnDiskForKey:_woRateAs5KeycodePrefKey] intValue];
    toggleMuteCode = [[synergyPreferences objectOnDiskForKey:_woToggleMuteKeycodePrefKey] intValue];
    toggleShuffleCode = [[synergyPreferences objectOnDiskForKey:_woToggleShuffleKeycodePrefKey] intValue];
    setRepeatModeCode = [[synergyPreferences objectOnDiskForKey:_woSetRepeatModeKeycodePrefKey] intValue];
    activateITunesCode = [[synergyPreferences objectOnDiskForKey:_woActivateITunesKeycodePrefKey] intValue];
    increaseRatingCode = [[synergyPreferences objectOnDiskForKey:_woIncreaseRatingKeycodePrefKey] intValue];
    decreaseRatingCode = [[synergyPreferences objectOnDiskForKey:_woDecreaseRatingKeycodePrefKey] intValue];

    // prepare the parameters so that we can register our hotkey
    const UInt32 mySignature = synergyAppSignature;

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*(quitCode !=0) && */(quitModifier !=0))
    {
        UInt32 quitKeyCode=quitCode;  // F10 is default... 109
        EventHotKeyID quitHotKeyID;
        quitHotKeyID.signature = mySignature; // (OSType)
        quitHotKeyID.id = 1;                  // (UInt32)
                           //EventHotKeyRef quitHotKeyRef;
                           //then register it
        RegisterEventHotKey(quitKeyCode,
                            quitModifier,
                            quitHotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &quitHotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*playCode !=0) && */(playModifier !=0))
    {
        UInt32 playKeyCode=playCode;
        EventHotKeyID playHotKeyID;
        playHotKeyID.signature = mySignature;
        playHotKeyID.id = 2;
        //EventHotKeyRef playHotKeyRef;
        RegisterEventHotKey(playKeyCode,
                            playModifier,
                            playHotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &playHotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*prevCode !=0) && */(prevModifier !=0))
    {
        UInt32 prevKeyCode=prevCode;
        EventHotKeyID prevHotKeyID;
        prevHotKeyID.signature = mySignature;
        prevHotKeyID.id = 3;
        //EventHotKeyRef prevHotKeyRef;
        RegisterEventHotKey(prevKeyCode,
                            prevModifier,
                            prevHotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &prevHotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*nextCode !=0) && */(nextModifier !=0))
    {
        UInt32 nextKeyCode=nextCode;
        EventHotKeyID nextHotKeyID;
        nextHotKeyID.signature = mySignature;
        nextHotKeyID.id = 4;
        //EventHotKeyRef nextHotKeyRef;localize
        RegisterEventHotKey(nextKeyCode,
                            nextModifier,
                            nextHotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &nextHotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*showHideCode !=0) && */(showHideModifier !=0))
    {
        UInt32 showHideKeyCode=showHideCode;
        EventHotKeyID showHideHotKeyID;
        showHideHotKeyID.signature = mySignature;
        showHideHotKeyID.id = 5;
        RegisterEventHotKey(showHideKeyCode,
                            showHideModifier,
                            showHideHotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &showHideHotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*volumeUpCode !=0) && */(volumeUpModifier !=0))
    {
        UInt32 volumeUpKeyCode = volumeUpCode;
        EventHotKeyID volumeUpHotKeyID;
        volumeUpHotKeyID.signature = mySignature;
        volumeUpHotKeyID.id = 6;
        RegisterEventHotKey(volumeUpKeyCode,
                            volumeUpModifier,
                            volumeUpHotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &volumeUpHotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*volumeDownCode !=0) && */(volumeDownModifier !=0))
    {
        UInt32 volumeDownKeyCode = volumeDownCode;
        EventHotKeyID volumeDownHotKeyID;
        volumeDownHotKeyID.signature = mySignature;
        volumeDownHotKeyID.id = 7;
        RegisterEventHotKey(volumeDownKeyCode,
                            volumeDownModifier,
                            volumeDownHotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &volumeDownHotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*showHideFloaterCode !=0) && */(showHideFloaterModifier !=0))
    {
        UInt32 showHideFloaterKeyCode=showHideFloaterCode;
        EventHotKeyID showHideFloaterHotKeyID;
        showHideFloaterHotKeyID.signature = mySignature;
        showHideFloaterHotKeyID.id = 8;
        RegisterEventHotKey(showHideFloaterKeyCode,
                            showHideFloaterModifier,
                            showHideFloaterHotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &showHideFloaterHotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*rateAs1Code !=0) && */(rateAs1Modifier !=0))
    {
        UInt32 rateAs1KeyCode = rateAs1Code;
        EventHotKeyID rateAs1HotKeyID;
        rateAs1HotKeyID.signature = mySignature;
        rateAs1HotKeyID.id = 9;
        RegisterEventHotKey(rateAs1KeyCode,
                            rateAs1Modifier,
                            rateAs1HotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &rateAs1HotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*rateAs2Code !=0) && */(rateAs2Modifier !=0))
    {
        UInt32 rateAs2KeyCode = rateAs2Code;
        EventHotKeyID rateAs2HotKeyID;
        rateAs2HotKeyID.signature = mySignature;
        rateAs2HotKeyID.id = 10;
        RegisterEventHotKey(rateAs2KeyCode,
                            rateAs2Modifier,
                            rateAs2HotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &rateAs2HotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*rateAs3Code !=0) && */(rateAs3Modifier !=0))
    {
        UInt32 rateAs3KeyCode = rateAs3Code;
        EventHotKeyID rateAs3HotKeyID;
        rateAs3HotKeyID.signature = mySignature;
        rateAs3HotKeyID.id = 11;
        RegisterEventHotKey(rateAs3KeyCode,
                            rateAs3Modifier,
                            rateAs3HotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &rateAs3HotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*rateAs4Code !=0) && */(rateAs4Modifier !=0))
    {
        UInt32 rateAs4KeyCode = rateAs4Code;
        EventHotKeyID rateAs4HotKeyID;
        rateAs4HotKeyID.signature = mySignature;
        rateAs4HotKeyID.id = 12;
        RegisterEventHotKey(rateAs4KeyCode,
                            rateAs4Modifier,
                            rateAs4HotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &rateAs4HotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*rateAs5Code !=0) && */(rateAs5Modifier !=0))
    {
        UInt32 rateAs5KeyCode = rateAs5Code;
        EventHotKeyID rateAs5HotKeyID;
        rateAs5HotKeyID.signature = mySignature;
        rateAs5HotKeyID.id = 13;
        RegisterEventHotKey(rateAs5KeyCode,
                            rateAs5Modifier,
                            rateAs5HotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &rateAs5HotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*rateAs0Code !=0) && */(rateAs0Modifier !=0))
    {
        UInt32 rateAs0KeyCode = rateAs0Code;
        EventHotKeyID rateAs0HotKeyID;
        rateAs0HotKeyID.signature = mySignature;
        rateAs0HotKeyID.id = 14;
        RegisterEventHotKey(rateAs0KeyCode,
                            rateAs0Modifier,
                            rateAs0HotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &rateAs0HotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*toggleMuteCode !=0) && */(toggleMuteModifier !=0))
    {
        UInt32 toggleMuteKeyCode = toggleMuteCode;
        EventHotKeyID toggleMuteHotKeyID;
        toggleMuteHotKeyID.signature = mySignature;
        toggleMuteHotKeyID.id = 15;
        RegisterEventHotKey(toggleMuteKeyCode,
                            toggleMuteModifier,
                            toggleMuteHotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &toggleMuteHotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*toggleShuffleCode !=0) && */(toggleShuffleModifier !=0))
    {
        UInt32 toggleShuffleKeyCode = toggleShuffleCode;
        EventHotKeyID toggleShuffleHotKeyID;
        toggleShuffleHotKeyID.signature = mySignature;
        toggleShuffleHotKeyID.id = 16;
        RegisterEventHotKey(toggleShuffleKeyCode,
                            toggleShuffleModifier,
                            toggleShuffleHotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &toggleShuffleHotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*setRepeatModeCode !=0) && */(setRepeatModeModifier !=0))
    {
        UInt32 setRepeatModeKeyCode = setRepeatModeCode;
        EventHotKeyID setRepeatModeHotKeyID;
        setRepeatModeHotKeyID.signature = mySignature;
        setRepeatModeHotKeyID.id = 17;
        RegisterEventHotKey(setRepeatModeKeyCode,
                            setRepeatModeModifier,
                            setRepeatModeHotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &setRepeatModeHotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*activateITunesCode !=0) && */(activateITunesModifier !=0))
    {
        UInt32 activateITunesKeyCode = activateITunesCode;
        EventHotKeyID activateITunesHotKeyID;
        activateITunesHotKeyID.signature = mySignature;
        activateITunesHotKeyID.id = 18;
        RegisterEventHotKey(activateITunesKeyCode,
                            activateITunesModifier,
                            activateITunesHotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &activateITunesHotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*increaseRatingCode !=0) && */(increaseRatingModifier !=0))
    {
        UInt32 increaseRatingKeyCode = increaseRatingCode;
        EventHotKeyID increaseRatingHotKeyID;
        increaseRatingHotKeyID.signature = mySignature;
        increaseRatingHotKeyID.id = 19;
        RegisterEventHotKey(increaseRatingKeyCode,
                            increaseRatingModifier,
                            increaseRatingHotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &increaseRatingHotKeyRef);
    }

    // Panther fix: API has changed and now allows "0" for modifier and keycode
    if (/*decreaseRatingCode !=0) && */(decreaseRatingModifier !=0))
    {
        UInt32 decreaseRatingKeyCode = decreaseRatingCode;
        EventHotKeyID decreaseRatingHotKeyID;
        decreaseRatingHotKeyID.signature = mySignature;
        decreaseRatingHotKeyID.id = 20;
        RegisterEventHotKey(decreaseRatingKeyCode,
                            decreaseRatingModifier,
                            decreaseRatingHotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &decreaseRatingHotKeyRef);
    }
}

- (void) unregisterHotkeys
{
    // Consequence of new Panther code: here we might be trying to unregister
    // keys that were never registered

    // only unregister the keys if we registered them in the first place
    if (!_hotkeysRegistered)
        return;

    UnregisterEventHotKey(quitHotKeyRef);
    UnregisterEventHotKey(playHotKeyRef);
    UnregisterEventHotKey(prevHotKeyRef);
    UnregisterEventHotKey(nextHotKeyRef);
    UnregisterEventHotKey(showHideHotKeyRef);
    UnregisterEventHotKey(volumeUpHotKeyRef);
    UnregisterEventHotKey(volumeDownHotKeyRef);
    UnregisterEventHotKey(showHideFloaterHotKeyRef);
    UnregisterEventHotKey(rateAs0HotKeyRef);
    UnregisterEventHotKey(rateAs1HotKeyRef);
    UnregisterEventHotKey(rateAs2HotKeyRef);
    UnregisterEventHotKey(rateAs3HotKeyRef);
    UnregisterEventHotKey(rateAs4HotKeyRef);
    UnregisterEventHotKey(rateAs5HotKeyRef);
    UnregisterEventHotKey(toggleMuteHotKeyRef);
    UnregisterEventHotKey(toggleShuffleHotKeyRef);
    UnregisterEventHotKey(setRepeatModeHotKeyRef);
    UnregisterEventHotKey(activateITunesHotKeyRef);
    UnregisterEventHotKey(increaseRatingHotKeyRef);
    UnregisterEventHotKey(decreaseRatingHotKeyRef);

    _hotkeysRegistered = NO;
}

@end
