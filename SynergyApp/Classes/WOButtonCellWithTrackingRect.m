//
//  WOButtonCellWithTrackingRect.m
//  Synergy
//
//  Created by Wincent Colaiuta on Mon Apr 28 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import "WOButtonCellWithTrackingRect.h"

#import "WOButtonState.h"
#import "WODebug.h"

// this is the class that actually does all the work
@implementation WOButtonCellWithTrackingRect

- (id)initTextCell:(NSString *)aString
{
    self = [super initTextCell:aString];
    return self;
}

- (id)initImageCell:(NSImage *)anImage
{
    self = [super initImageCell:anImage];
    return self;
}

- (BOOL)trackMouse:(NSEvent *)theEvent
            inRect:(NSRect)cellFrame
            ofView:(NSView *)controlView
      untilMouseUp:(BOOL)untilMouseUp
{
    int eventMask = (NSLeftMouseUpMask | NSMouseEnteredMask | NSMouseExitedMask);

    woContinueTracking = YES;

    // now run a modal event loop
    if ([self startTrackingAt:[controlView convertPoint:[theEvent locationInWindow] fromView:nil]
                       inView:controlView])
    {
        // track continously
        eventMask = (eventMask | NSLeftMouseDraggedMask);
    }

#ifndef TURN_OFF_WORKAROUND_FOR_APPLE_NSBUTTON_TRACK_MOUSE_BUG

    // unless we ask for MouseDragged events, there is a horrible lag (2 secs)
    // in receiving MouseExited/MouseEntered events
    eventMask = (eventMask | NSLeftMouseDraggedMask);

#endif

    // variables used in modal loop
    BOOL modalLoop = YES;
    BOOL isInside = YES;
    BOOL wasInside = YES;
    NSPoint currentPoint;
    NSPoint lastPoint;

    // set up starting point
    lastPoint = [controlView convertPoint:[theEvent locationInWindow]
                                 fromView:nil];

    while (modalLoop) {

        // I hope this isn't "dangerous". The Cocoa docs suggest using
        // NSEventTrackingRunLoopMode, but that blocks NSTimers from firing,
        // and that in turn stops my WOButtonState object from working. So I
        // have here substituted NSDefaultRunLoopMode and I hope it has no ill
        // effects.
        theEvent = [NSApp nextEventMatchingMask:NSAnyEventMask //eventMask
                                      untilDate:[NSDate distantFuture]
                                         inMode:NSDefaultRunLoopMode //NSEventTrackingRunLoopMode
                                        dequeue:YES];

        currentPoint =
            [controlView convertPoint:[theEvent locationInWindow] fromView:nil];

        isInside = [controlView mouse:currentPoint inRect:[controlView bounds]];

        // kludge-central: trying to stop the activation of the menu from
        // keeping tracking permanently active
        if ([self continueTracking:lastPoint
                                at:currentPoint
                            inView:controlView] == NO)
            modalLoop = NO;

        switch ([theEvent type])
        {
            case NSLeftMouseDragged:

                // only process event if we have been asked to do so
                if (!(eventMask & NSLeftMouseDraggedMask))
                    break;

                // necessary to update highlight on every MouseDragged event
                // otherwise we don't receive timely notification of MouseExited
                // and MouseEntered events!
                [self highlight:isInside
                      withFrame:[controlView bounds]
                         inView:controlView];

                if ([self continueTracking:lastPoint
                                        at:currentPoint
                                    inView:controlView] == NO)
                {
                    // don't track mouse dragged events anymore!
                    eventMask = (eventMask ^ NSLeftMouseDraggedMask);

                    // in fact, let's not track anything at all... (not sure if this is the correct behaviour)
                    goto mouseUp;
                }

                    // big kludge here
                    // this is the only place I can see to reliably replicate the behaviour of
                    // the safari forward/back buttons
                    //
                    // eg. click = action
                    // click+hold = popup menu
                    // click+hold+move outside of button area = stop monitoring for popup menu

                    if ((!isInside) && (popUpMenuStateObject))
                    {
                        // mouse is now outside of the button area, and we have
                        // a WOButtonState object, stop it from firing its timer
                        if ([popUpMenuStateObject timerRunning])
                            [popUpMenuStateObject cancelTimer];
                    }

                    // now, in case we miss the NSMouseExited and NSMouseEntered
                    // events (incredibly likely given my experience with Cocoa)
                    if (isInside && !wasInside)
                    {
                        // now inside, but was outside
                        // therefore we have a mouseEntered event

                        if (eventMask & NSMouseEnteredMask)
                            goto mouseEntered;
                        else
                            // at the very least, remove the highlighting
                            [self highlight:YES
                                  withFrame:[controlView bounds]
                                     inView:controlView];
                    }
                    else if (!isInside && wasInside)
                    {
                        // now outside, but was outside
                        // therefore we have a mouseExited event

                        if (eventMask & NSMouseExitedMask)
                            goto mouseExited;
                        else
                            // at the very least, remove the highlighting
                            [self highlight:NO
                                  withFrame:[controlView bounds]
                                     inView:controlView];
                    }

                    // only problem with the above workaround: what if we
                    // get a mouse dragged event AND an exited/entered event
                    // next time around?
                    // in this case, it is effectively equivalent to
                    // getting two Exited events (or two entered events) in
                    // a row
                    // worst case scenario: the action gets performed twice

                    break;

            case NSMouseExited:

                // only process event if we have been asked to do so
                if (!(eventMask & NSMouseExitedMask))
                    break;

                mouseExited:

                [self highlight:NO
                      withFrame:[controlView bounds]
                         inView:controlView];

                if (untilMouseUp == NO)
                {
                    // must end modal loop now -- WRONG! we continue tracking but we return a different result
                    //modalLoop = NO;
                }

                    // if a mouseExited action is specified, perform it now
                    if (_mouseExitedAction != 0)
                    {
                        [[self target] performSelector:_mouseExitedAction];
                    }

                    break;

            case NSLeftMouseUp:

                mouseUp:

                if (popUpMenuStateObject)
                {
                    // if we have a WOButtonState object, stop it from firing
                    // its timer
                    if ([popUpMenuStateObject timerRunning])
                        [popUpMenuStateObject cancelTimer];
                }

                [self highlight:NO
                      withFrame:[controlView bounds]
                         inView:controlView];

                modalLoop = NO;

                break;

            case NSMouseEntered:

                // only process event if we have been asked to do so
                if (!(eventMask & NSMouseEnteredMask))
                    break;

                mouseEntered:

                [self highlight:YES
                      withFrame:[controlView bounds]
                         inView:controlView];

                // if a mouseEntered action is specified, perform it now
                if (_mouseEnteredAction != 0)
                {
                    [[self target] performSelector:_mouseEnteredAction];
                }

                    break;

            default:
                // ignore any other kind of event
                break;
        }


        lastPoint = currentPoint;
        wasInside = isInside;

    }; // end while (modalLoop)

    [self stopTracking:lastPoint
                at:currentPoint
            inView:controlView
         mouseIsUp:YES];

    if (untilMouseUp)
    {
        // always return YES (mouse is up)
        return YES;
    }
    else
    {
        if (isInside)
        {
            // return YES if tracking ended due to mouseUp
            return YES;
        }
        else
        {
            // return NO if tracking ended due to leaving button bounds
            return NO;
        }
    }
}

