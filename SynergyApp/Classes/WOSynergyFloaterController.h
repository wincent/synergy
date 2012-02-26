//
//  WOSynergyFloaterView.h
//  Synergy
//
//  Created by Wincent Colaiuta on Wed Jan 15 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import <Cocoa/Cocoa.h>

#import "WOSynergyFloater.h"
#import "WOSynergyFloaterWindow.h"
#import "WOSynergyFloaterView.h"
#import "WODebug.h"

#define DEFAULT_DELAY_BEFORE_FADEOUT      10.0
#define MIN_DELAY_BEFORE_FADEOUT          1.0

// this used to be 60, but now I am changing it to 86,400 to accommodate the
// "show floater forever" preference setting
#define MAX_DELAY_BEFORE_FADEOUT          86400.0

#define FALLBACK_FOR_NO_HORIZONTAL_INSET  48.0
#define FALLBACK_FOR_NO_VERTICAL_INSET    48.0

@class WOSynergyFloaterView, WOSynergyFloaterWindow, WOSynergyAnchorController;

// copied straight from "WOSynergyAnchorController.h" (and renamed)
typedef enum WOScreenSegmentXCoordinate {

    WOScreenSegmentLeft = 0,
    WOScreenSegmentHorizontalMiddle = 1,
    WOScreenSegmentRight = 2

} WOScreenSegmentXCoordinate;

typedef enum WOScreenSegmentYCoordinate {

    WOScreenSegmentBottom = 0,
    WOScreenSegmentVerticalMiddle = 1,
    WOScreenSegmentTop = 2

} WOScreenSegmentYCoordinate;

// // due to poor design, I used separate names in WOSynergyAnchorController and
// // I have to include them here also
#import "WOSynergyAnchorController.h"

@interface WOSynergyFloaterController : NSObject
{
    IBOutlet WOSynergyFloaterWindow *floaterWindow;

    IBOutlet WOSynergyFloaterView   *floaterView;

    BOOL                            animateWhileResizing;

    BOOL                            movable;

    // window origin, *relative* to screen segment
    NSPoint                         windowOffset;

    // screensegment
    WOScreenSegmentXCoordinate      xScreenSegment;
    WOScreenSegmentYCoordinate      yScreenSegment;

    // a word about offsets:
    // the offset is the relative vector from the "anchor point" of the screensegment
    // to the "resize origin" of the floater
    // As and example:
    // in top left segment: anchor point is top left
    //        floater resize origin is top left of floater
    // ie. the floater resizes away from top left, and top left corner of floater
    // is fixed in space
    //
    // because of this design, offsets should survive (reasonably well) in the
    // event of a resolution change
    // why? because the largest distance a "resize origin" can be from its
    // "anchor point" is 1/3 of screen - 1/2 of floater dimension
    // eg somewhat less than 1/3 of screen
    // so if screen res suddenly doubles, the anchor point will appear to be
    // "less than 1/3 of old screen res" / 2 pixels too close to the anchor point
    // or if the res halve -> the same amount but too far from the anchor point
    // but in practical terms these numbers are small...
    // eg. example... 1280 wide screen (1/3 = approx 425 pixels)
    // anchor point might be, say, 50 pixels in (eg. 4% of screen width)
    // (almost halve screen res) to 640 ->
    // anchor point is still 50 pixels in (now 8% of screen width)
    // so the variation isn't bad... in reality res changes are rare, especially
    // res changes of this magnitude.

    // we keep multiple timers (one for each type of fade) because these fades
    // could be occurring simultaneously
    NSTimer                         *fadeInTimer;
    NSTimer                         *fadeOutTimer;

    NSTimer                         *textFadeInTimer;
    NSTimer                         *textFadeOutTimer;

    NSTimer                         *delayedFadeOutTimer;

    // horrible, kludgy timers -- split the fancy fade in process into two steps
    NSTimer                         *partTwoDelayTimer;

    // defines time period to display floater before fading it out
    float                           delayBeforeFade;

    float                           fgColor;
    float                           bgColor;
    float                           bgOpacity;

    // deprecated
    int                             screenIndex; // screen origin, relative to mainScreen

    int                             screenNumber; // the preferred new method
}

// debugging methods (for test app: RoundTransparentWindow.app):
- (IBAction)tellViewItNeedsToDisplay:(id)sender;
- (IBAction)displayNowOrElse:(id)sender;
- (IBAction)showMeTheIconOnly:(id)sender;
- (IBAction)zoomToFitText:(id)sender;
- (IBAction)removeWindowFromScreen:(id)sender;
- (IBAction)putWindowInScreen:(id)sender;
- (IBAction)drawTheText:(id)sender;
- (IBAction)fadeWindowOut:(id)sender; // this only sets up a timer, real work done below
- (IBAction)fadeWindowIn:(id)sender;  // ditto
- (IBAction)fadeTextIn:(id)sender;
- (IBAction)fadeTextOut:(id)sender;

