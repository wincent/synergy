// WONSScreenExtensions.m
// Copyright 2003-2011 Wincent Colaiuta. All rights reserved.

#import "WONSScreenExtensions.h"
#import "WODebug.h"

@implementation NSScreen (WONSScreenExtensions)
/*"
This category provides two means for finding a display in a multiple-display
 environment. The first is to provide access to the private _screenNumber ivar
 in the NSScreen class; and the second is to return an unsigned int indicating
 the display's position within the list of displays maintained by NSScreen.

 (Apple does not appear to provide a documented means of finding a display on a
  system between runs of a program. These category seeks to work around that.)

 The screenNumber method may be prone to error if the screenNumber changes
 across reboots (although in testing on my machine, it does not change).

 The screenIndex method may be prone to error if the ordering of screens in the
 display list changes (unable to test this because I only have one screen).
 "*/

// returns Cocoa's private _screenNumber ivar for a given NSScreen
- (int)screenNumber
{
    // on my machine this always returns 69498888, and it seems to be stable
    // across runs and even reboots
    return _screenNumber;
}

// Returns the NSScreen corresponding to the supplied screen number,
// or nil if no such screen exists.
+ (NSScreen *)screenFromScreenNumber:(int)screenNumber
{
    for (NSScreen *object in [NSScreen screens])
    {
        if ([object screenNumber] == screenNumber)
            return object; // match found!
    }
    return nil;
}

// returns the position of this screen in the NSScreen "screens" array
- (unsigned)screenIndex
{
    return [[NSScreen screens] indexOfObject:self];
}

// Returns the NSScreen from the NSScreen "screens" array which matches the
// supplied index value, or nil if no such screen exists.
+ (NSScreen *)screenFromScreenIndex:(unsigned)screenIndex
{
    NSArray *screens = [NSScreen screens];
    return (screenIndex < [screens count]) ? [screens objectAtIndex:screenIndex] : nil;
}

// takes an NSPoint specified in terms of a given screen's coordinate system
// and converts it into an "absolute" point expressed relative the the main
// screen
+ (NSPoint)offsetInScreen:(NSScreen *)screen
                withPoint:(NSPoint)relativeOffset
{
    // translate from "source" coordinate system to
    NSRect sourceFrame = [screen visibleFrame];

    // to "absolute" coordinate system
    NSRect destinationFrame =
        [[[NSScreen screens] objectAtIndex:0] visibleFrame];

    float xDelta = sourceFrame.origin.x - destinationFrame.origin.x;
    float yDelta = sourceFrame.origin.y - destinationFrame.origin.y;

    // this is the point that we will return
    NSPoint adjustedPoint;

    // do the actual mapping from one coordinate system to the other
    adjustedPoint.x = relativeOffset.x - xDelta;
    adjustedPoint.y = relativeOffset.y - yDelta;

    return adjustedPoint;
}

@end
