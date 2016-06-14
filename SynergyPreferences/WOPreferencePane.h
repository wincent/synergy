//
//  WOPreferencePane.h
//  Synergy
//
//  Created by Greg Hurrell on 18 December 2007.
//  Copyright 2007-present Greg Hurrell.

typedef enum WOPreferencePaneUnselectReply
{
    WOUnselectCancel = 0,
    WOUnselectNow = 1,
    WOUnselectLater = 2
} WOPreferencePaneUnselectReply;

extern NSString *WOPreferencePaneDoUnselectNotification;
extern NSString *WOPreferencePaneCancelUnselectNotification;

//! A clean-room rewrite of NSPreferencePane, or at least as much of it as is necessary to get the SynergyPref target hosted inside
//! the Synergy Preferences.app. This is necessary because the PreferencePanes framework is not compatible with GC on Leopard, and
//! all the other code has already moved to GC...
@interface WOPreferencePane : NSObject {

    // instance variables from PreferencePanes/NSPreferencePane.h
    IBOutlet NSWindow   *_window;
    IBOutlet NSView     *_initialKeyView;
    IBOutlet NSView     *_firstKeyView;
    IBOutlet NSView     *_lastKeyView;
    NSView              *_mainView;
    NSBundle            *_bundle;

}

// public methods from PreferencePanes/NSPreferencePane.h
- (id)initWithBundle:(NSBundle *)bundle;
- (NSBundle *)bundle;
- (NSView *)loadMainView;
- (void)mainViewDidLoad;
- (NSString *)mainNibName;
- (void)assignMainView;
- (void)willSelect;
- (void)didSelect;
- (WOPreferencePaneUnselectReply)shouldUnselect;

//! Posts either a WOPreferencePaneDoUnselectNotification or a WOPreferencePaneCancelUnselectNotification to the default
//! notification center depending on the value of \p shouldUnselect.
- (void)replyToShouldUnselect:(BOOL)shouldUnselect;

- (void)willUnselect;
- (void)didUnselect;
- (void)setMainView:(NSView *)view;
- (NSView *)mainView;
- (NSView *)initialKeyView;
- (void)setInitialKeyView:(NSView *)view;
- (NSView *)firstKeyView;
- (void)setFirstKeyView:(NSView *)view;
- (NSView *)lastKeyView;
- (void)setLastKeyView:(NSView *)view;
- (BOOL)autoSaveTextFields;

#if 0
// not implemented
- (BOOL)isSelected;
- (void)updateHelpMenuWithArray:(NSArray *)inArrayOfMenuItems;
#endif

@end

