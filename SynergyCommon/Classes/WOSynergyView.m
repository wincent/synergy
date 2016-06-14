//
//  WOSynergyView.m
//  Synergy
//
//  Created by Greg Hurrell on 9 December 2002.
//  Copyright 2002-present Greg Hurrell.

#import "WOSynergyView.h"
#import "HotkeyCapableApplication.h"
#import "WOPreferences.h"
#import "WODebug.h"
#import "WOButtonSet.h"
#import "WOButtonState.h"
#import "WOSynergyGlobal.h"
#import "WOButtonWithTrackingRect.h"
#import "WOPopUpButton.h"

/*

 This NSView subclass is used both in the Synergy.app and also in the
 Synergy.prefPane. The key difference is that in the prefPane the buttons are
 not actually connected with any action. The #ifdef statements simply comment
 out the relevant code.

 Also, the means by which the preferences are accessed is different. In the case
 of the app, read the preferences from disk; in the case of the prefPane, always
 use the "current" settings.

 */

#ifdef SYNERGY_APP_BUILD

// We will need to communicate with the main Controller class of the app
#import "SynergyController.h"

// When using this class in the app, always access prefs using
// "objectOnDiskForKey" method (ie. access the prefs on the disk)
#define usingMethodGetValueKey objectOnDiskForKey

#endif /* SYNERGY_APP_BUILD */

#ifdef SYNERGY_PREF_BUILD

// When using this class in the prefPane, always access prefs using
// "objectForKey" method (ie. access current prefs, not the possibly stale prefs
// on disk)
#define usingMethodGetValueKey objectForKey

#endif /* SYNERGY_PREF_BUILD */


#ifdef SYNERGY_APP_BUILD

@implementation NSButton (WOAppKitWorkaround)
/*"
 Override default NSButton implementation (but only in the Synergy application,
 not the preference pane) to indicate that the control buttons will not accept
 first responder status. This prevents the application being brought to the
 front when the buttons are clicked, even though it is a background-only
 application.
 "*/

- (BOOL)acceptsFirstResponder
{
    return NO;
}

@end

#endif /* SYNERGY_APP_BUILD */

#ifdef USE_APPLE_WORKAROUND_WHICH_DOES_NOT_COMPILE

// START: WORKAROUND FOR APPLE NSSTATUSITEM BUG ////////////////////////////////

/*

 Solution - from: "Background-only apps with NSStatusItems become active in 10.1
 on NSStatusItem clicks"
 (http://developer.apple.com/qa/qa2001/qa1081.html)

 */

// NSStatusBarButton is a private class, so put in a cheesy interface.
// Note that this interface is not correct and should only be used to
// allow the following workaround to compile.
@interface NSStatusBarButton : NSButton {

}

@end

// For 10.1 versions of the AppKit, workaround the activation issue;
// for later versions with the bug fix, defer to the kit.
@implementation NSStatusBarButton (AppKitWorkaround)

- (BOOL)acceptsFirstResponder
{
    return (NSAppKitVersionNumber < 630) ? NO : [super acceptsFirstResponder];
}

@end

// END: WORKAROUND FOR APPLE NSSTATUSITEM BUG //////////////////////////////////

#endif /* USE_APPLE_WORKAROUND_WHICH_DOES_NOT_COMPILE */

@implementation WOSynergyView

