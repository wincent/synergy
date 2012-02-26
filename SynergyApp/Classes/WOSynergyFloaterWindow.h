//
//  WOSynergyFloaterWindow.h
//  Synergy
//
//  Created by Wincent Colaiuta on Wed Jan 15 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import <Cocoa/Cocoa.h>

@class WOSynergyAnchorController;

@interface WOSynergyFloaterWindow : NSWindow {

    //! This point is used in dragging to mark the initial click location
    NSPoint                     initialLocation;

    NSPoint                     myCentreOrigin;
    int                         myX;
    int                         myY;

    // pointer to (optional) anchorController object that must be notified whenever receiver is dragged
    // programmer's responsibility to set this to nil when not in use
    WOSynergyAnchorController   *dragNotifier;
}

// method other objects can call to control window's transparency to mouse clicks
- (void)ignoreClicks:(BOOL)clickTransparency;

- (void)setDragNotifier:(WOSynergyAnchorController *)newDragNotifier;

- (WOSynergyAnchorController *)dragNotifier;

- (NSPoint)myCentreOrigin;

- (id)floaterWindow;

@end
