//
//  WOSynergyFloaterController.m
//  Synergy
//
//  Created by Greg Hurrell on Wed Jan 15 2003.
//  Copyright 2003-present Greg Hurrell.

#import "WOSynergyFloaterController.h"
#import "WOSynergyGlobal.h"
#import "WONSScreenExtensions.h"

// rate of fade
#define FRAMES_PER_SECOND 20
#define SECONDS_PER_FRAME (1.0 / (float)FRAMES_PER_SECOND)

@implementation WOSynergyFloaterController

- (void)awakeFromNib
{
    // make sure timers are nil so that methods below can check and see if a
    // timer is already initialised
    fadeOutTimer = nil;
    fadeInTimer = nil;
    textFadeOutTimer = nil;
    textFadeInTimer = nil;

    // this timer is distinct from the others -- it's used to fade window from screen after XX secs
    delayedFadeOutTimer = nil;

    // and this one is royal kludge
    partTwoDelayTimer = nil;

    // set this to a reasonable default
    delayBeforeFade = DEFAULT_DELAY_BEFORE_FADEOUT;

    [self setFgColor:WO_WHITE_FG];
    [self setBgColor:WO_BLACK_BG];

    // movable or not? defaults to NO
    [self setMovable:NO];

    // window is in which screen segment?
    [self setXScreenSegment:WOScreenSegmentLeft];
    [self setYScreenSegment:WOScreenSegmentBottom];

    // deprecated
    [self setScreenIndex:0];

    // new
    [self setScreenNumber:WONoScreenNumber]; // zero is the fallback value


    // and the default offset
    //NSRect visibleFrame = [[NSScreen mainScreen] visibleFrame];
    [self setWindowOffset:NSMakePoint(FALLBACK_FOR_NO_HORIZONTAL_INSET,
        FALLBACK_FOR_NO_VERTICAL_INSET)];

    [self removeWindowFromScreen:self];
    [self showMeTheIconOnly:self];
}

// "wrapper" methods that the main Synergy controller class will call in order
// to get the notification window on the screen. That's the only contact we
// have. It handles all the preferences; and this class just does the drawing.
-(void)timerDrivenUpdateWithTrackName:(NSString *)track
                                album:(NSString *)album
                               artist:(NSString *)artist
{
    [floaterView setTrackName:[NSMutableString stringWithString:track]];
    [floaterView setAlbumName:[NSMutableString stringWithString:album]];
    [floaterView setArtistName:[NSMutableString stringWithString:artist]];

    [self kickItTimerStyle:self];
}

-(void)clickDrivenUpdateWithTrackName:(NSString *)track
                                album:(NSString *)album
                               artist:(NSString *)artist
{
    [floaterView setTrackName:[NSMutableString stringWithString:track]];
    [floaterView setAlbumName:[NSMutableString stringWithString:album]];
    [floaterView setArtistName:[NSMutableString stringWithString:artist]];

    [self kickItClickStyle:self];
}

- (void)clickDrivenUpdate
{
    [self kickItClickStyle:self];
}

- (void)timerDrivenUpdate
{
    [self kickItTimerStyle:self];
}

- (void)setStrings:(NSString *)track
             album:(NSString *)album
            artist:(NSString *)artist
          composer:(NSString *)composer
{
    [floaterView setTrackName:[NSMutableString stringWithString:track]];
    [floaterView setAlbumName:[NSMutableString stringWithString:album]];
    [floaterView setArtistName:[NSMutableString stringWithString:artist]];
    [floaterView setComposerName:[NSMutableString stringWithString:composer]];
}

- (IBAction)tellViewItNeedsToDisplay:(id)sender
{
    [floaterView setNeedsDisplay:YES];
}

- (IBAction)displayNowOrElse:(id)sender
{
    [floaterView display];
}