// Gets called immediately on launch, even before SynergyController class
- (id)initWithFrame:(NSRect)frame {

    self = [super initWithFrame:frame];

    if (self)
    {
        nextButton = [[WOButtonWithTrackingRect alloc] init];
        playButton = [[WOPopUpButton alloc] init];
        prevButton = [[WOButtonWithTrackingRect alloc] init];

        // set these to safe values
        nextButtonState = nil;
        prevButtonState = nil;
        globalMenu = nil;

        /*

         New approach here is to make image choices dynamic: this means that
         instead of loading one image set at launch and using that for the life
         of the program, we have the option of loading different sets and
         switching between them. Furthermore, the sizes of the images in these
         sets are not fixed, although two obvious rules apply:

         1. The "next" and "previous" images must match in dimensions; and
         similarly, the "play", "pause", "stop" and "playPause" images must also
         match.

         2. A fixed, compulsory height of 22 pixels applies, because this is the
         height of the Mac OS X menu bar.

         Images are stored in folders inside the Resources folder of the bundle.
         The standard set is found in "buttons/Standard", and the first of the
         alternate sets is found in "buttons/3D". These names, "Standard" and
         "3D", are chosen to match exactly (including case) the names given to
         the buttons sets in the preferences user interface.

         */

        // prepare our dictionary of button sets...
        loadedButtonSets = [[NSMutableDictionary alloc] init];

        // make sure we're using the correct button set
        NSString *newButtonSet =
            [[WOPreferences sharedInstance] usingMethodGetValueKey:_woButtonStylePrefKey];

        if (newButtonSet != nil)
            [self setButtonSet:newButtonSet];
        else
            [self setButtonSet:WO_DEFAULT_BUTTON_SET];

        // try to prevent mouse clicks from being passed to SystemUIServer
    }

    return self;
}

- (void)finalize
{
    // finalize may be too late for this
    if ([nextButton isDescendantOf:self])
        [nextButton removeFromSuperview];

    if ([playButton isDescendantOf:self])
        [playButton removeFromSuperview];

    if ([prevButton isDescendantOf:self])
        [prevButton removeFromSuperview];
    [super finalize];
}

/*

 Note:

 -drawRect: is getting called every time I click one of the buttons, and as a
 result the entire NSView is being redrawn.

 In fact, on mouse click it appears to be getting drawn FOUR TIMES. Once for
 mouse down and three times at mouse up! (It is though it is doing it for each
 button drawing routine...)

 */


- (void)drawRect:(NSRect)rect {
    // all drawing gets done in the subviews
}

- (void)disableNextButton
{
    [nextButton setEnabled:NO];
}

- (void)enableNextButton
{
    [nextButton setEnabled:YES];
}

- (void)disablePrevButton
{
    [prevButton setEnabled:NO];
}

- (void)enablePrevButton
{
    [prevButton setEnabled:YES];
}

- (void) showNextButton
{

    [nextButton setButtonType:NSMomentaryChangeButton];
    [nextButton setBordered:NO];
    [nextButton setImage:[[self buttonSetId] nextImage]];
    [nextButton setImagePosition:NSImageOnly];
    [nextButton setTarget:self];

    // instead, supply custom actions for mouse up, down, entered and exit
    [nextButton sendActionOn:NSLeftMouseDownMask|NSLeftMouseUpMask];

    [nextButton setMouseDownAction:@selector(nextButtonDown)];
    [nextButton setMouseUpAction:@selector(nextButtonUp)];
    [nextButton setMouseExitedAction:@selector(nextButtonExited)];
    [nextButton setMouseEnteredAction:@selector(nextButtonEntered)];

    NSRect nextButtonFrame = NSMakeRect([self calculateNextButtonPosition],
                                        bottomControlPadding,
                                        [[self buttonSetId] nextImageSize].width,
                                        controlHotSpotHeight);
    [nextButton setFrame:nextButtonFrame];

    if ([nextButton isDescendantOf:self] == NO)
        [self addSubview:nextButton];
}

- (void) hideNextButton
{
    if ([nextButton isDescendantOf:self])
    {
        [nextButton removeFromSuperview];

        // do calculations to resize the WOSynergyView object and the NSStatusItem
        [self resizeSynergyView];
    }
}

- (void) nextButtonAction
{

#ifdef SYNERGY_APP_BUILD
    [[SynergyController sharedInstance] nextTrack:nil];
#endif

}

