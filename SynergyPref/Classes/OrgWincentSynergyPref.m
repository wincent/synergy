// SynergyPref.m
// Copyright 2002-present Greg Hurrell. All rights reserved.

// Originally based on System Pref Pane tutorial at:
// http://www.cocoadevcentral.com/tutorials/showpage.php?show=00000035.php

#import "OrgWincentSynergyPref.h"
#import "WODistributedNotification.h"
#import "WOSynergyGlobal.h"
#import "WODebug.h"
#import "WOCommon.h"
#import "WOPreferences.h"
#import "WOSynergyView.h"
#import "WOKeyCaptureView.h"
#import "WOSynergyFloaterController.h"
#import "WOProcessManager.h"
#import "WOSynergyAnchorController.h"
#import "WOSynergyFloater.h"
#import "WOSynergyPreferencesController.h"
#import "WOButtonSet.h"
#import "string.h"

#import "WOAudioscrobblerController.h"

// embed build number in executable; visible using what(1)
#import "WOSynergy_Version.h"

// WOPublic macro headers
#import "WOPublic/WOConvenienceMacros.h"

// WOPublic category headers
#import "WOPublic/NSDictionary+WOCreation.h"

#define FLOATER_PREVIEW_DELAY   3.0

#pragma mark -
#pragma mark Global variables

WOPreferences               *WOSynergyPreferencesSingleton  = nil;
NSTimer                     *buttonTimer                    = nil;

@interface OrgWincentSynergyPref (WOPrivate)

- (void)revertButtonSheetClicked:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end

@implementation OrgWincentSynergyPref

// provide access to global
+ (WOPreferences *)prefs
{
    return WOSynergyPreferencesSingleton;
}

- (void)updateButtonStylePopUp
{
    // update button set popup
    NSArray *availableButtonSets = [WOButtonSet availableButtonSets];
    [buttonStylePopUpButton removeAllItems];
    NSEnumerator *enumerator = [availableButtonSets objectEnumerator];
    NSString *setName;
    while ((setName = [enumerator nextObject]))
    {
        [buttonStylePopUpButton addItemWithTitle:setName];
    }
    NSMenu *buttonStyleMenu = [buttonStylePopUpButton menu];
    [buttonStyleMenu addItem:[NSMenuItem separatorItem]];

    NSString *refresh =
        NSLocalizedStringFromTableInBundle(@"Refresh...",
                                           @"",
                                           [NSBundle bundleForClass:
                                               [self class]],
                                           @"Refresh...");

    [buttonStylePopUpButton addItemWithTitle:refresh];
}

// Read prefs, put "about.rtfd" into aboutField etc:
- (void)mainViewDidLoad
{
    synergyPreferences = [WOPreferences sharedInstance];
    [synergyPreferences readPrefsFromWithinPrefPaneBundle];

    // hack so that other classes can funnel access through a single preferences object
    WOSynergyPreferencesSingleton = synergyPreferences;

    /*
     At this point we have the preferences (if any) read from disk and stored
     in the _woPreferencesOnDisk array. Any unset values will be set from the
     defaults.plist file.
     */
    [self updateButtonStylePopUp];

    // the ordering here is critical: do this early in setup; when it was at the
    // end I was getting drawing glitches
    [self calculateSizeAndLocationOfPreview]; // actually sets it too.

    [buttonSpacingBox addSubview:synergyMenuView];

    [synergyMenuView showPrevButton];
    [synergyMenuView showNextButton];
    [synergyMenuView showPlayButton];

    // adjust UI to reflect actual preference settings
    [self matchInterfaceToDictionary:[synergyPreferences woNewPreferences]];

    // think we might need this:
    [self updateGlobalMenuStatus];
    [self updateHotKeySettingControls];
    [self updateFloaterControls];
    [self updateRegistrationObjects];

    // no need to have a Revert button when we've just loaded
    [self disableRevertButton];

    // nor do we need an Apply button yet
    [self disableApplyButton];

    // turn defaults button on or off, depending on if we match the defaults
    [self updateDefaultsButton];

    // set up link to the app -- must set this up before trying to set the startToggleStatus (below)
    synergyApp = [WODistributedNotification makeAppObserver:self selector:@selector(processMessageFromApp:)];

    // update "Start/Stop" button
    [self checkSynergyRunning:nil];

    // set up a timer so that the button will get checked every 5 secs
    buttonTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)(5.0)
                                                   target:self
                                                 selector:@selector(checkSynergyRunning:)
                                                 userInfo:nil
                                                  repeats:YES];

    // load about.rtf into the About pane
    NSString *aboutPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"about" ofType:@"rtf"];
    NSAttributedString *aboutString = [[NSAttributedString alloc] initWithPath:aboutPath documentAttributes:nil];

    // store these so our scrolling routine knows how far to scroll
    aboutStringSize     = [aboutString size];
    aboutFieldBounds    = [aboutField bounds]; // from NSView

    // construct NSMutableAttributedString with height == view size

    // will build it up from simple lines of "padding"
    NSAttributedString *oneLineOfPadding = [[NSAttributedString alloc] initWithString:@" \n"];
    NSMutableAttributedString *padding = [[NSMutableAttributedString alloc] init];

    // workaround for appkit bug (NSAttributedString returns inaccurate
    // estimate for size); returned size appears to be too big
#define WO_APPKIT_STRING_SIZE_BUG_FACTOR    1.15

    while ([padding size].height < (aboutFieldBounds.size.height * WO_APPKIT_STRING_SIZE_BUG_FACTOR))
        // keep adding lines until padding is sufficiently long
        [padding appendAttributedString:oneLineOfPadding];

    NSMutableAttributedString *paddedAboutString = [[NSMutableAttributedString alloc] init];
    [paddedAboutString setAttributedString:padding];
    [paddedAboutString appendAttributedString:aboutString];

    // must make bottom padding longer due to size bug
    // (in order to scroll the text all the way off the top of the view we
    // must scroll to body text height + padding height; the size bug, however,
    // means that we must really scroll farther than those numbers would
    // indicate. The pre-padding is scaled to account for the bug. But we cannot
    // scale the body text, and so we must scale the post-padding even further
    // so as to account for the incorrect sizing of the body text. If we do not
    // do this then the scrolling hits the "limit" and won't go any futher,
    // leaving the tail end of the text still on the screen.)

    // base height of padding (absolute pixels)
    float basePadding = [padding size].height / WO_APPKIT_STRING_SIZE_BUG_FACTOR;

    // error (absolute pixels) introduced by size discrepancy in aboutStringSize
    // (tends to zero as WO_APPKIT_STRING_SIZE_BUG_FACTOR tends to 1.0)
    float additonalPadding = aboutStringSize.height * (1.0 - (1.0 / WO_APPKIT_STRING_SIZE_BUG_FACTOR));

    while ([padding size].height < ((basePadding + additonalPadding) * WO_APPKIT_STRING_SIZE_BUG_FACTOR))
        // keep adding lines until padding is sufficiently long
        [padding appendAttributedString:oneLineOfPadding];

    [paddedAboutString appendAttributedString:padding];

    // now actually draw the string in the NSTextView
    [aboutField replaceCharactersInRange:NSMakeRange(0,0)
                                withRTFD:[paddedAboutString RTFDFromRange:NSMakeRange(0,[paddedAboutString length])
                                                       documentAttributes:nil]];

    // safe starting value for this:
    delayedFadeOutTimer = nil;

    floaterController = [[WOSynergyFloaterController alloc] init];

    // this next line calls awakeFromNib on floaterController
    if(![NSBundle loadNibNamed:@"synergyFloater" owner:floaterController])
    {
        ELOG(@"An error occurred while trying to load the nib file for the "
             @"floater");
    };

    // based on preferences, tell floater how we want it to appear
    [self configureFloater];

    anchorController = [[WOSynergyAnchorController alloc] init];

    if(![NSBundle loadNibNamed:@"pin" owner:anchorController])
    {
        ELOG(@"An error occurred while trying to load the nib file for the "
             @"anchor window");
    };

    // make sure floaterContoller knows about anchorController
    [floaterController windowSetDragNotifier:anchorController];

    // and then it's safe to do this: both floaterController and anchorController
    // will be notified
    [self updateFloaterPositionIVars];

    // move the floater (doesn't display it, just moves it)
    [floaterController moveGivenOffset:NSMakePoint([[synergyPreferences objectForKey:_woFloaterHorizontalOffset] floatValue],
                                                   [[synergyPreferences objectForKey:_woFloaterVerticalOffset] floatValue])
                              xSegment:[[synergyPreferences objectForKey:_woFloaterHorizontalSegment] intValue]
                              ySegment:[[synergyPreferences objectForKey:_woFloaterVerticalSegment] intValue]];

    // move the anchor
    [anchorController moveToSegmentNoAnimate:[[synergyPreferences objectForKey:_woFloaterHorizontalSegment] intValue]
                                           y:[[synergyPreferences objectForKey:_woFloaterVerticalSegment] intValue]
                                      screen:[[floaterController floaterWindow] screen]];

    // stuff the app will want to be told about immediately
    enableLastFmLastValue = [[NSUserDefaults standardUserDefaults] boolForKey:@"enableLastFm"];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self
                                                              forKeyPath:@"values.enableLastFm"
                                                                 options:0
                                                                 context:NULL];
    hitAmazonLastValue = [[NSUserDefaults standardUserDefaults] boolForKey:@"hitAmazon"];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self
                                                              forKeyPath:@"values.hitAmazon"
                                                                 options:0
                                                                 context:NULL];
    extraVisualFeedbackForOtherHotKeysValue = [[NSUserDefaults standardUserDefaults] boolForKey:@"ExtraVisualFeedbackForOtherHotKeys"];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self
                                                              forKeyPath:@"values.ExtraVisualFeedbackForOtherHotKeys"
                                                                 options:0
                                                                 context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // change dictionary has _never_ worked properly with NSUserDefaultsController under any version of Mac OS X
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *changes = [NSMutableDictionary dictionary];
    BOOL newValue = [defaults boolForKey:@"enableLastFm"];
    if (newValue != enableLastFmLastValue)
    {
        enableLastFmLastValue = newValue;
        [changes setObject:WO_BOOL(newValue) forKey:@"enableLastFm"];

    }
    newValue = [defaults boolForKey:@"hitAmazon"];
    if (newValue != hitAmazonLastValue)
    {
        hitAmazonLastValue = newValue;
        [changes setObject:WO_BOOL(newValue) forKey:@"hitAmazon"];
    }
    newValue = [defaults boolForKey:@"ExtraVisualFeedbackForOtherHotKeys"];
    if (newValue != extraVisualFeedbackForOtherHotKeysValue)
    {
        extraVisualFeedbackForOtherHotKeysValue = newValue;
        [changes setObject:WO_BOOL(newValue) forKey:@"ExtraVisualFeedbackForOtherHotKeys"];
    }
    if ([changes count] > 0)
        [synergyApp sendUpdatedPrefsToApp:changes];
}

// tell floater how we want it to appear
- (void)configureFloater
{
    // good starting values
    [floaterController setWindowAlphaValue:0];
    [floaterController setDrawText:YES];
    [floaterController setAnimateWhileResizing:NO];
    [floaterController setDelayBeforeFade:5.0];

    // tell floater to display Synergy icon
    [floaterController setFloaterIconType:WOFloaterIconSynergyIcon];

    // set fade delay, background transparency and size based on preferences
    [floaterController setDelayBeforeFade:
        [[synergyPreferences objectForKey:_woFloaterDurationPrefKey] floatValue]];
    [floaterController setTransparency:
        [[synergyPreferences objectForKey:_woFloaterTransparencyPrefKey] floatValue]];
    [floaterController setSize:
        [[synergyPreferences objectForKey:_woFloaterSizePrefKey] intValue]];

    // default strings for preview
    [floaterController setStrings:
        NSLocalizedStringFromTableInBundle(@"Synergy floater title",
                                           @"",
                                           [NSBundle bundleForClass:
                                               [self class]],
                                           @"Synergy floater preview title")

                            album:
        NSLocalizedStringFromTableInBundle(@"This is a preview of the floater",
                                           @"",
                                           [NSBundle bundleForClass:
                                               [self class]],
                                           @"Synergy floater preview descriptive text")

                           artist:
        NSLocalizedStringFromTableInBundle(@"Read more about the floater in the Synergy Help",
                                           @"",
                                           [NSBundle bundleForClass:
                                               [self class]],
                                           @"Synergy floater preview help suggestion")

                         composer:@" "];
}

- (void)processMessageFromApp:(NSNotification *)message
/*"
 Processes a message received via the Cocoa Runtime's NSDistributedNotification
 mechanism. (This method is named processMessageFromApp: although the truth is
 that the message could be received from any sender which identifies itself with
 the object @"WODistributedNotificationIdentifier").

 It should be bourne in mind that the message may be received at a time when the
 prefPane is displaying a modal sheet (for example, a hot-key customisation
 sheet). In these cases there are no negative side-effects because the only
 response taken is to update the synergyApp "appState" variable and to toggle
 the appearance of the start/stop toggle in the UI.
"*/
{


    if ([[message object] isEqualToString:[NSString stringWithFormat:@"%d", WODNPaneStatus]])
    {
        // tell app that we are running
        [synergyApp notifyApp:WODNPaneIsRunning];

        // update toggle state in UI if required
        if (startToggleState == NO)
        {
            // Synergy is running, so set ToggleState to YES (running)
            startToggleState = YES;
            // adjust the toggle button to show an appropriate state
            [self makeToggleShowStop];
        }

        // update state variable to reflect that the app is also running
        [synergyApp setAppState:WODNRunning];
    }

    if ([[message object] isEqualToString:[NSString stringWithFormat:@"%d", WODNAppLaunched]])
    {
        // tell app that we are running
        [synergyApp notifyApp:WODNPaneIsRunning];

        // update toggle state in UI if required
        if (startToggleState == NO)
        {
            // Synergy is running, so set ToggleState to YES (running)
            startToggleState = YES;
            // adjust the toggle button to show an appropriate state
            [self makeToggleShowStop];
        }

        // update state variable to reflect that the app is also running
        [synergyApp setAppState:WODNRunning];
    }

    if ([[message object] isEqualToString:[NSString stringWithFormat:@"%d", WODNAppIsRunning]])
    {
        if (startToggleState == NO)
        {
            // Synergy is running, so set ToggleState to YES (running)
            startToggleState = YES;
            // adjust the toggle button to show an appropriate state
            [self makeToggleShowStop];
        }

        // update state variable to reflect that the app is also running
        [synergyApp setAppState:WODNRunning];
    }

    if ([[message object] isEqualToString:[NSString stringWithFormat:@"%d", WODNAppWillQuit]])
    {
        // update toggle state in UI if required
        if (startToggleState)
        {
            startToggleState = NO;
            // adjust the toggle button to show an appropriate state
            [self makeToggleShowStart];
        }

        // update state variable to reflect that the app is also running
        [synergyApp setAppState:WODNStopped];
    }

    if ([[message object] isEqualToString:[NSString stringWithFormat:@"%d", WODNPrefToggleSerialNoticePref]])
    {
        // simply toggle the value for this pref item
        if ([[synergyPreferences objectForKey:_woSerialNumberNoticePrefKey] boolValue])
        {
            [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                                   forKey:_woSerialNumberNoticePrefKey
                         flushImmediately:YES];
        }
        else
        {
            [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                                   forKey:_woSerialNumberNoticePrefKey
                         flushImmediately:YES];
        }
    }

    if ([[message object] isEqualToString:[NSString stringWithFormat:@"%d", WODNPrefNoteButtonSetLoaded]])
    {
        // at this point, Synergy.app has already updated the on-disk copy of prefs
        NSString *newSet = [[message userInfo] objectForKey:@"setName"];

        // update our "on disk" dictionary to reflect change made by Synergy.app
        [[synergyPreferences _woPreferencesOnDisk] setObject:newSet forKey:_woButtonStylePrefKey];

        // update in-memory copy of prefs also
        [synergyPreferences setObject:newSet forKey:_woButtonStylePrefKey];

        [self updateButtonStylePopUp];
        [buttonStylePopUpButton selectItemWithTitle:newSet];
        [synergyMenuView setButtonSet:newSet];
        [self resizeButtonPreview];
        [self changeButtonStyle];
        [self updateRevertButton];
        [self updateDefaultsButton];
        [self updateApplyButton];
    }

    // have new preferences been written out to disk?
    if ([[message name] isEqualToString:WO_NEW_PREFS_FROM_APP_TO_PREFS])
    {
        NSString *serializedPreferences = [message object];
        NSData *data = [serializedPreferences dataUsingEncoding:NSUTF8StringEncoding];
        NSString *error = nil;
        NSDictionary *newPrefs = [NSPropertyListSerialization propertyListFromData:data
                                                                  mutabilityOption:NSPropertyListImmutable
                                                                            format:NULL
                                                                  errorDescription:&error];
        if (error)
        {
            NSLog(@"+[NSPropertyListSerialization propertyListFromData:mutabilityOption:format:errorDescription:] reported error: %@", error);
            return;
        }
        if (!newPrefs)
        {
            NSLog(@"-[OrgWincentSynergyPref processMessageFromApp:] deserialization failed");
            return;
        }
        if ([newPrefs isKindOfClass:[NSDictionary class]])
        {
            // make Cocoa Bindings pick up the change(s)
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSEnumerator *keys = [newPrefs keyEnumerator];
            id prefKey;
            while ((prefKey = [keys nextObject]))
                [defaults setObject:[newPrefs objectForKey:prefKey]
                             forKey:prefKey];
        }
    }
}

- (void)calculateSizeAndLocationOfPreview
{
    // calculate the size and location of the view

    int previewWidth = [synergyMenuView calculateControlsStatusItemWidth];

    NSRect controlsPreviewFrame =
        NSMakeRect(93 - (previewWidth / 2), // ensure view is centred in NSBox
                   50,
                   previewWidth,
                   controlViewHeight);


    [synergyMenuView setFrame:controlsPreviewFrame];
}