// methods which actually do good shit!
// cleans up any running timers
- (void)stopFadeTimers;
- (void)stopDelayedFadeTimers;
- (void)stopPartTwoDelayTimer;
// the methods that do the actual work of fading
- (void)fadeOutIncrement:(NSTimer *)timer;
- (void)fadeInIncrement:(NSTimer *)timer;
// cleans up any running timers
- (void)stopTextFadeTimers;
- (void)textFadeInIncrement:(NSTimer *)timer;
- (void)textFadeOutIncrement:(NSTimer *)timer;
// test cases
- (IBAction)kickItTimerStyle:(id)sender;
- (void)partTwo:(NSTimer *)timer; // sigh.... kludgy

- (IBAction)kickItClickStyle:(id)sender;
// kicks in after the delayed fade out interval expires (eg 10 secs)
- (void)delayedFadeOutStart:(NSTimer *)timer;
// returns random string for test cases
- (NSString *)randomString;

// will set it up
- (void)setUpDelayedFadeOut;


// the real workhorse of the class: this is what other classes call to initiate
// an update
-(void)clickDrivenUpdateWithTrackName:(NSString *)track
                                album:(NSString *)album
                               artist:(NSString *)artist;

-(void)timerDrivenUpdateWithTrackName:(NSString *)track
                                album:(NSString *)album
                               artist:(NSString *)artist;

- (void)clickDrivenUpdate;
- (void)timerDrivenUpdate;

- (void)setStrings:(NSString *)track
             album:(NSString *)album
            artist:(NSString *)artist
          composer:(NSString *)composer;

// accessors

- (void)setDelayBeforeFade:(float)newDelay;
- (float)delayBeforeFade;

// haven't written "getters" for all of these yet, only "setters":
- (void)setTransparency:(float)newTransparency;
- (float)transparency;

- (void)setSize:(int)newSize;
- (void)setAnimateWhileResizing:(BOOL)newState;
- (BOOL)animateWhileResizing;

- (void)setWindowAlphaValue:(float)newAlpha;
- (float)windowAlphaValue;

- (void)setDrawText:(BOOL)theSetting;

- (void)setFgColor:(float)newColor;
- (float)fgColor;

- (void)setBgColor:(float)newColor;
- (float)bgColor;

//- (void)setBgOpacity:(float)newColor;
//- (float)bgOpacity;

// controls with floater is movable by clicking on background
- (void)setMovable:(BOOL)movableStatus;
- (BOOL)movable;

- (void)windowSetDragNotifier:(WOSynergyAnchorController *)newDragNotifier;

// routines for getting/setting window origin
- (NSPoint)windowOffset;
- (void)setWindowOffset:(NSPoint)newOffset;

- (void)setScreenIndex:(int)newIndex;

// routines for getting/setting screen segment
- (WOScreenSegmentXCoordinate)xScreenSegment;
- (void)setXScreenSegment:(WOScreenSegmentXCoordinate)xCoord;

- (WOScreenSegmentYCoordinate)yScreenSegment;
- (void)setYScreenSegment:(WOScreenSegmentYCoordinate)yCoord;

    // returns an offset from the bottom left of the screen given a screen segment
    // and an offset within that segment
- (NSPoint)originFromOffset:(NSPoint)theOffset
                   segmentX:(WOScreenSegmentXCoordinate)theXCoord
                   segmentY:(WOScreenSegmentXCoordinate)theYCoord;

// a version of the above that permits adjustment for dynamic text
- (NSPoint)originWithNewSize:(NSSize)newSize
                  fromOffset:(NSPoint)theOffset
                    segmentX:(WOScreenSegmentXCoordinate)theXCoord
                    segmentY:(WOScreenSegmentXCoordinate)theYCoord;


// moves the window but doesn't display it
- (void)moveGivenOffset:(NSPoint)theOffset
               xSegment:(WOScreenSegmentXCoordinate)theXCoord
               ySegment:(WOScreenSegmentYCoordinate)theYCoord;

// routines for finding our where floater currently is
- (NSPoint)returnCurrentOffset;

- (void)setScreenNumber:(int)newScreenNumber;

- (BOOL)windowIsVisible;

- (void)resizeInstantly;

- (void)setCurrentRating:(WORatingCode)newRating;
- (WORatingCode)currentRating;

// accessor to get pointer to floater window
- (id)floaterWindow;

// new accessors added to facilitate album cover in floater

// tell floater path to downloaded image
- (void)setAlbumImagePath:(NSString *)path;
- (NSString *)albumImagePath;

- (NSImage *)coverImage;

// tell floater to display album cover, icon, or nothing
- (void)setFloaterIconType:(WOFloaterIconType)iconType;


@end