- (void)nextButtonDown
{
    // only in the app do we actually do anything
#ifdef SYNERGY_APP_BUILD

    if (nextButtonState)
        nextButtonState = nil;

    // if pressed and held, use same "fast forward" method as "next" hot key
    nextButtonState = [[WOButtonState alloc] initWithTarget:[SynergyController sharedInstance]
                                                   selector:@selector(fastForwardHotKeyPressed)];

#endif
}

- (void)nextButtonUp
{
    // only in the app do we actually do anything
#ifdef SYNERGY_APP_BUILD

    // make sure we have a WOButtonState object
    if (nextButtonState)
    {
        // "next" menu bar button released; check to see if timer expired
        if ([nextButtonState timerRunning])
        {
            // timer is still running, so this isn't a "click+hold"
            [nextButtonState cancelTimer];

            // tell iTunes to go to next track
            [[SynergyController sharedInstance] nextTrack:nil];
        }
        else
        {
            // it was a "click+hold", so tell iTunes to resume
            [[SynergyController sharedInstance] fastForwardHotKeyReleased];
        }

        // clean up WOButtonState object
        nextButtonState = nil;
    }
#endif
}

- (void)nextButtonExited
{
    // only in the app do we actually do anything
#ifdef SYNERGY_APP_BUILD

    // make sure we have a WOButtonState object
    if (nextButtonState)
    {
        // "next" menu bar button released; check to see if timer expired
        if ([nextButtonState timerRunning])
        {
            // timer is still running, so this isn't a "click+hold"
            [nextButtonState cancelTimer];

            // tell iTunes to go to next track
            [[SynergyController sharedInstance] nextTrack:nil];
        }
        else
        {
            // it was a "click+hold", so tell iTunes to resume
            [[SynergyController sharedInstance] fastForwardHotKeyReleased];
        }

        // clean up WOButtonState object
        nextButtonState = nil;
    }
#endif
}

- (void)nextButtonEntered
{
    // only in the app do we actually do anything
#ifdef SYNERGY_APP_BUILD

    if (nextButtonState)
        nextButtonState = nil;

    // if pressed and held, use same "fast forward" method as "next" hot key
    nextButtonState =
        [[WOButtonState alloc] initWithTarget:[SynergyController sharedInstance]
                                     selector:@selector(fastForwardHotKeyPressed)];

#endif
}

- (void)prevButtonDown
{
    // only in the app do we actually do anything
#ifdef SYNERGY_APP_BUILD

    if (prevButtonState)
        prevButtonState = nil;

    // if pressed and held, use same "fast forward" method as "prev" hot key
    prevButtonState =
        [[WOButtonState alloc] initWithTarget:[SynergyController sharedInstance]
                                     selector:@selector(rewindHotKeyPressed)];

#endif
}

- (void)prevButtonUp
{
    // only in the app do we actually do anything
#ifdef SYNERGY_APP_BUILD

    // make sure we have a WOButtonState object
    if (prevButtonState)
    {
        // "prev" menu bar button released; check to see if timer expired
        if ([prevButtonState timerRunning])
        {
            // timer is still running, so this isn't a "click+hold"
            [prevButtonState cancelTimer];

            // tell iTunes to go to prev track
            [[SynergyController sharedInstance] prevTrack:nil];
        }
        else
        {
            // it was a "click+hold", so tell iTunes to resume
            [[SynergyController sharedInstance] rewindHotKeyReleased];
        }

        // clean up WOButtonState object
        prevButtonState = nil;
    }
#endif
}

- (void)prevButtonExited
{
    // only in the app do we actually do anything
#ifdef SYNERGY_APP_BUILD

    // make sure we have a WOButtonState object
    if (prevButtonState)
    {
        // "prev" menu bar button released; check to see if timer expired
        if ([prevButtonState timerRunning])
        {
            // timer is still running, so this isn't a "click+hold"
            [prevButtonState cancelTimer];

            // tell iTunes to go to prev track
            [[SynergyController sharedInstance] prevTrack:nil];
        }
        else
        {
            // it was a "click+hold", so tell iTunes to resume
            [[SynergyController sharedInstance] rewindHotKeyReleased];
        }

        // clean up WOButtonState object
        prevButtonState = nil;
    }
#endif
}

