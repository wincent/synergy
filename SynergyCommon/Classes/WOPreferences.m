// WOPreferences.m
// Synergy
//
// Copyright 2002-present Greg Hurrell. All rights reserved.

#import "WOPreferences.h"
#import "WODebug.h"

// WOPublic headers
#import "WOPublic/WOMemoryBarrier.h"

@interface WOPreferences (_private)

/*

 Low-level accessor methods:

 */

- (NSMutableDictionary *)_woDefaultPreferences;

- (void)_setWODefaultPreferences:(NSMutableDictionary *)newDefaultPreferences;

- (void)_setWOPreferencesOnDisk:(NSMutableDictionary *)newPreferencesOnDisk;

- (void)_setWONewPreferences:(NSMutableDictionary *)newNewPreferences;

@end

static WOPreferences *WOSharedPreferences = nil; 

@implementation WOPreferences

+ (WOPreferences *)sharedInstance
{
    WOPreferences *instance = WOSharedPreferences;
    WO_READ_MEMORY_BARRIER();
    if (!instance)
    {
        @synchronized ([WOPreferences class])
        {
            instance = WOSharedPreferences;
            if (!instance)
            {
                instance = [[WOPreferences alloc] init];
                WO_WRITE_MEMORY_BARRIER();
                WOSharedPreferences = instance;
            }
        }
    }
    return WOSharedPreferences;
}

- (id)init
{
    // trust WOSingleton class to avoid redundant multiple instantiations
    if ((self = [super init]))
    {
        _woDefaultPreferences   = [[NSMutableDictionary alloc] init];
        _woPreferencesOnDisk    = [[NSMutableDictionary alloc] init];
        woNewPreferences        = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)initialiseDefaultsDictionaryFromWithinAppBundle
{
    // read from "defaults.plist" file into a temporary NSDictionary
    NSDictionary *tempDictionary;
    NSString *defaultsFilePath =
        [[NSBundle bundleForClass:[self class]] pathForResource:@"defaults"
                                                         ofType:@"plist"];

    if ((tempDictionary =
        [NSDictionary dictionaryWithContentsOfFile:defaultsFilePath]))
        // success: store read defaults in _woDefaultPreferences
        [_woDefaultPreferences setDictionary:tempDictionary];
    else
        // non-fatal failure
        ELOG(@"Error reading defaults from %@", defaultsFilePath);

       // If the user deletes the defaults.plist file then the application
       // will behave unpredictably because no default values will be set.
}

- (void)initialiseDefaultsDictionaryFromWithinPrefPaneBundle
{
    // the same code will work within the prefPane bundle:
    [self initialiseDefaultsDictionaryFromWithinAppBundle];
}

// Register the defaults defined in this file with the system
- (void) registerStoredDefaultsWithSystem
{
    // this method will only have a useful effect if called from within an app
    // bundle.

    [[NSUserDefaults
        standardUserDefaults] registerDefaults:_woDefaultPreferences];
}

// Reset standardUserDefaults
- (void)resetStandardUserDefaults
/*"
 Sends a reset message to the NSUserDefaults shared defaults object. It is
 sometimes necessary to call this method in order to get around caching
 optimisations made by the Cocoa runtime that might prevent the defaults from
 being correctly re-read from the disk (a problem which can manifest when a
 program must re-read its preferences from disk several times to check for
 changes using the %readPrefsFromWithinAppBundle or
 %readPrefsFromWithinPrefPaneBundle methods)
"*/
{
    [NSUserDefaults resetStandardUserDefaults];
}

// Read the preferences from the disk (called from inside app bundle)
- (void) readPrefsFromWithinAppBundle
{
    [self initialiseDefaultsDictionaryFromWithinAppBundle];
    [self registerStoredDefaultsWithSystem];

    // read from disk
    [_woPreferencesOnDisk setDictionary:
        [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
    // any missing values will be automatically supplied from the defaults
    // registered with the system... (only works from within app bundle, not
    // prefPane)

    // Now set newPreferences to equal preferencesOnDisk
    [woNewPreferences setDictionary:_woPreferencesOnDisk];
}

// Read the preferences from the disk (called from inside prefPane bundle)
- (void) readPrefsFromWithinPrefPaneBundle
{
    /*

     The code for readPrefsFromWithinAppBundle and
     readPrefsFromWithinPrefPaneBundle is substantially similar but differs on
     two key points:

     1. The method for getting the defaults from disk is different.
     2. In the case of the prefPane, missing values will not be automatically
        supplied using the defaults registered with the system -- it has to be
        done manually here.

     */

    [self initialiseDefaultsDictionaryFromWithinPrefPaneBundle];

    // this Cocoa method won't work with an NSMutableDictionary, so use a
    // standard NSDictionary:
    NSDictionary *tempPreferences =
    [[NSUserDefaults standardUserDefaults] persistentDomainForName:
          [[NSBundle bundleForClass:[self class]] bundleIdentifier]];

    // start with values from disk
    [_woPreferencesOnDisk setDictionary:tempPreferences];

    // step through defaults dictionary, getting keys
    NSEnumerator *enumerator = [_woDefaultPreferences keyEnumerator];
    id key;

    while ((key = [enumerator nextObject]) != nil)
    {
        // for unset values, use default
        if ( [_woPreferencesOnDisk objectForKey:key] == nil)
            [_woPreferencesOnDisk setObject:[_woDefaultPreferences objectForKey:key] forKey:key];
    }

    // Now set newPreferences to equal preferencesOnDisk
    [woNewPreferences setDictionary:_woPreferencesOnDisk];

}

// Flush the preferences to the disk (called from inside prefPane bundle)
- (void) writePrefsFromPrefPaneBundle
{
    // delete prefs, then write out copy with new settings
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle bundleForClass:[self class]] bundleIdentifier]];

    [[NSUserDefaults standardUserDefaults] setPersistentDomain:woNewPreferences
                                                       forName:[[NSBundle bundleForClass:[self class]] bundleIdentifier]];

    // synchronize method forces a disk-write
    if ([[NSUserDefaults standardUserDefaults] synchronize] == NO)
        ELOG(@"Error writing preferences to disk");
    else
        // preferencesOnDisk now equal newPreferences
        [_woPreferencesOnDisk setDictionary:woNewPreferences];
}

