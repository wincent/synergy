// WOCoverDownloader.h
// Synergy
//
// Copyright 2003-present Greg Hurrell. All rights reserved.

#import <Cocoa/Cocoa.h>

@class WOSongInfo;

//! Log Amazon-related events conditionally (if user preferences request it).
void WOAmazonLog(NSString *format, ...);

@interface WOCoverDownloader : NSObject {

}

// returns nil if no album cover found on disk
+ (NSImage *)albumCover:(WOSongInfo *)song;

// for those callers who would rather receive a BOOL confirming that the album
// cover exists on the disk
+ (BOOL)albumCoverExists:(WOSongInfo *)song;

// returns path to album covers folder
+ (NSString *)albumCoversPath;

// returns path to temporary covers folder (cleaned out at end of execution)
+ (NSString *)tempAlbumCoversPath;

// public method that can be used to test reachability of an arbitrary host
+ (BOOL)hostIsReachable:(NSString *)host;

// accessors
+ (BOOL)connectOnDemand;
+ (void)setConnectOnDemand:(BOOL)connectOnDemand;

+ (BOOL)preprocess;
+ (void)setPreprocess:(BOOL)preprocess;

@end