- (void)prevButtonEntered
{
    // only in the app do we actually do anything
#ifdef SYNERGY_APP_BUILD

    if (prevButtonState)
        prevButtonState = nil;

    // if pressed and held, use same "fast forward" method as "prev" hot key
    prevButtonState =
        [[WOButtonState alloc] initWithTarget:[SynergyController sharedInstance]
                                     selector:@selector(rewindHotKeyPressed)];

#endif
}

- (void) showPlayButton
{


    [playButton setButtonType:NSMomentaryChangeButton];
    [playButton setBordered:NO];
    [playButton setImage:[[self buttonSetId] playImage]];
    [playButton setImagePosition:NSImageOnly];

    [playButton setTarget:self];
    [playButton setAction:@selector(playButtonAction)];


#ifdef SYNERGY_APP_BUILD
    // new code to differentiate mouseUp events inside vs outside button area
    [playButton setIgnoreMouseUpOutsideButton:YES];

    [playButton setPopUpMenu:globalMenu];

#ifdef WO_ENABLE_RIGHT_CLICK_FOR_GLOBAL_MENU
    [playButton setMenu:globalMenu];
#endif

#endif

    [playButton sendActionOn:NSLeftMouseUpMask];

    NSRect playButtonFrame = NSMakeRect([self calculatePlayButtonPosition],
                                        bottomControlPadding,
                                        [[self buttonSetId] playImageSize].width,
                                        controlHotSpotHeight);

    [playButton setFrame:playButtonFrame];

    if ([playButton isDescendantOf:self] == NO)
    {
        [self addSubview:playButton];
    }

#ifdef SYNERGY_APP_BUILD
    [[HotkeyCapableApplication sharedApplication] setNextResponder:playButton];
#endif

}


- (int) calculateControlsStatusItemWidth
{
    // we will adjust size of frame depending which buttons are displayed
    int totalWidth = 0;
    int spacerWidth = [[[WOPreferences sharedInstance] usingMethodGetValueKey:_woButtonSpacingPrefKey] intValue];

    // add initial padding on left hand side:
    totalWidth += leftAndRightControlPadding;

    if ([[[WOPreferences sharedInstance] usingMethodGetValueKey:_woPrevButtonInMenuPrefKey] intValue])
    {
        totalWidth += [[self buttonSetId] prevImageSize].width;
    }

    if ([[[WOPreferences sharedInstance] usingMethodGetValueKey:_woPlayButtonInMenuPrefKey] intValue])
    {
        if (totalWidth == (leftAndRightControlPadding + [[self buttonSetId] prevImageSize].width))
        {  // If already a button to our left, add spacer pixels to total
            totalWidth += spacerWidth;
        }
        totalWidth += [[self buttonSetId] playImageSize].width;
    }

    if ([[[WOPreferences sharedInstance] usingMethodGetValueKey:_woNextButtonInMenuPrefKey] intValue])
    {
        if ((totalWidth == (leftAndRightControlPadding + [[self buttonSetId] prevImageSize].width)) ||
            (totalWidth == (leftAndRightControlPadding + [[self buttonSetId] playImageSize].width)) ||
            (totalWidth == (leftAndRightControlPadding + [[self buttonSetId] prevImageSize].width + spacerWidth + [[self buttonSetId] playImageSize].width)))
        {   // If already a button to our left, add spacer pixels to total
            totalWidth += spacerWidth;
        }
        totalWidth += [[self buttonSetId] nextImageSize].width;
    }

    // add initial padding on right hand side:
    totalWidth += leftAndRightControlPadding;

    return totalWidth;
}

