//
// WOSynergyPreferencesController.h
// Synergy
//
// Created by Wincent Colaiuta on 19 December 2007.
// Copyright 2007-2009 Wincent Colaiuta.

@class WOPreferenceWindow;

@interface WOSynergyPreferencesController : NSObject {

    WOPreferenceWindow  *prefsWindow;
    BOOL                haveQuitOtherVersions;
    ProcessSerialNumber PSN;
}

#pragma mark -
#pragma mark Interface Builder actions

- (IBAction)showPrefsWindow:(id)sender;

- (IBAction)showHelp:(id)sender;

#pragma mark -
#pragma mark Login items

//! Make the login items match the preferences stored on disk, add or removing Synergy as necessary.
//! Invoked once at launch, and whenever the user clicks the Apply button in the preferences.
- (void)updateLoginItems;

@end
