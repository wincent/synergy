//
//  WOSynergyAnchorController.m
//  Synergy
//
//  Created by Wincent Colaiuta on Tue Jan 21 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import "WOSynergyAnchorController.h"
#import "WONSScreenExtensions.h"

@implementation WOSynergyAnchorController

- (void)awakeFromNib
{
    // store reasonable defaults for floater location
    xGridLocation = WOSynergyAnchorBottom;
    yGridLocation = WOSynergyAnchorLeft;

    windowOffset = NSMakePoint(DEFAULT_WINDOW_ORIGIN_X,
                               DEFAULT_WINDOW_ORIGIN_Y);

    // default screen number = number of main screen
    if ([[NSScreen screens] count] > 0)
    {
        screenNumber = [[[NSScreen screens] objectAtIndex:0] screenNumber];
    }
    else
    {
        // emergency value...
        screenNumber = 0;
    }

    // make window bounds equal the image bounds (IB won't let us shrink
    // it that much)
    NSRect initialRect = [anchorWindow frame];

    // get needed size (storing it in instance variable to avoid recalculation
    // and rounding errors)
    neededSize = [anchorView viewSize];

    // update size to needed size
    initialRect.size = neededSize;

    // and start in the bottom left
    NSRect neededOrigin = [[[NSScreen screens] objectAtIndex:0] visibleFrame];
    initialRect.origin = neededOrigin.origin;

    [anchorWindow setFrame:initialRect
                  display:NO
                  animate:NO];
}

// called whenever floater preview window is moved
- (void)newOrigin:(NSPoint)windowCentre
           origin:(NSPoint)windowOrigin
           window:(NSWindow *)window
{
    // work out which screen segment the anchor window should appear in
    // there are plenty of opportunities for optimisation here
    NSScreen *floaterScreen = [window screen];
    NSRect screenFrame = [floaterScreen visibleFrame];

    NSPoint normalizedWindowOrigin;
    normalizedWindowOrigin.x = (windowOrigin.x - screenFrame.origin.x);
    normalizedWindowOrigin.y = (windowOrigin.y - screenFrame.origin.y);

    NSPoint normalizedWindowCentre;
    normalizedWindowCentre.x = (windowCentre.x - screenFrame.origin.x);
    normalizedWindowCentre.y = (windowCentre.y - screenFrame.origin.y);

    // divide screen into a 3 x 3 grid
    int segmentWidth = floor(screenFrame.size.width / 3); // number of pixels for one-third screen width
    int segmentHeight = floor(screenFrame.size.height / 3);

    float c = floorf(ABS(normalizedWindowCentre.x) / segmentWidth); // screen segment, lateral grid coordinate 0, 1 or 2

    // do some bounds checking here -- coordinate can conceivably be < 0 or > 2
    // if user drags window partly off the edge of the screen or below dock etc
    if (c < 0)
    {
        c = WOSynergyAnchorLeft;
    }
    else if (c > 2)
    {
        c = WOSynergyAnchorRight;
    }

    float d = floorf(ABS(normalizedWindowCentre.y) / segmentHeight); // vertical coordinate 0, 1 or 2

    // bounds checking
    if (d < 0)
    {
        d = WOSynergyAnchorBottom;
    }
    else if (d > 2)
    {
        d = WOSynergyAnchorTop;
    }

    // storage for the anchor point
    NSPoint anchorPoint;

    // storage for the offset
    NSPoint theOffset;

    // note that unlike the other calculations in this method, here we use
    // the window origin (in the bottom left) as well as the center origin
    // (in the center) to give us the coordinates of the "resize centre"
    switch((int)c)
    {
        case WOSynergyAnchorLeft:

            anchorPoint.x = screenFrame.origin.x;

            theOffset.x =  (windowOrigin.x - anchorPoint.x);

            break;

        case WOSynergyAnchorHorizontalMiddle:

            anchorPoint.x = (screenFrame.origin.x + (segmentWidth * 1.5));

            theOffset.x = (windowCentre.x - anchorPoint.x);

            break;

        case WOSynergyAnchorRight:

            anchorPoint.x = (screenFrame.origin.x + (segmentWidth * 3)); // also equals screenFrame.origin.x + screenFrame.size.width

            theOffset.x = ((windowCentre.x + (windowCentre.x - windowOrigin.x)) - anchorPoint.x);

            break;

        default:
            // unknown value! use default
            anchorPoint.x = screenFrame.origin.x;

            theOffset.x = (DEFAULT_WINDOW_ORIGIN_X - anchorPoint.x);

            break;
    }

    switch((int)d)
    {
        case WOSynergyAnchorBottom:

            anchorPoint.y = screenFrame.origin.y;

            theOffset.y =  (windowOrigin.y - anchorPoint.y);

            break;

        case WOSynergyAnchorVerticalMiddle:

            anchorPoint.y = (screenFrame.origin.y + (segmentHeight * 1.5));

            theOffset.y = (windowCentre.y - anchorPoint.y);

            break;

        case WOSynergyAnchorTop:

            anchorPoint.y = (screenFrame.origin.y + (segmentHeight * 3)); // also equals screenFrame.origin.y + screenFrame.size.height

            theOffset.y = ((windowCentre.y + (windowCentre.y - windowOrigin.y)) - anchorPoint.y);

            break;

        default:
            // unknown value! use default
            anchorPoint.y = screenFrame.origin.y;

            theOffset.y = (DEFAULT_WINDOW_ORIGIN_Y - anchorPoint.y);

            break;
    }

    // store the calculated values
    windowOffset = theOffset;
    screenNumber = [floaterScreen screenNumber];

    // given the segment coordinates, move the anchor window as necessary
    // only move the if segment if the window has changed segments
    if ((c != [self xGridLocation]) || (d != [self yGridLocation]))
    {
        [self moveToSegment:c y:d screen:floaterScreen];
    }
}

