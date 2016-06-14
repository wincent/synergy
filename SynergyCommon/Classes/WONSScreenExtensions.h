//
//  WONSScreenExtensions.h
//  Synergy
//
//  Created by Greg Hurrell on Mon Mar 10 2003.
//  Copyright 2003-present Greg Hurrell.

#import <Cocoa/Cocoa.h>

@interface NSScreen (WONSScreenExtensions)

// returns Cocoa's private _screenNumber ivar for a given NSScreen
- (int)screenNumber;

    // returns the NSScreen corresponding to the supplied screen number,
    // or nil if no such screen exists
+ (NSScreen *)screenFromScreenNumber:(int)screenNumber;

    // returns the position of this screen in the NSScreen "screens" array
- (unsigned)screenIndex;

    // returns the NSScreen from the NSScreen "screens" array which matches the
    // supplied index value, or nil if no such screen exists
+ (NSScreen *)screenFromScreenIndex:(unsigned)screenIndex;

    // takes an NSPoint specified in terms of a given screen's coordinate system
    // and converts it into an "absolute" point expressed relative the the main
    // screen
+ (NSPoint)offsetInScreen:(NSScreen *)screen  // deprecated
                withPoint:(NSPoint)relativeOffset;

@end
