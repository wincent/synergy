// WOFeedbackView.m
// Synergy
//
// Copyright 2003-present Greg Hurrell. All rights reserved.

#import "WOFeedbackView.h"

#import "WOFeedbackDefaults.h"

#import "WORoundedRect.h"
#import "WOSynergyGlobal.h"
#import "WODebug.h"

@implementation WOFeedbackView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
    // load images from bundle in a prefPane-friendly way
    volumeImage = [[NSImage alloc] initByReferencingFile:
        [[NSBundle bundleForClass:[self class]] pathForResource:@"volume"
                                                         ofType:@"png"]];

    prevFeedbackImage = [[NSImage alloc] initByReferencingFile:
        [[NSBundle bundleForClass:[self class]] pathForResource:@"prevFeedback"
                                                         ofType:@"png"]];

    nextFeedbackImage = [[NSImage alloc] initByReferencingFile:
        [[NSBundle bundleForClass:[self class]] pathForResource:@"nextFeedback"
                                                         ofType:@"png"]];

    playFeedbackImage = [[NSImage alloc] initByReferencingFile:
        [[NSBundle bundleForClass:[self class]] pathForResource:@"playFeedback"
                                                         ofType:@"png"]];

    pauseFeedbackImage = [[NSImage alloc] initByReferencingFile:
        [[NSBundle bundleForClass:[self class]] pathForResource:@"pauseFeedback"
                                                         ofType:@"png"]];

    playPauseFeedbackImage = [[NSImage alloc] initByReferencingFile:
        [[NSBundle bundleForClass:[self class]] pathForResource:@"playPauseFeedback"
                                                         ofType:@"png"]];

    barsImage = [[NSImage alloc] initByReferencingFile:
        [[NSBundle bundleForClass:[self class]] pathForResource:@"bars"
                                                         ofType:@"png"]];

    shuffleOnImage = [[NSImage alloc] initByReferencingFile:
        [[NSBundle bundleForClass:[self class]] pathForResource:@"shuffleOn"
                                                         ofType:@"png"]];

    shuffleOffImage = [[NSImage alloc] initByReferencingFile:
        [[NSBundle bundleForClass:[self class]] pathForResource:@"shuffleOff"
                                                         ofType:@"png"]];

    repeatOneImage = [[NSImage alloc] initByReferencingFile:
        [[NSBundle bundleForClass:[self class]] pathForResource:@"repeatOne"
                                                         ofType:@"png"]];

    repeatAllImage = [[NSImage alloc] initByReferencingFile:
        [[NSBundle bundleForClass:[self class]] pathForResource:@"repeatAll"
                                                         ofType:@"png"]];

    repeatOffImage = [[NSImage alloc] initByReferencingFile:
        [[NSBundle bundleForClass:[self class]] pathForResource:@"repeatOff"
                                                         ofType:@"png"]];


    // cause Quartz to cache the images
    [volumeImage lockFocus];
    [volumeImage unlockFocus];

    [prevFeedbackImage lockFocus];
    [prevFeedbackImage unlockFocus];

    [nextFeedbackImage lockFocus];
    [nextFeedbackImage unlockFocus];

    [playFeedbackImage lockFocus];
    [playFeedbackImage unlockFocus];

    [pauseFeedbackImage lockFocus];
    [pauseFeedbackImage unlockFocus];

    [playPauseFeedbackImage lockFocus];
    [playPauseFeedbackImage unlockFocus];

    [barsImage lockFocus];
    [barsImage unlockFocus];

    [shuffleOnImage lockFocus];
    [shuffleOnImage unlockFocus];

    [shuffleOffImage lockFocus];
    [shuffleOffImage unlockFocus];

    [repeatOneImage lockFocus];
    [repeatOneImage unlockFocus];

    [repeatAllImage lockFocus];
    [repeatAllImage unlockFocus];

    [repeatOffImage lockFocus];
    [repeatOffImage unlockFocus];

    // set reasonable defaults for instance variables
    [self setBarOrigin:167];
    [self setCornerRadius:18];
    [self setBarEnabled:NO];
    [self setEnabledSegments:0];
    [self setStarBarEnabled:YES];
    [self setEnabledStars:0];
    [self setIconType:WOFeedbackVolumeIcon];


    }
    return self;
}

- (void)awakeFromNib
{
}

