//
//  WOButtonWithTrackingRect.h
//  Synergy
//
//  Created by Wincent Colaiuta on Thu Mar 13 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import <Cocoa/Cocoa.h>

@interface WOButtonWithTrackingRect : NSButton {

@private
    // optional overrides for default NSButton action
    // override neither, one or both
    SEL   _mouseUpAction;
    SEL   _mouseDownAction;

    // these should be specified so as to benefit from the tracking rect feature
    SEL   _mouseEnteredAction;
    SEL   _mouseExitedAction;

    BOOL  ignoreMouseUpOutsideButton;
}

// accessors

- (void)setMouseUpAction:(SEL)selector;
- (void)setMouseDownAction:(SEL)selector;
- (void)setMouseEnteredAction:(SEL)selector;
- (void)setMouseExitedAction:(SEL)selector;

- (SEL)mouseUpAction;
- (SEL)mouseDownAction;
- (SEL)mouseEnteredAction;
- (SEL)mouseExitedAction;

- (void)setIgnoreMouseUpOutsideButton:(BOOL)ignores;

@end