- (WOPreferencePaneUnselectReply) shouldUnselect
{
    // display warning if there are unsaved changes
    if ([synergyPreferences unsavedChanges] == NO)
        return WOUnselectNow;
    else
    {
        // unapplied changes -- need to display sheet
        NSString *title =
            NSLocalizedStringFromTableInBundle(@"Apply unsaved changes?",
                                               @"",
                                               [NSBundle bundleForClass:[self class]],
                                               @"unsaved changes title");

        NSString *message =
            NSLocalizedStringFromTableInBundle
            (@"You have modified your settings but did not apply them. If you want to do so, click the Apply button. Otherwise, click Don't Apply or Cancel.",
             @"",
             [NSBundle bundleForClass:[self class]],
             @"unsaved changes explanation");

        NSString *defaultButton =
            NSLocalizedStringFromTableInBundle(@"Apply",
                                               @"",
                                               [NSBundle bundleForClass:[self class]],
                                               @"Apply unsaved changes button");

        NSString *alternateButton =
            NSLocalizedStringFromTableInBundle(@"Don't Apply",
                                               @"",
                                               [NSBundle bundleForClass:[self class]],
                                               @"Don't apply unsaved changes button");

        NSString *otherButton =
            NSLocalizedStringFromTableInBundle(@"Cancel",
                                               @"",
                                               [NSBundle bundleForClass:[self class]],
                                               @"Cancel button");

        NSView *selfView = [self mainView];
        NSWindow *parentOfView = [selfView window];

        NSBeginAlertSheet(title,
                          defaultButton,
                          alternateButton,
                          otherButton,
                          parentOfView,
                          self,
                          @selector(sheetButtonClicked:returnCode:contextInfo:),
                          nil,
                          nil,
                          message);

        // for now... (sheetDidEnd will be called after the user makes a
        // selection)
        return WOUnselectLater;
    }
}

- (void)sheetButtonClicked:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
    if (returnCode == NSAlertDefaultReturn) // "Apply" button
        [self applyChanges];
    [self replyToShouldUnselect:(returnCode != NSAlertOtherReturn)];
}

- (void)didUnselect
{
    // breakdown connection with app, if it exists
    [synergyApp notifyApp:WODNPaneWillQuit];
    [synergyApp setSuspended:YES];
    // we tell the app we're about to quit, even though we might just be hiding
}

- (void)didSelect
{
    // behave as though revert button was clicked -- discard unsaved changes -- brings us into line with Apple behaviour
    [self revertButtonSheetClicked:nil returnCode:NSAlertDefaultReturn contextInfo:NULL];

    [self checkSynergyRunning:nil];
    [synergyApp setSuspended:NO];
    [synergyApp notifyApp:WODNPaneLaunched];
}

- (void)finalize
{
    // finalize may be too late for this
    // break connection with app
    [synergyApp removeAppObserver];
    [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self
                                                                 forKeyPath:@"values.enableLastFm"];

    if (scrollTimer)
    {
        if ([scrollTimer isValid])
            [scrollTimer invalidate];
    }

    [super finalize];
}

- (IBAction)applyButtonClicked:(id)sender
{
    [self applyChanges];
}

- (void)applyChanges
{
    [self disableRevertButton];
    [self disableApplyButton];

    // Ordering is important here: the writePrefs method must be called *before*
    // we update the login items because the latter bases its actions on the
    // state of the preferences on the disk.
    [synergyPreferences writePrefsFromPrefPaneBundle];
    WOSynergyPreferencesController *controller = [NSApp delegate];
    [controller updateLoginItems];
    [synergyApp notifyApp:WODNAppReadPrefs];
}

- (void) disableApplyButton
{
    [applyButton setEnabled:NO];
    [applyButton setToolTip:
        NSLocalizedStringFromTableInBundle
        (@"Apply changes permanently\n(Disabled because there are no changes)",
         @"",
         [NSBundle bundleForClass:[self class]],
         @"Tool-tip for Apply button (ghosted)")];
}

- (void) enableApplyButton
{
    [applyButton setEnabled:YES];
    [applyButton setToolTip:
        NSLocalizedStringFromTableInBundle
        (@"Apply changes permanently",
         @"",
         [NSBundle bundleForClass:[self class]],
         @"Tool-tip for Apply button (active)")];
}

- (void) updateApplyButton
{
    if ([synergyPreferences unsavedChanges])
        [self enableApplyButton];
    else
        [self disableApplyButton];
}

- (void) disableRevertButton
{
    [revertButton setEnabled:NO];
    [revertButton setToolTip:
        NSLocalizedStringFromTableInBundle
        (@"Revert to last-saved state\n(Disabled because there are no changes)",
         @"",
         [NSBundle bundleForClass:[self class]],
         @"Tool-tip for Revert button (ghosted)")];
}

- (void) enableRevertButton
{
    [revertButton setEnabled:YES];
    [revertButton setToolTip:
        NSLocalizedStringFromTableInBundle
        (@"Revert to last-saved state", @"",
         [NSBundle bundleForClass:[self class]],
         @"Tool-tip for Revert button (active)")];
}

// enable/disable revert button as appropriate
- (void) updateRevertButton
{
    if ([synergyPreferences unsavedChanges])
        [self enableRevertButton];
    else
        [self disableRevertButton];
}

- (IBAction)defaultsButtonClicked:(id)sender
{
    // display a confirmation sheet; request: http://wincent.com/a/support/bugs/show_bug.cgi?id=445
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *title = NSLocalizedStringFromTableInBundle(@"Really switch to defaults?", @"", bundle, @"Really switch to defaults?");
    NSString *message = NSLocalizedStringFromTableInBundle
        (@"This will set all preferences, including preferences in other tabs, back to their default values. "
         @"Are you sure you want to do this?", @"", bundle, @"Defaults button explanation");
    NSString *defaultButton = NSLocalizedStringFromTableInBundle(@"Use defaults", @"", bundle, @"Use defaults button");
    NSString *alternateButton = NSLocalizedStringFromTableInBundle(@"Cancel", @"", bundle, @"Cancel button");
    NSBeginAlertSheet(title, defaultButton, alternateButton, nil, [[self mainView] window], self,
                      @selector(defaultsButtonSheetClicked:returnCode:contextInfo:), nil, NULL, message);
}

- (void)defaultsButtonSheetClicked:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
    if (returnCode == NSAlertDefaultReturn)
    {
        // set newPreferences to equal defaults
        [synergyPreferences resetToDefaults];

        // the idea is that the serial number and registration email (if any) aren't
        // reset with the rest of the preferences
        [self matchInterfaceToDictionary:[synergyPreferences woNewPreferences]];
        [self disableDefaultsButton];
        [self updateRevertButton];
        [self updateApplyButton];
        [self updateControlHidingToggleStatus];
        [self updateHotKeySettingControls];
        [self updateGlobalMenuStatus];
        [self updateFloaterControls];
        [self updateFloaterPositionIVars];

        [synergyMenuView setButtonSet:[[synergyPreferences woNewPreferences] objectForKey:_woButtonStylePrefKey]];
        [self resizeButtonPreview];
        [self changeButtonStyle];


        // move the floater (doesn't display it, just moves it)
        [floaterController moveGivenOffset:NSMakePoint([[synergyPreferences objectForKey:_woFloaterHorizontalOffset] floatValue],
                                                       [[synergyPreferences objectForKey:_woFloaterVerticalOffset] floatValue])
                                  xSegment:[[synergyPreferences objectForKey:_woFloaterHorizontalSegment] intValue]
                                  ySegment:[[synergyPreferences objectForKey:_woFloaterVerticalSegment] intValue]];

        // move the anchor
        [anchorController moveToSegmentNoAnimate:[[synergyPreferences objectForKey:_woFloaterHorizontalSegment] intValue]
                                               y:[[synergyPreferences objectForKey:_woFloaterVerticalSegment] intValue]
                                          screen:[[floaterController floaterWindow] screen]];
    }
}

- (IBAction)helpButtonClicked:(id)sender
{
    if (![[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://synergy.wincent.com/Synergy%20Help.html#top"]])
        NSLog(@"Error while trying to open http://synergy.wincent.com/Synergy%%20Help.html#top");
}

- (IBAction)launchAtLoginClicked:(id)sender
{
    if ([launchAtLogin state] == NSOffState)
        [synergyPreferences setObject:[NSNumber numberWithBool:NO] forKey:_woLaunchAtLoginPrefKey];
    else
        [synergyPreferences setObject:[NSNumber numberWithBool:YES] forKey:_woLaunchAtLoginPrefKey];

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (void) disableDefaultsButton
{
    [defaultsButton setEnabled:NO];
    [defaultsButton setToolTip:
        NSLocalizedStringFromTableInBundle
        (@"Reset to default settings\n(Disabled because settings already match defaults)",
         @"",
         [NSBundle bundleForClass:[self class]],
         @"Tool-tip for Defaults button (ghosted)")];
}

- (void) enableDefaultsButton
{
    [defaultsButton setEnabled:YES];
    [defaultsButton setToolTip:
        NSLocalizedStringFromTableInBundle
        (@"Reset to default settings", @"",
         [NSBundle bundleForClass:[self class]],
         @"Tool-tip for Defaults button (active)")];
}

// enable/disable default button as appropriate
- (void) updateDefaultsButton
{
    if ([synergyPreferences preferencesEqualDefaults])
        [self disableDefaultsButton];
    else
        [self enableDefaultsButton];
}

- (IBAction)revertButtonClicked:(id)sender
{
    // display a confirmation sheet; request: http://wincent.com/a/support/bugs/show_bug.cgi?id=445
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *title = NSLocalizedStringFromTableInBundle(@"Really revert to previous settings?", @"", bundle,
                                                         @"Really revert to previous settings?");
    NSString *message = NSLocalizedStringFromTableInBundle
        (@"This will revert all preferences, including preferences in other tabs, back to their previous values. "
         @"Are you sure you want to do this?", @"", bundle, @"Revert button explanation");
    NSString *defaultButton = NSLocalizedStringFromTableInBundle(@"Revert all", @"", bundle, @"Revert all button");
    NSString *alternateButton = NSLocalizedStringFromTableInBundle(@"Cancel", @"", bundle, @"Cancel button");
    NSBeginAlertSheet(title, defaultButton, alternateButton, nil, [[self mainView] window], self,
                      @selector(revertButtonSheetClicked:returnCode:contextInfo:), nil, NULL, message);
}

- (void)revertButtonSheetClicked:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
    if (returnCode == NSAlertDefaultReturn)
    {
        [self disableRevertButton];
        [self disableApplyButton];
        [synergyPreferences revertToSaved];
        [self matchInterfaceToDictionary:[synergyPreferences woNewPreferences]];
        [self updateDefaultsButton];
        [self updateControlHidingToggleStatus];
        [self updateHotKeySettingControls];
        [self updateGlobalMenuStatus];
        [self updateFloaterControls];
        [self updateFloaterPositionIVars];

        [synergyMenuView setButtonSet:[[synergyPreferences woNewPreferences] objectForKey:_woButtonStylePrefKey]];
        [self resizeButtonPreview];
        [self changeButtonStyle];

        // move the floater (doesn't display it, just moves it)
        [floaterController moveGivenOffset:NSMakePoint([[synergyPreferences objectForKey:_woFloaterHorizontalOffset] floatValue],
                                                       [[synergyPreferences objectForKey:_woFloaterVerticalOffset] floatValue])
                                  xSegment:[[synergyPreferences objectForKey:_woFloaterHorizontalSegment] intValue]
                                  ySegment:[[synergyPreferences objectForKey:_woFloaterVerticalSegment] intValue]];

        // move the anchor
        [anchorController moveToSegmentNoAnimate:[[synergyPreferences objectForKey:_woFloaterHorizontalSegment] intValue]
                                               y:[[synergyPreferences objectForKey:_woFloaterVerticalSegment] intValue]
                                          screen:[[floaterController floaterWindow] screen]];
    }
}

- (IBAction)setNextKeyClicked:(id)sender
{
    // update description
    [hotKeySheetDescriptionTextField setStringValue:
        NSLocalizedStringFromTableInBundle(
            @"Next track",
            @"",
            [NSBundle bundleForClass:[self class]],
            @"Next track action description")];

    // update to reflect current hotkey setting (if any)

    // modifier flags
    [keyCaptureView setModifierFlags:
        [[synergyPreferences objectForKey:_woNextModifierPrefKey]
            unsignedIntValue]];

    // raw key code
    [keyCaptureView setKeyCode:
        [[synergyPreferences objectForKey:_woNextKeycodePrefKey]
            unsignedShortValue]];

    // the unicode representation
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[synergyPreferences objectForKey:
            _woNextUnicodePrefKey]]];

    [self startHotKeySheet:@"next"];
}

- (IBAction)setPlayKeyClicked:(id)sender
{
    // update description
    [hotKeySheetDescriptionTextField setStringValue:
        NSLocalizedStringFromTableInBundle(
            @"Play/Pause",
            @"",
            [NSBundle bundleForClass:[self class]],
            @"Play/Pause action description")];

    // update to reflect current hotkey setting (if any)

    // modifier flags
    [keyCaptureView setModifierFlags:
        [[synergyPreferences objectForKey:_woPlayModifierPrefKey]
            unsignedIntValue]];

    // raw key code
    [keyCaptureView setKeyCode:
        [[synergyPreferences objectForKey:_woPlayKeycodePrefKey]
            unsignedShortValue]];

    // the unicode representation
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[synergyPreferences objectForKey:
            _woPlayUnicodePrefKey]]];

    [self startHotKeySheet:@"play"];
}

- (IBAction)setPrevKeyClicked:(id)sender
{
    // update description
    [hotKeySheetDescriptionTextField setStringValue:
        NSLocalizedStringFromTableInBundle(
            @"Previous track",
            @"",
            [NSBundle bundleForClass:[self class]],
            @"Previous track action description")];

    // update to reflect current hotkey setting (if any)

    // modifier flags
    [keyCaptureView setModifierFlags:
        [[synergyPreferences objectForKey:_woPrevModifierPrefKey]
            unsignedIntValue]];

    // raw key code
    [keyCaptureView setKeyCode:
        [[synergyPreferences objectForKey:_woPrevKeycodePrefKey]
            unsignedShortValue]];

    // the unicode representation
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[synergyPreferences objectForKey:
            _woPrevUnicodePrefKey]]];

    [self startHotKeySheet:@"prev"];
}

- (IBAction)setQuitKeyClicked:(id)sender
{
    // update description
    [hotKeySheetDescriptionTextField setStringValue:
        NSLocalizedStringFromTableInBundle(
            @"Quit Synergy",
            @"",
            [NSBundle bundleForClass:[self class]],
            @"Quit Synergy action description")];

    // update to reflect current hotkey setting (if any)

    // modifier flags
    [keyCaptureView setModifierFlags:
        [[synergyPreferences objectForKey:_woQuitModifierPrefKey]
            unsignedIntValue]];

    // raw key code
    [keyCaptureView setKeyCode:
        [[synergyPreferences objectForKey:_woQuitKeycodePrefKey]
            unsignedShortValue]];

    // the unicode representation
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[synergyPreferences objectForKey:
            _woQuitUnicodePrefKey]]];

    [self startHotKeySheet:@"quit"];
}

- (IBAction)setShowHideKeyClicked:(id)sender
{
    // update description
    [hotKeySheetDescriptionTextField setStringValue:
        NSLocalizedStringFromTableInBundle(
            @"Show/Hide Synergy menu buttons",
            @"",
            [NSBundle bundleForClass:[self class]],
            @"Show/Hide Synergy menu buttons")];

    // update to reflect current hotkey setting (if any)

    // modifier flags
    [keyCaptureView setModifierFlags:[[synergyPreferences objectForKey:_woShowHideModifierPrefKey] unsignedIntValue]];

    // raw key code
    [keyCaptureView setKeyCode:[[synergyPreferences objectForKey:_woShowHideKeycodePrefKey] unsignedShortValue]];

    // the unicode representation
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[synergyPreferences objectForKey:_woShowHideUnicodePrefKey]]];

    [self startHotKeySheet:@"showHide"];
}

- (IBAction)hotKeySheetCancelButtonClicked:(id)sender
{
    // store exit status here for processing by processHotKeySheetResult method
    hotKeySheetExitStatus = SHEET_CANCEL;
    [self endHotKeySheet];
}

- (IBAction)hotKeySheetOKButtonClicked:(id)sender
{
    // store exit status here for processing by processHotKeySheetResult method
    hotKeySheetExitStatus = SHEET_OK;

    [self endHotKeySheet];
}

- (void)startHotKeySheet:(id)callingMethod
{
    // if Synergy.app running, tell it to stop listening for hotkeys right now
    // (don't want actions being triggered while capturing key press events)

    [synergyApp notifyApp:WODNAppUnregisterHotkeys];

    // get parent window (System Preferences.app)
    NSView *selfView = [self mainView];
    NSWindow *parentOfView = [selfView window];

    // display sheet
    [NSApp beginSheet:hotKeySheet
       modalForWindow:parentOfView
        modalDelegate:self
       didEndSelector:@selector(processHotKeySheetResult:withReturnCode:fromCallingMethod:)
          contextInfo:callingMethod];
}

- (void)endHotKeySheet
{
    // make sheet go away
    [hotKeySheet orderOut:nil];
    [NSApp endSheet:hotKeySheet];

    // if Synergy.app running, tell it to start listening for hotkeys again (it
    // will re-register the hotkeys only if its preferences tell it to do so)
    [synergyApp notifyApp:WODNAppRegisterHotkeys];
}

- (IBAction)hotKeySheetClearButtonClicked:(id)sender
{
    [keyCaptureView setKeyCode:0];
    [keyCaptureView setModifierFlags:0];
    [keyCaptureView setRepresentation:0];
    [keyCaptureView setNeedsDisplay:YES];
}

