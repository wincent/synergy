//
//  WOPopUpButton.m
//  Synergy
//
//  Created by Wincent Colaiuta on Sun Apr 27 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

// elements and ideas taken from sample code by Matt Gemmell at:
// http://www.scotlandsoftware.com/products/source/

// for access to Carbon Menu Manager -- which we don't use...
#import <Carbon/Carbon.h>

#import "WOPopUpButton.h"

#import "WOSynergyGlobal.h"
#import "WOButtonState.h"
#import "WOButtonCellWithTrackingRect.h"
#import "WODebug.h"

@interface WOPopUpButton (_woPrivate)

// simple method called on click-and-hold to force the display of the popup menu
- (void)_popUpMenu;

@end

@implementation WOPopUpButton

- (id)initWithFrame:(NSRect)frameRect
{
    // safe values
    woPopUpMenu     = nil;
    woButtonState   = nil;
    woCurrentEvent  = nil;
    woForwardTarget = nil;

    return [super initWithFrame:frameRect];
}

- (void)drawRect:(NSRect)rect
{
    // preserves correct highlighting behaviour
    [super drawRect:rect];
}

- (void)popUpMenuWithEvent:(NSEvent *)theEvent
{
    // make a new event identical to theEvent, but with a location at frame
    // origin (ensures that the menu pops up in the same place each time)
    NSEvent *evt;

    // start menu at base location -- looks great, except when menu is too wide
    // and it "flips" back over so that its *right* edge is at the origin
    NSPoint location = [self frame].origin;

    // this removes all relativity from the equation...
    // the x coordinate will line up with the mouse (doesn't look perfect, but
    // is ok)
    location.x = [[self window] convertScreenToBase:[NSEvent mouseLocation]].x;

    // move it down to the same level as other drop-down menus
    location.y = location.y - 3;

    // alternative 4: try to calculate width using Cocoa calls (real guess work)
    // iterate through menu items until widest is found
    NSEnumerator *enumerator = [[woPopUpMenu itemArray] objectEnumerator];
    NSMenuItem *item;
    float maxWidth = 0;
    // get default menu bar font (default size)
    NSFont *menuBarFont = [NSFont menuFontOfSize:0];
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:menuBarFont forKey:NSFontAttributeName];
    while ((item = [enumerator nextObject]))
    {
        // try to guess width
        float width = [[item title] sizeWithAttributes:attributes].width;
        if (width > maxWidth)
            maxWidth = width;
    }

    // compensate for Cocoa's poor estimation of sizes
    maxWidth = floor(maxWidth * WO_COCOA_TEXT_BUG_FACTOR);

    // and add another control-width just to be safe (flipping is just too ugly,
    // so better to err on the side of caution; original testing was showng that
    // there was a "sweet spot" where the menu would flip even though our test
    // here predicted it wouldn't)
    maxWidth = floor(maxWidth + [self frame].size.width);

    NSRect screenFrame = [[[self window] screen] frame];
    // calculate span from mouse location to edge of screen
    float span =
        ((screenFrame.size.width + screenFrame.origin.x) - [NSEvent mouseLocation].x);

    // if maxWidth > span, menu will "flip", so move it over to the right
    if (maxWidth > span)
    {
        location.x = location.x + [self frame].size.width;
    }
    else
    {
        // else move it over to the left
        location.x = location.x - [self frame].size.width;
    }

    if (([theEvent type] == NSLeftMouseDown) ||
        ([theEvent type] == NSRightMouseDown))
    {
        // mouse event

        evt = [NSEvent mouseEventWithType:[theEvent type]
                                 location:location
                            modifierFlags:[theEvent modifierFlags]
                                timestamp:[theEvent timestamp]
                             windowNumber:[[self window] windowNumber]
                                  context:[theEvent context]
                              eventNumber:[theEvent eventNumber]
                               clickCount:[theEvent clickCount]
                                 pressure:[theEvent pressure]];
    }
    else if ([theEvent type] == NSKeyDown)
    {
        // keyboard event

        evt = [NSEvent keyEventWithType:[theEvent type]
                               location:location
                          modifierFlags:[theEvent modifierFlags]
                              timestamp:[theEvent timestamp]
                           windowNumber:[[self window] windowNumber] // remove even more relativity!
                                context:[theEvent context]
                             characters:[theEvent characters]
            charactersIgnoringModifiers:[theEvent charactersIgnoringModifiers]
                              isARepeat:[theEvent isARepeat]
                                keyCode:[theEvent keyCode]];
    }
    else
        return;

    // disable tooltips (for some reason, they still show if we get here via
    // a right-click)
    NSString *toolTip = [self toolTip];

    if (toolTip)
        [self setToolTip:nil];

    // pop-up the menu
    if (woPopUpMenu)
        // use custom defined menu, if present
        [NSMenu popUpContextMenu:woPopUpMenu withEvent:evt forView:self];
    else
        // otherwise fallback to Cocoa-provided context menu
        [NSMenu popUpContextMenu:[self menu] withEvent:evt forView:self];

    // ensure that we always receive a mouseUp, so we can get rid of
    // highlighting
    if ([theEvent type] == NSRightMouseDown)
    {
        [self highlight:NO];
        [self rightMouseUp:theEvent];
    }
    else
        [self mouseUp:evt];
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
    // act just like in the (left) mouseDown method
    [self highlight:YES];

    // Show our menu
    [self popUpMenuWithEvent:theEvent];
}

