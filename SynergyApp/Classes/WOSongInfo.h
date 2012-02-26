//
//  WOSongInfo.h
//  Synergy
//
//  Created by Wincent Colaiuta on Mon Mar 24 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import <Cocoa/Cocoa.h>

// songInfo class used internally to represent items in the album cover download
// queue, and also used to pass data from the main thread to the download
// threads
@interface WOSongInfo : NSObject {

    NSURL     *URL;       // this is the URL to the cover image
    NSURL     *buyNowURL; // and this is to amazon's "buy now" page
    NSString  *artist;
    NSString  *album;
    NSString  *song;
    NSString  *filename;

    // simple state flag to indicate whether a download thread has been
    // spawned or not (YES = thread active, NO = no thread active)
    BOOL      downloadThreadSpawned;

    // whether object is brand new (no attempt made to download yet)
    BOOL      attemptedDownload;

    // set to YES when ready to retry
    BOOL      readyToRetry;

@private

    // how long waited before last retry
    float     _retryInterval;

    // timer object to ensure we wait before retrying, sets readyToRetry to YES
    // when timer expires
    NSTimer   *_retryTimer;
}

- (void)incrementRetryInterval;

// accessors

- (NSURL *)URL;
- (void)setURL:(NSURL *)newURL;
- (NSURL *)buyNowURL;
- (void)setBuyNowURL:(NSURL *)newBuyNowURL;
- (NSString *)artist;
- (void)setArtist:(NSString *)newArtist;
- (NSString *)album;
- (void)setAlbum:(NSString *)newAlbum;
- (NSString *)song;
- (void)setSong:(NSString *)newSong;
- (NSString *)filename;
- (void)setFilename:(NSString *)newFilename;
- (BOOL)downloadThreadSpawned;
- (void)setDownloadThreadSpawned:(BOOL)newDownloadThreadSpawned;
- (BOOL)attemptedDownload;
- (void)setAttemptedDownload:(BOOL)newAttemptedDownload;
- (BOOL)readyToRetry;
- (void)setReadyToRetry:(BOOL)newReadyToRetry;

@end