// method to process the results of the hot-key setting sheet
// check for duplicates, update preferences etc
- (void)processHotKeySheetResult:(id)sheet
                  withReturnCode:(int)returnCode
               fromCallingMethod:(id)callingMethod
{
    // callingMethod is actually an NSString containing the name of the calling
    // method: "play", "prev", "next", "quit", "showHide", "volumeUp",
    // "volumeDown", "showHideFloater", "rateAs1", "rateAs2", "rateAs3",
    // "rateAs4", "rateAs5", "rateAs0", "toggleMute", "toggleShuffle" and
    // "setRepeatMode", "activateITunes", "increaseRating", "decreaseRating"
    // returnCode is meaningless here (always = -1000 in my testing)

    if (hotKeySheetExitStatus == SHEET_CANCEL)
        // cancel pressed; no changes to commit
        return;

    if (hotKeySheetExitStatus == SHEET_OK)
    {
        /*

         Check for duplicates:
         - if there is a duplicate, the action just edited will keep the new
         hot key combo, and the other action which has the duplicate will be
         cleared

         - one special case is when the "duplicate" is actually the action just
         edited -- ie. it was edited to contain the same value as before

         - another is when the preference file is hacked so that multiple
         actions duplicate the same hot key; in this case the other actions will
         all be cleared and action just edited will keep the new combo

         - another is when the keycode+modifier clashes, but the unicode
         representation does not, which could happen due to user hackery or due
         to copying a prefs file across machines; in this case it is considered
         a full duplicate

         - the only duplicate that is actually permitted is the "none"
         combination

         */

        // update NSTextField -- this happens in all cases regardless of
        // duplicates
        id textField; // the text field to be updated

        // determine which text field will be updated:
        if ([callingMethod isEqualToString:@"next"])
        {
            textField = nextKeySetting;
            [synergyPreferences setObject:[NSNumber numberWithUnsignedInt:[keyCaptureView modifierFlags]]
                                   forKey:_woNextModifierPrefKey];
            [synergyPreferences setObject:[NSNumber numberWithUnsignedShort:[keyCaptureView keyCode]]
                                   forKey:_woNextKeycodePrefKey];
            [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [keyCaptureView representation]]
                                   forKey:_woNextUnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"prev"])
        {
            textField = prevKeySetting;
            [synergyPreferences setObject:[NSNumber numberWithUnsignedInt:[keyCaptureView modifierFlags]]
                                   forKey:_woPrevModifierPrefKey];
            [synergyPreferences setObject:[NSNumber numberWithUnsignedShort:[keyCaptureView keyCode]]
                                   forKey:_woPrevKeycodePrefKey];
            [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [keyCaptureView representation]]
                                   forKey:_woPrevUnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"play"])
        {
            textField = playKeySetting;
            [synergyPreferences setObject:[NSNumber numberWithUnsignedInt:[keyCaptureView modifierFlags]]
                                   forKey:_woPlayModifierPrefKey];
            [synergyPreferences setObject:[NSNumber numberWithUnsignedShort:[keyCaptureView keyCode]]
                                   forKey:_woPlayKeycodePrefKey];
            [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [keyCaptureView representation]]
                                   forKey:_woPlayUnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"quit"])
        {
            textField = quitKeySetting;
            [synergyPreferences setObject:[NSNumber numberWithUnsignedInt:[keyCaptureView modifierFlags]]
                                   forKey:_woQuitModifierPrefKey];
            [synergyPreferences setObject:[NSNumber numberWithUnsignedShort:[keyCaptureView keyCode]]
                                   forKey:_woQuitKeycodePrefKey];
            [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [keyCaptureView representation]]
                                   forKey:_woQuitUnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"showHide"])
        {
            textField = showHideKeySetting;
            [synergyPreferences setObject:[NSNumber numberWithUnsignedInt:[keyCaptureView modifierFlags]]
                                   forKey:_woShowHideModifierPrefKey];
            [synergyPreferences setObject:[NSNumber numberWithUnsignedShort:[keyCaptureView keyCode]]
                                   forKey:_woShowHideKeycodePrefKey];
            [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [keyCaptureView representation]]
                                   forKey:_woShowHideUnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"volumeUp"])
        {
            textField = volumeUpSetting;
            [synergyPreferences setObject:[NSNumber numberWithUnsignedInt:[keyCaptureView modifierFlags]]
                                   forKey:_woVolumeUpModifierPrefKey];
            [synergyPreferences setObject:[NSNumber numberWithUnsignedShort:[keyCaptureView keyCode]]
                                   forKey:_woVolumeUpKeycodePrefKey];
            [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [keyCaptureView representation]]
                                   forKey:_woVolumeUpUnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"volumeDown"])
        {
            textField = volumeDownSetting;
            [synergyPreferences setObject:[NSNumber numberWithUnsignedInt:[keyCaptureView modifierFlags]]
                                   forKey:_woVolumeDownModifierPrefKey];
            [synergyPreferences setObject:[NSNumber numberWithUnsignedShort:[keyCaptureView keyCode]]
                                   forKey:_woVolumeDownKeycodePrefKey];
            [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [keyCaptureView representation]]
                                   forKey:_woVolumeDownUnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"showHideFloater"])
        {
            textField = showHideFloaterSetting;
            [synergyPreferences setObject:[NSNumber numberWithUnsignedInt:[keyCaptureView modifierFlags]]
                                   forKey:_woShowHideFloaterModifierPrefKey];
            [synergyPreferences setObject:[NSNumber numberWithUnsignedShort:[keyCaptureView keyCode]]
                                   forKey:_woShowHideFloaterKeycodePrefKey];
            [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [keyCaptureView representation]]
                                   forKey:_woShowHideFloaterUnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"rateAs0"])
        {
            textField = rateAs0KeySetting;
            [synergyPreferences setObject:[NSNumber numberWithUnsignedInt:[keyCaptureView modifierFlags]]
                                   forKey:_woRateAs0ModifierPrefKey];
            [synergyPreferences setObject:[NSNumber numberWithUnsignedShort:[keyCaptureView keyCode]]
                                   forKey:_woRateAs0KeycodePrefKey];
            [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [keyCaptureView representation]]
                                   forKey:_woRateAs0UnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"rateAs1"])
        {
            textField = rateAs1KeySetting;
            [synergyPreferences setObject:[NSNumber numberWithUnsignedInt:[keyCaptureView modifierFlags]]
                                   forKey:_woRateAs1ModifierPrefKey];
            [synergyPreferences setObject:[NSNumber numberWithUnsignedShort:[keyCaptureView keyCode]]
                                   forKey:_woRateAs1KeycodePrefKey];
            [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [keyCaptureView representation]]
                                   forKey:_woRateAs1UnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"rateAs2"])
        {
            textField = rateAs2KeySetting;
            [synergyPreferences setObject:[NSNumber numberWithUnsignedInt:[keyCaptureView modifierFlags]]
                                   forKey:_woRateAs2ModifierPrefKey];
            [synergyPreferences setObject:[NSNumber numberWithUnsignedShort:[keyCaptureView keyCode]]
                                   forKey:_woRateAs2KeycodePrefKey];
            [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [keyCaptureView representation]]
                                   forKey:_woRateAs2UnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"rateAs3"])
        {
            textField = rateAs3KeySetting;
            [synergyPreferences setObject:[NSNumber numberWithUnsignedInt:[keyCaptureView modifierFlags]]
                                   forKey:_woRateAs3ModifierPrefKey];
            [synergyPreferences setObject:[NSNumber numberWithUnsignedShort:[keyCaptureView keyCode]]
                                   forKey:_woRateAs3KeycodePrefKey];
            [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [keyCaptureView representation]]
                                   forKey:_woRateAs3UnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"rateAs4"])
        {
            textField = rateAs4KeySetting;
            [synergyPreferences setObject:[NSNumber numberWithUnsignedInt:[keyCaptureView modifierFlags]]
                                   forKey:_woRateAs4ModifierPrefKey];
            [synergyPreferences setObject:[NSNumber numberWithUnsignedShort:[keyCaptureView keyCode]]
                                   forKey:_woRateAs4KeycodePrefKey];
            [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [keyCaptureView representation]]
                                   forKey:_woRateAs4UnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"rateAs5"])
        {
            textField = rateAs5KeySetting;
            [synergyPreferences setObject:[NSNumber numberWithUnsignedInt:[keyCaptureView modifierFlags]]
                                   forKey:_woRateAs5ModifierPrefKey];
            [synergyPreferences setObject:[NSNumber numberWithUnsignedShort:[keyCaptureView keyCode]]
                                   forKey:_woRateAs5KeycodePrefKey];
            [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x",[keyCaptureView representation]]
                                   forKey:_woRateAs5UnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"toggleMute"])
        {
            // again, for readability, we handball this off to a new method
            textField = toggleMuteSetting;
            [self setNewHotKeyPrefWithModifierKey:_woToggleMuteModifierPrefKey
                                       keycodeKey:_woToggleMuteKeycodePrefKey
                                       unicodeKey:_woToggleMuteUnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"toggleShuffle"])
        {
            textField = toggleShuffleSetting;
            [self setNewHotKeyPrefWithModifierKey:_woToggleShuffleModifierPrefKey
                                       keycodeKey:_woToggleShuffleKeycodePrefKey
                                       unicodeKey:_woToggleShuffleUnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"setRepeatMode"])
        {
            textField = setRepeatModeSetting;
            [self setNewHotKeyPrefWithModifierKey:_woSetRepeatModeModifierPrefKey
                                       keycodeKey:_woSetRepeatModeKeycodePrefKey
                                       unicodeKey:_woSetRepeatModeUnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"activateITunes"])
        {
            textField = activateITunesSetting;
            [self setNewHotKeyPrefWithModifierKey:_woActivateITunesModifierPrefKey
                                       keycodeKey:_woActivateITunesKeycodePrefKey
                                       unicodeKey:_woActivateITunesUnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"increaseRating"])
        {
            textField = increaseRatingSetting;
            [self setNewHotKeyPrefWithModifierKey:_woIncreaseRatingModifierPrefKey
                                       keycodeKey:_woIncreaseRatingKeycodePrefKey
                                       unicodeKey:_woIncreaseRatingUnicodePrefKey];
        }
        else if ([callingMethod isEqualToString:@"decreaseRating"])
        {
            textField = decreaseRatingSetting;
            [self setNewHotKeyPrefWithModifierKey:_woDecreaseRatingModifierPrefKey
                                       keycodeKey:_woDecreaseRatingKeycodePrefKey
                                       unicodeKey:_woDecreaseRatingUnicodePrefKey];
        }
        else
        {
            ELOG(@"Unrecognised calling method on return from hot key "
                 @"customisation sheet");
            textField = nil;
        }

        // do the actual update
        if (textField != nil)
            [textField setStringValue:[keyCaptureView keyComboString]];

        // check for duplicates -- if found, clear duplicated instance (keep new)

        // must read these into temporary storage because they will be
        // overwritten during the test for duplicates (we use keyCaptureView to
        // calculate and return human-readable string representations)
        unsigned int x = [keyCaptureView modifierFlags];
        unsigned short y = [keyCaptureView keyCode];

        // even the combinaton of "none" will be detected as a duplicate by the
        // following tests, but we let that through because testing for that
        // case would make the code harder to read. As things stand, even after
        // "eliminating" the "duplicate", both still have the value of "none",
        // which is the desired behaviour.

        // check against "next" value
         if ((x == [[synergyPreferences objectForKey:_woNextModifierPrefKey] unsignedIntValue]) &&
             (y == [[synergyPreferences objectForKey:_woNextKeycodePrefKey] unsignedShortValue]) &&
             ([callingMethod isEqualToString:@"next"] == NO))
         {
             // duplicate found! clear redundant entry in prefs
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woNextModifierPrefKey];
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woNextKeycodePrefKey];
             [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [NSNumber numberWithInt:0]]
                                    forKey:_woNextUnicodePrefKey];

             // and clear the textfield
             [keyCaptureView setKeyCode:0];
             [keyCaptureView setModifierFlags:0];
             [keyCaptureView setRepresentation:0];
             [nextKeySetting setStringValue:[keyCaptureView keyComboString]];
         }

         // check against "prev" value
         if ((x == [[synergyPreferences objectForKey:_woPrevModifierPrefKey] unsignedIntValue]) &&
             (y == [[synergyPreferences objectForKey:_woPrevKeycodePrefKey] unsignedShortValue]) &&
             ([callingMethod isEqualToString:@"prev"] == NO))
         {
             // duplicate found! clear redundant entry in prefs
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woPrevModifierPrefKey];
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woPrevKeycodePrefKey];
             [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [NSNumber numberWithInt:0]]
                                    forKey:_woPrevUnicodePrefKey];

             // and clear the textfield
             [keyCaptureView setKeyCode:0];
             [keyCaptureView setModifierFlags:0];
             [keyCaptureView setRepresentation:0];
             [prevKeySetting setStringValue:[keyCaptureView keyComboString]];
         }

         // check against "play" value
         if ((x == [[synergyPreferences objectForKey:_woPlayModifierPrefKey] unsignedIntValue]) &&
             (y == [[synergyPreferences objectForKey:_woPlayKeycodePrefKey] unsignedShortValue]) &&
             ([callingMethod isEqualToString:@"play"] == NO))
         {
             // duplicate found! clear redundant entry in prefs
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woPlayModifierPrefKey];
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woPlayKeycodePrefKey];
             [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [NSNumber numberWithInt:0]]
                                    forKey:_woPlayUnicodePrefKey];

             // and clear the textfield
             [keyCaptureView setKeyCode:0];
             [keyCaptureView setModifierFlags:0];
             [keyCaptureView setRepresentation:0];
             [playKeySetting setStringValue:[keyCaptureView keyComboString]];
         }

         // check against "quit" value
         if ((x == [[synergyPreferences objectForKey:_woQuitModifierPrefKey] unsignedIntValue]) &&
             (y == [[synergyPreferences objectForKey:_woQuitKeycodePrefKey] unsignedShortValue]) &&
             ([callingMethod isEqualToString:@"quit"] == NO))
         {
             // duplicate found! clear redundant entry in prefs
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woQuitModifierPrefKey];
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woQuitKeycodePrefKey];
             [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [NSNumber numberWithInt:0]]
                                    forKey:_woQuitUnicodePrefKey];

             // and clear the textfield
             [keyCaptureView setKeyCode:0];
             [keyCaptureView setModifierFlags:0];
             [keyCaptureView setRepresentation:0];
             [quitKeySetting setStringValue:[keyCaptureView keyComboString]];
         }

         // check against "showHide" value
         if ((x == [[synergyPreferences objectForKey:_woShowHideModifierPrefKey] unsignedIntValue]) &&
             (y == [[synergyPreferences objectForKey:_woShowHideKeycodePrefKey] unsignedShortValue]) &&
             ([callingMethod isEqualToString:@"showHide"] == NO))
         {
             // duplicate found! clear redundant entry in prefs
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woShowHideModifierPrefKey];
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woShowHideKeycodePrefKey];
             [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [NSNumber numberWithInt:0]]
                                    forKey:_woShowHideUnicodePrefKey];

             // and clear the textfield
             [keyCaptureView setKeyCode:0];
             [keyCaptureView setModifierFlags:0];
             [keyCaptureView setRepresentation:0];
             [showHideKeySetting setStringValue:[keyCaptureView keyComboString]];
         }

         // check against "volumeUp" value
         if ((x == [[synergyPreferences objectForKey:_woVolumeUpModifierPrefKey] unsignedIntValue]) &&
             (y == [[synergyPreferences objectForKey:_woVolumeUpKeycodePrefKey] unsignedShortValue]) &&
             ([callingMethod isEqualToString:@"volumeUp"] == NO))
         {
             // duplicate found! clear redundant entry in prefs
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woVolumeUpModifierPrefKey];
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woVolumeUpKeycodePrefKey];
             [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [NSNumber numberWithInt:0]]
                                    forKey:_woVolumeUpUnicodePrefKey];

             // and clear the textfield
             [keyCaptureView setKeyCode:0];
             [keyCaptureView setModifierFlags:0];
             [keyCaptureView setRepresentation:0];
             [volumeUpSetting setStringValue:[keyCaptureView keyComboString]];
         }

         // check against "volumeDown" value
         if ((x == [[synergyPreferences objectForKey:_woVolumeDownModifierPrefKey] unsignedIntValue]) &&
             (y == [[synergyPreferences objectForKey:_woVolumeDownKeycodePrefKey] unsignedShortValue]) &&
             ([callingMethod isEqualToString:@"volumeDown"] == NO))
         {
             // duplicate found! clear redundant entry in prefs
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woVolumeDownModifierPrefKey];
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woVolumeDownKeycodePrefKey];
             [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [NSNumber numberWithInt:0]]
                                    forKey:_woVolumeDownUnicodePrefKey];

             // and clear the textfield
             [keyCaptureView setKeyCode:0];
             [keyCaptureView setModifierFlags:0];
             [keyCaptureView setRepresentation:0];
             [volumeDownSetting setStringValue:[keyCaptureView keyComboString]];
         }

         // check against "showHideFloater" value
         if ((x == [[synergyPreferences objectForKey:_woShowHideFloaterModifierPrefKey] unsignedIntValue]) &&
             (y == [[synergyPreferences objectForKey:_woShowHideFloaterKeycodePrefKey] unsignedShortValue]) &&
             ([callingMethod isEqualToString:@"showHideFloater"] == NO))
         {
             // duplicate found! clear redundant entry in prefs
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woShowHideFloaterModifierPrefKey];
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woShowHideFloaterKeycodePrefKey];
             [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [NSNumber numberWithInt:0]]
                                    forKey:_woShowHideFloaterUnicodePrefKey];

             // and clear the textfield
             [keyCaptureView setKeyCode:0];
             [keyCaptureView setModifierFlags:0];
             [keyCaptureView setRepresentation:0];
             [showHideFloaterSetting setStringValue:[keyCaptureView keyComboString]];
         }

         // check against "rateAs0" value
         if ((x == [[synergyPreferences objectForKey:_woRateAs0ModifierPrefKey] unsignedIntValue]) &&
             (y == [[synergyPreferences objectForKey:_woRateAs0KeycodePrefKey] unsignedShortValue]) &&
             ([callingMethod isEqualToString:@"rateAs0"] == NO))
         {
             // duplicate found! clear redundant entry in prefs
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woRateAs0ModifierPrefKey];
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woRateAs0KeycodePrefKey];
             [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [NSNumber numberWithInt:0]]
                                    forKey:_woRateAs0UnicodePrefKey];

             // and clear the textfield
             [keyCaptureView setKeyCode:0];
             [keyCaptureView setModifierFlags:0];
             [keyCaptureView setRepresentation:0];
             [rateAs0KeySetting setStringValue:[keyCaptureView keyComboString]];
         }


         // check against "rateAs1" value
         if ((x == [[synergyPreferences objectForKey:_woRateAs1ModifierPrefKey] unsignedIntValue]) &&
             (y == [[synergyPreferences objectForKey:_woRateAs1KeycodePrefKey] unsignedShortValue]) &&
             ([callingMethod isEqualToString:@"rateAs1"] == NO))
         {
             // duplicate found! clear redundant entry in prefs
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woRateAs1ModifierPrefKey];
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woRateAs1KeycodePrefKey];
             [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [NSNumber numberWithInt:0]]
                                    forKey:_woRateAs1UnicodePrefKey];

             // and clear the textfield
             [keyCaptureView setKeyCode:0];
             [keyCaptureView setModifierFlags:0];
             [keyCaptureView setRepresentation:0];
             [rateAs1KeySetting setStringValue:[keyCaptureView keyComboString]];
         }

         // check against "rateAs2" value
         if ((x == [[synergyPreferences objectForKey:_woRateAs2ModifierPrefKey] unsignedIntValue]) &&
             (y == [[synergyPreferences objectForKey:_woRateAs2KeycodePrefKey] unsignedShortValue]) &&
             ([callingMethod isEqualToString:@"rateAs2"] == NO))
         {
             // duplicate found! clear redundant entry in prefs
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woRateAs2ModifierPrefKey];
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woRateAs2KeycodePrefKey];
             [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [NSNumber numberWithInt:0]]
                                    forKey:_woRateAs2UnicodePrefKey];

             // and clear the textfield
             [keyCaptureView setKeyCode:0];
             [keyCaptureView setModifierFlags:0];
             [keyCaptureView setRepresentation:0];
             [rateAs2KeySetting setStringValue:[keyCaptureView keyComboString]];
         }

         // check against "rateAs3" value
         if ((x == [[synergyPreferences objectForKey:_woRateAs3ModifierPrefKey] unsignedIntValue]) &&
             (y == [[synergyPreferences objectForKey:_woRateAs3KeycodePrefKey] unsignedShortValue]) &&
             ([callingMethod isEqualToString:@"rateAs3"] == NO))
         {
             // duplicate found! clear redundant entry in prefs
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woRateAs3ModifierPrefKey];
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woRateAs3KeycodePrefKey];
             [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [NSNumber numberWithInt:0]]
                                    forKey:_woRateAs3UnicodePrefKey];

             // and clear the textfield
             [keyCaptureView setKeyCode:0];
             [keyCaptureView setModifierFlags:0];
             [keyCaptureView setRepresentation:0];
             [rateAs3KeySetting setStringValue:[keyCaptureView keyComboString]];
         }

         // check against "rateAs4" value
         if ((x == [[synergyPreferences objectForKey:_woRateAs4ModifierPrefKey] unsignedIntValue]) &&
             (y == [[synergyPreferences objectForKey:_woRateAs4KeycodePrefKey] unsignedShortValue]) &&
             ([callingMethod isEqualToString:@"rateAs4"] == NO))
         {
             // duplicate found! clear redundant entry in prefs
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woRateAs4ModifierPrefKey];
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woRateAs4KeycodePrefKey];
             [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [NSNumber numberWithInt:0]]
                                    forKey:_woRateAs4UnicodePrefKey];

             // and clear the textfield
             [keyCaptureView setKeyCode:0];
             [keyCaptureView setModifierFlags:0];
             [keyCaptureView setRepresentation:0];
             [rateAs4KeySetting setStringValue:[keyCaptureView keyComboString]];
         }

         // check against "rateAs5" value
         if ((x == [[synergyPreferences objectForKey:_woRateAs5ModifierPrefKey] unsignedIntValue]) &&
             (y == [[synergyPreferences objectForKey:_woRateAs5KeycodePrefKey] unsignedShortValue]) &&
             ([callingMethod isEqualToString:@"rateAs5"] == NO))
         {
             // duplicate found! clear redundant entry in prefs
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woRateAs5ModifierPrefKey];
             [synergyPreferences setObject:[NSNumber numberWithInt:0]
                                    forKey:_woRateAs5KeycodePrefKey];
             [synergyPreferences setObject:[NSString stringWithFormat:@"0x%04x", [NSNumber numberWithInt:0]]
                                    forKey:_woRateAs5UnicodePrefKey];

             // and clear the textfield
             [keyCaptureView setKeyCode:0];
             [keyCaptureView setModifierFlags:0];
             [keyCaptureView setRepresentation:0];
             [rateAs5KeySetting setStringValue:[keyCaptureView keyComboString]];
         }

         // new hot keys are tested in the following manner: the code that's
         // been repeated above for each hotkey is now split off into a separate
         // method for code readability: the method call is ugly, but it's still
         // better than the above, and less likely to fall pray to errors

         // check against "toggleMute" value
         [self checkForDuplicateAgainstHotKey:x
                                      keycode:y
                              modifierPrefKey:_woToggleMuteModifierPrefKey
                               keycodePrefKey:_woToggleMuteKeycodePrefKey
                               unicodePrefKey:_woToggleMuteUnicodePrefKey
                                callingMethod:callingMethod
                             comparisonMethod:@"toggleMute"
                           targetSettingField:toggleMuteSetting];

         // check against "toggleShuffle" value
         [self checkForDuplicateAgainstHotKey:x
                                      keycode:y
                              modifierPrefKey:_woToggleShuffleModifierPrefKey
                               keycodePrefKey:_woToggleShuffleKeycodePrefKey
                               unicodePrefKey:_woToggleShuffleUnicodePrefKey
                                callingMethod:callingMethod
                             comparisonMethod:@"toggleShuffle"
                           targetSettingField:toggleShuffleSetting];

         // check against "SetRepeatMode" value
         [self checkForDuplicateAgainstHotKey:x
                                      keycode:y
                              modifierPrefKey:_woSetRepeatModeModifierPrefKey
                               keycodePrefKey:_woSetRepeatModeKeycodePrefKey
                               unicodePrefKey:_woSetRepeatModeUnicodePrefKey
                                callingMethod:callingMethod
                             comparisonMethod:@"setRepeatMode"
                           targetSettingField:setRepeatModeSetting];

         // check against "activateITunes" value
         [self checkForDuplicateAgainstHotKey:x
                                      keycode:y
                              modifierPrefKey:_woActivateITunesModifierPrefKey
                               keycodePrefKey:_woActivateITunesKeycodePrefKey
                               unicodePrefKey:_woActivateITunesUnicodePrefKey
                                callingMethod:callingMethod
                             comparisonMethod:@"activateITunes"
                           targetSettingField:activateITunesSetting];

         // check against "increaseRating" value
         [self checkForDuplicateAgainstHotKey:x
                                      keycode:y
                              modifierPrefKey:_woIncreaseRatingModifierPrefKey
                               keycodePrefKey:_woIncreaseRatingKeycodePrefKey
                               unicodePrefKey:_woIncreaseRatingUnicodePrefKey
                                callingMethod:callingMethod
                             comparisonMethod:@"increaseRating"
                           targetSettingField:increaseRatingSetting];

         // check against "decreaseRating" value
         [self checkForDuplicateAgainstHotKey:x
                                      keycode:y
                              modifierPrefKey:_woDecreaseRatingModifierPrefKey
                               keycodePrefKey:_woDecreaseRatingKeycodePrefKey
                               unicodePrefKey:_woDecreaseRatingUnicodePrefKey
                                callingMethod:callingMethod
                             comparisonMethod:@"decreaseRating"
                           targetSettingField:decreaseRatingSetting];

        // update defaults, revert, apply buttons
         [self updateRevertButton];
         [self updateDefaultsButton];
         [self updateApplyButton];
    }
    else
        ELOG(@"Unknown exit status from hot key customisation sheet");
}