- (void)drawRect:(NSRect)rect
{
    // draw clean version of view
    [self clearView];
    [self drawBackground];

    // draw appropriate icon
    switch ([self iconType])
    {
        case WOFeedbackVolumeIcon:
            [self drawIcon:volumeImage];
            break;

        case WOFeedbackPrevIcon:
            [self drawIcon:prevFeedbackImage];
            break;

        case WOFeedbackPlayIcon:
            [self drawIcon:playFeedbackImage];
            break;

        case WOFeedbackPauseIcon:
            [self drawIcon:pauseFeedbackImage];
            break;

        case WOFeedbackNextIcon:
            [self drawIcon:nextFeedbackImage];
            break;

        case WOFeedbackPlayPauseIcon:
            [self drawIcon:playPauseFeedbackImage];
            break;

        case WOFeedbackShuffleOnIcon:
            [self drawIcon:shuffleOnImage];
            break;

        case WOFeedbackShuffleOffIcon:
            [self drawIcon:shuffleOffImage];
            break;

        case WOFeedbackRepeatOneIcon:
            [self drawIcon:repeatOneImage];
            break;

        case WOFeedbackRepeatAllIcon:
            [self drawIcon:repeatAllImage];
            break;

        case WOFeedbackRepeatOffIcon:
            [self drawIcon:repeatOffImage];
            break;

        default:
            // unknown icon type!
            [self drawIcon:volumeImage];
            break;
    }

    if ([self barEnabled])
        [self drawBar];

    if ([self starBarEnabled])
        [self drawStarBar];

    // issue a warning if the programmer has shot himself in the foot here (by
    // having both the volume bar and the star bar enabled at the same time)
    if (([self barEnabled]) && ([self starBarEnabled] == YES))
    {
        ELOG(@"Warning: volume feedback bar and star rating bar simultaneously active");
    }

    // resets the CoreGraphics window shadow
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_1)
    {
        [[self window] setHasShadow:NO];
        [[self window] setHasShadow:YES];
    }
    else
        [[self window] invalidateShadow];
}

// erase whatever graphics were in view before with clear
- (void)clearView
{
    [[NSColor clearColor] set];
    NSRectFill([self frame]);
}

- (void)drawBackground
/*"
 Fills in background with rounded corners, using appropriate alpha value and
 arc radius on the corners.
"*/
{
    NSBezierPath    *rectangle  = [NSBezierPath bezierPath];
    NSRect          bounds      = [self bounds];

    [[NSColor colorWithDeviceWhite:0.0 alpha:[self backgroundAlpha]] set];
    [rectangle appendBezierPathWithRoundedRectangle:bounds radius:[self cornerRadius]];
    [rectangle fill];
}

- (void)drawIcon:(NSImage *)theIcon
/*"
 Draws the icon into the view, using the "barEnabled" ivar to help in
 determining placement. If the bar is enabled the icon will be moved upwards in
 the view. Otherwise it will be centred.
"*/
{
    // calculate where to place icon
    NSRect view = [self bounds];

    // calculate where icon should be placed
    NSPoint iconPoint;
    iconPoint.x = floor((view.size.width / 2) - ([theIcon size].width / 2));

    if ([self barEnabled] || [self starBarEnabled])
        // move icon up by 20 to make room for bar
        iconPoint.y = floor(20 + ((view.size.height / 2) - ([theIcon size].height / 2)));
    else
        iconPoint.y = floor((view.size.height / 2) - ([theIcon size].height / 2));

    // now stick the icon in the view
    [theIcon dissolveToPoint:iconPoint fraction:1.0];
}

- (void)drawBar
{
    // calculate where to place bar
    NSRect view = [self bounds];

    NSPoint barsPoint;
    barsPoint.x = floor((view.size.width / 2) - ([barsImage size].width /2));
    barsPoint.y = floor([self barOrigin]);

    [barsImage dissolveToPoint:barsPoint fraction:1.0];

    // each segment will be a tiny rectangle
    NSRect segment;
    segment.origin.y    = barsPoint.y; // segment.origin.x filled out later
    segment.size.width  = FEEDBACK_BAR_SEGMENT_WIDTH;
    segment.size.height = FEEDBACK_BAR_SEGMENT_HEIGHT;

    // of white colour
    [[NSColor whiteColor] set];

    // draw the bars from left to right
    for (int i = 0; i < [self enabledSegments]; i++)
    {
        segment.origin.x = floor(barsPoint.x + (i * (FEEDBACK_BAR_SEGMENT_WIDTH + FEEDBACK_BAR_SEGMENT_GAP)));
        NSRectFill(segment);
    }
}

