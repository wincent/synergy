//
//  WOSynergyAnchorController.h
//  Synergy
//
//  Created by Greg Hurrell on Tue Jan 21 2003.
//  Copyright 2003-present Greg Hurrell.

#import <Foundation/Foundation.h>

#import "WOSynergyAnchorWindow.h"
#import "WOSynergyAnchorView.h"
#import "WODebug.h"

#define DEFAULT_WINDOW_ORIGIN_X     48.0
#define DEFAULT_WINDOW_ORIGIN_Y     48.0

@class WOSynergyAnchorView, WOSynergyAnchorWindow;

typedef enum WOSynergyAnchorXCoordinate {

    WOSynergyAnchorLeft = 0,
    WOSynergyAnchorHorizontalMiddle = 1,
    WOSynergyAnchorRight = 2

} WOSynergyAnchorXCoordinate;

typedef enum WOSynergyAnchorYCoordinate {

    WOSynergyAnchorBottom = 0,
    WOSynergyAnchorVerticalMiddle = 1,
    WOSynergyAnchorTop = 2

} WOSynergyAnchorYCoordinate;

@interface WOSynergyAnchorController : NSObject {

    IBOutlet WOSynergyAnchorWindow  *anchorWindow;

    IBOutlet WOSynergyAnchorView    *anchorView;

    WOSynergyAnchorXCoordinate      xGridLocation;

    WOSynergyAnchorYCoordinate      yGridLocation;

    // the window size necessary to contain the view (used in resizing)
    NSSize                          neededSize;

    // store the relative window offset of the floater here so that the main
    // controller can grab it, store it in preferences etc
    NSPoint                         windowOffset;

    float                           xScreenOffset;
    float                           yScreenOffset;

    int                             screenNumber;

}

// called whenever floater preview window is moved
- (void)newOrigin:(NSPoint)windowCentre
           origin:(NSPoint)windowOrigin
           window:(NSWindow *)window;

// move anchor window into appropriate segment
- (void)moveToSegment:(int)x y:(int)y screen:(NSScreen *)screen;
- (void)moveToSegmentNoAnimate:(int)x y:(int)y screen:(NSScreen *)screen;
// called by methods above to do actual work
- (void)moveToSegmentMaster:(int)x y:(int)y screen:(NSScreen *)screen animate:(BOOL)animate;

// wrapper functions (which forward messages on to the view and window)

// view wrapper functions
- (void)viewSetNeedsDisplay:(BOOL)newState;

// window wrapper functions
- (void)windowOrderFront:(id)sender;

- (void)windowOrderOut:(id)sender;

// accessor methods
- (void)setXGridLocation:(WOSynergyAnchorXCoordinate)newX;
- (WOSynergyAnchorXCoordinate)xGridLocation;

- (void)setYGridLocation:(WOSynergyAnchorYCoordinate)newY;
- (WOSynergyAnchorYCoordinate)yGridLocation;

- (void)setWindowOffset:(NSPoint)newOffset;
- (NSPoint)windowOffset;

- (float)xScreenOffset;
- (float)yScreenOffset;

// deprecated
- (int)screenIndex;

- (int)screenNumber;
- (void)setScreenNumber:(int)newScreenNumber;

@end
