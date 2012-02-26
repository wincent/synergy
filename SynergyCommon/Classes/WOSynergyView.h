//
//  WOSynergyView.h
//  Synergy
//
//  Created by Wincent Colaiuta on Mon Dec 09 2002.
//  Copyright 2002-2008 Wincent Colaiuta.

#import <AppKit/AppKit.h>

@class WOButtonSet, WOButtonWithTrackingRect, WOButtonState, WOPopUpButton;

// reusable NSView subclass suitable for displaying Synergy controls in the
// menubar, or a demonstration preview version in the Synergy preference panel
@interface WOSynergyView : NSView {

    // these button instances endure for the life of the program
    WOButtonWithTrackingRect    *nextButton;
    WOButtonWithTrackingRect    *prevButton;

    WOPopUpButton               *playButton;

    NSMenu                      *globalMenu;

    // objects for tracking state of button (up, down, clicked, held etc)
    WOButtonState               *nextButtonState;
    WOButtonState               *prevButtonState;

    // the name of the currently active button set
    NSString                    *buttonSet;

    // a dictionary of button sets
    NSMutableDictionary         *loadedButtonSets;
}

- (void)resizeSynergyView;
- (void)resizeAndRefresh:(int)newButtonSpacing;
- (int)calculateControlsStatusItemWidth;

- (void)showNextButton;
- (int)calculateNextButtonPosition;
- (void)hideNextButton;

// old way:
- (void)nextButtonAction;

// new way:
- (void)nextButtonUp;
- (void)nextButtonDown;
- (void)nextButtonExited;
- (void)nextButtonEntered;

- (void)showPrevButton;
- (void)hidePrevButton;
- (void)prevButtonAction;
// no method needed for "calculatePrevButtonPosition" (position is constant)

- (void)prevButtonUp;
- (void)prevButtonDown;
- (void)prevButtonExited;
- (void)prevButtonEntered;

- (void)showPlayButton;
- (int)calculatePlayButtonPosition;
- (void)hidePlayButton;
- (void)playButtonAction;

// toggle play/pause image depending on iTunes state:
- (void)makePlayButtonShowPlayImage;
- (void)makePlayButtonShowPauseImage;
- (void)makePlayButtonShowStopImage;
- (void)makePlayButtonShowPlayPauseImage;

// ghost/unghost next and prev buttons
- (void)disableNextButton;
- (void)enableNextButton;
- (void)disablePrevButton;
- (void)enablePrevButton;

// methods for setting/updating tooltips
- (void)setPlayPauseTooltip:(NSString *)toolTipString;
- (void)setPrevTooltip:(NSString *)toolTipString;
- (void)setNextTooltip:(NSString *)toolTipString;

// methods for getting/setting current button set
- (void)setButtonSet:(NSString *)newSet;
- (NSString *)buttonSet;

// this one returns an actual button set object, rather than a string identifier
- (WOButtonSet *)buttonSetId;

// adds (loads from disk) another button set to our dictionary
- (void)addNewButtonSet:(NSString *)newSet;

// improved implementation
- (void)addPrevButton;
- (void)addPlayButton;
- (void)addNextButton;
- (void)removePrevButton;
- (void)removePlayButton;
- (void)removeNextButton;
- (void)movePrevButton;
- (void)movePlayButton;
- (void)moveNextButton;
- (void)resizeViewRectangle;
- (void)updateButtonSpacing;

// accessors
- (void)setGlobalMenu:(NSMenu *)menu;

@end
