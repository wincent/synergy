//
//  WOSynergyAnchorView.h
//  Synergy
//
//  Created by Wincent Colaiuta on Tue Jan 21 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import <AppKit/AppKit.h>

#import "WORoundedRect.h"
#import "WODebug.h"

#define DEFAULT_CORNER_RADIUS_FOR_ANCHOR    4
#define DEFAULT_ALPHA_LEVEL_FOR_ANCHOR      0.8
#define DEFAULT_ICON_OPACITY_FOR_ANCHOR     1.0

// there is common code between this and the WOSynergyFloater classes: possibly
// an indication that they should be subclasses of one common parent class
@interface WOSynergyAnchorView : NSView {

    NSImage     *pinImage;

    // alpha level for window background
    float       bgAlpha;

    // number of pixels for round corners, expressed as a radius
    float       cornerRadius;

    // alpha level for icon
    float       iconAlpha;
}

// methods taken from WOSynergyFloaterView and modified (for updating the view)
- (void)clearView;
- (void)drawBackground;
- (void)drawIcon;

// general methods

// return the size needed to contain view
- (NSSize)viewSize;

// accessor methods

- (void)setBgAlpha:(float)newAlpha;
- (float)bgAlpha;

- (void)setCornerRadius:(float)newRadius;
- (float)cornerRadius;

- (void)setIconAlpha:(float)newAlpha;
- (float)iconAlpha;

@end