- (void)mouseDown:(NSEvent *)theEvent
{
    woCurrentEvent = [theEvent copy];

    // drop menu if control key held
    if ([theEvent modifierFlags] & NSControlKeyMask)
    {
        [self highlight:YES];

        // Show our menu
        [self popUpMenuWithEvent:theEvent];
    }
    else
    {
        woButtonState = [[WOButtonState alloc] initWithTimer:WO_POPUP_BUTTON_DEFAULT_TIME
                                                      target:self
                                                    selector:@selector(_popUpMenu)];

        // notify cell of buttonstate object (horrible kludge to work around Apple limitations)
        WOButtonCellWithTrackingRect *targetCell = [self cell];
        [targetCell setPopUpMenuStateObject:woButtonState];
        [super mouseDown:theEvent];
    }
}

// this method called when WOButtonState timer fires (ie. when button is being pressed-and-held)
- (void)_popUpMenu
{
    // make sure we have a WOButtonState object
    if (!woButtonState)
        return;

    // clean up the object
    woButtonState = nil;

    WOButtonCellWithTrackingRect *targetCell = [self cell];
    [targetCell setPopUpMenuStateObject:nil];

    // tell the cell to stop tracking
    [targetCell setContinueTracking:NO];

    // show the menu
    [self highlight:YES];
    [self popUpMenuWithEvent:woCurrentEvent];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    if (woButtonState)
    {
        if ([woButtonState timerRunning])
            [woButtonState cancelTimer];
        woButtonState = nil;
        WOButtonCellWithTrackingRect *targetCell = [self cell];
        [targetCell setPopUpMenuStateObject:nil];
    }

    if (woCurrentEvent)
        woCurrentEvent = nil;

    // not sure if we always get mouse up, or if we only get it when the user
    // releases the mouse button inside the area of the button
    // should I be releasing it in the popUpMenu routine?

    // I can confirm that under Panther we never get the mouseUp even on a normal
    // click, only after a click-and-hold (ie. after a popup menu has been shown)

    // of course, releasing it in the popUpMenu routine does not help

    [self highlight:NO];
    [super mouseUp:theEvent];
}

- (void)finalize
{
    if (woButtonState)
    {
        // finalize may be too late for this
        WOButtonCellWithTrackingRect *targetCell = [self cell];
        [targetCell setPopUpMenuStateObject:nil];
    }

    [super finalize];
}

- (void)setPopUpMenu:(NSMenu *)menu
{
    woPopUpMenu = menu;
}

@end
