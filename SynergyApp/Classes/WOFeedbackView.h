//
//  WOFeedbackView.h
//  Synergy
//
//  Created by Greg Hurrell on Sat Jan 25 2003.
//  Copyright 2003-present Greg Hurrell.

#import <AppKit/AppKit.h>

typedef enum WOFeedbackIconType {

    WOFeedbackVolumeIcon      = 0,
    WOFeedbackPrevIcon        = 1,
    WOFeedbackPlayIcon        = 2,
    WOFeedbackPauseIcon       = 3,
    WOFeedbackNextIcon        = 4,
    WOFeedbackPlayPauseIcon   = 5, // added more here:
    WOFeedbackShuffleOnIcon   = 6,
    WOFeedbackShuffleOffIcon  = 7,
    WOFeedbackRepeatOneIcon   = 8,
    WOFeedbackRepeatAllIcon   = 9,
    WOFeedbackRepeatOffIcon   = 10

} WOFeedbackIconType;

@interface WOFeedbackView : NSView {

    // pointers to our icon images
    NSImage             *volumeImage;
    NSImage             *prevFeedbackImage;
    NSImage             *nextFeedbackImage;
    NSImage             *playFeedbackImage;
    NSImage             *pauseFeedbackImage;
    NSImage             *playPauseFeedbackImage;

    NSImage             *shuffleOnImage;
    NSImage             *shuffleOffImage;
    NSImage             *repeatOneImage;
    NSImage             *repeatAllImage;
    NSImage             *repeatOffImage;

    // background for the bar segments
    NSImage             *barsImage;

    // for the bar
    float               barOrigin;

    // number of enabled (lit) segments
    int                 enabledSegments;

    // for the rounded corners in the view
    float               cornerRadius;

    // alpha level for transparent background
    float               backgroundAlpha;

    // YES if we are to draw the segmented bar
    BOOL                barEnabled;

    // YES if we are to draw the star bar
    BOOL                starBarEnabled;

    // number of enabled (lit) stars
    int                 enabledStars;

    // the kind of icon we'll show
    WOFeedbackIconType  iconType;
}

// methods taken from WOSynergyAnchorView and modified (for updating the view)
- (void)clearView;
- (void)drawBackground;
- (void)drawIcon:(NSImage *)theIcon;

// other methods for updating the view
- (void)drawBar;
- (void)drawStarBar;

#pragma mark -
#pragma mark Accessors

- (float)barOrigin;
- (void)setBarOrigin:(float)newValue;

- (float)cornerRadius;
- (void)setCornerRadius:(float)newValue;

- (float)backgroundAlpha;
- (void)setBackgroundAlpha:(float)newValue;

- (BOOL)barEnabled;
- (void)setBarEnabled:(BOOL)newValue;

- (int)enabledSegments;
- (void)setEnabledSegments:(int)newValue;

- (BOOL)starBarEnabled;
- (void)setStarBarEnabled:(BOOL)newValue;

- (int)enabledStars;
- (void)setEnabledStars:(int)newValue;

- (WOFeedbackIconType)iconType;
- (void)setIconType:(WOFeedbackIconType)newIconType;

@end