// returns an obsolute origin (from the bottom left of the screen) given a
// screen segment and a relative offset within that segment
- (NSPoint)originWithNewSize:(NSSize)newSize
                  fromOffset:(NSPoint)theOffset
                   segmentX:(WOScreenSegmentXCoordinate)theXCoord
                   segmentY:(WOScreenSegmentXCoordinate)theYCoord
{
    // work out the horizontal and vertical midpoints of the floater
    float floaterHorizontalMidpoint = (newSize.width / 2);
    float floaterVerticalMidpoint = (newSize.height / 2);

    // need to know the screen dimensions
    NSScreen *floaterScreen = [NSScreen screenFromScreenNumber:screenNumber];

    NSRect screenBounds;

    if (floaterScreen != nil)
    {
        // found the screen
        screenBounds = [floaterScreen visibleFrame];
    }
    else
    {
        // didn't find the screen
        // fall back to the main screen
        screenBounds =
        [[[NSScreen screens] objectAtIndex:0] visibleFrame];
    }


    // divide screen into a 3 x 3 grid
    int segmentWidth = floor(screenBounds.size.width / 3); // number of pixels for one-third screen width
    int segmentHeight = floor(screenBounds.size.height / 3);

    // this will contain the absolute offset in screen coordinates
    NSPoint absoluteOffset;

    // consider the x axis first

    switch (theXCoord)
    {
        case WOScreenSegmentLeft:
            // anchor point = left
            // resize centre = left

            absoluteOffset.x = (screenBounds.origin.x + theOffset.x);

            break;
        case WOScreenSegmentHorizontalMiddle:
            // anchor point = middle
            // resize centre = middle

            absoluteOffset.x = (screenBounds.origin.x + (segmentWidth * 1.5) +
                                theOffset.x - floaterHorizontalMidpoint);

            break;

        case WOScreenSegmentRight:
            // anchor point = right
            // resize centre = right

            absoluteOffset.x = (screenBounds.origin.x + (segmentWidth * 3) +
                                theOffset.x - newSize.width);

            break;
        default:
            // unknown x axis coordinate!

            absoluteOffset.x = (screenBounds.origin.x +
                                FALLBACK_FOR_NO_HORIZONTAL_INSET); // 48.0

            break;
    }

    // now the y axis

    switch (theYCoord)
    {
        case WOScreenSegmentBottom:
            // anchor point = bottom
            // resize centre = bottom

            absoluteOffset.y = (screenBounds.origin.y + theOffset.y);

            break;
        case WOScreenSegmentVerticalMiddle:
            // anchor point = middle
            // resize centre = middle

            absoluteOffset.y = (screenBounds.origin.y + (segmentHeight * 1.5) +
                                theOffset.y - floaterVerticalMidpoint);

            break;

        case WOScreenSegmentTop:
            // anchor point = top
            // resize centre = top

            absoluteOffset.y = (screenBounds.origin.y + (segmentHeight * 3) +
                                theOffset.y - newSize.height);

            break;
        default:
            // unknown y axis coordinate!

            absoluteOffset.y = (screenBounds.origin.y +
                                FALLBACK_FOR_NO_VERTICAL_INSET); // 48.0

            break;
    }

    // now, the offset is expressed relative to bottom corner of display in
    // holding the floater.
    // before returning, convert so that the offset is expressed relative to
    // the main screen

    return absoluteOffset;
}

