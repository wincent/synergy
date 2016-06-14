//
//  WOButtonState.h
//  Synergy
//
//  Created by Greg Hurrell on Wed Mar 12 2003.
//  Copyright 2003-present Greg Hurrell.

#import <Foundation/Foundation.h>

// default timer value for differentiating between a "click+hold" and a "click"
#define WO_BUTTON_STATE_DEFAULT_TIMER 0.30

@interface WOButtonState : NSObject {

@private
    // named "_buttonDownTimer" because it starts counting on button down
    NSTimer *_buttonDownTimer;
    BOOL    _timerRunning;
    BOOL    _repeats;

    // selector performed on target object in the event of a "click+hold" event
    id      _target;
    SEL     _selector;
}

// creating WOButtonState objects

// master init method
- (id)initWithTimer:(float)timerValue
             target:(id)targetObject
           selector:(SEL)selectorInTarget
            repeats:(BOOL)repeats;

// init with a repeating timer
- (id)initWithRepeatingTimer:(float)timerValue
                      target:(id)targetObject
                    selector:(SEL)selectorInTarget;

// init with a non-repeating timer
- (id)initWithTimer:(float)timerValue
             target:(id)targetObject
           selector:(SEL)selectorInTarget;

 // most basic form: init with non-repeating timer, default time interval
- (id)initWithTarget:(id)targetObject
            selector:(SEL)selectorInTarget;

// controlling the timer

- (void)cancelTimer;

// querying the state of the button

- (BOOL)timerRunning;

@end
