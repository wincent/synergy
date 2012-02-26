//
//  WOFeedbackWindow.m
//  Synergy
//
//  Created by Wincent Colaiuta on Sat Jan 25 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import <Carbon/Carbon.h>

#import "WOFeedbackWindow.h"
#import "WODebug.h"

@implementation WOFeedbackWindow

// in IB set window class to "WOSynergyFeedbackWindow" so as to call this
- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(unsigned int)aStyle
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)flag
{
    // NSBorderlessWindowMask means we have no title bar
    NSWindow* result = [super initWithContentRect:contentRect
                                        styleMask:NSBorderlessWindowMask
                                          backing:NSBackingStoreBuffered
                                            defer:NO];

    // make it transparent to mouse clicks when a Carbon app is underneath
    void *ref = [result windowRef];

    ChangeWindowAttributes(ref, kWindowIgnoreClicksAttribute, kWindowNoAttributes);

    // make it transparent to mouse clicks when a Cocoa app is underneath
    [result setIgnoresMouseEvents:YES];

    // Set the background color to clear so that (along with the setOpaque call
    // below) we can see through the parts of the window that we're not drawin
    // into
    [result setBackgroundColor:[NSColor clearColor]];

    // This next line pulls the window up to the front on top of other system
    // windows.
    [result setLevel: NSStatusWindowLevel];

    // start with no transparency for all drawing into the window
    [result setAlphaValue:1.0];

    // But turn off opaqueness so that we can see through the parts of the
    // window that we're not drawing into
    [result setOpaque:NO];

    // and while we're at it, make sure the window has NO shadow (shadows
    // added to our images in Fireworks first)
    [result setHasShadow:YES];

    // prevent window from being hidden, even if application is
    [result setCanHide:NO];

    return result;
}

@end