// another readability method... no functionality, just makes the source look
// better
- (void)setNewHotKeyPrefWithModifierKey:(NSString *)modifier
                             keycodeKey:(NSString *)keycode
                             unicodeKey:(NSString *)unicode

{
    // we split these lines into their own method here so that we can just call
    // the wrapper method once for each hot key, instead of calling the
    // component calls here once for each hot key, which would make for ugly
    // source!

    // update it in prefs
    [synergyPreferences setObject:
        [NSNumber numberWithUnsignedInt:[keyCaptureView modifierFlags]]
                           forKey:modifier];

    [synergyPreferences setObject:
        [NSNumber numberWithUnsignedShort:[keyCaptureView keyCode]]
                           forKey:keycode];

    [synergyPreferences setObject:
        [NSString stringWithFormat:@"0x%04x",
            [keyCaptureView representation]]
                           forKey:unicode];
}

// another readability method... no functionality, just makes the source look
// better, and less error-prone...
- (void)checkForDuplicateAgainstHotKey:(unsigned int)modifierFlags
                               keycode:(unsigned short)keycode
                       modifierPrefKey:(NSString *)modifierPrefKey
                        keycodePrefKey:(NSString *)keycodePrefKey
                        unicodePrefKey:(NSString *)unicodePrefKey
                         callingMethod:(NSString *)callingMethod
                      comparisonMethod:(NSString *)comparisonMethod
                    targetSettingField:(NSTextField *)targetField
{
    if ((modifierFlags ==
         [[synergyPreferences objectForKey:modifierPrefKey] unsignedIntValue])
        &&
        (keycode ==
         [[synergyPreferences objectForKey:keycodePrefKey] unsignedShortValue])
        &&
        ([callingMethod isEqualToString:comparisonMethod] == NO))
    {
        // duplicate found! clear redundant entry in prefs
        [synergyPreferences setObject:[NSNumber numberWithInt:0]
                               forKey:modifierPrefKey];

        [synergyPreferences setObject:[NSNumber numberWithInt:0]
                               forKey:keycodePrefKey];

        [synergyPreferences setObject:
            [NSString stringWithFormat:@"0x%04x",
                [NSNumber numberWithInt:0]]
                               forKey:unicodePrefKey];

        // and clear the correspond textfield
        [keyCaptureView setKeyCode:0];
        [keyCaptureView setModifierFlags:0];
        [keyCaptureView setRepresentation:0];
        [targetField setStringValue:[keyCaptureView keyComboString]];
    }
}

- (IBAction)globalHotKeysToggleClicked:(id)sender
{
    if ([globalHotKeysToggle state] == NSOffState)
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woGlobalHotkeysPrefKey];
    else
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woGlobalHotkeysPrefKey];

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
    [self updateHotKeySettingControls];
}

- (void)updateHotKeySettingControls
{
	BOOL enabled = [[synergyPreferences objectForKey:_woGlobalHotkeysPrefKey] boolValue];
	[setNextHotKeyButton setEnabled:enabled];
    [setPlayPauseHotKeyButton setEnabled:enabled];
    [setPrevHotKeyButton setEnabled:enabled];
    [setQuitHotKeyButton setEnabled:enabled];
    [setShowHideHotKeyButton setEnabled:enabled];
    [setVolumeUpHotKeyButton setEnabled:enabled];
    [setVolumeDownHotKeyButton setEnabled:enabled];
    [setShowHideFloaterHotKeyButton setEnabled:enabled];
    [setRateAs0HotKeyButton setEnabled:enabled];
    [setRateAs1HotKeyButton setEnabled:enabled];
    [setRateAs2HotKeyButton setEnabled:enabled];
    [setRateAs3HotKeyButton setEnabled:enabled];
    [setRateAs4HotKeyButton setEnabled:enabled];
    [setRateAs5HotKeyButton setEnabled:enabled];
    [setToggleMuteHotKeyButton setEnabled:enabled];
    [setToggleShuffleHotKeyButton setEnabled:enabled];
    [setSetRepeatModeSettingHotKeyButton setEnabled:enabled];
    [setActivateITunesHotKeyButton setEnabled:enabled];
    [setIncreaseRatingHotKeyButton setEnabled:enabled];
    [setDecreaseRatingHotKeyButton setEnabled:enabled];
}

- (IBAction)showNotificationClicked:(id)sender
{
    if ([showNotificationWindow state] == NSOffState)
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woShowNotificationWindowPrefKey];
    else
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woShowNotificationWindowPrefKey];

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
    [self updateFloaterControls];
}

- (BOOL)isSynergyRunning
{
    // send message to app asking for notification of its running state
    [synergyApp notifyApp:WODNAppStatus];

    // check state variable to see what's known about iTunes running state
    return ([synergyApp appState] == WODNRunning);
}

- (IBAction)startToggleClicked:(id)sender
{
    // We check to see if Synergy is already running in mainViewDidLoad
    // but it could have been quit by the user after that point, so we test
    // again here

    //    startToggleState (NSInteger) holds the current state of the button
    if (startToggleState) // Synergy IS running, so stop it
    {
        // stop Synergy

        // the catch here is that IF Synergy crashed, then this stop command
        // will have no effect because we'll think it's still running -- so
        // we check for a crashed app here

        ProcessSerialNumber synergyAppPSN = [WOProcessManager PSNForSignature:'Snrg'];

        if ([WOProcessManager PSNEqualsNoProcess:synergyAppPSN])
        {
            // looks like app has crashed

            // update state variable
            startToggleState = NO;

            [self makeToggleShowStart];
        }
        else
        {
            // app still running, the following should quit it:
            [self stopSynergy];

            // do nothing more here, because Synergy will notify us with
            // "WODNAppWillQuit" when it quits
        }
    }
    else // Synergy IS NOT running, so start it
    {
        [self makeToggleShowStarting];

        [self launchSynergy];

        // app will notify us with "WODNAppLaunched" when it launches

        /*

         Note that launchApplication returns immediately, so we can't rely on
         its BOOL return value to know when the launch is finished.
         Cannot use NSWorkspaceDidLaunchApplicationNotification here because
         Synergy.app is a LSUIElement 1 app; see:
            http://developer.apple.com/technotes/tn/tn2050.html#Section4
         So a more elegant solution in this case is to use
         NSDistributedNotificationCenter
            http://developer.apple.com/techpubs/macosx/Cocoa/Reference/Foundation/ObjC_classic/Classes/NSDistributedNotifctnCtr.html
        */
    }
}

- (void)launchSynergy
{
    NSString *path = [[NSBundle bundleForClass:[self class]] bundlePath];
    path = [path stringByAppendingPathComponent:@"Contents"];
    path = [path stringByAppendingPathComponent:@"Helpers"];
    path = [path stringByAppendingPathComponent:@"Synergy.app"];
    if (![[NSWorkspace sharedWorkspace] launchApplication:path])
        ELOG(@"Synergy.app did not launch successfully");
}

- (void) stopSynergy
{
    // send quit message to app
    [synergyApp notifyApp:WODNAppQuit];
}

// Make start/stop toggle button say "Start"
- (void) makeToggleShowStart
{
    startToggleState = NO;
    [startToggleDescription setStringValue:
        NSLocalizedStringFromTableInBundle(
                                    @"Click to start Synergy.",
                                    @"",
                                    [NSBundle bundleForClass:[self class]],
                                    @"Start Synergy button descriptive text")];
    [startToggle setTitle:
        NSLocalizedStringFromTableInBundle(@"Start",
                                           @"",
                                           [NSBundle bundleForClass:
                                               [self class]],
                                           @"Start Synergy button")];
    [startToggle setToolTip:
        NSLocalizedStringFromTableInBundle
        (@"Start Synergy and place controls for iTunes in the Menu Bar",
         @"",
         [NSBundle bundleForClass:[self class]],
         @"Tool-tip for Start button (active)")];
}

- (void) makeToggleShowStarting
{
    // Disable the button while waiting for Synergy to launch
    [startToggle setEnabled:NO];
    [startToggleDescription setStringValue:
        NSLocalizedStringFromTableInBundle(@"Starting Synergy.",
                                           @"",
                                           [NSBundle bundleForClass:
                                               [self class]],
                                           @"Starting Synergy status message")];
    [startToggle setToolTip:
        NSLocalizedStringFromTableInBundle
        (@"Start Synergy and place controls for iTunes in the Menu Bar\n(Disabled because Synergy is in the process of starting)",
         @"",
         [NSBundle bundleForClass:[self class]],
         @"Tool-tip for Start button (ghosted)")];

}

- (void) makeToggleShowStop
{
    // special case for when control hiding is turned on AND global menu off
    // (user may not realise Synergy is running if iTunes is not running)
    if (([[synergyPreferences objectForKey:_woGlobalMenuPrefKey] boolValue] == NO) &&
        ([[synergyPreferences objectForKey:_woControlHidingPrefKey] boolValue]))
    {
        [startToggleDescription setStringValue:
            NSLocalizedStringFromTableInBundle(@"Click to stop Synergy (currently running in the background).",
                                               @"",
                                               [NSBundle bundleForClass:
                                                   [self class]],
                                               @"Stop Synergy button descriptive text")];

        // set tool-tip
        [startToggle setToolTip:
            NSLocalizedStringFromTableInBundle
            (@"Stop Synergy and, if present, remove controls for iTunes from Menu Bar",
             @"",
             [NSBundle bundleForClass:[self class]],
             @"Tool-tip for Stop button (active, but controls may be hidden)")];
    }
    else
    {
        [startToggleDescription setStringValue:
            NSLocalizedStringFromTableInBundle(@"Click to stop Synergy.",
                                               @"",
                                               [NSBundle bundleForClass:
                                                   [self class]],
                                               @"Stop Synergy button descriptive text")];

        if([[synergyPreferences objectForKey:_woControlHidingPrefKey] boolValue])
        {
            // set tool-tip
            [startToggle setToolTip:
                NSLocalizedStringFromTableInBundle
                (@"Stop Synergy and, if present, remove controls for iTunes from Menu Bar",
                 @"",
                 [NSBundle bundleForClass:[self class]],
                 @"Tool-tip for Stop button (active, but controls may be hidden)")];
        }
        else
        {
            // set tool-tip
            [startToggle setToolTip:
                NSLocalizedStringFromTableInBundle
                (@"Stop Synergy and remove controls for iTunes from Menu Bar",
                 @"",
                 [NSBundle bundleForClass:[self class]],
                 @"Tool-tip for Stop button (active)")];
        }
    }

    [startToggle setTitle:
        NSLocalizedStringFromTableInBundle(@"Stop",
                                           @"",
                                           [NSBundle bundleForClass:
                                               [self class]],
                                           @"Stop Synergy button")];



    // Re-enable the button and set the state flag
    [startToggle setEnabled:YES];
}

- (IBAction)undoButtonClicked:(id)sender
{
}

- (IBAction)weblinkClicked:(id)sender
{
    if([[NSWorkspace sharedWorkspace] openURL:
        [NSURL URLWithString:@"http://synergy.wincent.com/"]] == NO)
        ELOG(@"openURL failed (attempting to open http://synergy.wincent.com/ "
             @"in default browser).");
}


