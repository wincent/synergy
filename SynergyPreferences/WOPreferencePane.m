// WOPreferencePane.m
// Synergy
//
// Copyright 2007-2009 Wincent Colaiuta. All rights reserved.

// class header
#import "WOPreferencePane.h"

// WOCommon headers
#import "WOPublic/WOConvenienceMacros.h"

#pragma mark -
#pragma mark Global variables

NSString *WOPreferencePaneDoUnselectNotification        = @"WOPreferencePaneDoUnselectNotification";
NSString *WOPreferencePaneCancelUnselectNotification    = @"WOPreferencePaneCancelUnselectNotification";

// export the class so the preference pane can link against the app using BUNDLE_LOADER
@implementation WOPreferencePane
WO_CLASS_EXPORT(WOHost);

- (id)initWithBundle:(NSBundle *)bundle
{
    if ((self = [super init]))
        _bundle = bundle;
    return self;
}

- (NSBundle *)bundle
{
    return _bundle;
}

- (NSView *)loadMainView
{
    NSNib *nib = [[NSNib alloc] initWithNibNamed:[self mainNibName] bundle:[self bundle]];
    if ([nib instantiateNibWithOwner:self topLevelObjects:NULL])
    {
        [self assignMainView];
        [self mainViewDidLoad];
        return [self mainView];
    }
    return nil;
}

- (void)mainViewDidLoad
{
    // overridden, but super not called
}

- (NSString *)mainNibName
{
    NSString *name = [[[self bundle] infoDictionary] objectForKey:@"NSMainNibFile"];
    return name ? name : @"Main";
}

- (void)assignMainView
{
    [self setMainView:[_window contentView]];
    _window = nil;
}

- (void)willSelect
{
    // default implementation does nothing
}

- (void)didSelect
{
    // default implementation does nothing
}

- (WOPreferencePaneUnselectReply)shouldUnselect
{
    // overridden, but super not called
    return WOUnselectNow;
}

// not overridden, but called
- (void)replyToShouldUnselect:(BOOL)shouldUnselect
{
    NSString *name = shouldUnselect ? WOPreferencePaneDoUnselectNotification : WOPreferencePaneCancelUnselectNotification;
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:nil userInfo:nil];
}

- (void)willUnselect
{
    // default implementation does nothing
}


- (void)didUnselect
{
    // default implementation does nothing
}

- (void)setMainView:(NSView *)view
{
    _mainView = view;
}

// not overridden, but called
- (NSView *)mainView
{
    return _mainView;
}

- (NSView *)initialKeyView
{
    return _initialKeyView;
}

- (void)setInitialKeyView:(NSView *)view
{
    _initialKeyView = view;
}

- (NSView *)firstKeyView
{
    return _firstKeyView;
}

- (void)setFirstKeyView:(NSView *)view
{
    _firstKeyView = view;
}

- (NSView *)lastKeyView
{
    return _lastKeyView;
}

- (void)setLastKeyView:(NSView *)view
{
    _lastKeyView = view;
}

- (BOOL)autoSaveTextFields
{
    return YES;
    // TODO: preference window responsibility to check this
    // If this method returns YES, text fields are forced to give up their responder status before shouldUnselect is called on the preference pane. If this method returns NO, the preference pane is responsible for forcing text fields to give up their responder status before saving them. The default return value is YES.
}

#if 0
// not implemented
- (BOOL)isSelected;
- (void)updateHelpMenuWithArray:(NSArray *)inArrayOfMenuItems;
#endif

@end