// called by showPlayButton to determine appropriate X-coordinate
- (int) calculatePlayButtonPosition
{
    int returnValue = 0;
    int spacerWidth = [[[WOPreferences sharedInstance] usingMethodGetValueKey:_woButtonSpacingPrefKey] intValue];

    returnValue += leftAndRightControlPadding;

    if ([[[WOPreferences sharedInstance] usingMethodGetValueKey:_woPrevButtonInMenuPrefKey] intValue])
    {
        returnValue += [[self buttonSetId] prevImageSize].width + spacerWidth;
    }

    return returnValue;
}

// called by showNextButton to determine appropriate X-coordinate
- (int) calculateNextButtonPosition
{
    int returnValue = 0;
    int spacerWidth = [[[WOPreferences sharedInstance] usingMethodGetValueKey:_woButtonSpacingPrefKey] intValue];

    returnValue += leftAndRightControlPadding;

    if ([[[WOPreferences sharedInstance] usingMethodGetValueKey:_woPrevButtonInMenuPrefKey] intValue])
    {
        returnValue += [[self buttonSetId] prevImageSize].width + spacerWidth;
    }

    if ([[[WOPreferences sharedInstance] usingMethodGetValueKey:_woPlayButtonInMenuPrefKey] intValue])
    {
        returnValue += [[self buttonSetId] playImageSize].width + spacerWidth;
    }

    return returnValue;
}

- (void) hidePlayButton
{
    if ([playButton isDescendantOf:self])
    {
        [playButton removeFromSuperview];

        // do calculations to resize the WOSynergyView object and the NSStatusItem
        [self resizeSynergyView];
    }
}

- (void) makePlayButtonShowPlayImage
{
    [playButton setImage:[[self buttonSetId] playImage]];

    // notify of need to redraw?
}

- (void) makePlayButtonShowPauseImage
{
    [playButton setImage:[[self buttonSetId] pauseImage]];

    // notify of need to redraw?
}

- (void) makePlayButtonShowStopImage
{
    [playButton setImage:[[self buttonSetId] stopImage]];

    // notify of need to redraw?
}

- (void) makePlayButtonShowPlayPauseImage
{
    [playButton setImage:[[self buttonSetId] playPauseImage]];

    // notify of need to redraw?
}

- (void) playButtonAction
{


    /*

     Note that there is no point in trying to differentiate between mouseDown and mouseUp events here:
     if the user moves the mouse away from the button and THEN releases the mouse button then we won't
     be notified.

     So if we tell iTunes to start playing on the mouseDown, and then hope to update the image on the
     mouseUp, we might never actually update the image! Therefore we have to do it all on the
     mouseDown...

     */

#ifdef SYNERGY_APP_BUILD
    [[SynergyController sharedInstance] playPause:nil];
#endif

#ifdef SYNERGY_PREF_BUILD
    // do nothing
#endif


}

- (void) showPrevButton
{

    // work around an Apple bug: set type to NSMomentaryChangeButton, but don't
    // set an alternateImage;
    // this removes the issue with the background being transposed upwards by
    // one pixel (despite its transparency)
    [prevButton setButtonType:NSMomentaryChangeButton];
    [prevButton setBordered:NO];
    [prevButton setImage:[[self buttonSetId] prevImage]];
    [prevButton setImagePosition:NSImageOnly];
    [prevButton setTarget:self];

    // This one only notifies us on MouseDown (default is only on MouseUp):
    [prevButton sendActionOn:NSLeftMouseDownMask|NSLeftMouseUpMask];
    [prevButton setMouseUpAction:@selector(prevButtonUp)];
    [prevButton setMouseDownAction:@selector(prevButtonDown)];
    [prevButton setMouseExitedAction:@selector(prevButtonExited)];
    [prevButton setMouseEnteredAction:@selector(prevButtonEntered)];

    // There is never a button to the left of the prevButton, so it can make use
    // of constants defined in the WOPreferences.h file.
    NSRect prevButtonFrame = NSMakeRect(leftAndRightControlPadding,
                                        bottomControlPadding,
                                        [[self buttonSetId] prevImageSize].width,
                                        controlHotSpotHeight);
    [prevButton setFrame:prevButtonFrame];

    if ([prevButton isDescendantOf:self] == NO)
        [self addSubview:prevButton];
}

