//
//  WOSongInfo.m
//  Synergy
//
//  Created by Wincent Colaiuta on Mon Mar 24 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import "WOSongInfo.h"
#import "WODebug.h"

@interface WOSongInfo (_private)

- (NSTimer *)_retryTimer;
- (void)_setRetryTimer:(NSTimer *)newRetryTimer;
- (float)_retryInterval;
- (void)_setRetryInterval:(float)newRetryInterval;

@end

@implementation WOSongInfo

// Not sure if this is required, strictly speaking, but using accessors a lot
// here in an effort to make the class thread-safe. I want it to be absolutely
// bulletproof because pretty much all information passed between threads in
// Synergy will be of class WOSongInfo.

- (id)init
{
    if ((self = [super init]))
    {
        // initialise to safe starting values
        [self setURL:nil];
        [self setBuyNowURL:nil];
        [self setArtist:nil];
        [self setAlbum:nil];
        [self setSong:nil];
        [self setFilename:nil];
        [self setDownloadThreadSpawned:NO];
        [self setAttemptedDownload:NO];
        [self setReadyToRetry:NO];

        // changed 27 March to hit Amazon less
        [self _setRetryInterval:10.0];

        [self _setRetryTimer:nil];
    }
    return self;
}

- (void)finalize
{
    // clean up timer if it is around
    if ([self _retryTimer])
    {
        // finalize may be too late for this
        if ([[self _retryTimer] isValid])
            [[self _retryTimer] invalidate];
    }

    [super finalize];
}

- (void)incrementRetryInterval
    /*"
     Sets up a timer. On firing, the timer sets the readyToRetry ivar and
     doubles the retry interval (up to a limit).
     "*/
{
    [self setReadyToRetry:NO];

    // clean up timer if it is around (shouldn't be, but multiple threads
    // could conceivable call this routine if there is a programmer error)
    if ([self _retryTimer])
    {
        if ([[self _retryTimer] isValid])
            [[self _retryTimer] invalidate];

        [self _setRetryTimer:nil];
    }

    // actually... don't retry at all! this should really help amazon...
    return;

    // set up retry timer
    [self _setRetryTimer:
        [NSTimer scheduledTimerWithTimeInterval:_retryInterval
                                         target:self
                                       selector:@selector(timer:)
                                       userInfo:nil
                                        repeats:NO]];

}

- (void)timer:(NSTimer *)timer
{
    // clean up timer
    [self _setRetryTimer:nil];

    // and to be doubly sure that amazon doesn't get requeried (27 march 2004)
    return;

    // next time the queue is examined, this download will be eligible to begin
    [self setReadyToRetry:YES];

    // increase retry interval for next attempt (if there is one)

    // changed 27 March 2004 to help Amazon...
    if ([self _retryInterval] < 5120.0)
        [self _setRetryInterval:([self _retryInterval] * 2.0)];
}

// accessors (thread-safe)

// TODO: Objective-C 2.0 properties

- (NSURL *)URL
{
    return URL;
}

- (void)setURL:(NSURL *)newURL
{
    URL = [newURL copy];
}

- (NSURL *)buyNowURL
{
    return buyNowURL;
}

- (void)setBuyNowURL:(NSURL *)newBuyNowURL
{
    buyNowURL = [newBuyNowURL copy];
}

- (NSString *)artist
{
    return artist;
}

- (void)setArtist:(NSString *)newArtist
{
    artist = [newArtist copy];
}

- (NSString *)album
{
    return album;
}

- (void)setAlbum:(NSString *)newAlbum
{
    album = [newAlbum copy];
}

- (NSString *)song
{
    return song;
}

- (void)setSong:(NSString *)newSong
{
    song = [newSong copy];
}

- (NSString *)filename
{
    // complex accessor: if filename not initialised, construct it from
    // artist + album
    if (!filename)
    {
        // but only do this if we have artist and/or album and/or song

        NSString *artistString  = [self artist];
        NSString *albumString   = [self album];
        NSString *songString    = [self song];

        NSString *generatedFilename;

        // will mimic the "try" order of WOCoverDownloader's
        // _searchForAlbumCover method

        if (albumString && (![albumString isEqualToString:@""]) &&
            artistString && (![artistString isEqualToString:@""]))
            generatedFilename = [NSString stringWithFormat:@"Artist-%@,Album-%@", artistString, albumString];
        else if (songString && (![songString isEqualToString:@""]) &&
                 artistString && (![artistString isEqualToString:@""]))
            generatedFilename = [NSString stringWithFormat:@"Artist-%@,Song-%@", artistString, songString];
        else if (albumString && (![albumString isEqualToString:@""]))
            generatedFilename = [NSString stringWithFormat:@"Album-%@", albumString];
        else if (songString && (![songString isEqualToString:@""]))
            generatedFilename = [NSString stringWithFormat:@"Song-%@", songString];
        else
            // not enough info to construct filename, return nil
            generatedFilename = nil;

        // if we have a filename, make strip out "unsafe" chars
        if (generatedFilename)
        {
            NSMutableCharacterSet *unsafeChars = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
            [unsafeChars addCharactersInString:@":/"];
            NSMutableString *scratch = [NSMutableString string];
            NSScanner *scanner = [NSScanner scannerWithString:generatedFilename];
            NSString *result;
            while (![scanner isAtEnd])
            {
                if ([scanner scanUpToCharactersFromSet:unsafeChars intoString:&result])
                    // found a segment without any unsafe chars, append it
                    [scratch appendString:result];

                // now skip over unsafe chars
                [scanner scanCharactersFromSet:unsafeChars intoString:nil];
            }
            // check to see if any characters left in string after stripping
            if (![scratch isEqualToString:@""])
                filename = [scratch stringByAppendingPathExtension:@"jpg"];
            else
                filename = nil;
        }
        else
            filename = nil;
    }
    return filename;
}

- (void)setFilename:(NSString *)newFilename
{
    filename = [newFilename copy];
}

- (BOOL)downloadThreadSpawned
{
    return downloadThreadSpawned;
}

- (void)setDownloadThreadSpawned:(BOOL)newDownloadThreadSpawned
{
    downloadThreadSpawned = newDownloadThreadSpawned;
}

- (BOOL)attemptedDownload;
{
    return attemptedDownload;
}

- (void)setAttemptedDownload:(BOOL)newAttemptedDownload
{
    attemptedDownload = newAttemptedDownload;
}

- (BOOL)readyToRetry
{
    return readyToRetry;
}

- (void)setReadyToRetry:(BOOL)newReadyToRetry
{
    readyToRetry = newReadyToRetry;
}

- (NSTimer *)_retryTimer
{
    return _retryTimer;
}

- (void)_setRetryTimer:(NSTimer *)newRetryTimer
{
    if (_retryTimer != newRetryTimer)
        _retryTimer = newRetryTimer;
}

- (float)_retryInterval
{
    return _retryInterval;
}

- (void)_setRetryInterval:(float)newRetryInterval
{
    _retryInterval = newRetryInterval;
}

@end