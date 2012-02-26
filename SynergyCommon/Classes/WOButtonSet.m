// WOButtonSet.m
// Copyright 2003-2010 Wincent Colaiuta. All rights reserved.

#import "WOButtonSet.h"
#import "WODebug.h"
#import "WOSynergyGlobal.h"
#import "WONSFileManagerExtensions.h"

// for Random() function
#import <Carbon/Carbon.h>

// private methods
@interface WOButtonSet (_private)

// accessors that should only be used from the +init method
- (void)_setPlayPauseImage:(NSImage *)newImage;
- (void)_setPlayImage:(NSImage *)newImage;
- (void)_setPauseImage:(NSImage *)newImage;
- (void)_setStopImage:(NSImage *)newImage;
- (void)_setNextImage:(NSImage *)newImage;
- (void)_setPrevImage:(NSImage *)newImage;

// other private accessors
- (void)_setPlayPauseImageSize:(NSSize)newSize;
- (void)_setPlayImageSize:(NSSize)newSize;
- (void)_setPauseImageSize:(NSSize)newSize;
- (void)_setStopImageSize:(NSSize)newSize;
- (void)_setNextImageSize:(NSSize)newSize;
- (void)_setPrevImageSize:(NSSize)newSize;

// returns "~/Application Support/Button Sets/" etc
+ (NSArray *)_searchPaths;

@end

@implementation WOButtonSet

// returns "~/Application Support/Button Sets/" etc
+ (NSArray *)_searchPaths
{
    NSMutableArray  *searchPaths        = [NSMutableArray arrayWithCapacity:3];
    NSString        *dirName            = @"Button Sets";
    NSString        *bundlePath         = [[NSBundle bundleForClass:[self class]] bundlePath];
    bundlePath = [bundlePath stringByAppendingPathComponent:@"Contents"];
#ifdef SYNERGY_PREF_BUILD
    // special hack to get preference pane to share button sets with application
    bundlePath = [bundlePath stringByAppendingPathComponent:@"Helpers"];
    bundlePath = [bundlePath stringByAppendingPathComponent:@"Synergy.app"];
    bundlePath = [bundlePath stringByAppendingPathComponent:@"Contents"];
    bundlePath = [bundlePath stringByAppendingPathComponent:@"Resources"];
#else
    bundlePath = [bundlePath stringByAppendingPathComponent:@"Resources"];
#endif

    NSString        *homeAppSupport     =
        [[NSFileManager defaultManager] findSystemFolderType:kApplicationSupportFolderType
                                                   forDomain:kUserDomain
                                                   creating:NO];
    NSString        *globalAppSupport   =
        [[NSFileManager defaultManager] findSystemFolderType:kApplicationSupportFolderType
                                                   forDomain:kLocalDomain
                                                    creating:NO];

    if (bundlePath)
        [searchPaths addObject:[bundlePath stringByAppendingPathComponent:dirName]];
    if (homeAppSupport)
    {
        homeAppSupport = [homeAppSupport stringByAppendingPathComponent:@"Synergy"];
        homeAppSupport = [homeAppSupport stringByAppendingPathComponent:dirName];
        [searchPaths addObject:homeAppSupport];
    }
    if (globalAppSupport)
    {
        globalAppSupport = [globalAppSupport stringByAppendingPathComponent:@"Synergy"];
        globalAppSupport = [globalAppSupport stringByAppendingPathComponent:dirName];
        [searchPaths addObject:globalAppSupport];
    }
    return searchPaths;
}

// returns the full path to the directory where new button sets should be installed
+ (NSString *)installPath
{
    NSFileManager *manager = [NSFileManager defaultManager];

    // check for and try to create "~/Library/Application Support/" if necessary
    NSString *homeAppSupport =
        [manager findSystemFolderType:kApplicationSupportFolderType
                            forDomain:kUserDomain
                             creating:YES];

    NSString *synergySubdir = [homeAppSupport stringByAppendingPathComponent:@"Synergy"];
    NSString *buttonsSubdir = [synergySubdir stringByAppendingPathComponent:@"Button Sets"];

    // check for and try to create "~/Library/Application Support/Synergy/" if necessary
    BOOL synergySubdirIsDirectory;
    BOOL synergySubdirExists = [manager fileExistsAtPath:synergySubdir isDirectory:&synergySubdirIsDirectory];

    if (!synergySubdirExists)
    {
        if (![manager createDirectoryAtPath:synergySubdir
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:NULL])
            return nil;
    }
    else if (!synergySubdirIsDirectory)
        return nil;

    // check for and try to create "~/Library/Application Support/Synergy/Button Sets" if necessary
    BOOL buttonsSubdirIsDirectory;
    BOOL buttonsSubdirExists = [manager fileExistsAtPath:buttonsSubdir isDirectory:&buttonsSubdirIsDirectory];

    if (!buttonsSubdirExists)
    {
        if (![manager createDirectoryAtPath:buttonsSubdir
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:NULL])
              return nil;
    }
    else if (!buttonsSubdirIsDirectory)
        return nil;

    return buttonsSubdir;
}


