//
//  WOSynergyAnchorView.m
//  Synergy
//
//  Created by Wincent Colaiuta on Tue Jan 21 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import "WOSynergyAnchorView.h"

@implementation WOSynergyAnchorView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // load pin image from bundle in a prefPane-friendly way
        pinImage = [[NSImage alloc] initByReferencingFile:
            [[NSBundle bundleForClass:[self class]] pathForResource:@"pin"
                                                            ofType:@"png"]];

        // set reasonable defaults for instance variables
        [self setBgAlpha:DEFAULT_ALPHA_LEVEL_FOR_ANCHOR];
        [self setCornerRadius:DEFAULT_CORNER_RADIUS_FOR_ANCHOR];
        [self setIconAlpha:DEFAULT_ICON_OPACITY_FOR_ANCHOR];
    }
    return self;
}

- (void)drawRect:(NSRect)rect
{
    // draw clean version of view
    [self clearView];
    [self drawBackground];
    [self drawIcon];

    // resets the CoreGraphics window shadow
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_1)
    {
        [[self window] setHasShadow:NO];
        [[self window] setHasShadow:YES];
    }
    else
    {
        [[self window] invalidateShadow];
    }
}

// sub-methods for drawing into the view (updating it)

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

    [[NSColor colorWithDeviceWhite:0.0 alpha:bgAlpha] set];

    [rectangle appendBezierPathWithRoundedRectangle:bounds
                                             radius:cornerRadius];

    [rectangle fill];
}

- (void)drawIcon
{
    // now stick icon in the view
    NSPoint iconPoint;
    iconPoint.x = cornerRadius;	// inset it from bottomLeft corner
    iconPoint.y = cornerRadius;  // by radius

    [pinImage dissolveToPoint:iconPoint
                     fraction:DEFAULT_ICON_OPACITY_FOR_ANCHOR];
}

// return the size needed to contain view
- (NSSize)viewSize
{
    NSRect myBounds = [self bounds];

    return myBounds.size;
}

// accessor methods

- (void)setBgAlpha:(float)newAlpha
{
    bgAlpha = newAlpha;
}

- (float)bgAlpha
{
    return bgAlpha;
}

- (void)setCornerRadius:(float)newRadius
{
    cornerRadius = newRadius;
}

- (float)cornerRadius
{
    return cornerRadius;
}

- (void)setIconAlpha:(float)newAlpha
{
    iconAlpha = newAlpha;
}

- (float)iconAlpha
{
    return iconAlpha;
}

@end