// apply preferences to the GUI according to submitted dictionary
// Note this only adjusts the settings widgets themselves
// It is still necessary to call updateDefaultsButton, updateRevertButton etc
- (void) matchInterfaceToDictionary:(NSDictionary*)submittedDictionary
{
    // "Launch Synergy at login"
    if ([[submittedDictionary objectForKey:_woLaunchAtLoginPrefKey] boolValue])
        [launchAtLogin setState:NSOnState];
    else
        [launchAtLogin setState:NSOffState];

    // show extra feedback
    if ([[submittedDictionary objectForKey:_woShowFeedbackWindowPrefKey] boolValue])
        [extraFeedbackToggle setState:NSOnState];
    else
        [extraFeedbackToggle setState:NSOffState];

    // floater delay slider

    // handle special cases: values > 20 are set to 21
    if ([[submittedDictionary objectForKey:
        _woFloaterDurationPrefKey] floatValue] > 20.0)
    {
        [floaterDelaySlider setFloatValue:21.0];
        [floaterDelayTextField setStringValue:
            NSLocalizedStringFromTableInBundle(
                                               @"always",
                                               @"",
                                               [NSBundle bundleForClass:[self class]],
                                               @"Show floater forever")];

        [showNotificationWindow setEnabled:NO];
    }
    else
    {
        [floaterDelaySlider setFloatValue:[[submittedDictionary objectForKey:
            _woFloaterDurationPrefKey] floatValue]];

        // build the string in three parts: "for xx,x secs"

        // 1. "for"
        NSMutableString *floaterDelayString = [NSMutableString stringWithString:
            NSLocalizedStringFromTableInBundle(@"for",
                                               @"",
                                               [NSBundle bundleForClass:[self class]],
                                               @"'for' xxxx seconds")];
        // 2. "xx,x"

        [floaterDelayString appendString:
            [NSString localizedStringWithFormat:@" %.1f ",
                [[submittedDictionary objectForKey:_woFloaterDurationPrefKey] floatValue]]];

        // 3. "secs"
        [floaterDelayString appendString:
            NSLocalizedStringFromTableInBundle(@"secs",
                                               @"",
                                               [NSBundle bundleForClass:[self class]],
                                               @"abbreviation for 'seconds'")];

        [floaterDelayTextField setStringValue:floaterDelayString];

        [showNotificationWindow setEnabled:YES];
    }

    // show floater
    if ([[submittedDictionary objectForKey:_woShowNotificationWindowPrefKey] boolValue])
        [showNotificationWindow setState:NSOnState];
    else
        [showNotificationWindow setState:NSOffState];

    [self updateFloaterTooltip];

    // floater transparency slider
    [floaterTransparencySlider setFloatValue:[[submittedDictionary objectForKey:_woFloaterTransparencyPrefKey] floatValue]];

    // floater size slider
    [floaterSizeSlider setIntValue:[[submittedDictionary objectForKey:_woFloaterSizePrefKey] intValue]];

    // include album in floater toggle
    if ([[submittedDictionary objectForKey:_woIncludeAlbumInFloaterPrefKey] boolValue])
        [includeAlbumInFloaterToggle setState:NSOnState];
    else
        [includeAlbumInFloaterToggle setState:NSOffState];

    // include artist in floater toggle
    if ([[submittedDictionary objectForKey:_woIncludeArtistInFloaterPrefKey] boolValue])
        [includeArtistInFloaterToggle setState:NSOnState];
    else
        [includeArtistInFloaterToggle setState:NSOffState];

    // include composer in floater toggle
    if ([[submittedDictionary objectForKey:_woIncludeComposerInFloaterPrefKey] boolValue])
        [includeComposerInFloaterToggle setState:NSOnState];
    else
        [includeComposerInFloaterToggle setState:NSOffState];

    // include duration in floater toggle
    if ([[submittedDictionary objectForKey:_woIncludeDurationInFloaterPrefKey] boolValue])
        [includeDurationInFloaterToggle setState:NSOnState];
    else
        [includeDurationInFloaterToggle setState:NSOffState];

    // include year in floater toggle
    if ([[submittedDictionary objectForKey:_woIncludeYearInFloaterPrefKey] boolValue])
        [includeYearInFloaterToggle setState:NSOnState];
    else
        [includeYearInFloaterToggle setState:NSOffState];

    // include rating in floater toggle
    if ([[submittedDictionary objectForKey:_woIncludeStarRatingInFloaterPrefKey] boolValue])
        [includeRatingInFloaterToggle setState:NSOnState];
    else
        [includeRatingInFloaterToggle setState:NSOffState];

    // "Previous track action behaves like iTunes"
    if ([[submittedDictionary objectForKey:_woPrevActionSameAsITunesPrefKey] boolValue])
        [prevActionToggle setState:NSOnState];
    else
        [prevActionToggle setState:NSOffState];

    // "Bring iTunes to front when switching playlists"
    if ([[submittedDictionary objectForKey:_woBringITunesToFrontPrefKey]
        boolValue])
        [bringITunesToFrontToggle setState:NSOnState];
    else
        [bringITunesToFrontToggle setState:NSOffState];

    // "Automatically initiate connection to Internet when required"
    if ([[submittedDictionary objectForKey:_woAutoConnectTogglePrefKey]
        boolValue])
        [autoConnectToggle setState:NSOnState];
    else
        [autoConnectToggle setState:NSOffState];

    // "Preprocess ID3 tags"
    if ([[submittedDictionary objectForKey:_woPreprocessTogglePrefKey]
        boolValue])
        [preprocessToggle setState:NSOnState];
    else
        [preprocessToggle setState:NSOffState];

    // "Random button style"
    if ([[submittedDictionary objectForKey:_woRandomButtonStylePrefKey] boolValue])
    {
        [randomButtonStyleToggle setState:NSOnState];
        [self disableButtonStylePopUp];
    }
    else
    {
        [randomButtonStyleToggle setState:NSOffState];
        [self enableButtonStylePopUp];
    }

    // "Control Synergy with global hotkeys"
    if ([[submittedDictionary objectForKey:_woGlobalHotkeysPrefKey] boolValue])
        [globalHotKeysToggle setState:NSOnState];
    else
        [globalHotKeysToggle setState:NSOffState];

    // "Play/Pause hotkey setting"
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woPlayKeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woPlayModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woPlayUnicodePrefKey]]];
    [playKeySetting setStringValue:[keyCaptureView keyComboString]];

    // "Prev hotkey setting"
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woPrevKeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woPrevModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woPrevUnicodePrefKey]]];
    [prevKeySetting setStringValue:[keyCaptureView keyComboString]];

    // "Next hotkey setting"
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woNextKeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woNextModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woNextUnicodePrefKey]]];
    [nextKeySetting setStringValue:[keyCaptureView keyComboString]];

    // "Quit hotkey setting"
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woQuitKeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woQuitModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woQuitUnicodePrefKey]]];
    [quitKeySetting setStringValue:[keyCaptureView keyComboString]];

    // "Show/Hide hotkey setting"
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woShowHideKeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woShowHideModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woShowHideUnicodePrefKey]]];
    [showHideKeySetting setStringValue:[keyCaptureView keyComboString]];

    // "Volume up hotkey setting"
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woVolumeUpKeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woVolumeUpModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woVolumeUpUnicodePrefKey]]];
    [volumeUpSetting setStringValue:[keyCaptureView keyComboString]];

    // "Volume down hotkey setting"
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woVolumeDownKeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woVolumeDownModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woVolumeDownUnicodePrefKey]]];
    [volumeDownSetting setStringValue:[keyCaptureView keyComboString]];

    // "Show/Hide floater hotkey setting"
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woShowHideFloaterKeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woShowHideFloaterModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woShowHideFloaterUnicodePrefKey]]];
    [showHideFloaterSetting setStringValue:[keyCaptureView keyComboString]];

    // "rate as zero stars hotkey setting"
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woRateAs0KeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woRateAs0ModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woRateAs0UnicodePrefKey]]];
    [rateAs0KeySetting setStringValue:[keyCaptureView keyComboString]];

    // "rate as * hotkey setting"
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woRateAs1KeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woRateAs1ModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woRateAs1UnicodePrefKey]]];
    [rateAs1KeySetting setStringValue:[keyCaptureView keyComboString]];

    // "rate as ** hotkey setting"
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woRateAs2KeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woRateAs2ModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woRateAs2UnicodePrefKey]]];
    [rateAs2KeySetting setStringValue:[keyCaptureView keyComboString]];

    // "rate as *** hotkey setting"
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woRateAs3KeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woRateAs3ModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woRateAs3UnicodePrefKey]]];
    [rateAs3KeySetting setStringValue:[keyCaptureView keyComboString]];

    // "rate as **** hotkey setting"
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woRateAs4KeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woRateAs4ModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woRateAs4UnicodePrefKey]]];
    [rateAs4KeySetting setStringValue:[keyCaptureView keyComboString]];

    // "rate as ***** hotkey setting"
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woRateAs5KeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woRateAs5ModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woRateAs5UnicodePrefKey]]];
    [rateAs5KeySetting setStringValue:[keyCaptureView keyComboString]];

    // "toggle mute" setting
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woToggleMuteKeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woToggleMuteModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woToggleMuteUnicodePrefKey]]];
    [toggleMuteSetting setStringValue:[keyCaptureView keyComboString]];

    // "toggle shuffle" setting
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woToggleShuffleKeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woToggleShuffleModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woToggleShuffleUnicodePrefKey]]];
    [toggleShuffleSetting setStringValue:[keyCaptureView keyComboString]];

    // "set repeat mode" setting
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woSetRepeatModeKeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woSetRepeatModeModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woSetRepeatModeUnicodePrefKey]]];
    [setRepeatModeSetting setStringValue:[keyCaptureView keyComboString]];

    // "activateITunes" setting
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woActivateITunesKeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woActivateITunesModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woActivateITunesUnicodePrefKey]]];
    [activateITunesSetting setStringValue:[keyCaptureView keyComboString]];

    // "increaseRating" setting
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woIncreaseRatingKeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woIncreaseRatingModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woIncreaseRatingUnicodePrefKey]]];
    [increaseRatingSetting setStringValue:[keyCaptureView keyComboString]];

    // "decreaseRating" setting
    [keyCaptureView setKeyCode: [[submittedDictionary objectForKey:_woDecreaseRatingKeycodePrefKey] unsignedShortValue]];
    [keyCaptureView setModifierFlags: [[submittedDictionary objectForKey:_woDecreaseRatingModifierPrefKey] unsignedIntValue]];
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[submittedDictionary objectForKey:_woDecreaseRatingUnicodePrefKey]]];
    [decreaseRatingSetting setStringValue:[keyCaptureView keyComboString]];

    // "Display Play/Pause button in menu bar"
    if ([[submittedDictionary objectForKey:_woPlayButtonInMenuPrefKey] boolValue])
    {
        [playPauseButtonToggle setState:NSOnState];
        [synergyMenuView showPlayButton];
    }
    else
    {
        [playPauseButtonToggle setState:NSOffState];
        [synergyMenuView hidePlayButton];
    }

    // "Display prev track button in menu bar"
    if ([[submittedDictionary objectForKey:_woPrevButtonInMenuPrefKey] boolValue])
    {
        [prevButtonToggle setState: NSOnState];
        [synergyMenuView showPrevButton];
    }
    else
    {
        [prevButtonToggle setState: NSOffState];
        [synergyMenuView hidePrevButton];
    }

    // "Display next track button in menu bar"
    if ([[submittedDictionary objectForKey:_woNextButtonInMenuPrefKey] boolValue])
    {
        [nextButtonToggle setState:NSOnState];
        [synergyMenuView showNextButton];
    }
    else
    {
        [nextButtonToggle setState:NSOffState];
        [synergyMenuView hideNextButton];
    }

    // "Hide controls when iTunes not running"
    if ([[submittedDictionary objectForKey:_woControlHidingPrefKey] boolValue])
        [controlHidingToggle setState:NSOnState];
    else
        [controlHidingToggle setState:NSOffState];

    // "Button spacing slider"
    [buttonSpacingSlider setIntValue:[[submittedDictionary objectForKey:_woButtonSpacingPrefKey] intValue]];

    // "Show Global Menu as a separate menu item (not integrated into Play/Pause
    // button)"
    if ([[submittedDictionary objectForKey:_woGlobalMenuPrefKey] boolValue])
    {
        [globalMenuToggle setState:NSOnState];
        [globalMenuOnlyWhenControlsHiddenToggle setEnabled:YES];
    }
    else
    {
        [globalMenuToggle setState:NSOffState];
        [globalMenuOnlyWhenControlsHiddenToggle setEnabled:NO];
    }

    // "Only when Menu Bar control buttons are hidden"
    if ([[submittedDictionary objectForKey:_woGlobalMenuOnlyWhenHiddenPrefKey] boolValue])
        [globalMenuOnlyWhenControlsHiddenToggle setState:NSOnState];
    else
        [globalMenuOnlyWhenControlsHiddenToggle setState:NSOffState];

    // "Include recently played tracks submenu"
    if ([[submittedDictionary objectForKey:_woRecentlyPlayedSubmenuPrefKey] boolValue])
        [recentlyPlayedSubmenuToggle setState:NSOnState];
    else
        [recentlyPlayedSubmenuToggle setState:NSOffState];

    // "Include artist in recent tracks menu"
    if ([[submittedDictionary objectForKey:_woIncludeArtistInRecentTracksPrefKey] boolValue])
        [includeArtistInRecentTracksToggle setState:NSOnState];
    else
        [includeArtistInRecentTracksToggle setState:NSOffState];

    // "Floater graphic type" NSPopUpButton
    int floaterGraphicType = [[submittedDictionary objectForKey:_woFloaterGraphicType] intValue];

    if ((floaterGraphicType >= 0) && (floaterGraphicType < 3))
        [graphicPopUpButton selectItemAtIndex:floaterGraphicType];
    else
    {
        ELOG(@"Illegal value found in org.wincent.Synergy.plist for "
             @"'Floater graphic type'");

        [graphicPopUpButton selectItemAtIndex:0];
    }

    // "Button style" PopUpButton
    NSString *buttonStylePopUpValue = [submittedDictionary objectForKey:_woButtonStylePrefKey];

    [buttonStylePopUpButton selectItemWithTitle:buttonStylePopUpValue];

    [self resizeButtonPreview];

    [self changeButtonStyle];

    // "Remember (x) recent tracks"
    // for readability, cache an int of the submitted pref
    int recentTracksPopUpValue = [[submittedDictionary objectForKey:_woNumberOfRecentlyPlayedTracksPrefKey] intValue];

    if (recentTracksPopUpValue == 1)
        [recentlyPlayedPopUp selectItemAtIndex:0];
    else if (recentTracksPopUpValue == 5)
        [recentlyPlayedPopUp selectItemAtIndex:1];
    else if (recentTracksPopUpValue == 10)
        [recentlyPlayedPopUp selectItemAtIndex:2];
    else if (recentTracksPopUpValue == 20)
        [recentlyPlayedPopUp selectItemAtIndex:3];
    else if (recentTracksPopUpValue == 50)
        [recentlyPlayedPopUp selectItemAtIndex:4];
    else
        // illegal value: log error message
        ELOG(@"Illegal value found in org.wincent.Synergy.plist for 'Number of "
             @"recently played tracks' (permitted values are 5, 10, 20 and 50; "
             @"actual value: %d)", recentTracksPopUpValue);

    // "Include playlists submenu"
    if ([[submittedDictionary objectForKey:_woPlaylistsSubmenuPrefKey] boolValue])
        [playlistSubmenuToggle setState:NSOnState];
    else
        [playlistSubmenuToggle setState:NSOffState];

    if ([[submittedDictionary objectForKey:_woLaunchQuitItemsPrefKey] boolValue])
        [launchQuitItemsToggle setState:NSOnState];
    else
        [launchQuitItemsToggle setState:NSOffState];

    // "Use NSMenuExtra"
    if ([[submittedDictionary objectForKey:_woUseNSMenuExtraPrefKey] boolValue])
        [useNSMenuExtraToggle setState:NSOnState];
    else
        [useNSMenuExtraToggle setState:NSOffState];

    // also may need to resize buttons in demo view here, so refresh them
    [synergyMenuView resizeAndRefresh:[[submittedDictionary objectForKey:_woButtonSpacingPrefKey] intValue]];
}

- (IBAction)graphicPopUpButtonChanged:(id)sender
{
    int selectedIndex = [graphicPopUpButton indexOfSelectedItem];

    switch (selectedIndex)
    {
        case 0: // album cover
            [synergyPreferences setObject:[NSNumber numberWithInt:WOFloaterIconAlbumCover]
                                   forKey:_woFloaterGraphicType];
            break;
        case 1: // Synergy icon
            [synergyPreferences setObject:[NSNumber numberWithInt:WOFloaterIconSynergyIcon]
                                   forKey:_woFloaterGraphicType];
            break;
        case 2: // no graphic
            [synergyPreferences setObject:[NSNumber numberWithInt:WOFloaterIconNoIcon]
                                   forKey:_woFloaterGraphicType];
            break;
        default: // unknown!
            ELOG(@"No legal value detected for \"Floater graphic type\"");

            // default back to SynergyIcon
            [synergyPreferences setObject:[NSNumber numberWithInt:WOFloaterIconSynergyIcon]
                                   forKey:_woFloaterGraphicType];
            break;
    }

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (IBAction)recentlyPlayedPopUpChanged:(id)sender
{
    // legal values for this pop up are 1, 5, 10, 20 and 50
    int selectedIndex = [recentlyPlayedPopUp indexOfSelectedItem];

    if (selectedIndex == 0)
        [synergyPreferences setObject:[NSNumber numberWithInt:1]
                               forKey:_woNumberOfRecentlyPlayedTracksPrefKey];
    else if (selectedIndex == 1)
        [synergyPreferences setObject:[NSNumber numberWithInt:5]
                               forKey:_woNumberOfRecentlyPlayedTracksPrefKey];
    else if (selectedIndex == 2)
        [synergyPreferences setObject:[NSNumber numberWithInt:10]
                               forKey:_woNumberOfRecentlyPlayedTracksPrefKey];
    else if (selectedIndex == 3)
        [synergyPreferences setObject:[NSNumber numberWithInt:20]
                               forKey:_woNumberOfRecentlyPlayedTracksPrefKey];
    else if (selectedIndex == 4)
        [synergyPreferences setObject:[NSNumber numberWithInt:50]
                               forKey:_woNumberOfRecentlyPlayedTracksPrefKey];
    else
    {
        // we'll never get this far, unless someone hacks the nib file
        ELOG(@"No legal value detected for 'Number of recently played tracks' "
             @"pop-up");

        // default to safe value
        [synergyPreferences setObject:[NSNumber numberWithInt:10]
                               forKey:_woNumberOfRecentlyPlayedTracksPrefKey];
    }

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (IBAction)buttonStylePopUpButtonChanged:(id)sender
{
    int selectedIndex = [buttonStylePopUpButton indexOfSelectedItem];
    int numberOfItems = [[buttonStylePopUpButton menu] numberOfItems];

    if (selectedIndex == (numberOfItems - 1))
    {
        // user selected the "Refresh..." item
        [self updateButtonStylePopUp];

        // re-select whatever was previously selected
        NSString *buttonStylePopUpValue =
            [synergyPreferences objectForKey:_woButtonStylePrefKey];

        [buttonStylePopUpButton selectItemWithTitle:buttonStylePopUpValue];
    }
    else
    {
            NSString *selectedTitle = [buttonStylePopUpButton titleOfSelectedItem];
            [synergyPreferences setObject:selectedTitle
                                   forKey:_woButtonStylePrefKey];
            [synergyMenuView setButtonSet:selectedTitle];
            [self resizeButtonPreview];
            [self changeButtonStyle];
            [self updateRevertButton];
            [self updateDefaultsButton];
            [self updateApplyButton];
    }
}

- (IBAction)colorSchemePopUpButtonChanged:(id)sender
{
    // tell Synergy.app not to display floater so won't clash with preview
    [synergyApp notifyApp:WODNAppNoFloater];

    // stop any old fade timers which might be operating
    [floaterController stopFadeTimers];
    [floaterController stopDelayedFadeTimers];
    [floaterController stopTextFadeTimers];
    [self cancelDelayedFadeOut];

    // ensure view is the right size
    [floaterController zoomToFitText:self];

    // now update the floater
    int selectedIndex = 0;
    //selectedIndex = [colorSchemePopUpButton indexOfSelectedItem];

    switch (selectedIndex)
    {
        case 0: // "White on black" (default)
            [synergyPreferences setObject:[NSNumber numberWithFloat:1.0]
                                   forKey:_woFloaterForegroundColorPrefKey];

            [synergyPreferences setObject:[NSNumber numberWithFloat:0.0]
                                   forKey:_woFloaterBackgroundColorPrefKey];

            [floaterController setFgColor:1.0];
            [floaterController setBgColor:0.0];

            break;

        case 1: // "Black on white"
            [synergyPreferences setObject:[NSNumber numberWithFloat:0.0]
                                   forKey:_woFloaterForegroundColorPrefKey];

            [synergyPreferences setObject:[NSNumber numberWithFloat:0.6]
                                   forKey:_woFloaterBackgroundColorPrefKey];

            [floaterController setFgColor:0.0];
            [floaterController setBgColor:0.6];

            break;

        default:

            break;

    }

    // now show the floater
    [floaterController tellViewItNeedsToDisplay:self];

    // display preview at full alpha if haven't done so already
    [floaterController putWindowInScreen:self];
    [floaterController setWindowAlphaValue:1.0];

    // start (or restart) timer for delayed fadeout!
    [self setUpDelayedFadeOut];

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];

}

// eventually move this into another class and make it a factory method
- (unsigned short)unsignedShortValueForHexString:(NSString *)theString
/*"
 Simple wrapper method that uses NSScanner to convert from a human-readable hex
 representation (eg 0xf700) in an NSString to an unsigned short integer. Returns
 0 if submitted an invalid string.
"*/
{
    unsigned int result;

    if([[NSScanner scannerWithString:theString] scanHexInt:&result] == NO)
    {
        ELOG(@"Error attempting to convert hex string to integer (invalid hex "
             @"string)");

        return 0; // non-fatal error, proceed with harmless value
    }

    return [[NSNumber numberWithUnsignedInt:result] unsignedShortValue];
}

- (IBAction)playPauseButtonToggleClicked:(id)sender
{
    if ([playPauseButtonToggle state] == NSOffState)
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woPlayButtonInMenuPrefKey];
        [synergyMenuView hidePlayButton];

    }
    else
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woPlayButtonInMenuPrefKey];
        [synergyMenuView showPlayButton];

    }

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
    [self updateControlHidingToggleStatus];
    [self updateHotKeySettingControls];

    [self resizeButtonPreview];
}