// moves the anchor window to its position in the new segment
- (void)moveToSegment:(int)x
                    y:(int)y
               screen:(NSScreen *)screen
{
    [self moveToSegmentMaster:x y:y screen:screen animate:YES];
}

- (void)moveToSegmentNoAnimate:(int)x y:(int)y screen:(NSScreen *)screen
{
    [self moveToSegmentMaster:x y:y screen:screen animate:NO];
}

- (void)moveToSegmentMaster:(int)x y:(int)y screen:(NSScreen *)screen animate:(BOOL)animate
{
    // this will be the new origin for the anchor window
    NSPoint newOrigin;

    // get screen and segment boundaries
    NSRect screenFrame = [screen visibleFrame];

    // divide screen into a 3 x 3 grid
    switch(x)
    {
        case WOSynergyAnchorLeft:
            // left
            newOrigin.x = screenFrame.origin.x;

            break;
        case WOSynergyAnchorHorizontalMiddle:
            // middle
            newOrigin.x = (screenFrame.origin.x + ((screenFrame.size.width / 2)  - (neededSize.width / 2)));

            break;
        case WOSynergyAnchorRight:
            // right
            newOrigin.x = (screenFrame.origin.x + (screenFrame.size.width - neededSize.width));
            break;
        default:
            newOrigin.x = screenFrame.origin.x;

            break;
    }

    switch(y)
    {
        case WOSynergyAnchorBottom:
            // bottom
            newOrigin.y = screenFrame.origin.y;

            break;
        case WOSynergyAnchorVerticalMiddle:
            // middle
            newOrigin.y = (screenFrame.origin.y + ((screenFrame.size.height / 2) - (neededSize.height / 2)));

            break;
        case WOSynergyAnchorTop:
            // top
            newOrigin.y = (screenFrame.origin.y + (screenFrame.size.height - (neededSize.height)));

            break;
        default:
            newOrigin.y = screenFrame.origin.y;

            break;
    }

    NSRect newRect;
    newRect.origin = newOrigin;

    // just use pre-stored value for needed size
    newRect.size = neededSize;

    // move the window
    [anchorWindow setFrame:newRect
                   display:YES
                   animate:animate];

    // update to reflect new location
    [self setXGridLocation:x];
    [self setYGridLocation:y];
}

// wrapper functions (which forward messages on to the view and window)

// view wrapper functions
- (void)viewSetNeedsDisplay:(BOOL)newState
{
    [anchorView setNeedsDisplay:newState];
}

// window wrapper functions
- (void)windowOrderFront:(id)sender
{
    [anchorWindow orderFront:sender];
}

- (void)windowOrderOut:(id)sender
{
    [anchorWindow orderOut:sender];
}

// accessor methods
- (void)setXGridLocation:(WOSynergyAnchorXCoordinate)newX
{
    xGridLocation = newX;
}

- (WOSynergyAnchorXCoordinate)xGridLocation
{
    return xGridLocation;
}

- (void)setYGridLocation:(WOSynergyAnchorYCoordinate)newY
{
    yGridLocation = newY;
}

- (WOSynergyAnchorYCoordinate)yGridLocation
{
    return yGridLocation;
}

- (void)setWindowOffset:(NSPoint)newOffset
{
    windowOffset = newOffset;
}

- (NSPoint)windowOffset
{
    return windowOffset;
}

- (float)xScreenOffset
{
    return xScreenOffset;
}

- (float)yScreenOffset
{
    return yScreenOffset;
}

- (int)screenIndex
{
    // this is deprecated!
    return 0;
}

- (int)screenNumber
{
    return screenNumber;
}

- (void)setScreenNumber:(int)newScreenNumber
{
    screenNumber = newScreenNumber;
}

@end
