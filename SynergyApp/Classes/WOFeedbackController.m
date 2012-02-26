//
//  WOFeedbackController.m
//  Synergy
//
//  Created by Wincent Colaiuta on Sat Jan 25 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import "WOFeedbackController.h"
#import "WOFeedbackWindow.h"
#import "WODebug.h"

#import "WOFeedbackDefaults.h"

@implementation WOFeedbackController

- (void)awakeFromNib
{
    // set these to safe starting values
    fadeTimer = nil;
    delayedFadeTimer = nil;

    // set reasonable defaults
    [self setWindowLateralOffset:FEEDBACK_LATERAL_OFFSET_FROM_MIDDLE];
    [self setWindowVerticalInset:FEEDBACK_VERTICAL_INSET_FROM_BOTTOM];
    [self setWindowWidth:FEEDBACK_WIDTH];
    [self setWindowHeight:FEEDBACK_HEIGHT];
    [self setCornerRadius:FEEDBACK_CORNER_RADIUS];
    [self setBarSegments:FEEDBACK_BAR_SEGMENTS];
    [self setBarLateralOffset:FEEDBACK_BAR_LATERAL_OFFSET_FROM_MIDDLE];
    [self setBarVerticalInset:FEEDBACK_BAR_VERTICAL_INSET_FROM_BOTTOM];
    [self setBarSegmentWidth:FEEDBACK_BAR_SEGMENT_WIDTH];
    [self setBarSegmentHeight:FEEDBACK_BAR_SEGMENT_HEIGHT];
    [self setBarSegmentGap:FEEDBACK_BAR_SEGMENT_GAP];
    [self setViewBackgroundAlpha:FEEDBACK_BACKGROUND_ALPHA];
    [self setEnabledSegments:FEEDBACK_BAR_ENABLED_SEGMENTS];
    [self setBarEnabled:FEEDBACK_BAR_ENABLED];

    // set up window to suit screen geometry
    [self applicationDidChangeScreenParameters:nil];
}

- (void)applicationDidChangeScreenParameters:(NSNotification *)aNotification
{
    // make window bounds equal that which we desire (don't trust IB)
    NSRect windowRect;

    // find out screen dimensions of screen with menu bar on it
    NSRect screen = [[[NSScreen screens] objectAtIndex:0] frame];

    // origin is to the left of the screen centre-line
    float xOrigin = (floor(screen.size.width / 2) -
                     FEEDBACK_LATERAL_OFFSET_FROM_MIDDLE);

    windowRect.origin =
        NSMakePoint(xOrigin, FEEDBACK_VERTICAL_INSET_FROM_BOTTOM);

    windowRect.size = NSMakeSize(FEEDBACK_WIDTH, FEEDBACK_HEIGHT);

    // this will resize the view as well because of the auto-size settings in IB
    [feedbackWindow setFrame:windowRect
                     display:NO
                     animate:NO];
}

// methods related to fading

// cancel any running fades, and show window at full alpha
- (void)showAtFullAlpha
{
    [self stopFadeTimer];

    [self stopDelayedFadeTimer];

    [feedbackWindow orderFront:self];

    [feedbackWindow setAlphaValue:1.0];

    [feedbackWindow display];
}

- (void)fadeWindowOut
{
    // stop any existing fade timers
    [self stopFadeTimer];
    [self stopDelayedFadeTimer];

    // set up a new timer
    fadeTimer = [NSTimer scheduledTimerWithTimeInterval:FEEDBACK_FADE_INTERVAL
                                                 target:self
                                               selector:@selector(fadeOutStep:)
                                               userInfo:nil
                                                repeats:YES];
}

- (void)fadeOutStep:(NSTimer *)theTimer
{
    float currentAlpha = [feedbackWindow alphaValue];
    float newAlpha = (currentAlpha - 0.05);

    if (newAlpha < 0)
    {
        // the fade is over
        [self stopFadeTimer];

        // and in case this one is still hanging around, by some odd chance
        [self stopDelayedFadeTimer];

        [feedbackWindow setAlphaValue:0];

        // remove the window from the screen
        [feedbackWindow orderOut:self];
    }
    else
    {
        [feedbackWindow setAlphaValue:newAlpha];
    }

    [feedbackWindow display];
}