- (IBAction)prevButtonToggleClicked:(id)sender
{
    if ([prevButtonToggle state] == NSOffState)
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woPrevButtonInMenuPrefKey];
        [synergyMenuView hidePrevButton];

    }
    else
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woPrevButtonInMenuPrefKey];
        [synergyMenuView showPrevButton];

    }

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
    [self updateControlHidingToggleStatus];

    // redraw the view
    [self resizeButtonPreview];
}

- (IBAction)nextButtonToggleClicked:(id)sender
{
    if ([nextButtonToggle state] == NSOffState)
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woNextButtonInMenuPrefKey];

        [synergyMenuView hideNextButton];
    }
    else
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woNextButtonInMenuPrefKey];

        [synergyMenuView showNextButton];
    }

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
    [self updateControlHidingToggleStatus];

    [self resizeButtonPreview];
}

- (void)resizeButtonPreview
{
    // By the time we get this far the appropriate buttons will already have
    // been added or removed from the view

    // calculate the size and location of the view

    [self calculateSizeAndLocationOfPreview]; // actually sets it too.

    // this only moves and resizes buttons: it is up to the calling method
    // to hide or show buttons as appropriate

    [synergyMenuView resizeAndRefresh:
        [[synergyPreferences objectForKey:_woButtonSpacingPrefKey] intValue]];
}


- (IBAction)controlHidingToggleClicked:(id)sender
{
    if ([controlHidingToggle state] == NSOffState)
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woControlHidingPrefKey];
    else
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woControlHidingPrefKey];

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (void)updateFloaterPositionIVars
{
    [floaterController setWindowOffset:
        NSMakePoint([[synergyPreferences objectForKey:_woFloaterHorizontalOffset] floatValue],
                    [[synergyPreferences objectForKey:_woFloaterVerticalOffset] floatValue])];

    [floaterController setXScreenSegment:
        [[synergyPreferences objectForKey:_woFloaterHorizontalSegment] intValue]];

    [floaterController setYScreenSegment:
        [[synergyPreferences objectForKey:_woFloaterVerticalSegment] intValue]];


    [floaterController setScreenNumber:
        [[synergyPreferences objectForKey:_woScreenIndex] intValue]];

    [anchorController setXGridLocation:[[synergyPreferences objectForKey:_woFloaterHorizontalSegment] intValue]];
    [anchorController setYGridLocation:[[synergyPreferences objectForKey:_woFloaterVerticalSegment] intValue]];
    [anchorController setWindowOffset:NSMakePoint([[synergyPreferences objectForKey:_woFloaterHorizontalOffset] floatValue],
                                                  [[synergyPreferences objectForKey:_woFloaterVerticalOffset] floatValue])];


    [anchorController setScreenNumber:[[synergyPreferences objectForKey:_woScreenIndex] intValue]];
}

- (void)getFloaterPositionIVars
{
    // weakness: anchorController only knows about these things if the window
    // has been dragged!
    NSPoint theOffset = [anchorController windowOffset];

    [synergyPreferences setObject:[NSNumber numberWithFloat:theOffset.x]
                           forKey:_woFloaterHorizontalOffset];

    [synergyPreferences setObject:[NSNumber numberWithFloat:theOffset.y]
                           forKey:_woFloaterVerticalOffset];

    [synergyPreferences setObject:[NSNumber numberWithInt:[anchorController xGridLocation]]
                           forKey:_woFloaterHorizontalSegment];

    [synergyPreferences setObject:[NSNumber numberWithInt:[anchorController yGridLocation]]
                           forKey:_woFloaterVerticalSegment];

    [synergyPreferences setObject:[NSNumber numberWithInt:[anchorController screenNumber]]
                           forKey:_woScreenIndex];

}

- (void)backupFloaterPositionIVars
{
    localWindowOffsetBackup = [anchorController windowOffset];
    localXScreenSegmentBackup = [anchorController xGridLocation];
    localYScreenSegmentBackup = [anchorController yGridLocation];

    localScreenNumber = [anchorController screenNumber];

    // make sure floaterController matches the backed-up values
    [floaterController setWindowOffset:localWindowOffsetBackup];
    [floaterController setXScreenSegment:localXScreenSegmentBackup];
    [floaterController setYScreenSegment:localYScreenSegmentBackup];

    [floaterController setScreenNumber:localScreenNumber];
}

- (void)revertFloaterPositionIVars
{
    [floaterController setWindowOffset:localWindowOffsetBackup];
    [floaterController setXScreenSegment:localXScreenSegmentBackup];
    [floaterController setYScreenSegment:localYScreenSegmentBackup];

    [floaterController setScreenNumber:localScreenNumber];

    [anchorController setXGridLocation:localXScreenSegmentBackup];
    [anchorController setYGridLocation:localYScreenSegmentBackup];
    [anchorController setWindowOffset:localWindowOffsetBackup];

    [anchorController setScreenNumber:localScreenNumber];

    // this should make the changes "live"

    // hide anchor window before moving it -- normally it gets hidden later...
    [anchorController windowOrderOut:self];

    // make floater invisible before moving it -- not actually removing it from
    // screen... that will happen later under the natural course of the fade
    // that is initiated in processFloater method
    [floaterController setWindowAlphaValue:0.0];

    // move the floater (doesn't display it, just moves it)
    [floaterController moveGivenOffset:localWindowOffsetBackup
                              xSegment:localXScreenSegmentBackup
                              ySegment:localYScreenSegmentBackup];

    // move the anchor
    [anchorController moveToSegmentNoAnimate:localXScreenSegmentBackup
                                           y:localYScreenSegmentBackup
                                      screen:[[floaterController floaterWindow] screen]];
}

- (void)updateFloaterControls
{
    // added this because clicking "Revert" or "Defaults" while the floater
    // preview was visible wasn't updating the size and transparency even if
    // the sliders moved
    [floaterController setSize:[floaterSizeSlider intValue]];
    [floaterController setTransparency:[floaterTransparencySlider floatValue]];
    [floaterController zoomToFitText:self];
    [floaterController tellViewItNeedsToDisplay:self];
}

- (void) updateControlHidingToggleStatus
{
    // Ghost or enable controlHidingToggle depending on settings for other
    // control buttons
    int activeButtons = 0; // keep a count of the number of active buttons

    if ([playPauseButtonToggle state] == NSOnState)
        activeButtons += 1;

    if ([prevButtonToggle state] == NSOnState)
        activeButtons += 1;

    if ([nextButtonToggle state] == NSOnState)
        activeButtons += 1;

    if (activeButtons == 0)
    {
        // all controls are switched off...
        [controlHidingToggle setEnabled:NO]; // ghost out controlHidingToggle
        [buttonSpacingSlider setEnabled:NO]; // and the buttonSpacingSlider
    }
    else if (activeButtons == 1)
    {
        // just one control is active
        [controlHidingToggle setEnabled:YES]; // enable the controlHidingToggle
        [buttonSpacingSlider setEnabled:NO];  // and ghost the slider
    }
    else
    {
        // at least two controls are switched on...
        [controlHidingToggle setEnabled:YES]; // enable the controlHidingToggle
        [buttonSpacingSlider setEnabled:YES]; // and the buttonSpacingSlider
    }
}

- (IBAction)recentlyPlayedSubmenuToggleClicked:(id)sender
{
    if ([recentlyPlayedSubmenuToggle state] == NSOffState)
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woRecentlyPlayedSubmenuPrefKey];
    else
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woRecentlyPlayedSubmenuPrefKey];

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
    [self updateGlobalMenuStatus]; // handles enabling of recent tracks popup
}

- (IBAction)playlistSubmenuToggleClicked:(id)sender
{
    if ([playlistSubmenuToggle state] == NSOffState)
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woPlaylistsSubmenuPrefKey];
    else
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woPlaylistsSubmenuPrefKey];

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
    [self updateGlobalMenuStatus];
}

- (IBAction)launchQuitItemsToggleClicked:(id)sender
{
    if ([launchQuitItemsToggle state] == NSOffState)
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woLaunchQuitItemsPrefKey];
    else
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woLaunchQuitItemsPrefKey];

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
    [self updateGlobalMenuStatus];
}

- (void) updateGlobalMenuStatus
{
    // enable the related controls
    [recentlyPlayedSubmenuToggle setEnabled:YES];
    [playlistSubmenuToggle setEnabled:YES];
    [launchQuitItemsToggle setEnabled:YES];

    // but handle these separately:
    if ([recentlyPlayedSubmenuToggle state] == NSOffState)
    {
        [recentlyPlayedPopUp setEnabled:NO];
        [includeArtistInRecentTracksToggle setEnabled:NO];
    }
    else
    {
        [recentlyPlayedPopUp setEnabled:YES];
        [includeArtistInRecentTracksToggle setEnabled:YES];
    }
}

// update the preview of the button spacing
- (IBAction) buttonSpacingSliderMoved:(id)sender
{
    // this will be called once on mouse down, once on mouse up, and whenever
    // there is a change of values in between (continuous)

    int newButtonSpacing = [buttonSpacingSlider intValue];

    // update preferences value
    [synergyPreferences setObject:[NSNumber numberWithInt:newButtonSpacing]
                           forKey:_woButtonSpacingPrefKey];

    [synergyMenuView resizeAndRefresh:newButtonSpacing];

    // update defaults/revert/apply buttons
    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (void)updateFloaterTooltip
{
    if ([showNotificationWindow isEnabled])
        [showNotificationWindow setToolTip:
            NSLocalizedStringFromTableInBundle
            (@"When checked, a temporary song information floater appears when changing tracks",
             @"",
             [NSBundle bundleForClass:[self class]],
             @"Tool-tip for Floater checkbox (not ghosted)")];
    else
        [showNotificationWindow setToolTip:
            NSLocalizedStringFromTableInBundle
            (@"When checked, a temporary song information floater appears when changing tracks;\ndisabled because the floater is set to display 'always'",
             @"",
             [NSBundle bundleForClass:[self class]],
             @"Tool-tip for Floater checkbox (ghosted)")];
}

- (IBAction)floaterDelaySliderMoved:(id)sender
{
    float newDelay = [floaterDelaySlider floatValue];

    // special case: if delay is 21.0 seconds (slider all the way to the right)
    // then leave floater on-screen permanently: simulate this by setting a
    // duration of 86,400 seconds (ie. one day)
    if (newDelay > 20.9)
    {
        newDelay = 86400.0;

        [floaterDelayTextField setStringValue:
            NSLocalizedStringFromTableInBundle(
                                               @"always",
                                               @"",
                                               [NSBundle bundleForClass:[self class]],
                                               @"Show floater forever")];

        // disable (ghost) the "show when track changes" toggle
        [showNotificationWindow setEnabled:NO];

    }
    else
    {
        // un-ghost the "show when track changes" toggle
        [showNotificationWindow setEnabled:YES];

        // round others down to 20.0
        if ((newDelay > 20.0) && (newDelay <= 20.9))
            newDelay = 20.0;

        // set the text string...

        // build the string in three parts: "for xx,x secs"
        // note I think I might be able to do this with one statement instead...

        // 1. "for"
        NSMutableString *floaterDelayString = [NSMutableString stringWithString:
            NSLocalizedStringFromTableInBundle(@"for",
                                               @"",
                                               [NSBundle bundleForClass:[self class]],
                                               @"'for' xxxx seconds")];
        // 2. "xx,x"

        [floaterDelayString appendString:
            [NSString localizedStringWithFormat:@" %.1f ", newDelay]];

        // 3. "secs"
        [floaterDelayString appendString:
            NSLocalizedStringFromTableInBundle(@"secs",
                                               @"",
                                               [NSBundle bundleForClass:[self class]],
                                               @"abbreviation for 'seconds'")];

        [floaterDelayTextField setStringValue:floaterDelayString];
    }

    [synergyPreferences setObject:[NSNumber numberWithFloat:newDelay]
                           forKey:_woFloaterDurationPrefKey];

    [self updateFloaterTooltip];
    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];

    // no other updating of the UI required; this is an "invisible" change
}

- (IBAction)floaterTransparencySliderMoved:(id)sender
{
    // code common to all event types
    float newTransparency = [floaterTransparencySlider floatValue];

    [synergyPreferences setObject:[NSNumber numberWithFloat:newTransparency]
                           forKey:_woFloaterTransparencyPrefKey];

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];

    // event type-specific code -- some redundancy here as noted in the
    // floaterSizeSliderMoved method
    NSEventType theEventType = [[NSApp currentEvent] type];

    if ((theEventType == NSLeftMouseDown) || (theEventType == NSRightMouseDown) || (theEventType == NSOtherMouseDown))
    {
        // tell Synergy.app not to display floater so won't clash with preview
        [synergyApp notifyApp:WODNAppNoFloater];

        // stop any old fade timers which might be operating
        [floaterController stopFadeTimers];
        [floaterController stopDelayedFadeTimers];
        [floaterController stopTextFadeTimers];
        [self cancelDelayedFadeOut];

        // ensure view is the right size
        [floaterController zoomToFitText:self];

        // the actual update according to the slider value:
        [floaterController setTransparency:newTransparency];
        [floaterController tellViewItNeedsToDisplay:self];

        // display preview at full alpha if haven't done so already
        [floaterController putWindowInScreen:self];
        [floaterController setWindowAlphaValue:1.0];

        // start (or restart) timer for delayed fadeout!
        [self setUpDelayedFadeOut];
    }
    else if ((theEventType == NSLeftMouseUp) || (theEventType == NSRightMouseUp) || (theEventType == NSOtherMouseUp))
    {
        // the actual update according to the slider value:
        [floaterController setTransparency:newTransparency];
        [floaterController tellViewItNeedsToDisplay:self];

        // stop any old fade timers which might be operating
        [floaterController stopFadeTimers];
        [floaterController stopDelayedFadeTimers];
        [floaterController stopTextFadeTimers];

        // initiate delayed fadeout
        [self setUpDelayedFadeOut]; // removes window from screen
    }
    else if ((theEventType == NSLeftMouseDragged) || (theEventType == NSRightMouseDragged) || (theEventType == NSOtherMouseDragged))
    {
        // the actual update according to the slider value:
        [floaterController setTransparency:newTransparency];
        [floaterController tellViewItNeedsToDisplay:self];

        // start timer for delayed fadeout!
        [self setUpDelayedFadeOut];
    }
    else
        VLOG(@"Unknown event type");
}

