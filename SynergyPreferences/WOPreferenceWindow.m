// WOPreferenceWindow.m
// Copyright 2007-2010 Wincent Colaiuta.

// class header
#import "WOPreferenceWindow.h"

// other headers
#import "WOPreferencePane.h"

@interface WOPreferenceWindow ()

#pragma mark -
#pragma mark Notification methods

- (void)registerForNotifications;
- (void)unregisterForNotifications;
- (void)handleNotification:(NSNotification *)notification;

#pragma mark Property redeclarations

@property WOPreferencePane *pane;

@end

@implementation WOPreferenceWindow

+ (WOPreferenceWindow *)windowForPane:(NSString *)name
{
    // load the prefPane bundle
    NSString *mainBundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *contentsPath = [mainBundlePath stringByAppendingPathComponent:@"Contents"];
    NSString *prefPanesPath = [contentsPath stringByAppendingPathComponent:@"PreferencePanes"];
    NSString *path = [[prefPanesPath stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"prefPane"];
    NSBundle *bundle = [NSBundle bundleWithPath:path];
    [bundle load];
    NSString *className = [[bundle infoDictionary] objectForKey:@"NSPrincipalClass"];
    Class class = NSClassFromString(className);
    WOPreferencePane *thePane = [[class alloc] initWithBundle:bundle];
    NSView *mainView = [thePane loadMainView];

    // determine the size/location
    NSRect content = NSZeroRect;
    content = [mainView bounds];
    NSRect available = [[NSScreen mainScreen] visibleFrame];
    content.origin.x = NSMidX(available) - content.size.width / 2;
    content.origin.y = NSMidY(available) - content.size.height / 2;

    // initialize the window
    NSUInteger style = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask;
    WOPreferenceWindow *window = [[self alloc] initWithContentRect:content
                                                         styleMask:style
                                                           backing:NSBackingStoreBuffered
                                                             defer:YES];
    window.pane = thePane;
    [window setContentView:mainView];
    return window;
}

#pragma mark -
#pragma mark NSObject overrides

- (void)finalize
{
    [self unregisterForNotifications];
    [super finalize];
}

#pragma mark -
#pragma mark Notification methods

- (void)registerForNotifications
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(handleNotification:)
                   name:WOPreferencePaneCancelUnselectNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleNotification:)
                   name:WOPreferencePaneDoUnselectNotification
                 object:nil];
}

- (void)unregisterForNotifications
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:WOPreferencePaneCancelUnselectNotification object:nil];
    [center removeObserver:self name:WOPreferencePaneDoUnselectNotification object:nil];
}

- (void)handleNotification:(NSNotification *)notification
{
    if (!notification)
        return;
    NSString *name = [notification name];
    [self unregisterForNotifications];

    if ([WOPreferencePaneDoUnselectNotification isEqualToString:name])
    {
        if ([NSApp isEqual:target])
            [NSApp replyToApplicationShouldTerminate:YES];
        else
            [self close];
    }
    else if ([WOPreferencePaneCancelUnselectNotification isEqualToString:name])
    {
        if ([NSApp isEqual:target])
            [NSApp replyToApplicationShouldTerminate:NO];
    }
    target = nil;
}

#pragma mark -
#pragma mark NSApplication delegate methods

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    if (self.pane)
    {
        switch ([self.pane shouldUnselect])
        {
            case WOUnselectNow:
                return NSTerminateNow;
            case WOUnselectCancel:
                return NSTerminateCancel;
            case WOUnselectLater:
                target = NSApp;
                [self registerForNotifications];
                return NSTerminateLater;
            default:
                break;
        }
    }
    return NSTerminateNow;
}

#pragma mark -
#pragma mark NSWindow overrides

- (BOOL)windowShouldClose:(id)window
{
    if (self.pane)
    {
        switch ([self.pane shouldUnselect])
        {
            case WOUnselectNow:
                return YES;
            case WOUnselectCancel:
                return NO;
            case WOUnselectLater:
                target = nil;
                [self registerForNotifications];
                return NO;
            default:
                break;
        }
    }
    return YES;
}

#pragma mark -
#pragma mark Properties

@synthesize pane;

@end
