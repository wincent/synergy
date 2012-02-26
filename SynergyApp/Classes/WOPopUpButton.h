//
//  WOPopUpButton.h
//  Synergy
//
//  Created by Wincent Colaiuta on Sun Apr 27 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

//  Simple NSPopUpButton-like class that doesn't draw the down-pointing arrow

#import <Cocoa/Cocoa.h>

#import "WOButtonWithTrackingRect.h"

@class WOButtonState;

#ifndef WO_POPUP_BUTTON_DEFAULT_TIME
// define an interval here double the normal WOButtonState interval
#define WO_POPUP_BUTTON_DEFAULT_TIME  (0.60)
#endif

@interface WOPopUpButton : WOButtonWithTrackingRect {

    // custom popup menu
    NSMenu        *woPopUpMenu;

    // timer, state variables etc to determine whether to popup menu
    WOButtonState *woButtonState;
    NSEvent       *woCurrentEvent;

    // backup copy of target ivar
    id            woForwardTarget;
}

// custom popup menu (used in lieu of Cocoa's standard context menu)
- (void)setPopUpMenu:(NSMenu *)menu;

@end
