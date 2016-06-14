//
//  WOFeedbackController.h
//  Synergy
//
//  Created by Greg Hurrell on Sat Jan 25 2003.
//  Copyright 2003-present Greg Hurrell.

#import <Cocoa/Cocoa.h>

// necessary for typedef of WOFeedbackIconType
#import "WOFeedbackView.h"

@class WOFeedbackWindow;

@interface WOFeedbackController : NSObject {

    // ivars for communicating with other objects (hooked up in IB)
    IBOutlet WOFeedbackView     *feedbackView;

    IBOutlet WOFeedbackWindow   *feedbackWindow;

    // for managing fade outs
    NSTimer                     *fadeTimer;

    NSTimer                     *delayedFadeTimer;

    // ivars for controlling the appearance of the feedback window

    // left edge is this many pixels from the middle of the screen
    float                       windowLateralOffset;

    // bottom edge is this many pixels from the bottom of the screen (Dock ignored)
    float                       windowVerticalInset;

    // feedback window is this many pixels wide
    float                       windowWidth;

    // feedback window is this many pixels high
    float                       windowHeight;

    // corner radius on feedback window in pixels
    float                       cornerRadius;

    // number of segments in the feedback bar (if any)
    float                       barSegments;

    // feedback bar begins this many pixels to the left of the middle of the screen
    float                       barLateralOffset;

    // feedback bar is this many pixels from the bottom of the screen (Dock ignored)
    float                       barVerticalInset;

    // each segment of feedback bar is this many pixels wide
    float                       barSegmentWidth;

    // each segment of feedback bar is this many pixels high
    float                       barSegmentHeight;

    // add this many pixels to get from end of one segment to beginning of next
    float                       barSegmentGap;

    // window background alpha
    float                       viewBackgroundAlpha;

    // other ivars

    // number of segments currently "enabled"
    int                         enabledSegments;
}

// methods related to fading

// cancel any running fades, and show window at full alpha
- (void)showAtFullAlpha;

- (void)fadeWindowOut;

- (void)fadeOutStep:(NSTimer *)theTimer;

- (void)stopFadeTimer;

// sets up a delayed fade out
- (void)delayedFadeOut;

// once the delay has passed, begin the actual fade out
- (void)delayedFadeOutStart:(NSTimer *)theTimer;

- (void)stopDelayedFadeTimer;

// window wrapper methods (messages will be forwarded to feedbackWindow)

- (void)windowOrderOut:(id)sender;
- (void)windowOrderFront:(id)sender;

- (void)windowSetAlpha:(float)newAlpha;
- (float)windowAlpha;

- (void)applicationDidChangeScreenParameters:(NSNotification *)aNotification;

// accessor methods

//- (float)windowLateralOffset;
- (void)setWindowLateralOffset:(float)newValue;

//- (float)windowVerticalInset;
- (void)setWindowVerticalInset:(float)newValue;

//- (float)windowWidth;
- (void)setWindowWidth:(float)newValue;

//- (float)windowHeight;
- (void)setWindowHeight:(float)newValue;

//- (float)cornerRadius;
- (void)setCornerRadius:(float)newValue;

//- (float)barSegments;
- (void)setBarSegments:(float)newValue;

//- (float)barLateralOffset;
- (void)setBarLateralOffset:(float)newValue;

- (float)barVerticalInset;
- (void)setBarVerticalInset:(float)newValue;

//- (float)barSegmentWidth;
- (void)setBarSegmentWidth:(float)newValue;

//- (float)barSegmentHeight;
- (void)setBarSegmentHeight:(float)newValue;

//- (float)barSegmentGap;
- (void)setBarSegmentGap:(float)newValue;

- (float)viewBackgroundAlpha;
- (void)setViewBackgroundAlpha:(float)newValue;

- (int)enabledSegments;
- (void)setEnabledSegments:(int)newValue;

- (BOOL)barEnabled;
- (void)setBarEnabled:(BOOL)newValue;

- (BOOL)starBarEnabled;
- (void)setStarBarEnabled:(BOOL)newValue;

- (int)enabledStars;
- (void)setEnabledStars:(int)newValue;

- (WOFeedbackIconType)iconType;
- (void)setIconType:(WOFeedbackIconType)newIconType;

@end
