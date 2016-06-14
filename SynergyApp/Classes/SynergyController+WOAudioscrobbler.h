//
//  SynergyController+WOAudioscrobbler.h
//  Synergy
//
//  Created by Greg Hurrell on 6 November 2006.
//  Copyright 2006-present Greg Hurrell.

#import <Cocoa/Cocoa.h>
#import "SynergyController.h"

//! \name Timer user info dictionary keys
//! Key names used in the Audioscrobbler timer user info dictionary
//! \startgroup

#define WO_AUDIOSCROBBLER_TRACK     @"WOAudioscrobblerTrack"
#define WO_AUDIOSCROBBLER_ARTIST    @"WOAudioscrobblerArtist"
#define WO_AUDIOSCROBBLER_ALBUM     @"WOAudioscrobblerAlbum"
#define WO_AUDIOSCROBBLER_LENGTH    @"WOAudioscrobblerLength"

//! \endgroup

// It's possible that this stuff probably all belongs in the darn WOAudioscrobbler class, but leave it here just for now. I wanted to keep a separation between the SynergyController (which talks to iTunes) and the WOAudioscobbler object (which submits to Audioscrobbler and should probably be called WOAudioscrobblerSubmitter; not sure: the name WOAudioscrobbler implies that it is an abstraction for Audioscrobbler itself). These methods are in a category to minimize pollution of the main controller (keep instance variables and methods out of the main controller).
@interface SynergyController (WOAudioscrobbler)

- (void)audioscrobblerReadPreferences;

- (BOOL)audioscrobblerEnabled;
- (void)audioscrobblerUpdate:(BOOL)newState;
- (void)audioscrobblerEnable;
- (void)audioscrobblerDisable;

// called whenever iTunes posts a notification and conditions for potential track submission are met
- (void)audioscrobblerUpdateWithSong:(NSString *)track artist:(NSString *)artist album:(NSString *)album length:(unsigned)length;
- (void)audioscrobblerSetUpSubmissionTimer:(NSDictionary *)info length:(unsigned)length;

// called when iTunes posts a notification and conditions are not met
- (void)audioscrobblerCurrentTrackIsTooShort;
- (void)audioscrobblerCurrentTrackIsNotRegularFile;
- (void)audioscrobblerNotPlaying:(NSString *)track artist:(NSString *)artist album:(NSString *)album length:(unsigned)length;

// called whenever user skips within a track
- (void)audioscrobblerUserDidSkip;

@end