// returns an obsolute origin (from the bottom left of the screen) given a
// screen segment and a relative offset within that segment
- (NSPoint)originFromOffset:(NSPoint)theOffset
                   segmentX:(WOScreenSegmentXCoordinate)theXCoord
                   segmentY:(WOScreenSegmentXCoordinate)theYCoord
{
    // also need to factor in current floater size...
    NSRect floaterFrame = [floaterWindow frame];

    // work out the horizontal and vertical midpoints of the floater
    float floaterHorizontalMidpoint = (floaterFrame.size.width / 2);
    float floaterVerticalMidpoint = (floaterFrame.size.height / 2);

    // need to know the screen dimensions
    NSScreen *floaterScreen = [NSScreen screenFromScreenNumber:screenNumber];

    NSRect screenBounds;

    if (floaterScreen != nil)
    {
        // found the screen
        screenBounds = [floaterScreen visibleFrame];
    }
    else
    {
        // didn't find the screen
        // fall back to the main screen
        screenBounds =
        [[[NSScreen screens] objectAtIndex:0] visibleFrame];
    }

    // divide screen into a 3 x 3 grid
    int segmentWidth = floor(screenBounds.size.width / 3); // number of pixels for one-third screen width
    int segmentHeight = floor(screenBounds.size.height / 3);

    // this will contain the absolute offset in screen coordinates
    NSPoint absoluteOffset;

    // consider the x axis first

    switch (theXCoord)
    {
        case WOScreenSegmentLeft:
            // anchor point = left
            // resize centre = left

            absoluteOffset.x = (screenBounds.origin.x + theOffset.x);

            break;
        case WOScreenSegmentHorizontalMiddle:
            // anchor point = middle
            // resize centre = middle

            absoluteOffset.x = (screenBounds.origin.x + (segmentWidth * 1.5) +
                                theOffset.x - floaterHorizontalMidpoint);

            break;

        case WOScreenSegmentRight:
            // anchor point = right
            // resize centre = right

            absoluteOffset.x = (screenBounds.origin.x + (segmentWidth * 3) +
                                theOffset.x - floaterFrame.size.width);

            break;
        default:
            // unknown x axis coordinate!

            absoluteOffset.x = (screenBounds.origin.x +
                                FALLBACK_FOR_NO_HORIZONTAL_INSET); // 48.0

            break;
    }

    // now the y axis

    switch (theYCoord)
    {
        case WOScreenSegmentBottom:
            // anchor point = bottom
            // resize centre = bottom

            absoluteOffset.y = (screenBounds.origin.y + theOffset.y);

            break;
        case WOScreenSegmentVerticalMiddle:
            // anchor point = middle
            // resize centre = middle

            absoluteOffset.y = (screenBounds.origin.y + (segmentHeight * 1.5) +
                                theOffset.y - floaterVerticalMidpoint);

            break;

        case WOScreenSegmentTop:
            // anchor point = top
            // resize centre = top

            absoluteOffset.y = (screenBounds.origin.y + (segmentHeight * 3) +
                                theOffset.y - floaterFrame.size.height);

            break;
        default:
            // unknown y axis coordinate!

            absoluteOffset.y = (screenBounds.origin.y +
                                FALLBACK_FOR_NO_VERTICAL_INSET); // 48.0

            break;
    }

    return absoluteOffset;
}

- (IBAction)showMeTheIconOnly:(id)sender
{
    // determine the extent of usable screen realestate
    // determine how much of that realestate we are going to use
    NSRect newRect;
    // set us in 48 pixels above and to the right of the bottom left corner

    // new code for determining absolute origin: default is (48, 48)
    newRect.origin = [self originFromOffset:windowOffset
                                   segmentX:xScreenSegment
                                   segmentY:yScreenSegment];


    newRect.size = [floaterView calculateSizeNeededForIcon];
    // remove the text
    [floaterView setDrawText:NO]; // will disappear as soon as we start resizing
                                  // resize us
    [floaterWindow setFrame:newRect display:YES animate:animateWhileResizing];
}

- (void)moveGivenOffset:(NSPoint)theOffset
               xSegment:(WOScreenSegmentXCoordinate)theXCoord
               ySegment:(WOScreenSegmentYCoordinate)theYCoord
{
    NSRect theNewRect = [floaterWindow frame];
    theNewRect.origin = [self originFromOffset:theOffset
                                      segmentX:theXCoord
                                      segmentY:theYCoord];

    [floaterWindow setFrame:theNewRect
                    display:NO
                    animate:NO];
}

// routines for finding our where floater currently is
- (NSPoint)returnCurrentOffset
{
    return [floaterWindow myCentreOrigin];
}