- (BOOL)startTrackingAt:(NSPoint)startPoint inView:(NSView *)controlView
{
    [self highlight:YES withFrame:[controlView bounds] inView:controlView];

    return NO;
}

- (BOOL)continueTracking:(NSPoint)lastPoint
                      at:(NSPoint)currentPoint
                  inView:(NSView *)controlView
{
    return woContinueTracking;
}

// provide a means by which a firing WOButtonState object can tell us to stop
// tracking
- (void)setContinueTracking:(BOOL)continueTracking
{
    woContinueTracking = continueTracking;
}

- (void)setPopUpMenuStateObject:(WOButtonState *)stateObject
{
    popUpMenuStateObject = stateObject;
}

- (void)stopTracking:(NSPoint)lastPoint
                  at:(NSPoint)stopPoint
              inView:(NSView *)controlView
           mouseIsUp:(BOOL)flag
{
    [self highlight:NO withFrame:[controlView bounds] inView:controlView];
}

// accessors

- (void)setMouseEnteredAction:(SEL)selector
{
    _mouseEnteredAction = selector;
}

- (void)setMouseExitedAction:(SEL)selector
{
    _mouseExitedAction = selector;
}

@end

/*"

Notes on implementation

These notes are based on my efforts to get the menu bar control buttons in
Synergy to behave in the desired fashion. The default NSButton class did not
appear to have the required behaviour.

Initial design:

Each control is an NSButton.
NSButton inherits from NSControl, NSView, NSResponder and finally NSObject.
Each NSButton uses an NSButtonCell.
NSButtonCell inherits from NSActionCell, NSCell and NSObject.
All buttons appear in a superview of my own design, WOSynergyView, which in
turn sits in an NSStatusBarWindow.

Inheritance/placement diagram:

NSObject
..NSResponder
....NSView
......NSControl
........NSButton

NSObject
..NSCell
....NSActionCell
......NSButtonCell

NSButton --superview--> WOSynergyView --superview--> NSNextStepFrame
NSButton  --window-->   NSStatusBarWindow
WOSynergyView   --window-->   NSStatusBarWindow

Problems with initial design:

If I use NSControl's sendActionOn: method to specify that I wish the action to
be triggered on both mouseUp (the default) and mouseDown events, then the action
is indeed triggered, but the mouseUp method (defined in NSView) is not always
called. In fact, the following occurs:

1. mouseDown method is always called on mouseDown.
2. mouseUp method is only called if button is clicked very rapidly.
3. When mouseUp method is called in my button, it is ALSO called in the
superview (WOSynergyView). (In other words, they both or neither appear, never
                            just one)
4. The action is always sent on mouseDown, but only sent on mouseUp if the
mouseUp event occurs when the pointer is inside the button area; this (correct)
behaviour occurs regardless of whether or not the (incorrect) behaviour of
calling/not-calling the mouseUp method is occurring.

In addition, every mouseDown event inside the view causes the SystemUI server
to go into "menu bar is active" mode. So, click once on a button in the
NSStatusItem, and then move the mouse towards any NSMenuExtras. Their menus will
be active. (Note that any NSStatusItem's menus will NOT be active). Conversely,
click twice in the NSStatusItem and the NSMenuExtras will NOT be active.

This suggests a possible workaround of simulating two click events to trick
the SystemUI server into not make the menu bar active.

Related behaviours that are inconsistent: click on an NSMenuExtra and it will
not make the menu bar active for NSStatusItems, only for NSMenuExtras; click on
either an NSMenuExtra or an NSStatusItem and the left end of the menu bar will
not become active.

New design:

As above, except NSButton is subclassed to produce WOButtonWithTrackingRect.
Similarly, NSButtonCell is subclassed to produce WOButtonCellWithTrackingRect.

Calling [super mouseDown:theEvent] or [super mouseUp:theEvent] in the subclass
only replicates the buggy behaviour of the superclass, so the mouseDown: and
mouseUp: methods are reimplimented from scratch.

Two key distinctions of the subclass: mouseUp events are ALWAYS received, even
if the mouseUp event occurs outside of the button area; duplicate mouseUp events
are NOT sent to the superview.

The custom class respects the "sendActionOn" settings specified by the
programmer, but with the possibility of specifying distinct actions for each
operation (mouseUp and mouseDown).

It would also be possible for the programmer to just use one method and
differenatiate between mouseUp and mouseDown by using NSApp's currentEvent
method.

Tracking Rectangles in the new design:

Problems with tracking rectangles when implemented from an NSButton subclass:
- there is a massive (two second) lag between entering/exiting and receiving
    the corresponding event
- it is possible to exit then re-enter (or conversely, enter then re-exit) the
    area and miss both events
- these problems do not appear to manifested in a direct subclass of NSView
- attempting to run a modal event loop in the mouseDown method of the NSButton
    subclass does not work either; the lag is still present
- overriding startTrackingAt, continueTracking and stopTracking in the
    NSButtonCell subclass fails also; these methods are only called if I include
    the NSButton version of mouseDown.
- setting showsBorderOnlyWhileMouseInside to YES and implementing mouseEntered
    and mouseExited methods in the NSButtonCell subclass proves that entered
    and exited events can be received instantaneously, but as soon as the
    mouse button is pressed down, the lag effect appears again and events can
    arrive late or not at all
- this issue is not particular to the NSStatusItem implementation, but also
    manifests when the view is in a normal window (such as in the Synergy
                                                   prefPane)
- allowing button to become first responder does not remedy the issue, and
    is not a viable work-around anyway (steals focus from frontmost app)
- it makes no difference whether the modal event loop retrieves the next event
    from the window, or from the NSApp object

What happens if we revert to super implementation of mouseUp and mouseDown?

- trackMouse and startTracking get called
- each time mouse re-enters area, those two get called
- nothing called when leaves the area (but cell does "un-highlight")
- action called if release mouse button inside cell area, but not outside
- continue to get old behaviour of mouseUp events only on ultra-fast clicks!

This is not suitable for an app like Synergy, beccause there are two goals:

1. Make it so click+hold can drop down a menu. For this to work, we need to be
able to differentiate between click+hold and click+release, and if we are losing
mouseUp events we can't do that
2. Duplicate functionality of iTunes "next" button. This means click+release
    results in a skip track operation; click+hold equals scrub; leave button
    area equals resume playback; re-enter button area equals resume scrub. So,
for this, I need to know both entry and exit events (so far I only have entry).

    Solution --

    Reimplement everything from scratch. Works. In order to prevent the buggy
NSButton behaviour from re-emerging, must do the following -

- ensure that the continueTracking method always returns YES
- make sure that MouseDragged events are included in the modal run loop
- update the "highlight" setting every time a MouseDragged event is received

"*/
