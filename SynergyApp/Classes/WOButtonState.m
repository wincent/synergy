// WOButtonState.m
// Synergy
//
// Copyright 2003-present Greg Hurrell. All rights reserved.

#import "WOButtonState.h"
#import "WODebug.h"

// private methods

@interface WOButtonState (_private)

- (void)_timerDone:(NSTimer *)timer;

@end

@implementation WOButtonState
/*"
A simple class for interacting with a "hot key" or button combination. At
 present, it only tracks whether the button(s) have been pressed and released,
 or pressed and held. It maintains a timer so that the released/held status can
 be determined.

 The life cycle of a WOButtonState object begins when a button down event is
 received. At this point the object is created and a user-definable timer is
 started ticking.

 Two possible events then occur: either the timer fires, in which case the
 appropriate action is triggered; or the button is released before the timer
 fires, in which case again the appropriate action can be triggered.

 Example scenario:

 User presses "Next" hot key. New WOButtonState object created with appropriate
 timer value, and an action event (an object and selector to perform on that
                                   object).

 Timer fires: action event is triggered.

 or, if timer doesn't fire, alternative action event is triggered when button
 is finally released.

 "*/

// master init method
- (id)initWithTimer:(float)timerValue
             target:(id)targetObject
           selector:(SEL)selectorInTarget
            repeats:(BOOL)repeats
{
    // do basic initialisation in super
    self = [super init];

    // set up the target object and selector that will be used if the timer
    // exits
    _target     = targetObject;
    _selector   = selectorInTarget;

    // initialise the timer
    _buttonDownTimer =
        [NSTimer scheduledTimerWithTimeInterval:timerValue
                                         target:self
                                       selector:@selector(_timerDone:)
                                       userInfo:nil
                                        repeats:repeats];
    // adjust ivar to show that we're running
    _timerRunning = YES;

    // and whether or not we are repeating
    _repeats = repeats;

    return self;
}

// init with a repeating timer
- (id)initWithRepeatingTimer:(float)timerValue
                      target:(id)targetObject
                    selector:(SEL)selectorInTarget
{
    return [self initWithTimer:timerValue
                        target:targetObject
                      selector:selectorInTarget
                       repeats:YES];
}

// init with a non-repeating timer
- (id)initWithTimer:(float)timerValue
             target:(id)targetObject
           selector:(SEL)selectorInTarget
/*"
    Initialises the object ready for use; if the timer value is exceeded, the
 button is deemed to be "clicked+held", and so the selector is performed on the
 supplied object.
"*/
{
    return [self initWithTimer:timerValue
                        target:targetObject
                      selector:selectorInTarget
                       repeats:NO];
}

// most basic form: init with non-repeating timer, default time interval
- (id)initWithTarget:(id)targetObject
            selector:(SEL)selectorInTarget
{
    return [self initWithTimer:WO_BUTTON_STATE_DEFAULT_TIMER
                        target:targetObject
                      selector:selectorInTarget
                       repeats:NO];
}

- (void)finalize
{
    // finalize may be too late for this
    // stop timer if it is still running
    [self cancelTimer];
    [super finalize];
}

- (void)_timerDone:(NSTimer *)timer
/*"
Called if the timer fires (in which case we have a "click+hold" event).
"*/
{
    if(_repeats == NO)
    {
        // update instance ivar
        _timerRunning = NO;

        // timer is already invalidated
        _buttonDownTimer = nil;
    }

    // initiate appropriate action
    [_target performSelector:_selector];
}

- (void)cancelTimer
{
    // stop timer if it is still running
    if (_buttonDownTimer)
    {
        [_buttonDownTimer invalidate];
        _buttonDownTimer = nil;
    }
}

- (BOOL)timerRunning
{
    return _timerRunning;
}

@end
