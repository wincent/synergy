//
//  WOSynergyFloaterView.h
//  Synergy
//
//  Created by Wincent Colaiuta on Wed Jan 15 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import <Cocoa/Cocoa.h>

#import "WOSynergyFloater.h"
#import "WORoundedRect.h"
#import "WODebug.h"
#import "WOSynergyGlobal.h"

#define DEFAULT_ALPHA_FOR_FLOATER_WINDOW  0.20
#define DEFAULT_CORNER_RADIUS             16
#define DEFAULT_INSET_FROM_BOTTOM_LEFT    48

#define MIN_ALPHA_FOR_FLOATER_WINDOW      0.0     /* prior to version 2.8 was 0.10 */
#define MIN_CORNER_RADIUS                 8
#define MIN_INSET_FROM_BOTTOM_LEFT        8

#define MAX_ALPHA_FOR_FLOATER_WINDOW      1.0     /* prior to version 2.8 was 0.90 */
#define MAX_CORNER_RADIUS                 24
#define MAX_INSET_FROM_BOTTOM_LEFT        128

#define WO_ICON_ALPHA                     0.80

// used to identify the segments of the 3 x 3 grid into which the screen is
// divided
typedef enum WOFloaterScreenSegment {

    WOBottomLeftScreenSegment   = 1,
    WOBottomMiddleScreenSegment = 2,
    WOBottomRightScreenSegment  = 3,
    WOMiddleLeftScreenSegment   = 4,
    WOMiddleMiddleScreenSegment = 5,
    WOMiddleRightScreenSegment  = 6,
    WOTopLeftScreenSegment      = 7,
    WOTopMiddleScreenSegment    = 8,
    WOTopRightScreenSegment     = 9

} WOFloaterScreenSegment;

// used to store "star" ratings
typedef enum WORatingCode {

    WO0StarRating = 0,
    WO1StarRating = 1,
    WO2StarRating = 2,
    WO3StarRating = 3,
    WO4StarRating = 4,
    WO5StarRating = 5,
    WONoStarRatingDisplay = 6

} WORatingCode;

@interface WOSynergyFloaterView : NSView
{
    NSImage                 *synergyImage;
    NSImage                 *noCoverArtImage;

    NSMutableString         *trackName;
    NSMutableString         *artistName;
    NSMutableString         *composerName;
    NSMutableString         *albumName;

    // alpha level for window background
    float                   bgAlpha;

    // number of pixels for round corners, expressed as a radius
    float                   cornerRadius;

    // spacing to maintain between view and bottom left corner of screen
    // where "bottom left corner of the screen" avoids the Dock as appropriate
    float                   insetSpacer;

    // NEW:
    // instead of a single "insetSpacer" value, our new version will feature
    // separate X and Y insets, which can be negative or positive
    // and the addition of a "screenSegment" to indicate which part of the
    // screen to display in
    //
    // the segments are numbered from 1 to 9 (produced by cutting the screen
    // into thirds width-wise and height-wise) starting in the bottom left
    // corner (the most common) and working up.
    //
    // the significance of the screen segment is two-fold
    // 1. it tells us which "anchorPoint we'll be using"
    // 2. it tells us which part of the floater is considered to be the "origin"
    // for resize operations -> for example, in the bottom-left screen segment,
    // it is the bottom-left corner of the floater that is most important,
    // because the floater grows up and across from that point
    // -> in contrast in the top-right screen segment, the floater must grow
    // down and to the left, and so the top-right corner becomes the "origin"

    float                   relativeXPosition; // distance from anchorPoint
    float                   relativeYPosition; // distance from anchorPoint

    WOFloaterScreenSegment  screenSegment;

    // used to store the so-called anchor point in screen coordinates
    NSPoint                 anchorPoint;

    // used to store the point in the floater which is considered to be the
    // "center" or "origin" for all resize operations
    // the floater will grow away from this base point in the direction(s)
    // required according to its screen segment
    NSPoint                 floaterResizeBase;


    // whether or not view should include the text when updating the view
    BOOL                    drawText;

    // used to store text colour when fading text in and out
    NSColor                 *textColor;

    // draw semi-transparent registration reminder when NO
    BOOL                    registrationStatus;

    // for the display of the star rating...
    WORatingCode            currentRating;

    NSColor                 *fgColor;
    NSColor                 *bgColor;

    // for album cover support
    WOFloaterIconType       floaterIconType;
    NSString                *albumImagePath;

    // private vars for album cover
    NSImage                 *albumImage;      // the actual image
    NSSize                  albumImageSize;   // size
}


- (void)clearView;

- (void)drawBackground;

- (void)drawIcon;

- (void)resizeIcon;

    // this version of the resizeIcon method takes into account the height of the
    // text in the floater
- (void)resizeIconWithTextHeight:(float)textHeight;

- (void)drawTextAndSeparator;

- (void)drawTextForMiniFloater;

- (void)drawRatingStars;

- (NSSize)calculateSizeNeededForIcon;

- (NSSize)calculateSizeNeededForText;

- (NSSize)calculateSizeNeededForMiniFloater;

#pragma mark -
#pragma mark Properties

@property       BOOL                drawText;

// deprecated:
@property(copy) NSColor             *textColor;

// replaces textColor:
@property(copy) NSColor             *fgColor;

@property(copy) NSColor             *bgColor;
@property(copy) NSMutableString     *trackName;
@property(copy) NSMutableString     *artistName;
@property(copy) NSMutableString     *composerName;
@property(copy) NSMutableString     *albumName;
@property       float               bgAlpha;
@property       float               cornerRadius;
@property       float               insetSpacer;
@property       WORatingCode        currentRating;

// tell floater path to downloaded image
@property(copy) NSString            *albumImagePath;

// returns nil if there is no cover image in the floater
@property(copy) NSImage             *albumImage;

// tell floater to display album cover, icon, or nothing
@property       WOFloaterIconType   floaterIconType;

@end