- (IBAction)zoomToFitText:(id)sender
{
    // determine the extent of usable screen realestate
    // determine how much of that realestate we are going to use
    NSRect newRect;
    // set us in 48 pixels above and to the right of the bottom left corner

    // new code for determining absolute origin: default is (48, 48)

    newRect.size = [floaterView calculateSizeNeededForText];

    newRect.origin = [self originWithNewSize:newRect.size
                                  fromOffset:windowOffset
                                    segmentX:xScreenSegment
                                    segmentY:yScreenSegment];


    // resize us
    [floaterWindow setFrame:newRect display:YES animate:animateWhileResizing];
}

/*

 When window is hidden it's ok to call the resize methods... when the window is
 shown again it will be in the right place
 */

- (IBAction)removeWindowFromScreen:(id)sender
{
    [floaterWindow orderOut:self];
}

- (IBAction)putWindowInScreen:(id)sender
{
    [floaterWindow orderFront:self];
}

- (IBAction)drawTheText:(id)sender
{
    [floaterView setDrawText:YES];
    [self tellViewItNeedsToDisplay:self];
}

- (IBAction)fadeWindowOut:(id)sender
{
    [self stopFadeTimers];
    // should be no harm here in calling also
    [self stopDelayedFadeTimers]; // no need to call it...?
                                  // set up new timer
    fadeOutTimer = [NSTimer scheduledTimerWithTimeInterval:SECONDS_PER_FRAME
                                                    target:self
                                                  selector:@selector(fadeOutIncrement:)
                                                  userInfo:nil
                                                   repeats:YES];
}

- (void)fadeOutIncrement:(NSTimer *)timer
{
    float currentAlpha = [floaterWindow alphaValue];
    float newAlpha = (currentAlpha - 0.05);
    if (newAlpha < 0)
    {
        // the fade is over
        [self stopFadeTimers];
        // should be no harm here in calling also
        [self stopDelayedFadeTimers]; //but no need to call it either
                                      // and set alpha to 0
        [floaterWindow setAlphaValue:0];
        // make the window go away!
        [self removeWindowFromScreen:self];
    }
    else
    {
        [floaterWindow setAlphaValue:newAlpha];
    }
    [floaterWindow display];
}

- (IBAction)fadeWindowIn:(id)sender
{
    [self stopFadeTimers];
    // should be no harm here in calling also
    [self stopDelayedFadeTimers]; //may be calling this too late...
    [self putWindowInScreen:self];
    // set up new timer -- fade in four times faster than we fade out
    fadeInTimer = [NSTimer scheduledTimerWithTimeInterval:(SECONDS_PER_FRAME/4)
                                                   target:self
                                                 selector:@selector(fadeInIncrement:)
                                                 userInfo:nil
                                                  repeats:YES];
}

- (void)fadeInIncrement:(NSTimer *)timer
{
    float currentAlpha = [floaterWindow alphaValue];
    float newAlpha = (currentAlpha + 0.05);
    if (newAlpha > 1)
    {
        // the fade is over
        [self stopFadeTimers];
        [floaterWindow setAlphaValue:1];
    }
    else
    {
        [floaterWindow setAlphaValue:newAlpha];
    }
    [floaterWindow display];
}

- (void)stopFadeTimers
{
    // stop timer if it's already going
    if (fadeOutTimer)
    {
        if ([fadeOutTimer isValid])
            [fadeOutTimer invalidate];
        fadeOutTimer = nil;
    }
    // stop fadeIn timer as well if it's going!
    if (fadeInTimer)
    {
        if ([fadeInTimer isValid])
            [fadeInTimer invalidate];
        fadeInTimer = nil;
    }
}

- (void)stopDelayedFadeTimers
{
    if (delayedFadeOutTimer)
    {
        // if timer has fired, it will already be invalidated
        if ([delayedFadeOutTimer isValid])
            [delayedFadeOutTimer invalidate];
        delayedFadeOutTimer = nil;
    }
}

- (void)stopPartTwoDelayTimer
{
    if (partTwoDelayTimer)
    {
        if ([partTwoDelayTimer isValid])
            [partTwoDelayTimer invalidate];
        partTwoDelayTimer = nil;
    }
}