- (void) hidePrevButton
{
    if ([prevButton isDescendantOf:self])
    {
        [prevButton removeFromSuperview];

        // do calculations to resize the WOSynergyView object and the NSStatusItem
        [self resizeSynergyView];
    }
}

- (void) prevButtonAction
{
#ifdef SYNERGY_APP_BUILD
    // only fire the action if building the app
    [[SynergyController sharedInstance] prevTrack:nil];
#endif

}

// repositions buttons and resizes view (for example, when button spacing is
// modified):
- (void) resizeAndRefresh:(int)newButtonSpacing
{

#ifdef SYNERGY_PREF_BUILD
    int previewWidthChange = [self calculateControlsStatusItemWidth];

    // why these constants?
    // in the pref pane... we want our preview to always be 50 pixels from the
    // bottom of the preview subview
    // and 93 pixels is the midpoint of the preview subview

    NSRect controlsPreviewFrameChange =
        NSMakeRect(93 - (previewWidthChange / 2), // ensure view is centred in NSBox
                   50,
                   previewWidthChange,
                   controlViewHeight);
        [self setFrame:controlsPreviewFrameChange];

#endif

    // there should be no need to touch the prev button here because it will
    // always appear two pixels in...

    // if appropriate, display the Play Button at its new position
    if ([[[WOPreferences sharedInstance] usingMethodGetValueKey:_woPlayButtonInMenuPrefKey] boolValue])
    {
        NSRect playButtonFrame = NSMakeRect([self calculatePlayButtonPosition],
                                            bottomControlPadding,
                                            [[self buttonSetId] playImageSize].width,
                                            controlHotSpotHeight);


        [playButton setFrame:playButtonFrame];
    }

    // if appropriate, display the Next Button at its new position
    if ([[[WOPreferences sharedInstance] usingMethodGetValueKey:_woNextButtonInMenuPrefKey] boolValue])
    {
        NSRect nextButtonFrame = NSMakeRect([self calculateNextButtonPosition],
                                            bottomControlPadding,
                                            [[self buttonSetId] nextImageSize].width,
                                            controlHotSpotHeight);


        [nextButton setFrame:nextButtonFrame];
    }

    // how about this:
#ifdef SYNERGY_PREF_BUILD

    [[self superview] setNeedsDisplay:YES];

#endif

    // try this:
    [playButton setNeedsDisplay:YES];
    [prevButton setNeedsDisplay:YES];
    [nextButton setNeedsDisplay:YES];

#ifdef SYNERGY_APP_BUILD
    // this is the old way of doing it that appears to be working well for the
    // Synergy.app

    // calculate overall size of view and resize it
    NSSize menuViewFrameSize = NSMakeSize([self calculateControlsStatusItemWidth],
                                          controlViewHeight);

    [self setFrameSize:menuViewFrameSize];
#endif


#ifdef SYNERGY_PREF_BUILD
    // and this is the new way (copied straight from OrgWincentSynergyPref.m)
    // to hopefully get it working in the prefPane smoothly.

    // calculate the size and location of the view
    int previewWidth = [self calculateControlsStatusItemWidth];

    NSRect controlsPreviewFrame =
        NSMakeRect(93 - (previewWidth / 2), // ensure view is centred in NSBox
                   50,
                   previewWidth,
                   controlViewHeight);


        [self setFrame:controlsPreviewFrame];
#endif

    [self setNeedsDisplay:YES];
}

- (void) resizeSynergyView
{

}

