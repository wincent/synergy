// SynergyController+WOAudioscrobbler.m
// Synergy
//
// Copyright 2006-present Greg Hurrell. All rights reserved.

// classs header
#import "SynergyController+WOAudioscrobbler.h"

// other headers
#import "WOAudioscrobblerController.h"
#import "WOAudioscrobbler.h"
#import "WOProcessManager.h"
#import "NSTimer+WOPausable.h"
#import "WOPreferences.h"
#import "WODebug.h"

//! The number of seconds of "fuzziness" used when checking to see if the user has seeked within a track
#define WO_AUDIOSCROBBLER_SKIP_CHECK_RESOLUTION 5

// preferences key
NSString *WOSynergyPrefEnableLastFm = @"enableLastFm";

// some preferences are stored under the SynergyPreferences domain so that the
// preferences app can benefit from Cocoa Bindings
NSString *WOSynergyPreferencesAppBundleId = @"com.wincent.SynergyPreferences";

BOOL lastFmEnabled;

// could make these instance variables, but for now leave them as file-scoped globals
NSTimer *audioscrobblerTimer;

// which track are we monitoring?
NSMutableDictionary *audioscrobblerCurrentTrack;

@implementation SynergyController (WOAudioscrobbler)

+ (void)initialize
{
    Boolean keyExistsAndHasValidFormat;
    Boolean enableLastFm = CFPreferencesGetAppBooleanValue((CFStringRef)WOSynergyPrefEnableLastFm,
                                                           (CFStringRef)WOSynergyPreferencesAppBundleId,
                                                           &keyExistsAndHasValidFormat);
    lastFmEnabled = !(keyExistsAndHasValidFormat && !enableLastFm);
}

- (void)audioscrobblerTimerFired:(NSTimer *)aTimer
{
    WOAudioscrobblerLog(@"Submission timer fired; will double-check that current track position matches expected value");
    NSParameterAssert(aTimer != nil);
    NSDictionary *info = (NSDictionary *)[aTimer userInfo];
    NSParameterAssert(info != nil);
    NSNumber *length = [info objectForKey:WO_AUDIOSCROBBLER_LENGTH];
    NSParameterAssert(length != nil);

    // query iTunes and ask it if we are where we think we should be (at the "trigger" point)
    unsigned trigger = MIN((unsigned)240, ([length unsignedIntValue] / 2));

    static NSAppleScript *script = nil;
    if (!script)
        // effectively leak this script, keeping it around for the lifetime of the program to avoid recompiling it every single time
        script = [[NSAppleScript alloc] initWithSource:@"tell application \"iTunes\" to get player position"];
    if (!script)
        NSLog(@"Error compiling AppleScript (audioscrobblerTimerFired:)");

    // was a bug: this method reliably caused iTunes to respawn if it was quit
    // there is still about a 2 second window of possible error in which iTunes can quit and the system will claim it is still running
    // the proper solution is to use Apple Events (which don't cause a respawn) but that will be for Synergy Advance
    NSAppleEventDescriptor *result = nil;
    if ([WOProcessManager processRunningWithSignature:'hook'])
        result = [script executeAndReturnError:NULL];
    if (result)
    {
        SInt32 position = [result int32Value];
        if ((position > WO_AUDIOSCROBBLER_SKIP_CHECK_RESOLUTION) &&
            (abs(position - trigger) < WO_AUDIOSCROBBLER_SKIP_CHECK_RESOLUTION))
        {
            WOAudioscrobblerLog(@"Position matches, will submit to Audioscrobbler");
            [audioscrobbler submitSong:[info objectForKey:WO_AUDIOSCROBBLER_TRACK]
                                artist:[info objectForKey:WO_AUDIOSCROBBLER_ARTIST]
                                 album:[info objectForKey:WO_AUDIOSCROBBLER_ALBUM]
                                length:[length unsignedIntValue]];
        }
        else
            WOAudioscrobblerLog(@"Position does not match (user must have skipped); will not submit to Audioscrobbler");
    }
    else
        NSLog(@"Error executing AppleScript (audioscrobblerTimerFired:)");
    audioscrobblerTimer = nil;
}

// if the submission timer is running, invalidates it
- (void)audioscrobblerCancelSubmission
{
    WOAudioscrobblerLog(@"Cancelling previously existing submission timer, if any");
    [audioscrobblerTimer cancel];
    audioscrobblerTimer = nil;
}