- (IBAction)fadeTextIn:(id)sender
{
    [self stopTextFadeTimers];
    // set up new timer
    textFadeInTimer = [NSTimer scheduledTimerWithTimeInterval:SECONDS_PER_FRAME
                                                       target:self
                                                     selector:@selector(textFadeInIncrement:)
                                                     userInfo:nil
                                                      repeats:YES];
}

- (void)textFadeInIncrement:(NSTimer *)timer
{
    float currentAlpha = [[floaterView textColor] alphaComponent];
    float newAlpha = (currentAlpha + 0.05);
    if (newAlpha > 1)
    {
        // the fade is over
        [self stopTextFadeTimers];
        // and set alpha to 1
        [floaterView setTextColor:[NSColor colorWithDeviceWhite:1.0 alpha:1.0]];
    }
    else
    {
        [floaterView setTextColor:[NSColor colorWithDeviceWhite:1.0 alpha:newAlpha]];
    }
    [floaterWindow display];
}

- (IBAction)fadeTextOut:(id)sender
{
    [self stopTextFadeTimers];
    // set up new timer -- does the actual work of fading in the text
    textFadeOutTimer = [NSTimer scheduledTimerWithTimeInterval:SECONDS_PER_FRAME
                                                        target:self
                                                      selector:@selector(textFadeOutIncrement:)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)textFadeOutIncrement:(NSTimer *)timer
{
    float currentAlpha = [[floaterView textColor] alphaComponent];
    float newAlpha = (currentAlpha - 0.05);
    if (newAlpha < 0)
    {
        // the fade is over
        [self stopTextFadeTimers];
        // and set alpha to 0
        [floaterView setTextColor:[NSColor colorWithDeviceWhite:1.0 alpha:0.0]];
    }
    else
    {
        [floaterView setTextColor:[NSColor colorWithDeviceWhite:1.0 alpha:newAlpha]];
    }
    [floaterWindow display];
}

- (void)stopTextFadeTimers
{
    // stop timer if it's already going
    if (textFadeOutTimer)
    {
        [textFadeOutTimer invalidate];
        textFadeOutTimer = nil;
    }
    if (textFadeInTimer)
    {
        [textFadeInTimer invalidate];
        textFadeInTimer = nil;
    }
}
- (void)finalize
{
    // finalize may be too late for this
    [self stopFadeTimers];
    // should be no harm here in calling also
    [self stopDelayedFadeTimers];
    [self stopTextFadeTimers];
    [super finalize];
}
// test cases
- (IBAction)kickItTimerStyle:(id)sender
{
    if ([floaterWindow alphaValue] > 0) // window probably already on screen
    {
        [self stopFadeTimers];
        [self stopDelayedFadeTimers];
        [self stopTextFadeTimers];
        [self putWindowInScreen:self];  // in case not on screen after all
        [self fadeWindowIn:self];       // in case not at full alpha
        [floaterView setDrawText:NO];   // erase existing text
        [self tellViewItNeedsToDisplay:self];
        animateWhileResizing = NO;
        [self zoomToFitText:self];      // initiate zoom
        [self drawTheText:self];        // finally redraws it with text
        [self fadeTextIn:self];         // fade text in

        // this will fade the window after XX secs + 1 second for text to fade in
        delayedFadeOutTimer = [NSTimer scheduledTimerWithTimeInterval:([self delayBeforeFade] + 1)
                                                               target:self
                                                             selector:@selector(delayedFadeOutStart:)
                                                             userInfo:nil
                                                              repeats:NO];
    }
    else    // 0 alpha, window probably not on screen
    {
        [self stopFadeTimers];
        [self stopDelayedFadeTimers];
        [self stopTextFadeTimers];
        [self removeWindowFromScreen:self];
        [floaterWindow setAlphaValue:0.0];
        animateWhileResizing = NO;
        [self showMeTheIconOnly:self];  // show only icon
        [self putWindowInScreen:self];
        [self fadeWindowIn:self];
        [floaterView setTextColor:[NSColor colorWithDeviceWhite:1.0 alpha:0.0]];
        partTwoDelayTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                             target:self
                                                           selector:@selector(partTwo:)
                                                           userInfo:nil
                                                            repeats:NO];
    }
}
- (void)partTwo:(NSTimer *)timer
{
    // resize = 0.33 seconds per 150 pixels... trouble is, we don't know how many pixels we'll move unless we ask
    // so let's just override - (NSTimeInterval)animationResizeTime:(NSRect)newFrame in our window subclass
    // in override, we cap to 1.5 secs (equiv to about 700 pixel movement)
    partTwoDelayTimer = nil;
    // then we can finally fade the text in
    [floaterView setDrawText:NO];
    // well, first thing's first.. re-enable animation!
    animateWhileResizing = YES;
    // resize to fit updated text
    [self zoomToFitText:self];    // doesn't redraw it though because drawText is NO
                                  // now wait 1.5 secs

    [self drawTheText:self];      // final redraws it with text
    [self fadeTextIn:self];       // fade text in
    // set up delayedFadeOutTimer
    // this will fade the window after XX secs + 1 second for text to fade in
    delayedFadeOutTimer = [NSTimer scheduledTimerWithTimeInterval:([self delayBeforeFade] + 1)
                                                           target:self
                                                         selector:@selector(delayedFadeOutStart:)
                                                         userInfo:nil
                                                          repeats:NO];
}

