//
//  WOAudioscrobbler.h
//  Synergy
//
//  Created by Greg Hurrell on 31 October 2006.
//  Copyright 2006-present Greg Hurrell.

#import <Cocoa/Cocoa.h>

typedef enum {

    WOAudioscrobblerIdle,
    WOAudioscrobblerWaitingForHandshake,
    WOAudioscrobblerHandshakeFailed,
    WOAudioscrobblerHandshakeSucceeded,
    WOAudioscrobblerBadUser,
    WOAudioscrobblerWaitingForSubmissionResponse,
    WOAudioscrobblerSubmissionFailed,
    WOAudioscrobblerSubmissionSucceeded,
    WOAudioscrobblerWaitingToRetrySubmission,
    WOAudioscrobblerBadAuth,
    WOAudioscrobblerNoAuth                          //!< State when username and/or password is not set

} WOAudioscrobblerState;

//! \sa     http://www.audioscrobbler.net/wiki/Protocol1.0_1.1
//! \warn   Not threadsafe; should only be called from a single thread (most likely the main thread)
@interface WOAudioscrobbler : NSObject {

    NSString                *protocolVersion;

    WOAudioscrobblerState   currentState;

    //! FIFO (first-in, first-out submissions queue)
    NSMutableArray          *queue;

    //! Keep count of submission failures.
    unsigned                submissionFailures;

    //! Keep count of "BADAUTH" retries.
    unsigned                badauthRetries;

    //! "INTERVAL commands can be at the end of any response block, but don't expect them to be. Always observe the latest INTERVAL you get."
    unsigned                lastKnownInterval;


    //! Instance variables starting with underscores; Apple officially does it in Leopard (synthesized instance variables with properties)
    NSURLConnection         *connection;

    NSMutableData           *receivedData;

    //! Passed in from last.fm during handshake
    NSURL                   *submissionURL;

    //! Passed in from last.fm during handshake
    NSString                *challenge;

    //! User agent string passed with all new requests
    NSString                *userAgent;

    NSString                *user;

    NSString                *password;
}


#pragma mark -
#pragma mark Custom methods

//! \warn Can only start a session when idle
- (void)startSession;

//! Can be used to force a session to be renegotiated (a new handshake)
- (void)refreshSession;

- (void)submitSong:(NSString *)track artist:(NSString *)artist album:(NSString *)album length:(unsigned)length;

- (void)finalizeSession;

#pragma mark -
#pragma mark Properties

@property(copy)     NSString                *protocolVersion;
@property           WOAudioscrobblerState   currentState;
@property(copy)     NSMutableArray          *queue;
@property           unsigned                lastKnownInterval;
@property(assign)   NSURLConnection         *connection;
@property(copy)     NSMutableData           *receivedData;
@property(copy)     NSURL                   *submissionURL;
@property(copy)     NSString                *challenge;
@property(copy)     NSString                *userAgent;
@property(copy)     NSString                *user;
@property(copy)     NSString                *password;

@end
