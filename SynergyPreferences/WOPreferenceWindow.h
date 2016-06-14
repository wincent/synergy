//
//  WOPreferenceWindow.h
//  Synergy
//
//  Created by Greg Hurrell on 19 December 2007.
//  Copyright 2007-present Greg Hurrell.

@class WOPreferencePane;

@interface WOPreferenceWindow : NSWindow {

    WOPreferencePane *pane;

    //! The target which will be messaged when a termination or window closing sheet is finished.
    //! Will either be the NSApp object (in the case of termination) or nil (in the case of window closing).
    id target;
}

//! \p name The name of the prefPane bundle to be loaded, excluding the prefPane extension.
+ (WOPreferenceWindow *)windowForPane:(NSString *)name;

#pragma mark -
#pragma mark NSApplication delegate methods

//! The preferences window should either be the application delegate (or have these messages forwarded to it by the delegate)
//! so that it can give the user a chance to apply unsaved changes prior to quitting if necessary.
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender;

#pragma mark -
#pragma mark Properties

@property(readonly) WOPreferencePane *pane;

@end