- (IBAction)kickItClickStyle:(id)sender
{
    // this is my Panther "workaround".... simply to ALWAYS draw the other way
    [self kickItTimerStyle:self];
    return;
}

- (void)resizeInstantly
{
    // just zoom to fit the text... do nothing else...
    [self zoomToFitText:self];
}

- (void)setUpDelayedFadeOut
{
    // interrupt any fade going on
    [self stopDelayedFadeTimers];
    delayedFadeOutTimer = [NSTimer scheduledTimerWithTimeInterval:[self delayBeforeFade]
                                                           target:self
                                                         selector:@selector(delayedFadeOutStart:)
                                                         userInfo:nil
                                                          repeats:NO];
}

- (void)delayedFadeOutStart:(NSTimer *)timer
{
    // all we do here is call the real fade out routine
    [self fadeWindowOut:self]; // delayedFadeOutTimer will get cleaned up in this method
}

// for testing purposes -- generates a "random-ish" length string to fill up the
// floater
- (NSString *)randomString
{
    // random number of "words" in string
    int theLength = random() % 10;
    NSMutableString *theString = [NSMutableString stringWithString:@""];
    for (int i = 0; i < theLength; i ++)
        [theString appendString:@"Abcd "];
    return theString;
}


// accessors

- (void)setDelayBeforeFade:(float)newDelay
{
    if (delayBeforeFade < MIN_DELAY_BEFORE_FADEOUT)
        delayBeforeFade = MIN_DELAY_BEFORE_FADEOUT;
    else if (delayBeforeFade > MAX_DELAY_BEFORE_FADEOUT)
        delayBeforeFade = MAX_DELAY_BEFORE_FADEOUT;
    else
        delayBeforeFade = newDelay;
}

- (float)delayBeforeFade
{
    return delayBeforeFade;
}

// pass on requests to modify settings to floaterView
- (void)setTransparency:(float)newTransparency
{
    // error handling done by floaterView
    [floaterView setBgAlpha:newTransparency];

    // do I need to call setNeedsDisplay:YES here?
}

- (float)transparency
{
    return [floaterView bgAlpha];
}

// pass on requests to modify settings to floaterView
- (void)setSize:(int)newSize
{
    // error handling done by floaterView
    [floaterView setCornerRadius:newSize];
}

- (void)setAnimateWhileResizing:(BOOL)newState
{
    animateWhileResizing = newState;
}

- (BOOL)animateWhileResizing
{
    return animateWhileResizing;
}