// called at launch and whenever the preferences get updated
- (void)audioscrobblerReadPreferences
{
    WOAudioscrobblerLog(@"Read preferences");
    BOOL firstTime = NO;
    if (!audioscrobblerController)
    {
        WOAudioscrobblerLog(@"Perform first-time initialization");
        audioscrobblerController    = [[WOAudioscrobblerController alloc] init];        // leak this, effectively a singleton
        audioscrobbler              = [[WOAudioscrobbler alloc] init];                  // again, effectively a singleton
        firstTime = YES;
    }

#ifdef USE_BUGGY_VERSION
    // BUG: changes written to disk (confirmed by inspection) not picked up here
    NSString *username = [[NSUserDefaults standardUserDefaults] objectForKey:WO_AUDIOSCROBBLER_USERNAME];
#else
    if (!CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication))
        WOAudioscrobblerLog(@"warning: CFPreferencesAppSynchronize returned false");
    NSString *username = NSMakeCollectable(CFPreferencesCopyAppValue
        ((CFStringRef)WO_AUDIOSCROBBLER_USERNAME, kCFPreferencesCurrentApplication));
#endif
    NSString *password = [audioscrobblerController getPasswordFromKeychainForUsername:username];

    NSString *oldUsername = [audioscrobbler user];
    if ((username && ![username isEqualToString:oldUsername]) || (!username && oldUsername))
        WOAudioscrobblerLog(@"Read new username");
    else
        WOAudioscrobblerLog(@"Username is unchanged");

    NSString *oldPassword = [audioscrobbler password];
    if ((password && ![password isEqualToString:oldPassword]) || (!password && oldPassword))
        WOAudioscrobblerLog(@"Read new password");
    else
        WOAudioscrobblerLog(@"Password is unchanged");

    [audioscrobbler setUser:username];
    [audioscrobbler setPassword:password];

    if (firstTime)
    {
        WOAudioscrobblerLog(@"First time we've read the preferences; will start a new session");
        [audioscrobbler startSession];
    }
    else
    {
        WOAudioscrobblerLog(@"Not the first time we've read the preferences; will refresh the existing session");
        [audioscrobbler refreshSession];
    }
}

- (BOOL)audioscrobblerEnabled
{
    return lastFmEnabled;
}

// this is trigger by notification from prefPane, so we don't re-notify in this case
- (void)audioscrobblerUpdate:(BOOL)newState
{
    if (newState != lastFmEnabled)
    {
        if (!newState)
            [self audioscrobblerCancelSubmission];
        lastFmEnabled = newState;
    }
}

- (void)audioscrobblerEnable
{
    lastFmEnabled = YES;
    CFPreferencesSetAppValue((CFStringRef)WOSynergyPrefEnableLastFm, kCFBooleanTrue, (CFStringRef)WOSynergyPreferencesAppBundleId);
    if (!CFPreferencesAppSynchronize((CFStringRef)WOSynergyPreferencesAppBundleId))
        NSLog(@"warning: CFPreferencesAppSyncrhonize returned false");
}

- (void)audioscrobblerDisable
{
    // cancel existing submission timer, if any
    [self audioscrobblerCancelSubmission];
    lastFmEnabled = NO;
    CFPreferencesSetAppValue((CFStringRef)WOSynergyPrefEnableLastFm, kCFBooleanFalse, (CFStringRef)WOSynergyPreferencesAppBundleId);
    if (!CFPreferencesAppSynchronize((CFStringRef)WOSynergyPreferencesAppBundleId))
        NSLog(@"warning: CFPreferencesAppSyncrhonize returned false");
}