- (void) setPlayPauseTooltip:(NSString *)toolTipString
{
    [playButton setToolTip:toolTipString];
}

- (void) setPrevTooltip:(NSString *)toolTipString
{
    [prevButton setToolTip:toolTipString];
}

- (void) setNextTooltip:(NSString *)toolTipString
{
    [nextButton setToolTip:toolTipString];
}

- (void)setButtonSet:(NSString *)newSet
/*"
 Somewhat more than your average accessor method, this method will switch to a
 new button set if required (the "Standard" button set is loaded at launch).
 The input is an NSString containing the set name: currently only "Standard" and
 "3D" are supported.
"*/
{
    // test to see if the requested set is already loaded
    if ([loadedButtonSets objectForKey:newSet] == nil)
    {
        // if not, load it
        [self addNewButtonSet:newSet];
    }

    // start using that set!

    // update the ivar to reflect the newly selected set
    buttonSet = newSet;

#ifdef SYNERGY_PREF_BUILD
    // this is only necessary in the pref pane version; in the app version,
    // the buttons are refreshed automatically because they are removed and
    // then re-added whenever there is a preferences change

    // tell the buttons which images they should be showing
    [playButton setImage:[[self buttonSetId] playImage]];
    [nextButton setImage:[[self buttonSetId] nextImage]];
    [prevButton setImage:[[self buttonSetId] prevImage]];
#endif

}

// returns the currently active button set
- (NSString *)buttonSet
{
    return buttonSet;
}

- (WOButtonSet *)buttonSetId
{
    // we only have a string identifier for the current button set
    // convert it into a pointer to an actual button set object

    return [loadedButtonSets objectForKey:[self buttonSet]];
}

// adds (loads from disk) another button set to our dictionary
- (void)addNewButtonSet:(NSString *)newSet
{
    // check to see if the button set is already loaded
    if ([loadedButtonSets objectForKey:newSet] == nil)
    {
        // the set is not yet loaded: proceed and load it!
        WOButtonSet *newButtonSet = [[WOButtonSet alloc] initWithButtonSetName:newSet];
        [loadedButtonSets setObject:newButtonSet forKey:newSet];

    }
}

