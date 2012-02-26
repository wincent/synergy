//
//  WOButtonSet.h
//  Synergy
//
//  Created by Wincent Colaiuta on Mon Feb 24 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import <Cocoa/Cocoa.h>

@interface WOButtonSet : NSObject {

    // name for this button set
    NSString  *buttonSetName;

    // the button images themselves
    NSImage   *playPauseImage;
    NSImage   *playImage;
    NSImage   *pauseImage;
    NSImage   *stopImage;
    NSImage   *nextImage;
    NSImage   *prevImage;

    // cached size information for button images
    NSSize    playPauseImageSize;
    NSSize    playImageSize;
    NSSize    pauseImageSize;
    NSSize    stopImageSize;
    NSSize    nextImageSize;
    NSSize    prevImageSize;

}

//! Designated initializer
- (id)initWithButtonSetName:(NSString *)theName;

// returns an array of available button set names (NSStrings)
+ (NSArray *)availableButtonSets;

// returns the full path to the directory where new button sets should be installed
+ (NSString *)installPath;

    // returns a button set index in the range of min <-> max
+ (int)randomButtonSetMin:(int)min max:(int)max;

    // wrapper that calls class method of same name
- (int)randomButtonSetMin:(int)min max:(int)max;

// accessors (public)

- (NSString *)buttonSetName;

- (NSImage *)playPauseImage;
- (NSImage *)playImage;
- (NSImage *)pauseImage;
- (NSImage *)stopImage;
- (NSImage *)nextImage;
- (NSImage *)prevImage;

- (NSSize)playPauseImageSize;
- (NSSize)playImageSize;
- (NSSize)pauseImageSize;
- (NSSize)stopImageSize;
- (NSSize)nextImageSize;
- (NSSize)prevImageSize;

@end