- (void)audioscrobblerUpdateWithSong:(NSString *)track artist:(NSString *)artist album:(NSString *)album length:(unsigned)length
{
    WOAudioscrobblerLog(@"Received notification of playing status");
    NSParameterAssert(track != nil);
    length = length / 1000; // convert from milliseconds to seconds
    NSParameterAssert(length >= 30);

    // new in 3.5.1a: can temporarily disable submissions, had better check
    if (![self audioscrobblerEnabled])
    {
        WOAudioscrobblerLog(@"Skipping submission ('Send track information updates to last.fm' checkbox is unchecked)");
        return;
    }

    // "Each song should be posted to the server when it is 50% or 240 seconds complete, whichever comes first."
    // "If a user seeks (i.e. manually changes position) within a song before the song is due to be submitted, do not submit that song."
    // "Songs with a duration of less than 30 seconds should not be submitted."

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    [info setObject:track forKey:WO_AUDIOSCROBBLER_TRACK];
    [info setObject:[NSNumber numberWithUnsignedInt:length] forKey:WO_AUDIOSCROBBLER_LENGTH];
    if (artist) [info setObject:artist  forKey:WO_AUDIOSCROBBLER_ARTIST];
    if (album)  [info setObject:album   forKey:WO_AUDIOSCROBBLER_ALBUM];
    WOAudioscrobblerLog(@"Track information: %@", info);

    // check to see if this is the same track/artist/album/length combination as previously submitted; if so, resume
    if ([info isEqualToDictionary:audioscrobblerCurrentTrack])
    {
        // must check "isPaused" here in case iTunes posts duplicate notifications for the same song
        // (can occur when adding album art to a playing track, for example)
        if (audioscrobblerTimer && [audioscrobblerTimer isPaused])
        {
            // looks like this was submitted previously, and we have a paused timer: resuming timer
            WOAudioscrobblerLog(@"This track was previously submitted for consideration and we have a paused timer; resuming it");
            [audioscrobblerTimer resume];
        }
        else if (playerPosition == 0)
        {
            // this is a track we've seen before, but it looks like it's on repeat
            // see: https://wincent.com/issues/1365
            WOAudioscrobblerLog(@"This track was previously submitted for consideration but player position is 0, so treating like a new submission");
            [self audioscrobblerSetUpSubmissionTimer:info length:length];
        }
        else
            // getting here is either a programming error, or iTunes is getting funky about what it's submitting (duplicate sub)
            WOAudioscrobblerLog(@"This track was previously submitted for consideration but no paused timer found; doing nothing");
    }
    else    // looks like this is a new submission, will set up timer
    {
        WOAudioscrobblerLog(@"This track appears to be a new submission");
        [self audioscrobblerSetUpSubmissionTimer:info length:length];
    }
}

- (void)audioscrobblerSetUpSubmissionTimer:(NSDictionary *)info length:(unsigned)length
{
    // clean up existing timer, if any
    [self audioscrobblerCancelSubmission];
    audioscrobblerCurrentTrack = [info copy];

    // set up timer for 240 secs or 50%, which is smaller
    NSTimeInterval interval = MIN((unsigned)240, (length / 2));
    WOAudioscrobblerLog(@"Setting up new submission timer (%d seconds)", (int)interval);
    audioscrobblerTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                           target:self
                                                         selector:@selector(audioscrobblerTimerFired:)
                                                         userInfo:info
                                                          repeats:NO];
}

// keep informed of causes for non-submission: this might be ok
// if it is the same track/artist/album/length, and state goes to paused, pause the timer
// if the same track then re-enters playing state them restart the timer
- (void)audioscrobblerNotPlaying:(NSString *)track artist:(NSString *)artist album:(NSString *)album length:(unsigned)length
{
    WOAudioscrobblerLog(@"Received notification of non-playing status");
    length = length / 1000; // convert from milliseconds to seconds
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    [info setObject:track forKey:WO_AUDIOSCROBBLER_TRACK];
    [info setObject:[NSNumber numberWithUnsignedInt:length] forKey:WO_AUDIOSCROBBLER_LENGTH];
    if (artist) [info setObject:artist  forKey:WO_AUDIOSCROBBLER_ARTIST];
    if (album)  [info setObject:album   forKey:WO_AUDIOSCROBBLER_ALBUM];
    WOAudioscrobblerLog(@"Track information: %@", info);

    if ([info isEqualToDictionary:audioscrobblerCurrentTrack])
    {
        WOAudioscrobblerLog(@"This track was previously submitted for consideration; pausing timer");
        [audioscrobblerTimer pause];                // not playing but looks like this is a previous submission; pausing timer
    }
    else
    {
        WOAudioscrobblerLog(@"This track was not previously submitted for consideration; cancelling timer");
        [self audioscrobblerCancelSubmission];      // not playing and doesn't look like a previous submission; cancelling timer
    }
}

// keep informed of causes for non-submission: this is cause for immediate cancellation of the timer
- (void)audioscrobblerCurrentTrackIsTooShort
{
    WOAudioscrobblerLog(@"Current track is too short for submission");
    [self audioscrobblerCancelSubmission];
}

// keep informed of causes for non-submission: this is cause for immediate cancellation of the timer
// "If a user is playing a stream instead of a regular file, do not submit that stream/song."
- (void)audioscrobblerCurrentTrackIsNotRegularFile
{
    WOAudioscrobblerLog(@"Current track cannot be submitted because it is not a regular file");
    [self audioscrobblerCancelSubmission];
}

// grounds for immediate cancellation
- (void)audioscrobblerUserDidSkip
{
    WOAudioscrobblerLog(@"Current track cannot be submitted because the user performed a skip");
    [self audioscrobblerCancelSubmission];
}

@end