- (IBAction)floaterSizeSliderMoved:(id)sender
{
    // code common to all event types
    int newSize = [floaterSizeSlider intValue];

    [synergyPreferences setObject:[NSNumber numberWithInt:newSize]
                           forKey:_woFloaterSizePrefKey];

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];

    // maybe overkill? is it already set?
    [floaterController setAnimateWhileResizing:NO];

    // event type-specific code -- there is some redundancy in here because an
    // especially quick mouseclick will cause us to see only the mouseDown and
    // not a mouseUp -- therefore we have to put some appropriate cleanup in
    // the mouseDown event also just in case
    NSEventType theEventType = [[NSApp currentEvent] type];

    if ((theEventType == NSLeftMouseDown) || (theEventType == NSRightMouseDown) || (theEventType == NSOtherMouseDown))
    {
        // tell Synergy.app not to display floater so won't clash with preview
        [synergyApp notifyApp:WODNAppNoFloater];

        // stop any old fade timers which might be operating
        [floaterController stopFadeTimers];
        [floaterController stopDelayedFadeTimers];
        [floaterController stopTextFadeTimers];
        [self cancelDelayedFadeOut];

        // the actual update according to the slider value:
        [floaterController setSize:newSize];
        [floaterController zoomToFitText:self];
        [floaterController tellViewItNeedsToDisplay:self];

        // display preview at full alpha if haven't done so already
        [floaterController putWindowInScreen:self];
        [floaterController setWindowAlphaValue:1.0];

        // start (or restart) timer for delayed fadeout!
        [self setUpDelayedFadeOut];
    }
    else if ((theEventType == NSLeftMouseUp) || (theEventType == NSRightMouseUp) || (theEventType == NSOtherMouseUp))
    {
        // the actual update according to the slider value:
        [floaterController setSize:newSize];
        [floaterController zoomToFitText:self];
        [floaterController tellViewItNeedsToDisplay:self];

        // stop any old fade timers which might be operating
        [floaterController stopFadeTimers];
        [floaterController stopDelayedFadeTimers];
        [floaterController stopTextFadeTimers];

        // initiate delayed fadeout
        [self setUpDelayedFadeOut]; // removes window from screen
    }
    else if ((theEventType == NSLeftMouseDragged) || (theEventType == NSRightMouseDragged) || (theEventType == NSOtherMouseDragged))
    {
        // this is a "continuous" slider so update the preview
        [floaterController setSize:newSize];
        [floaterController zoomToFitText:self];
        [floaterController tellViewItNeedsToDisplay:self];

        // start timer for delayed fadeout!
        [self setUpDelayedFadeOut];
    }
    else
        VLOG(@"Unknown event type");
}

- (void)setUpDelayedFadeOut
{
    // remove any existing timers
    [self cancelDelayedFadeOut];

    // set up new timer
    delayedFadeOutTimer = [NSTimer scheduledTimerWithTimeInterval:FLOATER_PREVIEW_DELAY
                                                           target:self
                                                         selector:@selector(performDelayedFadeOut:)
                                                         userInfo:nil
                                                          repeats:NO];
}

- (void)cancelDelayedFadeOut
{
    if (delayedFadeOutTimer)
    {
        // if timer has fired, it will already be invalidated
        if ([delayedFadeOutTimer isValid])
            [delayedFadeOutTimer invalidate];
        delayedFadeOutTimer = nil;
    }
}

- (void)performDelayedFadeOut:(NSTimer *)timer
{
    // ask the controller to perform the actual fade
    [floaterController fadeWindowOut:self];

    // do clean up
    [self cancelDelayedFadeOut];

    // tell Synergy.app it can display floater again
    [synergyApp notifyApp:WODNAppFloaterOK];
}

- (void) enablePayNowButton
{
    [payNowButton setEnabled:YES];
}

- (void) disablePayNowButton
{
    [payNowButton setEnabled:NO];
}

- (IBAction) payNowButtonClicked:(id)sender
{
    if([[NSWorkspace sharedWorkspace] openURL:
        [NSURL URLWithString:
            @"https://secure.wincent.com/a/products/synergy-classic/purchase/"]] == NO)
        VLOG(@"openURL failed (attempting to open "
             @"https://secure.wincent.com/a/products/synergy-classic/purchase/ in default "
             @"browser).");
}

- (IBAction)floaterPositionButtonClicked:(id)sender
{
    // tell Synergy.app not to display floater so won't clash with preview
    [synergyApp notifyApp:WODNAppNoFloater];

    // backup
    [self backupFloaterPositionIVars];

    // stop any old fade timers which might be operating
    [floaterController stopFadeTimers];
    [floaterController stopDelayedFadeTimers];
    [floaterController stopTextFadeTimers];
    [self cancelDelayedFadeOut];

    // display preview at full alpha if haven't done so already
    [floaterController putWindowInScreen:self];
    [floaterController setWindowAlphaValue:1.0];

    // make preview draggable
    [floaterController setMovable:YES];

    // display anchor window
    [anchorController viewSetNeedsDisplay:YES];
    [anchorController windowOrderFront:self];

    // get parent window (System Preferences.app)
    NSView *selfView = [self mainView];
    NSWindow *parentOfView = [selfView window];

    // display sheet
    [NSApp beginSheet:floaterPositionSheet
       modalForWindow:parentOfView
        modalDelegate:self
       didEndSelector:@selector(processFloaterPositionSheetResult:returnCode:)
          contextInfo:nil];
}

- (void)processFloaterPositionSheetResult:(id)sheet
                               returnCode:(int)returnCode
{
    if (returnCode == SHEET_OK)
    {
        // brings local prefs into line with floater position ivars
        [self getFloaterPositionIVars];

        // backup ivars so revert button will work in future
        [self backupFloaterPositionIVars];

        // redundant? forces
        [self updateFloaterPositionIVars];

        // update UI as appropriate
        [self updateRevertButton];
        [self updateDefaultsButton];
        [self updateApplyButton];
    }
    else if (returnCode == SHEET_CANCEL)
        // return floater position ivars to previous state
        [self revertFloaterPositionIVars];
    else
        ELOG(@"Unknown return code from floater position sheet");

    // remove anchor window
    [anchorController windowOrderOut:self];

    // ask the controller to fade out the floater preview
    [floaterController fadeWindowOut:self];

    // make preview non-draggable
    [floaterController setMovable:NO];

    // tell Synergy.app it can display floater again
    [synergyApp notifyApp:WODNAppFloaterOK];
}

- (IBAction)floaterPositionSheetOKButtonClicked:(id)sender
{
    // make sheet go away
    [floaterPositionSheet orderOut:nil];
    [NSApp endSheet:floaterPositionSheet returnCode:SHEET_OK];
}

- (IBAction)floaterPositionSheetCancelButtonClicked:(id)sender
{
    // make sheet go away
    [floaterPositionSheet orderOut:nil];
    [NSApp endSheet:floaterPositionSheet returnCode:SHEET_CANCEL];
}

- (IBAction)setVolumeUpKeyClicked:(id)sender
{
    // update description
    [hotKeySheetDescriptionTextField setStringValue:
        NSLocalizedStringFromTableInBundle(
            @"Volume up",
            @"",
            [NSBundle bundleForClass:[self class]],
            @"Volume up action description")];

    // update to reflect current hot key setting (if any)

    // modifier flags
    [keyCaptureView setModifierFlags:
        [[synergyPreferences objectForKey:_woVolumeUpModifierPrefKey]
            unsignedIntValue]];

    // raw key code
    [keyCaptureView setKeyCode:
        [[synergyPreferences objectForKey:_woVolumeUpKeycodePrefKey]
            unsignedShortValue]];

    // the Unicode representation
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[synergyPreferences objectForKey:
            _woVolumeUpUnicodePrefKey]]];

    // pass identifier here, so that the sheet knows where it was called from
    [self startHotKeySheet:@"volumeUp"];
}

- (IBAction)setVolumeDownKeyClicked:(id)sender
{
    // update description
    [hotKeySheetDescriptionTextField setStringValue:
        NSLocalizedStringFromTableInBundle
        (@"Volume down",
         @"",
         [NSBundle bundleForClass:[self class]],
         @"Volume down action description")];

    // update to reflect current hot key setting (if any)

    // modifier flags
    [keyCaptureView setModifierFlags:
        [[synergyPreferences objectForKey:_woVolumeDownModifierPrefKey]
            unsignedIntValue]];

    // raw key code
    [keyCaptureView setKeyCode:
        [[synergyPreferences objectForKey:_woVolumeDownKeycodePrefKey]
            unsignedShortValue]];

    // the Unicode representation
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[synergyPreferences objectForKey:
            _woVolumeDownUnicodePrefKey]]];

    // pass identifier here, so that the sheet knows where it was called from
    [self startHotKeySheet:@"volumeDown"];
}

// wrapper method for preparing and then showing a hot key sheet; as this
// operation is repeated many times in a slightly different way (once for each
// different hotkey), the use of this method makes for more readable code
- (void)prepareHotKeySheet:(NSString *)identifier
               description:(NSString *)action
           modifierPrefKey:(NSString *)modifier
            keycodePrefKey:(NSString *)keycode
            unicodePrefKey:(NSString *)unicode
{

    // TODO: need to update the following method in some way: genstrings chokes on it
    // Bad entry in file OrgWincentSynergyPref.m (line = 4627): Argument is not a literal string.

    // update description
    [hotKeySheetDescriptionTextField setStringValue:
        NSLocalizedStringFromTableInBundle
        (action,
         @"",
         [NSBundle bundleForClass:[self class]],
         [action stringByAppendingString:@" action description"])];

    // update to reflect current hot key setting (if any)

    // modifier flags
    [keyCaptureView setModifierFlags:
        [[synergyPreferences objectForKey:modifier]
            unsignedIntValue]];

    // raw key code
    [keyCaptureView setKeyCode:
        [[synergyPreferences objectForKey:keycode]
            unsignedShortValue]];

    // the Unicode representation
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[synergyPreferences objectForKey:
            unicode]]];

    // pass identifier here, so that the sheet knows where it was called from
    [self startHotKeySheet:identifier];
}


- (IBAction)setToggleMuteHotKeyButtonClicked:(id)sender
{
    // this method and the methods below use the new -prepareHotKeySheet:
    // wrapper to make things a little more readable. The methods that were
    // previously written for the other hot keys still use the "old", unwrapped
    // way
    [self prepareHotKeySheet:@"toggleMute"
                 description:@"Toggle mute"
             modifierPrefKey:_woToggleMuteModifierPrefKey
              keycodePrefKey:_woToggleMuteKeycodePrefKey
              unicodePrefKey:_woToggleMuteUnicodePrefKey];
}

- (IBAction)setToggleShuffleHotKeyButtonClicked:(id)sender
{
    [self prepareHotKeySheet:@"toggleShuffle"
                 description:@"Toggle shuffle"
             modifierPrefKey:_woToggleShuffleModifierPrefKey
              keycodePrefKey:_woToggleShuffleKeycodePrefKey
              unicodePrefKey:_woToggleShuffleUnicodePrefKey];
}

- (IBAction)setSetRepeatModeSettingHotKeyButtonClicked:(id)sender
{
    [self prepareHotKeySheet:@"setRepeatMode"
                 description:@"Set repeat mode"
             modifierPrefKey:_woSetRepeatModeModifierPrefKey
              keycodePrefKey:_woSetRepeatModeKeycodePrefKey
              unicodePrefKey:_woSetRepeatModeUnicodePrefKey];
}

- (IBAction)setActivateITunesHotKeyButtonClicked:(id)sender
{
    [self prepareHotKeySheet:@"activateITunes"
                 description:@"Bring iTunes to front"
             modifierPrefKey:_woActivateITunesModifierPrefKey
              keycodePrefKey:_woActivateITunesKeycodePrefKey
              unicodePrefKey:_woActivateITunesUnicodePrefKey];
}

- (IBAction)setShowHideFloaterKeyClicked:(id)sender
{
    // update description
    [hotKeySheetDescriptionTextField setStringValue:
        NSLocalizedStringFromTableInBundle
        (@"Show/Hide floater",
         @"",
         [NSBundle bundleForClass:[self class]],
         @"Show/Hide floater action description")];

    // update to reflect current hot key setting (if any)

    // modifier flags
    [keyCaptureView setModifierFlags:
        [[synergyPreferences objectForKey:_woShowHideFloaterModifierPrefKey]
            unsignedIntValue]];

    // raw key code
    [keyCaptureView setKeyCode:
        [[synergyPreferences objectForKey:_woShowHideFloaterKeycodePrefKey]
            unsignedShortValue]];

    // the Unicode representation
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[synergyPreferences objectForKey:
            _woShowHideFloaterUnicodePrefKey]]];

    // pass identifier here, so that the sheet knows where it was called from
    [self startHotKeySheet:@"showHideFloater"];
}

- (IBAction)setDecreaseRatingHotKeyButtonClicked:(id)sender
{
    // update description
    [hotKeySheetDescriptionTextField setStringValue:
        NSLocalizedStringFromTableInBundle(@"Decrease rating",
                                           @"",
                                           [NSBundle bundleForClass:[self class]],
                                           @"'Decrease rating' text")];

    // update to reflect current hot key setting (if any)

    // modifier flags
    [keyCaptureView setModifierFlags:
        [[synergyPreferences objectForKey:_woDecreaseRatingModifierPrefKey]
            unsignedIntValue]];

    // raw key code
    [keyCaptureView setKeyCode:
        [[synergyPreferences objectForKey:_woDecreaseRatingKeycodePrefKey]
            unsignedShortValue]];

    // the Unicode representation
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[synergyPreferences objectForKey:
            _woDecreaseRatingUnicodePrefKey]]];

    // pass identifier here, so that the sheet knows where it was called from
    [self startHotKeySheet:@"decreaseRating"];
}

- (IBAction)setIncreaseRatingHotKeyButtonClicked:(id)sender
{
    // update description
    [hotKeySheetDescriptionTextField setStringValue:
        NSLocalizedStringFromTableInBundle(@"Increase rating",
                                           @"",
                                           [NSBundle bundleForClass:[self class]],
                                           @"'Increase rating' text")];

    // update to reflect current hot key setting (if any)

    // modifier flags
    [keyCaptureView setModifierFlags:
        [[synergyPreferences objectForKey:_woIncreaseRatingModifierPrefKey]
            unsignedIntValue]];

    // raw key code
    [keyCaptureView setKeyCode:
        [[synergyPreferences objectForKey:_woIncreaseRatingKeycodePrefKey]
            unsignedShortValue]];

    // the Unicode representation
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[synergyPreferences objectForKey:
            _woIncreaseRatingUnicodePrefKey]]];

    // pass identifier here, so that the sheet knows where it was called from
    [self startHotKeySheet:@"increaseRating"];
}

- (IBAction)setRateAs0HotKeyButtonClicked:(id)sender
{
    // update description
    [hotKeySheetDescriptionTextField setStringValue:
        NSLocalizedStringFromTableInBundle(@"Rate as no stars",
                                               @"",
                                               [NSBundle bundleForClass:[self class]],
                                               @"'Rate as no stars' text")];

    // update to reflect current hot key setting (if any)

    // modifier flags
    [keyCaptureView setModifierFlags:
        [[synergyPreferences objectForKey:_woRateAs0ModifierPrefKey]
            unsignedIntValue]];

    // raw key code
    [keyCaptureView setKeyCode:
        [[synergyPreferences objectForKey:_woRateAs0KeycodePrefKey]
            unsignedShortValue]];

    // the Unicode representation
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[synergyPreferences objectForKey:
            _woRateAs0UnicodePrefKey]]];

    // pass identifier here, so that the sheet knows where it was called from
    [self startHotKeySheet:@"rateAs0"];
}

- (IBAction)setRateAs1HotKeyButtonClicked:(id)sender
{
    // update description
    [hotKeySheetDescriptionTextField setStringValue:
        [NSString stringWithFormat:@"%@ %C",
            NSLocalizedStringFromTableInBundle(@"Rate as",
                                               @"",
                                               [NSBundle bundleForClass:[self class]],
                                               @"'Rate as' text"),
            WO_RATING_STAR_UNICODE_CHAR]];

    // update to reflect current hot key setting (if any)

    // modifier flags
    [keyCaptureView setModifierFlags:
        [[synergyPreferences objectForKey:_woRateAs1ModifierPrefKey]
            unsignedIntValue]];

    // raw key code
    [keyCaptureView setKeyCode:
        [[synergyPreferences objectForKey:_woRateAs1KeycodePrefKey]
            unsignedShortValue]];

    // the Unicode representation
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[synergyPreferences objectForKey:
            _woRateAs1UnicodePrefKey]]];

    // pass identifier here, so that the sheet knows where it was called from
    [self startHotKeySheet:@"rateAs1"];
}


- (IBAction)setRateAs2HotKeyButtonClicked:(id)sender
{
    // update description
    [hotKeySheetDescriptionTextField setStringValue:
        [NSString stringWithFormat:@"%@ %C%C",
            NSLocalizedStringFromTableInBundle(@"Rate as",
                                               @"",
                                               [NSBundle bundleForClass:[self class]],
                                               @"'Rate as' text"),
            WO_RATING_STAR_UNICODE_CHAR,
            WO_RATING_STAR_UNICODE_CHAR]];


    // update to reflect current hot key setting (if any)

    // modifier flags
    [keyCaptureView setModifierFlags:
        [[synergyPreferences objectForKey:_woRateAs2ModifierPrefKey]
            unsignedIntValue]];

    // raw key code
    [keyCaptureView setKeyCode:
        [[synergyPreferences objectForKey:_woRateAs2KeycodePrefKey]
            unsignedShortValue]];

    // the Unicode representation
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[synergyPreferences objectForKey:
            _woRateAs2UnicodePrefKey]]];

    // pass identifier here, so that the sheet knows where it was called from
    [self startHotKeySheet:@"rateAs2"];
}

- (IBAction)setRateAs3HotKeyButtonClicked:(id)sender
{
    // update description
    [hotKeySheetDescriptionTextField setStringValue:
        [NSString stringWithFormat:@"%@ %C%C%C",
            NSLocalizedStringFromTableInBundle(@"Rate as",
                                               @"",
                                               [NSBundle bundleForClass:[self class]],
                                               @"'Rate as' text"),
            WO_RATING_STAR_UNICODE_CHAR,
            WO_RATING_STAR_UNICODE_CHAR,
            WO_RATING_STAR_UNICODE_CHAR]];


    // update to reflect current hot key setting (if any)

    // modifier flags
    [keyCaptureView setModifierFlags:
        [[synergyPreferences objectForKey:_woRateAs3ModifierPrefKey]
            unsignedIntValue]];

    // raw key code
    [keyCaptureView setKeyCode:
        [[synergyPreferences objectForKey:_woRateAs3KeycodePrefKey]
            unsignedShortValue]];

    // the Unicode representation
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[synergyPreferences objectForKey:
            _woRateAs3UnicodePrefKey]]];

    // pass identifier here, so that the sheet knows where it was called from
    [self startHotKeySheet:@"rateAs3"];
}

- (IBAction)setRateAs4HotKeyButtonClicked:(id)sender
{
    // update description
    [hotKeySheetDescriptionTextField setStringValue:
        [NSString stringWithFormat:@"%@ %C%C%C%C",
            NSLocalizedStringFromTableInBundle(@"Rate as",
                                               @"",
                                               [NSBundle bundleForClass:[self class]],
                                               @"'Rate as' text"),
            WO_RATING_STAR_UNICODE_CHAR,
            WO_RATING_STAR_UNICODE_CHAR,
            WO_RATING_STAR_UNICODE_CHAR,
            WO_RATING_STAR_UNICODE_CHAR]];


    // update to reflect current hot key setting (if any)

    // modifier flags
    [keyCaptureView setModifierFlags:
        [[synergyPreferences objectForKey:_woRateAs4ModifierPrefKey]
            unsignedIntValue]];

    // raw key code
    [keyCaptureView setKeyCode:
        [[synergyPreferences objectForKey:_woRateAs4KeycodePrefKey]
            unsignedShortValue]];

    // the Unicode representation
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[synergyPreferences objectForKey:
            _woRateAs4UnicodePrefKey]]];

    // pass identifier here, so that the sheet knows where it was called from
    [self startHotKeySheet:@"rateAs4"];
}