- (void)setWindowAlphaValue:(float)newAlpha
{
    [floaterWindow setAlphaValue:newAlpha];
}

- (float)windowAlphaValue
{
    return [floaterWindow alphaValue];
}

- (void)setDrawText:(BOOL)theSetting
{
    [floaterView setDrawText:theSetting];
}

// controls whether floater is movable by clicking on background
- (void)setMovable:(BOOL)movableStatus
{
    movable = movableStatus;

    if (movableStatus)
    {
        [floaterWindow ignoreClicks:NO];
    }
    else
    {
        [floaterWindow ignoreClicks:YES];
    }
}

- (BOOL)movable
{
    return movable;
}

- (void)windowSetDragNotifier:(WOSynergyAnchorController *)newDragNotifier
{
    [floaterWindow setDragNotifier:newDragNotifier];
}

// routines for getting/setting window origin as a relative vector between
// the screen segment "anchor point" and the floater "resize center"
// the main controller should use these methods to override the defaults and
// control where the window appears on screen
- (NSPoint)windowOffset
{
    return windowOffset;
}

- (void)setWindowOffset:(NSPoint)newOffset
{
    windowOffset = newOffset;

    // should really forward this to anchorController, if we have an id for it
    [[floaterWindow dragNotifier] setWindowOffset:newOffset];
}

// routines for getting/setting screen segment
- (WOScreenSegmentXCoordinate)xScreenSegment
{
    return xScreenSegment;
}

- (void)setXScreenSegment:(WOScreenSegmentXCoordinate)xCoord
{
    xScreenSegment = xCoord;

    // should really forward this to anchorController, if we have an id for it
    [[floaterWindow dragNotifier] setXGridLocation:xCoord];
}

- (WOScreenSegmentYCoordinate)yScreenSegment
{
    return yScreenSegment;
}

- (void)setYScreenSegment:(WOScreenSegmentYCoordinate)yCoord
{
    yScreenSegment = yCoord;

    // should really forward this to anchorController, if we have an id for it
    [[floaterWindow dragNotifier] setYGridLocation:yCoord];
}

- (BOOL)windowIsVisible
{
    return [floaterWindow isVisible];
}

- (void)setCurrentRating:(WORatingCode)newRating
{
    // pass the rating on to the floater view
    [floaterView setCurrentRating:newRating];
}

- (WORatingCode)currentRating
{
    // get the rating from the floater view
    return [floaterView currentRating];
}

// updates white component of color without changing alpha
- (void)setFgColor:(float)newColor
{
    [floaterView setFgColor:
        [NSColor colorWithDeviceWhite:newColor
                                alpha:[floaterView bgAlpha]]];
}

- (float)fgColor
{
    return [[floaterView fgColor] whiteComponent];
}

// updates white component of color without changing alpha
- (void)setBgColor:(float)newColor
{
    [floaterView setBgColor:
        [NSColor colorWithDeviceWhite:newColor
                                alpha:[floaterView bgAlpha]]];
}

- (float)bgColor
{
    return [[floaterView bgColor] whiteComponent];
}

// accessor to get pointer to floater window
- (id)floaterWindow
{
    return [floaterWindow floaterWindow];
}

// tell floater path to downloaded image
- (void)setAlbumImagePath:(NSString *)path
{
    // forward to floater
    [floaterView setAlbumImagePath:path];
}

- (NSString *)albumImagePath;
{
    // forward to floater
    return [floaterView albumImagePath];
}

- (NSImage *)coverImage
{
    return floaterView.albumImage;    // forward to floater view
}

    // tell floater to display album cover, icon, or nothing
- (void)setFloaterIconType:(WOFloaterIconType)iconType
{
    // forward to floater
    [floaterView setFloaterIconType:iconType];
}

// deprecated
- (void)setScreenIndex:(int)newIndex
{
    screenIndex = newIndex;
}

- (void)setScreenNumber:(int)newScreenNumber
{
    screenNumber = newScreenNumber;
}

@end
