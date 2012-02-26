//
//  WOButtonCellWithTrackingRect.h
//  Synergy
//
//  Created by Wincent Colaiuta on Mon Apr 28 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import <Cocoa/Cocoa.h>

@class WOButtonState;

// also override the NSButtonCell class
@interface WOButtonCellWithTrackingRect : NSButtonCell {

    @private
    SEL _mouseEnteredAction;
    SEL _mouseExitedAction;

    // horrible kludge, needed by WOPopUpButton to replicate Safari behaviour
    WOButtonState    *popUpMenuStateObject;

    BOOL  woContinueTracking;
}

// accessors

- (void)setMouseEnteredAction:(SEL)selector;
- (void)setMouseExitedAction:(SEL)selector;

- (void)setPopUpMenuStateObject:(WOButtonState *)stateObject;

    // provide a means by which a firing WOButtonState object can tell us to stop
    // tracking
- (void)setContinueTracking:(BOOL)continueTracking;

@end
