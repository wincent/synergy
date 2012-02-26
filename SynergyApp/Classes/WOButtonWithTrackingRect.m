//
//  WOButtonWithTrackingRect.m
//  Synergy
//
//  Created by Wincent Colaiuta on Thu Mar 13 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import "WOButtonWithTrackingRect.h"
#import "WOButtonCellWithTrackingRect.h"
#import "WOButtonState.h"
#import "WODebug.h"

@implementation WOButtonWithTrackingRect
/*"
A simple subclass of NSButton that includes a tracking rect implementation and
 overrides the mouseEntered: and mouseExited: methods.

 This can be used as a drop-in replacement for NSButton, the only difference is
 that because of the tracking rectangle, the button will be notified of
 mouseEntered and mouseExited events. Distinct actions can be set for each
 of these events.

 Actions are sent to the object as defined using NSButton's setTarget: method

 It is also possible to differentiate between mouseUp and mouseDown events, and
 perform a separate action for each. If no specific methods are specified, then
 the default behaviour of NSButton is followed.

 Note that mouseUp events are not received if the mouse is released outside of
 the button area (although it is possible to do this)!

 The actual work is really done by WOButtonCellWithTrackingRect, a subclass of
 NSButtonCell.

 "*/

// ensure that we use the right type of class for our cell
+ (Class)cellClass
{
    return [WOButtonCellWithTrackingRect class];
}

- (id)init
{
    self = [super init];
    return self;
}

- (BOOL)acceptsFirstResponder
{
    return NO;
}

- (void)setIgnoreMouseUpOutsideButton:(BOOL)ignores
{
    ignoreMouseUpOutsideButton = ignores;
}

- (void)mouseDown:(NSEvent *)theEvent
{
    // get status of "sendActionOn"
    int sendActionOn = [self sendActionOn:NSLeftMouseUpMask];

    // only perform action if we are told to send on mouseDown
    if (sendActionOn & NSLeftMouseDownMask)
    {
        // check if NSButton's "action" has been overriden
        if (_mouseDownAction != 0)
        {
            // optional selector will be peformed

            [[self target] performSelector:_mouseDownAction];
        }
        else
        {
            // standard selector will be performed

            [[self target] performSelector:[self action]];
        }
    }

    // start tracking the mouse
    BOOL mouseUpResult;

    if (ignoreMouseUpOutsideButton)
    {
        mouseUpResult = [[self cell] trackMouse:theEvent
                                              inRect:[self bounds]
                                              ofView:self
                                        untilMouseUp:NO];
        // report mouseUp only if it is inside button
        // returns YES if mouseUp inside button, NO if not inside button
    }
    else
    {
        mouseUpResult = [[self cell] trackMouse:theEvent
                                              inRect:[self bounds]
                                              ofView:self
                                        untilMouseUp:YES];
        // report mouseUp even if it is outside button
        // should return YES when the mouse goes up, regardless of whether it is
        // inside the button area; should never return NO

        if (!mouseUpResult)
            ELOG(@"Warning: didn't receive mouseUp!");
    }

    // a refinement of this class would differentiate between mouseUp events
    // on the basis of whether they occurred inside or outside button area

    // only perform action if we are told to send on mouseUp AND we got the
    // mouseUp!
    if ((sendActionOn & NSLeftMouseUpMask) &&
        (mouseUpResult))
    {
        // check if NSButton's "action" has been overriden
        if (_mouseUpAction != 0)
        {
            // optional selector will be performed

            [[self target] performSelector:_mouseUpAction];
        }
        else
        {
            // standard selector will be performed

            [[self target] performSelector:[self action]];
        }
    }

    // reset "sendActionOn" to prior status
    [self sendActionOn:sendActionOn];
}

// accessors

- (void)setMouseUpAction:(SEL)selector
{
    _mouseUpAction = selector;
}

- (void)setMouseDownAction:(SEL)selector
{
    _mouseDownAction = selector;
}

- (void)setMouseEnteredAction:(SEL)selector
{
    // update ivar
    _mouseEnteredAction = selector;

    // forward to cell
    [[self cell] setMouseEnteredAction:selector];
}

- (void)setMouseExitedAction:(SEL)selector
{
    // update ivar
    _mouseExitedAction = selector;

    // forward to cell
    [[self cell] setMouseExitedAction:selector];
}

- (SEL)mouseUpAction
{
    return _mouseUpAction;
}

- (SEL)mouseDownAction
{
    return _mouseDownAction;
}

- (SEL)mouseEnteredAction
{
    return _mouseEnteredAction;
}

- (SEL)mouseExitedAction
{
    return _mouseExitedAction;
}

@end