- (void)stopFadeTimer
{
    // make sure timer is actually running before trying to clean up
    if (fadeTimer)
    {
        if ([fadeTimer isValid])
            [fadeTimer invalidate];
        fadeTimer = nil;
    }
}

// sets up a delayed fade out
- (void)delayedFadeOut
{
    // stop any delayed fade which might already be set up
    [self stopDelayedFadeTimer];

    delayedFadeTimer =
        [NSTimer scheduledTimerWithTimeInterval:FEEDBACK_DURATION
                                         target:self
                                       selector:@selector(delayedFadeOutStart:)
                                       userInfo:nil
                                        repeats:NO];
}

// once the delay has passed, begin the actual fade out
- (void)delayedFadeOutStart:(NSTimer *)theTimer
{
    // let the fadeWindowOut method do the actual work
    [self fadeWindowOut];
}

- (void)stopDelayedFadeTimer
{
    // make sure timer exists before trying to clean up
    if (delayedFadeTimer)
    {
        // if timer has fired, it will already be invalidated
        if ([delayedFadeTimer isValid])
            [delayedFadeTimer invalidate];
        delayedFadeTimer = nil;
    }
}

// window wrapper methods (messages will be forwarded to feedbackWindow)

- (void)windowOrderOut:(id)sender
{
    [feedbackWindow orderOut:sender];
}

- (void)windowOrderFront:(id)sender
{
    [feedbackWindow orderFront:sender];
}

- (void)windowSetAlpha:(float)newAlpha
{
    [feedbackWindow setAlphaValue:newAlpha];
}

- (float)windowAlpha
{
    return [feedbackWindow alphaValue];
}

// accessor methods, many of these are just "wrapper" methods which pass
// messages on to the appropriate objects

// many of these not implemented!

- (void)setWindowLateralOffset:(float)newValue
{

}

- (void)setWindowVerticalInset:(float)newValue
{

}

- (void)setWindowWidth:(float)newValue
{

}

- (void)setWindowHeight:(float)newValue
{

}

- (void)setCornerRadius:(float)newValue
{
    [feedbackView setCornerRadius:newValue];
}

- (void)setBarSegments:(float)newValue
{

}

- (void)setBarLateralOffset:(float)newValue
{

}

- (float)barVerticalInset
{
    return [feedbackView barOrigin];
}

- (void)setBarVerticalInset:(float)newValue
{
    [feedbackView setBarOrigin:newValue];
}

- (void)setBarSegmentWidth:(float)newValue
{

}

- (void)setBarSegmentHeight:(float)newValue
{

}

- (void)setBarSegmentGap:(float)newValue
{

}

- (float)viewBackgroundAlpha
{
    return [feedbackView backgroundAlpha];
}

- (void)setViewBackgroundAlpha:(float)newValue
{
    [feedbackView setBackgroundAlpha:newValue];
}

- (int)enabledSegments
{
    return [feedbackView enabledSegments];
}

- (void)setEnabledSegments:(int)newValue
{
    [feedbackView setEnabledSegments:newValue];
}

- (BOOL)barEnabled
{
    return [feedbackView barEnabled];
}

- (void)setBarEnabled:(BOOL)newValue
{
    [feedbackView setBarEnabled:newValue];
}

- (BOOL)starBarEnabled
{
    return [feedbackView starBarEnabled];
}

- (void)setStarBarEnabled:(BOOL)newValue
{
    [feedbackView setStarBarEnabled:newValue];
}

- (int)enabledStars
{
    return [feedbackView enabledStars];
}

- (void)setEnabledStars:(int)newValue
{
    [feedbackView setEnabledStars:newValue];
}

- (WOFeedbackIconType)iconType
{
    return [feedbackView iconType];
}

- (void)setIconType:(WOFeedbackIconType)newIconType
{
    [feedbackView setIconType:newIconType];
}

@end
