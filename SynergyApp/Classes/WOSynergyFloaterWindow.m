// WOSynergyFloaterWindow.m
// Synergy
//
// Copyright 2003-present Greg Hurrell.

#import <Carbon/Carbon.h>
#import <AppKit/AppKit.h>

#import "WOPreferences.h"
#import "WOSynergyAnchorController.h"
#import "WOSynergyFloaterWindow.h"
#import "WODebug.h"


@implementation WOSynergyFloaterWindow

- (void)awakeFromNib
{
    dragNotifier = nil;
}

- (id)initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag {

    //Call NSWindow's version of this function, but pass in the all-important value of NSBorderlessWindowMask
    //for the styleMask so that the window doesn't have a title bar
    NSWindow* result = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];

    // make it transparent to mouse clicks when a Carbon app is underneath
    void *ref = [result windowRef];
    ChangeWindowAttributes(ref, kWindowIgnoreClicksAttribute, kWindowNoAttributes);

    // to begin with make window transparent to mouse clicks? (when a Cocoa app is underneath)
    [result setIgnoresMouseEvents:YES];

    //Set the background color to clear so that (along with the setOpaque call below) we can see through the parts
    //of the window that we're not drawing into
    [result setBackgroundColor:[NSColor clearColor]];
    //This next line pulls the window up to the front on top of other system windows.  This is how the Clock app behaves;
    //generally you wouldn't do this for windows unless you really wanted them to float above everything.

    if ([NSApp respondsToSelector:@selector(isSynergyApp)])
    {
        [[WOPreferences sharedInstance] readPrefsFromWithinAppBundle];
        if ([[[WOPreferences sharedInstance] objectOnDiskForKey:@"desktopFloater"] boolValue])
            [result setLevel:CGWindowLevelForKey(kCGDesktopWindowLevelKey)];
        else
            [result setLevel:NSStatusWindowLevel];
    }
    else
        [result setLevel:NSStatusWindowLevel];

    //Let's start with total transparency (invisibility) for all drawing into the window
    [result setAlphaValue:0.0f];
    //but let's turn off opaqueness so that we can see through the parts of the window that we're not drawing into
    [result setOpaque:NO];
    //and while we're at it, make sure the window has a shadow, which will automatically be the shape of our custom content.
    [result setHasShadow:YES];

    // prevent window from being hidden, even if application is
    [result setCanHide:NO];

    // see: https://wincent.com/issues/609
    [result setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];

    return result;
}

- (void)ignoreClicks:(BOOL)clickTransparency
{
    void *ref = [self windowRef];

    if (clickTransparency)
    {
        ChangeWindowAttributes(ref, kWindowIgnoreClicksAttribute, kWindowNoAttributes);     // Carbon
        [self setIgnoresMouseEvents:YES];                                                   // Cocoa
    }
    else
    {
        ChangeWindowAttributes(ref, kWindowNoAttributes, kWindowIgnoreClicksAttribute);     // Carbon
        [self setIgnoresMouseEvents:NO];                                                    // Cocoa
    }
}

// Once the user starts dragging the mouse, we move the window with it. We do this because the window has no title
// bar for the user to drag (so we have to implement dragging ourselves)
- (void)mouseDragged:(NSEvent *)theEvent
{
    NSPoint currentLocation;
    NSPoint newOrigin;
    NSRect  windowFrame = [self frame];

    // grab the current global mouse location; we could just as easily get the mouse location
    // in the same way as we do in -mouseDown:
    currentLocation = [self convertBaseToScreen:[self mouseLocationOutsideOfEventStream]];
    newOrigin.x     = currentLocation.x - initialLocation.x;
    newOrigin.y     = currentLocation.y - initialLocation.y;

#ifndef WO_FIX_FOR_BUG_309
    // lose this limitation to fix bug 309: http://wincent.com/a/support/bugs/show_bug.cgi?id=309
#else
    // Don't let window get dragged up under the menu bar
    NSRect screenFrame = [[[NSScreen screens] objectAtIndex:0] frame];
    if ((newOrigin.y + windowFrame.size.height) > (screenFrame.origin.y + screenFrame.size.height))
        newOrigin.y = screenFrame.origin.y + (screenFrame.size.height - windowFrame.size.height);
#endif

    //go ahead and move the window to the new location
    [self setFrameOrigin:newOrigin];

    // convert newOrigin into a "centreOrigin" so that the anchor knows where
    // centre point lies
    NSPoint centreOrigin;
    centreOrigin.x = (newOrigin.x + (windowFrame.size.width / 2));
    centreOrigin.y = (newOrigin.y + (windowFrame.size.height / 2));

    // and notify dragNotifier (if set) of new origin
    // we pass both the centrepoint of the window and the actual origin (bottom lft)
    // and also a pointer to ourself so that the anchor controller knows what
    // screen we are in...
    [dragNotifier newOrigin:centreOrigin origin:newOrigin window:self];

    // update instance ivars
    myCentreOrigin = centreOrigin;
}

//We start tracking the a drag operation here when the user first clicks the mouse,
//to establish the initial location.
- (void)mouseDown:(NSEvent *)theEvent
{
    NSRect  windowFrame = [self frame];

    //grab the mouse location in global coordinates
    initialLocation = [self convertBaseToScreen:[theEvent locationInWindow]];
    initialLocation.x -= windowFrame.origin.x;
    initialLocation.y -= windowFrame.origin.y;
}

- (NSTimeInterval)animationResizeTime:(NSRect)newFrame
{
    // if super returns anything longer than 1.5 seconds, just return 1.5 secs...
    NSTimeInterval resizeTime = [super animationResizeTime:newFrame];
    if (resizeTime < 1.5)
        return resizeTime;
    else
        return 1.5; // the max: equivalent to approx 700 pixels of movement
}

- (void)setDragNotifier:(WOSynergyAnchorController *)newDragNotifier
{
    dragNotifier = newDragNotifier;
}

- (WOSynergyAnchorController *)dragNotifier
{
    return dragNotifier;
}

- (NSPoint)myCentreOrigin
{
    return myCentreOrigin;
}

- (id)floaterWindow
{
    return self;
}

@end