// Flush preferences to disk (called from app... should rarely need to do this!)
- (void)writePrefsFromAppBundle
{
    // basically, same code should work from within app bundle
    [self writePrefsFromPrefPaneBundle];
}

// returns the value from _woPreferencesOnDisk
- (id) objectOnDiskForKey:(NSString *)keyName
{
    return [_woPreferencesOnDisk objectForKey:keyName];
}

// returns the value from woNewPreferences
- (id)objectForKey:(NSString *)keyName
{
    return [woNewPreferences objectForKey:keyName];
}

// Sets new value in woNewPreferences (syntax identical to NSMutableDictionary)
- (void)setObject:(NSObject *)newObject forKey:(NSString *)newObjectKey;
{
    [woNewPreferences setObject:newObject forKey:newObjectKey];
}

// As above, sets new value, but flushes it immediately to disk
- (void)setObject:(NSObject *)newObject forKey:(NSString *)newObjectKey flushImmediately:(BOOL)flush
{
    if (!flush)
    {
        // if flush == NO just use normal routine
        [self setObject:newObject forKey:newObjectKey];
        return;
    }

    // otherwise, using special flushing routine

    // modify the pertinent value
    [woNewPreferences setObject:newObject forKey:newObjectKey];

    // back up current prefs values
    NSDictionary *currentPrefsBackup;

    currentPrefsBackup = [NSDictionary dictionaryWithDictionary:woNewPreferences];

    // then revert to prefs as they were on disk
    [self revertToSaved];

    // apply pertinent modification again
    [woNewPreferences setObject:newObject forKey:newObjectKey];

    // write it to disk (works from both prefPane and app)
    [self writePrefsFromPrefPaneBundle];

    // now restore prefs to "current" values again
    [woNewPreferences setDictionary:currentPrefsBackup];
}

// make "newPreferences" equal to "defaultPreferences"
- (void)resetToDefaults
{
    // only replace values from defaults dictionary, leaving others untouched
    [woNewPreferences addEntriesFromDictionary:_woDefaultPreferences];
}

// make "newPreferences" equal to "preferencesOnDisk"
- (void)revertToSaved
{
    // note that "preferencesOnDisk" includes default values for any keys
    // missing from disk
    [woNewPreferences setDictionary:_woPreferencesOnDisk];
}

// test for equality between "newPreferences" and "preferencesOnDisk"
// or, in plain English, "Are there any unsaved changes?"
- (BOOL)unsavedChanges
{
    return (![woNewPreferences isEqualToDictionary:_woPreferencesOnDisk]);
}

// test for equality between "newPreferences" and "defaultPreferences"
- (BOOL)preferencesEqualDefaults
{
    return [woNewPreferences isEqualToDictionary:_woDefaultPreferences];
}

/*

 Low-level accessor methods:

 */

- (NSMutableDictionary *) _woDefaultPreferences
{
    return _woDefaultPreferences;
}

- (void) _setWODefaultPreferences:(NSMutableDictionary *)newDefaultPreferences
{
    _woDefaultPreferences = newDefaultPreferences;
}

- (NSMutableDictionary *) _woPreferencesOnDisk
{
    return _woPreferencesOnDisk;
}

- (void) _setWOPreferencesOnDisk:(NSMutableDictionary *)newPreferencesOnDisk
{
    _woPreferencesOnDisk = newPreferencesOnDisk;
}

- (NSMutableDictionary *) woNewPreferences
{
    return woNewPreferences;
}

/*

 make this next setter method public, the other setters private
 make all the getters public? so far, need: defaultPreferences to be public
 newPreferences also
 preferencesOnDisk too ie. all..

 */

- (void) _setWONewPreferences:(NSMutableDictionary *)newNewPreferences
{
    woNewPreferences = newNewPreferences;
}

@end