- (void)drawStarBar
{
    NSString    *starString     = nil;
    NSString    *unlitString    = nil;
    float       starFontSize    = 24.0f;

    // prepare colours and fonts for drawing
    NSColor     *starColor      = [NSColor colorWithDeviceWhite:1.0 alpha:1.0];
    NSColor     *unlitColor     = [NSColor colorWithDeviceWhite:0.0 alpha:0.5];
    NSFont      *bigSystemFont  = [NSFont systemFontOfSize:starFontSize];
    NSFont      *altFont        = nil; // workaround for Tiger font changes

    // http://daringfireball.net/2005/08/star_star
    // first choice: "Hiragino Kaku Gothic Pro" (must use postscript name)
    altFont = [NSFont fontWithName:@"HiraKakuPro-W3" size:starFontSize];

    // second choice: "Osaka"
    if (!altFont) altFont = [NSFont fontWithName:@"Osaka" size:starFontSize];

    // third choice: "Zapf Dingbats"
    if (!altFont) altFont = [NSFont fontWithName:@"ZapfDingbatsITC" size:starFontSize];
    if (altFont) bigSystemFont = altFont;

    NSMutableDictionary *starAttributes = [NSMutableDictionary dictionary];
    [starAttributes setObject:bigSystemFont forKey:NSFontAttributeName];
    [starAttributes setObject:starColor forKey:NSForegroundColorAttributeName];

    NSMutableDictionary *unlitAttributes = [NSMutableDictionary dictionary];
    [unlitAttributes setObject:bigSystemFont forKey:NSFontAttributeName];
    [unlitAttributes setObject:unlitColor forKey:NSForegroundColorAttributeName];

    // draw the unlit stars first
    unichar star = WO_RATING_STAR_UNICODE_CHAR;

    // this was the old workaround (not as neat); use it only if our font fallbacks all failed
    if (!altFont)
        star = WO_ALT_RATING_STAR;

    unlitString = [NSString stringWithFormat:@"%C%C%C%C%C", star, star, star, star, star];

    // specify where the unlit stars will be drawn
    NSRect starBarBounds = NSZeroRect;
    starBarBounds.size = [unlitString sizeWithAttributes:unlitAttributes];

    // calculate origin
    NSRect view = [self bounds];

    // "x" origin
    starBarBounds.origin.x = floor((view.size.width / 2) - (starBarBounds.size.width / 2));

    // for the "y" case, same as barOrigin, except we're taller by 15 pixels and so should start about 7 pixels lower
    starBarBounds.origin.y = floor([self barOrigin] - 7);

    // draw the unlit stars
    [unlitString drawAtPoint:starBarBounds.origin withAttributes:unlitAttributes];

    // now (over-)draw lit stars
    switch ([self enabledStars])
    {
        case 0: // no stars
            starString = @"";
            break;

        case 1: // one star
            starString = [NSString stringWithFormat:@"%C", star];
            break;

        case 2: // two stars
            starString = [NSString stringWithFormat:@"%C%C", star, star];
            break;

        case 3: // three stars
            starString = [NSString stringWithFormat:@"%C%C%C", star, star, star];
            break;

        case 4: // four stars
            starString = [NSString stringWithFormat:@"%C%C%C%C", star, star, star, star];
            break;

        case 5: // five stars
            starString = [NSString stringWithFormat:@"%C%C%C%C%C", star, star, star, star, star];
            break;

        default:
            // illegal number of stars!
            ELOG(@"Error: only star ratings between 0 and 5 are permitted");
            starString = @"";
            break;
    }

    [starString drawAtPoint:starBarBounds.origin withAttributes:starAttributes];
}

// accessors

- (float)barOrigin
{
    return barOrigin;
}

- (void)setBarOrigin:(float)newValue
{
    barOrigin = newValue;
}

- (float)cornerRadius
{
    return cornerRadius;
}

- (void)setCornerRadius:(float)newValue
{
    cornerRadius = newValue;
}

- (float)backgroundAlpha
{
    return backgroundAlpha;
}

- (void)setBackgroundAlpha:(float)newValue
{
    backgroundAlpha = newValue;
}

- (BOOL)barEnabled
{
    return barEnabled;
}

- (void)setBarEnabled:(BOOL)newValue
{
    barEnabled = newValue;
}

- (int)enabledSegments
{
    return enabledSegments;
}

- (void)setEnabledSegments:(int)newValue
{
    enabledSegments = newValue;
}

- (BOOL)starBarEnabled
{
    return starBarEnabled;
}

- (void)setStarBarEnabled:(BOOL)newValue
{
    starBarEnabled = newValue;
}

- (int)enabledStars
{
    return enabledStars;
}

- (void)setEnabledStars:(int)newValue
{
    enabledStars = newValue;
}

- (WOFeedbackIconType)iconType
{
    return iconType;
}

- (void)setIconType:(WOFeedbackIconType)newIconType
{
    iconType = newIconType;
}

@end
