//
//  NSTimer+WOPausable.h
//  Synergy
//
//  Created by Greg Hurrell on 7 November 2006.
//  Copyright 2006-present Greg Hurrell.

#import <Cocoa/Cocoa.h>

//@interface WOPausableTimer : NSTimer {
@interface NSTimer (WOPausable)

//! Pauses the receiver.
//!
//! Each pause message increments a counter and each resume message decrements that counter.
//! If the receiver is invalid, has no effect.
//!
- (void)pause;

//! Resumes the receiver.
//!
//! Each pause message increments a counter and each resume message decrements that counter; when the counter returns to zero the receiver is resumed.
//! If the receiver is invalid, has no effect.
//!
//! \warn the caller must balance pause and receive calls in order to automatically clean up state; otherwise must call the cancel method to manually clean up state
- (void)resume;

//! Returns YES if the timer is valid but paused, otherwise returns NO.
- (BOOL)isPaused;

//! If the receiver is valid calls invalidate and then cleans up internal state information; otherwise just cleans up internal state information.
- (void)cancel;

@end