/*

 I am starting again from scratch with the following methods, trying to name
 them extremely clearly so that their purposes are obvious and the flow of
 program execution will be easier to follow!

 Scenarios:
 -------------------------------------------------------------------------------
 1. USER CLICKS BUTTON TO DEACTIVATE PLAY (OR ANY OTHER) BUTTON
 -------------------------------------------------------------------------------
 [self removePlayButton];                   // removes play button from the view
 .|                                         // first ensure that button IS in the view!
 .|
 .\-[self moveNextButton];                  // calls moveNextButton AFTER removing
 .|..|                                      // (only operates if the next button is active)
 .|..|
 .|..\-[self calculateNextButtonPosition];  // which itself calls this method
 .|
 .\-[self resizeViewRectangle];             // the view has shrunk, so resize it
 .
 [self drawRect];                           // and trigger redraw (if necessary)
 [self setNeedsDisplay];                    // I am not sure which (or both) of these to use
 .
 (centre and position view)                 // if called from preference pane
 .
 superview setNeedNeedsDisplay

 -------------------------------------------------------------------------------
 2. USER CLICKS BUTTON TO ACTIVATE PREV (OR ANY OTHER) BUTTON
 -------------------------------------------------------------------------------

 [self addPrevButton];                      // adds prev button to the view
 .|
 .\-[self resizeViewRectangle];             // the view will grow, so resize it
 .|
 .\-[self moveNextButton];                  // calls moveNextButton BEFORE adding
 .|  |
 .|  \-[self calculateNextButtonPosition];
 .|
 .\-[self movePlayButton];                  // called BEFORE adding but AFTER moveNextButton
 .   |
 .   \-[self calculatePlayButtonPosition];
 .
 [self drawRect];                           // and trigger redraw (if necessary)
 [self setNeedsDisplay];                    // I am not sure which (or both) of these to use
 .
 (centre and position view)                 // if called from preference pane
 .                                          // also not sure of ordering here

 -------------------------------------------------------------------------------
 3. APPLICATION LAUNCHES AND DISPLAYS NSStatusItem CONTAINING VIEW IN MENU BAR
 -------------------------------------------------------------------------------
 (read preferences)
 .
 (allocate/instantiate view)
 .
 call [addPrevButton];                      // call these methods if user preferences
 call [addPlayButton];                      // require it; execution flows according to 2.
 call [addNextButton];                      // above

 I do not think I need to call and centering or position methods here because
 that appears to be handle by the NSStatusItem API.

 -------------------------------------------------------------------------------
 4. PREFERENCE PANE LAUNCHES AND DISPLAYS THE VIEW IN THE PREFERENCE PANE
 -------------------------------------------------------------------------------
 (read preferences)
 .
 (allocate/instantiate view)
 .
 call [addPrevButton];                      // call these methods if user preferences
 call [addPlayButton];                      // require it; execution flows according to 2.
 call [addNextButton];                      // above
 .
 [self drawRect];                           // and trigger redraw (if necessary)
 [self setNeedsDisplay];                    // I am not sure which (or both) of these to use
 .
 (centre and position the view)             // can call on the view's frame method here

 These last few parts I am not sure of: the addControl method will call drawRect
 and setNeedsDisplay if necessary. It is unlikely i need to re-do them here, but
 we will see...

 -------------------------------------------------------------------------------
 5. USER MOVES SLIDER TO CONTROL BUTTON SPACING
 -------------------------------------------------------------------------------
 (prefPane slider action called)
 .
 [self updateButtonSpacing];                // does all the work whenever spacing changes
 .|
 When shrinking, do:
 .|
 .\-[self movePrevButton];                  // has no real effect (prev button always same)
 .|
 .\-[self movePlayButton];
 .|
 .\-[self moveNextButton];
 .|
 .\-[self resizeViewRectangle];
 .|
 .\-[[self superview] setNeedNeedsDisplay]; // need this whenever shrinking
 .
 When expanding, do:
 .|
 .\-[self resizeViewRectangle];
 .|
 .\-[self moveNextButton];
 .|
 .\-[self movePlayButton];
 .|
 .\-[self movePrevButton];                  // has no real effect (prev button always same)
 .
 After shrinking, expanding:
 .|
 [self drawRect];                           // and trigger redraw (if necessary)
 [self setNeedsDisplay];                    // I am not sure which (or both) of these to use
 .
 (centre and position the view)             // can call on the view's frame method here

 -------------------------------------------------------------------------------
 6. USER CLICKS A BUTTON (MOUSEDOWN EVENT)
 -------------------------------------------------------------------------------
 [self  drawRect];
 .|
 (Action method in prefPane or app)

 -------------------------------------------------------------------------------
 7. USER RELEASES CLICKED BUTTON (MOUSEUP EVENT)
 -------------------------------------------------------------------------------
 [self drawRect];

 -------------------------------------------------------------------------------
 8. USER SWITCHES TO THE TAB THAT CONTAINS THE VIEW
 -------------------------------------------------------------------------------
 [self drawRect];


 */

- (void)addPrevButton
{
}

- (void)addPlayButton
{
}

- (void)addNextButton
{
}

- (void)removePrevButton
{
}

- (void)removePlayButton
{
}

- (void)removeNextButton
{
}

- (void)movePrevButton
{
}

- (void)movePlayButton
{
}

- (void)moveNextButton
{
}

- (void)resizeViewRectangle
{
}

- (void)updateButtonSpacing
{
}

// accessors
- (void)setGlobalMenu:(NSMenu *)menu
{
    globalMenu = menu;
}

@end