// returns an array of available button set names (NSStrings)
+ (NSArray *)availableButtonSets
{
    NSMutableArray  *returnArray    = [NSMutableArray array];
    NSArray         *searchPaths    = [WOButtonSet _searchPaths];

    unsigned i, max = [searchPaths count];
    for (i = 0; i < max; i++)
    {
        NSArray *directoryEntries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[searchPaths objectAtIndex:i]
                                                                                        error:NULL];
        NSEnumerator *enumerator = [directoryEntries objectEnumerator];
        NSString *entry;

        while ((entry = [enumerator nextObject]))
        {
            if ([[entry pathExtension] isEqualToString:@"synergyButtons"])
            {
                NSString *baseName = [entry stringByDeletingPathExtension];
               if (![returnArray containsObject:baseName])
               {
                   [returnArray addObject:baseName];
               }
            }
        }
    }

    [returnArray sortUsingSelector:@selector(caseInsensitiveCompare:)];

    return [NSArray arrayWithArray:returnArray];
}

// this is the only approved way to init a WOButtonSet object
- (id)initWithButtonSetName:(NSString *)theName
{
    self = [super init];

    if (!theName) theName = WO_DEFAULT_BUTTON_SET; // fallback button set

    NSArray *searchPaths = [WOButtonSet _searchPaths];

    unsigned i, max = [searchPaths count];
    BOOL directoryFound = NO, tryForFallbackSet = YES;
    NSString *buttonDir = nil;

    do
    {
        for (i = 0; i < max; i++)
        {
            buttonDir = [[[searchPaths objectAtIndex:i] stringByAppendingPathComponent:theName] stringByAppendingPathExtension:@"synergyButtons"];

            BOOL isDirectory;
            if ([[NSFileManager defaultManager] fileExistsAtPath:buttonDir isDirectory:&isDirectory] &&
                isDirectory)
            {
                directoryFound = YES;
                break;
            }
        }

        tryForFallbackSet = (!tryForFallbackSet);
        theName = WO_DEFAULT_BUTTON_SET;

    } while (directoryFound == NO && tryForFallbackSet == NO);

    if (!directoryFound)
    {
        NSLog(@"Couldn't find requested button set, or fallback set (%@)", theName);
        return self; // expect real weirdness with no button set
    }

    // load images: in the case of the app build, load all images
    // in the case of the pref pane build, only load "prev", "play" and "next"

#ifdef SYNERGY_APP_BUILD

    NSString *playPauseImagePath =
        [[buttonDir stringByAppendingPathComponent:@"playPauseImage"] stringByAppendingPathExtension:@"png"];

    // NSImage will return nil here if there is any failure
    [self _setPlayPauseImage:
        [[NSImage alloc] initWithContentsOfFile:playPauseImagePath]];

    NSString *pauseImagePath =
        [[buttonDir stringByAppendingPathComponent:@"pauseImage"] stringByAppendingPathExtension:@"png"];

    [self _setPauseImage:
        [[NSImage alloc] initWithContentsOfFile:pauseImagePath]];

    NSString *stopImagePath =
        [[buttonDir stringByAppendingPathComponent:@"stopImage"] stringByAppendingPathExtension:@"png"];

    [self _setStopImage:
        [[NSImage alloc] initWithContentsOfFile:stopImagePath]];

    // cause Quartz to cache the image
    [[self playPauseImage] lockFocus];
    [[self playPauseImage] unlockFocus];
    [[self pauseImage] lockFocus];
    [[self pauseImage] unlockFocus];
    [[self stopImage] lockFocus];
    [[self stopImage] unlockFocus];

#endif /* SYNERGY_APP_BUILD */

    // these images will be loaded by both the app build and the prefPane build

    NSString *playImagePath =
        [[buttonDir stringByAppendingPathComponent:@"playImage"] stringByAppendingPathExtension:@"png"];

    [self _setPlayImage:
        [[NSImage alloc] initWithContentsOfFile:playImagePath]];

    NSString *nextImagePath =
        [[buttonDir stringByAppendingPathComponent:@"nextImage"] stringByAppendingPathExtension:@"png"];

    [self _setNextImage:
        [[NSImage alloc] initWithContentsOfFile:nextImagePath]];

    NSString *prevImagePath =
        [[buttonDir stringByAppendingPathComponent:@"prevImage"] stringByAppendingPathExtension:@"png"];

    [self _setPrevImage:
        [[NSImage alloc] initWithContentsOfFile:prevImagePath]];

    // cause Quartz to cache the image
    [[self playImage] lockFocus];
    [[self playImage] unlockFocus];
    [[self nextImage] lockFocus];
    [[self nextImage] unlockFocus];
    [[self prevImage] lockFocus];
    [[self prevImage] unlockFocus];

    // cache image sizes

#ifdef SYNERGY_APP_BUILD

    // these image sizes will be cached only in the app build
    [self _setPlayPauseImageSize:[playPauseImage size]];
    [self _setPauseImageSize:[pauseImage size]];
    [self _setStopImageSize:[stopImage size]];

#endif /* SYNERGY_APP_BUILD */

#ifdef SYNERGY_PREF_BUILD

    // these image sizes will be set to harmless values in the pref build
    [self _setPlayPauseImageSize:NSZeroSize];
    [self _setPauseImageSize:NSZeroSize];
    [self _setStopImageSize:NSZeroSize];

#endif /* SYNERGY_PREF_BUILD */

    // these image sizes will be cached by both the app and the prefPane build
    [self _setPlayImageSize:[playImage size]];
    [self _setNextImageSize:[nextImage size]];
    [self _setPrevImageSize:[prevImage size]];

    return self;
}