- (IBAction)setRateAs5HotKeyButtonClicked:(id)sender
{
    // update description
    [hotKeySheetDescriptionTextField setStringValue:
        [NSString stringWithFormat:@"%@ %C%C%C%C%C",
            NSLocalizedStringFromTableInBundle(@"Rate as",
                                               @"",
                                               [NSBundle bundleForClass:[self class]],
                                               @"'Rate as' text"),
            WO_RATING_STAR_UNICODE_CHAR,
            WO_RATING_STAR_UNICODE_CHAR,
            WO_RATING_STAR_UNICODE_CHAR,
            WO_RATING_STAR_UNICODE_CHAR,
            WO_RATING_STAR_UNICODE_CHAR]];


    // update to reflect current hot key setting (if any)

    // modifier flags
    [keyCaptureView setModifierFlags:
        [[synergyPreferences objectForKey:_woRateAs5ModifierPrefKey]
            unsignedIntValue]];

    // raw key code
    [keyCaptureView setKeyCode:
        [[synergyPreferences objectForKey:_woRateAs5KeycodePrefKey]
            unsignedShortValue]];

    // the Unicode representation
    [keyCaptureView setRepresentation:
        [self unsignedShortValueForHexString:[synergyPreferences objectForKey:
            _woRateAs5UnicodePrefKey]]];

    // pass identifier here, so that the sheet knows where it was called from
    [self startHotKeySheet:@"rateAs5"];
}

- (IBAction)extraFeedbackToggleClicked:(id)sender
{
    if ([extraFeedbackToggle state] == NSOffState)
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woShowFeedbackWindowPrefKey];
    }
    else
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woShowFeedbackWindowPrefKey];
    }

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (IBAction)includeAlbumInFloaterToggleClicked:(id)sender
{
    if ([includeAlbumInFloaterToggle state] == NSOffState)
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woIncludeAlbumInFloaterPrefKey];
    }
    else
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woIncludeAlbumInFloaterPrefKey];
    }

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (IBAction)includeArtistInFloaterToggleClicked:(id)sender
{
    if ([includeArtistInFloaterToggle state] == NSOffState)
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woIncludeArtistInFloaterPrefKey];
    }
    else
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woIncludeArtistInFloaterPrefKey];
    }

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (IBAction)includeComposerInFloaterToggleClicked:(id)sender
{
    if ([includeComposerInFloaterToggle state] == NSOffState)
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woIncludeComposerInFloaterPrefKey];
    else
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woIncludeComposerInFloaterPrefKey];
    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (IBAction)includeArtistInRecentTracksToggleClicked:(id)sender
{
    // _woIncludeArtistInRecentTracksPrefKey
    if ([includeArtistInRecentTracksToggle state] == NSOffState)
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woIncludeArtistInRecentTracksPrefKey];
    }
    else
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woIncludeArtistInRecentTracksPrefKey];
    }

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
    [self updateGlobalMenuStatus];
}

- (IBAction)includeDurationInFloaterToggleClicked:(id)sender
{
    if ([includeDurationInFloaterToggle state] == NSOffState)
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woIncludeDurationInFloaterPrefKey];
    }
    else
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woIncludeDurationInFloaterPrefKey];

    }

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (IBAction)includeYearInFloaterToggleClicked:(id)sender
{
    if ([includeYearInFloaterToggle state] == NSOffState)
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woIncludeYearInFloaterPrefKey];
    }
    else
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woIncludeYearInFloaterPrefKey];

    }

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (IBAction)includeRatingInFloaterToggleClicked:(id)sender
{
    if ([includeRatingInFloaterToggle state] == NSOffState)
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woIncludeStarRatingInFloaterPrefKey];
    }
    else
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woIncludeStarRatingInFloaterPrefKey];
    }

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (void)changeButtonStyle
{
    // adjust size of frame depending which buttons are displayed
    int totalWidth = [synergyMenuView calculateControlsStatusItemWidth];

    NSSize menuViewFrameSize = NSMakeSize(totalWidth,controlViewHeight);

    [synergyMenuView setFrameSize:menuViewFrameSize];

    // these methods don't re-add the buttons: they just refresh them
    if ([[synergyPreferences objectForKey:_woPrevButtonInMenuPrefKey] boolValue])
        [synergyMenuView showPrevButton];

    if ([[synergyPreferences objectForKey:_woPlayButtonInMenuPrefKey] boolValue])
        [synergyMenuView showPlayButton];

    if ([[synergyPreferences objectForKey:_woNextButtonInMenuPrefKey] boolValue])
        [synergyMenuView showNextButton];

}

- (IBAction)preprocessToggleClicked:(id)sender
{
    if ([preprocessToggle state] == NSOffState)
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woPreprocessTogglePrefKey];
    else
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woPreprocessTogglePrefKey];

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (IBAction)autoConnectToggleClicked:(id)sender
{
    if ([autoConnectToggle state] == NSOffState)
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woAutoConnectTogglePrefKey];
    else
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woAutoConnectTogglePrefKey];

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (IBAction)bringITunesToFrontToggleClicked:(id)sender
{
    if ([bringITunesToFrontToggle state] == NSOffState)
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woBringITunesToFrontPrefKey];
    else
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woBringITunesToFrontPrefKey];

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (IBAction)prevActionToggleClicked:(id)sender
{
    if ([prevActionToggle state] == NSOffState)
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woPrevActionSameAsITunesPrefKey];
    else
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woPrevActionSameAsITunesPrefKey];

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (IBAction)randomButtonStyleToggleClicked:(id)sender
{
    // when active, ghost button style popup and change its tooltip to explain
    // why it is not available

    if ([randomButtonStyleToggle state] == NSOffState)
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:NO]
                               forKey:_woRandomButtonStylePrefKey];

        [self enableButtonStylePopUp];
    }
    else
    {
        [synergyPreferences setObject:[NSNumber numberWithBool:YES]
                               forKey:_woRandomButtonStylePrefKey];

        [self disableButtonStylePopUp];
    }

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (void)enableButtonStylePopUp
{
    [buttonStylePopUpButton setEnabled:YES];
    [buttonStylePopUpButton setToolTip:
        NSLocalizedStringFromTableInBundle
        (@"Changes the visual appearance of the Synergy Menu Bar buttons",
         @"",
         [NSBundle bundleForClass:[self class]],
         @"Tool-tip for button style popup (not ghosted)")];
}

- (void)disableButtonStylePopUp
{
    [buttonStylePopUpButton setEnabled:NO];
    [buttonStylePopUpButton setToolTip:
        NSLocalizedStringFromTableInBundle
        (@"Changes the visual appearance of the Synergy Menu Bar buttons\n(Disabled because \"Choose random button style\" is selected in the Advanced Tab",
         @"",
         [NSBundle bundleForClass:[self class]],
         @"Tool-tip for button style popup (ghosted)")];
}

// serial panel (sheet)
- (IBAction)serialButtonClicked:(id)sender
{
    // ensure that we are set up as delegate for the text fields
    // (this should actually be set up in IB)
    if ([serialPanelEmailTextField delegate] != self)
        [serialPanelEmailTextField setDelegate:self];
    if ([serialPanelSerialTextField delegate] != self)
        [serialPanelSerialTextField setDelegate:self];

    // get parent window (of System Preferences.app)
    NSView *selfView = [self mainView];
    NSWindow *parentWindow = [selfView window];

    // display the sheet
    [NSApp beginSheet:serialPanel
       modalForWindow:parentWindow
        modalDelegate:self
       didEndSelector:@selector(processSerialPanelResult:returnCode:)
          contextInfo:nil];
}

- (void)processSerialPanelResult:(id)panel
                      returnCode:(int)returnCode
{
    // strange Cocoa behaviour here:
    // if user clicks OK, the order of method invocation is:
    //   1. processSerialPanelResult:returnCode:
    //   2. serialPanelOKButtonClicked:
    // if user clicks Cancel, the order is reversed!
}

// timer-driven check to see if Synergy is still running (updates "Start/Stop"
// button)
- (void)checkSynergyRunning:(NSTimer *)timer
{
    // test if Synergy is already running and modify start/stop button
    // accordingly
    ProcessSerialNumber synergyAppPSN =
        [WOProcessManager PSNForSignature:'Snrg'];

    if ([WOProcessManager PSNEqualsNoProcess:synergyAppPSN])
    {
        // Synergy is not running, so set ToggleState to NO (not running)
        startToggleState = NO;
        // adjust the toggle button to show an appropriate state
        [self makeToggleShowStart];

        // update state variable
        [synergyApp setAppState:WODNStopped];
    }
    else
    {
        // Synergy is running, so set ToggleState to YES (running)
        startToggleState = YES;
        // adjust the toggle button to show an appropriate state
        [self makeToggleShowStop];

        // update state variable
        [synergyApp setAppState:WODNRunning];
    }
}

- (IBAction)serialPanelOKButtonClicked:(id)sender
{
}

- (IBAction)serialPanelCancelButtonClicked:(id)sender
{
    // make sheet go away
    [serialPanel orderOut:nil];
    [NSApp endSheet:serialPanel returnCode:SHEET_CANCEL];
}

// delegate methods for serial panel
- (void)controlTextDidChange:(NSNotification *)notification
{
}

// updates the serial, serial status etc fields
- (void)updateRegistrationObjects
{
    // unregistered!
    [serialStatusTextField setStringValue:NSLocalizedStringFromTableInBundle
        (@"Registered (Single user)", @"", [NSBundle bundleForClass:[self class]], @"Single user license description")];

    // MacHeist: disable "Enter serial number" and "Unregister" buttons
        [serialButton setEnabled:NO];
}

// methods for auto-scrolling about box

// use NSTabView delegate so we can be notified of tab coming into/out-of view
// the delegate connection is made in IB

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    // ensure we have correct NSTabView
    if (tabView != mainTabView)
        return;

    // ensure we can find correct NSTabViewItem
    int aboutTab = [tabView indexOfTabViewItemWithIdentifier:@"aboutTab"];
    if (aboutTab == NSNotFound)
    {
        ELOG(@"Unable to locate \"About\" tab using identifier \"aboutTab\"");
        return;
    }

    // have to do it this way because I can't get IB to give me a connection
    // directly to the About tab
    if (tabViewItem == [tabView tabViewItemAtIndex:aboutTab])
    {
        // about to select the "About" tab

        // reset scroll to starting position
        currentPoint = 0.0;

        [aboutField scrollPoint:NSMakePoint(0.0, currentPoint)];
    }
    // else, about to select some tab other than the "About" tab, do nothing
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    // ensure we have correct NSTabView
    if (tabView != mainTabView)
        return;

    // ensure we can find correct NSTabViewItem
    int aboutTab = [tabView indexOfTabViewItemWithIdentifier:@"aboutTab"];
    if (aboutTab == NSNotFound)
    {
        ELOG(@"Unable to locate \"About\" tab using identifier \"aboutTab\"");
        return;
    }

    // have to do it this way because I can't get IB to give me a connection
    // directly to the About tab
    if (tabViewItem == [tabView tabViewItemAtIndex:aboutTab])
    {
        // just selected the "About" tab

        // if timer already running (shouldn't be) stop it
        if (scrollTimer)
        {
            if ([scrollTimer isValid])
                [scrollTimer invalidate];
            scrollTimer = nil;
        }

        // start timer
        scrollTimer = [NSTimer scheduledTimerWithTimeInterval:WO_CREDITS_SCROLL_TIME_VALUE
                                                       target:self
                                                     selector:@selector(scrollCredits:)
                                                     userInfo:@"Incremental scroll"
                                                      repeats:YES];

    }
    else
    {
        // else, we have a different tab, stop timer if running (stop scrolling)
        if (scrollTimer)
        {
            if ([scrollTimer isValid])
                [scrollTimer invalidate];
            scrollTimer = nil;
        }

    }
}

// timer-driven method for scrolling credits in the About Tab
- (void)scrollCredits:(NSTimer *)timer
{
    // make sure we have the right NSTimer
    if (timer != scrollTimer)
        return;

    // in the normal case, we just keep on scrolling
    if ([[timer userInfo] isEqualToString:@"Incremental scroll"])
    {
        // this is just an incremental update, scroll 2 pixels at a time
        currentPoint += WO_CREDITS_SCROLL_PIXEL_JUMP;

        [aboutField scrollPoint:NSMakePoint(0.0, currentPoint)];

        // test to see if scroll is finished
        if (currentPoint >
            ((aboutStringSize.height * WO_APPKIT_STRING_SIZE_BUG_FACTOR) +
             aboutFieldBounds.size.height))
        {
            // restart scrolling from bottom
            currentPoint = 0.0;

            // note: there is no ill consequence if we try to draw
            // "out of bounds", as you might expect could occur when multiplying
            // by the WO_APPKIT_STRING_SIZE_BUG_FACTOR; the text will simply
            // remain at its highest allowed point
        }
        else if (currentPoint == aboutFieldBounds.size.height)
            // this test will match at some point if we choose a safe value,
            // like 1.0, for WO_CREDITS_SCROLL_PIXEL_JUMP
        {
            // special case: text is at top of field, pause for dramatic effect
            [scrollTimer invalidate];
            scrollTimer = nil;

            // set up pause timer
            scrollTimer = [NSTimer scheduledTimerWithTimeInterval:WO_CREDITS_SCROLL_PAUSE_TIME
                                                            target:self
                                                          selector:@selector(scrollCredits:)
                                                          userInfo:@"Paused scroll"
                                                           repeats:NO];
        }
        // else do nothing special
    }
    else
    {
        // special case: scrolling was paused, now unpause it
        if ([scrollTimer isValid])
            [scrollTimer invalidate];
        scrollTimer = nil;

        // start timer
        scrollTimer = [NSTimer scheduledTimerWithTimeInterval:WO_CREDITS_SCROLL_TIME_VALUE
                                                        target:self
                                                      selector:@selector(scrollCredits:)
                                                      userInfo:@"Incremental scroll"
                                                       repeats:YES];
    }
}

// generic toggle-handling method
// (all NSButton toggles should pass through this method so as to reduce
// number of methods/connections in Interface Builder)
- (IBAction)toggleClicked:(id)sender
{
    // sanity check
    if (![sender isKindOfClass:[NSButton class]])
        return;

    // the key (in the preferences dictionary)
    id key = nil;

    // the object for that key; in the case of a toggle, always an NSNumber with
    // a bool value
    NSNumber *newValue;

    if ([sender state] == NSOffState)
        newValue = [NSNumber numberWithBool:NO];
    else
        newValue = [NSNumber numberWithBool:YES];

    // "Show Global Menu as a separate menu item (not integrated into Play/Pause
    // button)"
    if (sender == globalMenuToggle)
    {
        key = _woGlobalMenuPrefKey;

        // enable/disable sub-toggle as appropriate
        [globalMenuOnlyWhenControlsHiddenToggle setEnabled:
            [newValue boolValue]];

        goto done;
    }

    // "Only when Menu Bar control buttons are hidden"
    if (sender == globalMenuOnlyWhenControlsHiddenToggle)
    {
        key = _woGlobalMenuOnlyWhenHiddenPrefKey;
        goto done;
    }

    // "Use Menu Extra mode if possible"
    if (sender == useNSMenuExtraToggle)
    {
        key = _woUseNSMenuExtraPrefKey;
        goto done;
    }

done:
    if (key)
        [synergyPreferences setObject:newValue
                               forKey:key];

    [self updateRevertButton];
    [self updateDefaultsButton];
    [self updateApplyButton];
}

- (IBAction)getMoreButtonSets:(id)sender
{
    if ([[NSWorkspace sharedWorkspace] openURL:
        [NSURL URLWithString:@"http://wincent.com/a/products/synergy-classic/buttons/"]] == NO)
        VLOG(@"Failed to open http://wincent.com/a/products/synergy-classic/buttons/ in default browser");
}

- (BOOL)iTunesSendsNotifications
{
    static BOOL firstRun = YES;

    if (!firstRun) return iTunesSendsNotifications;

    firstRun = NO;

    NSWorkspace *workspace  = [NSWorkspace sharedWorkspace];
    NSString    *path       = [workspace fullPathForApplication:@"iTunes.app"];
    if (path)
    {
        NSBundle     *bundle     = [NSBundle bundleWithPath:path];
        NSDictionary *info       = [bundle infoDictionary];
        NSString     *version    = [info objectForKey:@"CFBundleVersion"];
        NSArray      *components = [version componentsSeparatedByString:@"."];
        if (components && ([components count] >= 2))
        {
            int majorVersion, minorVersion;
            NSScanner *scanner1 = [NSScanner scannerWithString:[components objectAtIndex:0]];
            NSScanner *scanner2 = [NSScanner scannerWithString:[components objectAtIndex:1]];

            if ([scanner1 scanInt:&majorVersion] && [scanner2 scanInt:&minorVersion])
            {
                if (((majorVersion == 4) && (minorVersion >= 7)) || (majorVersion > 4))
                    iTunesSendsNotifications = YES;
            }
        }
    }

    return iTunesSendsNotifications;
}

- (IBAction)audioscrobblerButtonClicked:(id)sender
{
    // load nib
    if (!audioscrobblerController)
    {
        audioscrobblerController = [[WOAudioscrobblerController alloc] init];
        if (![NSBundle loadNibNamed:@"audioscrobbler" owner:audioscrobblerController])
        {
            NSLog(@"error: failed to load audioscrobbler nib");
            audioscrobblerController = nil;
            return;
        }
    }

    // show the sheet
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
        NSStringFromSelector(@selector(audioscrobblerAccountDetailsUpdated:)),  WO_SELECTOR,
        self,                                                                   WO_TARGET, nil];
    [audioscrobblerController beginSheetModalForWindow:[[self mainView] window] contextInfo:info];
}

- (void)audioscrobblerAccountDetailsUpdated:(NSNumber *)didUpdate
{
    // notify app if it is running
    if (didUpdate && [didUpdate boolValue])
        [synergyApp notifyApp:WODNAppReadPrefs];

    // balance alloc/int in audioscrobblerButtonClicked method
    audioscrobblerController = nil;
}

@end