// returns a button set index in the range of min <-> max
+ (int)randomButtonSetMin:(int)min max:(int)max
{
    NSParameterAssert(min <= max);
    int buttonSet;

    // not all that random, but ah well...
    SInt16 randNum = (SInt16)random(); // cast from long

    // scale to 0 <-> 65534
    UInt16 unsignedRandNum = randNum + 32767;

    // scale to 0.0 <-> 1.0
    float scaledRand = (unsignedRandNum / 65534.0);

    int range = max - min;

    // before multiplying the range by the random float value, add one
    // this compensates for the floor statement below, which will always round
    // down (otherwise we would only return values in the range min <-> max - 1)
    float rangeByRand = ((range + 1) * scaledRand);

    buttonSet = min + floor(rangeByRand);

    // boundary case: when randNum = 32767, unsignedRandNum = 65534,
    // scaledRand = 1.0, rangeByRand = max + 1,
    // min + floor(rangeByRand) = max + 1:
    if (buttonSet > max)
        return max;

    return buttonSet;
}

// wrapper that calls class method of same name
- (int)randomButtonSetMin:(int)min max:(int)max
{
    return [[self class] randomButtonSetMin:min max:max];
}

// TODO: move to Objective-C 2.0 properties here instead of hand-coded accessors

// public accessors

- (NSString *)buttonSetName
{
    return buttonSetName;
}

- (NSImage *)playPauseImage
{
    return playPauseImage;
}

- (NSImage *)playImage
{
    return playImage;
}


- (NSImage *)pauseImage
{
    return pauseImage;
}

- (NSImage *)stopImage
{
    return stopImage;
}

- (NSImage *)nextImage
{
    return nextImage;
}

- (NSImage *)prevImage
{
    return prevImage;
}

- (NSSize)playPauseImageSize
{
    return playPauseImageSize;
}

- (NSSize)playImageSize
{
    return playImageSize;
}

- (NSSize)pauseImageSize
{
    return pauseImageSize;
}

- (NSSize)stopImageSize
{
    return stopImageSize;
}

- (NSSize)nextImageSize
{
    return nextImageSize;
}

- (NSSize)prevImageSize
{
    return prevImageSize;
}

// private accessors that should only be used from the +init method

- (void)_setPlayPauseImage:(NSImage *)newImage
{
    playPauseImage = newImage;
}

- (void)_setPlayImage:(NSImage *)newImage
{
    playImage = newImage;
}

- (void)_setPauseImage:(NSImage *)newImage
{
    pauseImage = newImage;
}

- (void)_setStopImage:(NSImage *)newImage
{
    stopImage = newImage;
}

- (void)_setNextImage:(NSImage *)newImage
{
    nextImage= newImage;
}

- (void)_setPrevImage:(NSImage *)newImage
{
    prevImage= newImage;
}

// other private accessors

- (void)_setPlayPauseImageSize:(NSSize)newSize
{
    playPauseImageSize = newSize;
}

- (void)_setPlayImageSize:(NSSize)newSize
{
    playImageSize = newSize;
}

- (void)_setPauseImageSize:(NSSize)newSize
{
    pauseImageSize = newSize;
}

- (void)_setStopImageSize:(NSSize)newSize
{
    stopImageSize = newSize;
}

- (void)_setNextImageSize:(NSSize)newSize
{
    nextImageSize = newSize;
}

- (void)_setPrevImageSize:(NSSize)newSize
{
    prevImageSize = newSize;
}

@end
