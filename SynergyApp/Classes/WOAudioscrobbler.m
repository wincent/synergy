// WOAudioscrobbler.m
// Synergy
//
// Copyright 2006-present Greg Hurrell. All right reserved.

// class header
#import "WOAudioscrobbler.h"

// system headers
#import <openssl/md5.h>                     /* requires -lcrypto linker flag, TODO: in Synergy Advance, use CDSA instead */

// other headers
#import "WOAudioscrobblerController.h"      /* WOAudioscrobblerLog */

// WOPublic headers
#import "WOPublic/WOConvenienceMacros.h"
#import "WOPublic/WODebugMacros.h"

// TODO: wrap this up (or equivalent code) in a plug-in for Synergy Advance

//! Default timeout in seconds as noted in the NSURLRequest documentation
#define WO_DEFAULT_URL_REQUEST_TIMEOUT  60

//! Handshake delay in seconds after repeated failures failure: "A Handshake should occur just once during a SESSION, e.g. when the APP first loads, or after the APP detects 3 catastrophic (i.e. DNS resolution or connection refused) failures in submitting. In this case, the APP should not handshake more than once every 30 minutes."
#define WO_HANDSHAKE_DELAY_ON_FAILURES  (60 * 30)

#ifdef WO_AUDIOSCROBBLER_TEST_MODE

#define WO_ASSIGNED_PLUGIN_ID           @"tst"
#define WO_ASSIGNED_PLUGIN_VERSION      @"1.0"

#else

//! Synergy's Audioscrobbler plug-in ID as assigned by Russ of last.fm
#define WO_ASSIGNED_PLUGIN_ID           @"syn"

//! Synergy's Audioscrobbler plug-in version as assigned by Russ of last.fm
#define WO_ASSIGNED_PLUGIN_VERSION      @"0.1"

#endif /* WO_AUDIOSCROBBLER_TEST_MODE */

//! Base URL used for posting handshake requests
#define WO_HANDSHAKE_URL_BASE           @"http://post.audioscrobbler.com/"

//! Audioscrobbler protocol version
#define WO_PROTOCOL_VERSION             @"1.1"

//! Default delay between submissions in seconds
#define WO_DEFAULT_INTERVAL             1

//! Reply keywords from Audioscrobbler
#define WO_UP_TO_DATE   @"UPTODATE"
#define WO_UPDATE       @"UPDATE"
#define WO_FAILED       @"FAILED"
#define WO_BADUSER      @"BADUSER"
#define WO_INTERVAL     @"INTERVAL"
#define WO_OK           @"OK"
#define WO_BADAUTH      @"BADAUTH"

//! HTTP headers
#define WO_USER_AGENT @"User-Agent"

#define WO_DEFAULT_USER_AGENT @"Synergy (NSURLConnection) $Rev: 338 $"

//! Dictionary keys for items in queue
#define WO_TRACK_KEY    @"WOTrack"
#define WO_ARTIST_KEY   @"WOArtist"
#define WO_ALBUM_KEY    @"WOAlbum"
#define WO_MBID_KEY     @"WOMBID"
#define WO_LENGTH_KEY   @"WOLength"
#define WO_DATE_KEY     @"WODate"

@interface WOAudioscrobbler ()

- (void)requestHandshake;
- (NSString *)dateString;
- (BOOL)queueIsEmpty;
- (void)enqueue:(id)object;
- (NSDictionary *)firstObjectInQueue;
- (void)doSubmission:(NSDictionary *)songInfo;

@end

@implementation WOAudioscrobbler

#pragma mark -
#pragma mark NSObject overrides

- (id)init
{
    if ((self = [super init]))
    {
        WOAudioscrobblerLog(@"Initializing WOAudioscrobbler object");
        self->protocolVersion      = WO_PROTOCOL_VERSION;
        self->currentState         = WOAudioscrobblerIdle;
        self->queue                = [NSMutableArray array];
        self->userAgent            = WO_DEFAULT_USER_AGENT;
        self->lastKnownInterval    = WO_DEFAULT_INTERVAL;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(willTerminate:)
                                                     name:NSApplicationWillTerminateNotification
                                                   object:nil];
    }
    return self;
}

- (void)finalize
{
    WOAudioscrobblerLog(@"Finalizing WOAudioscrobbler object");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super finalize];
}

#pragma mark -
#pragma mark Custom methods

- (void)startSession
{
    WOAudioscrobblerLog(@"Start Audioscrobbler session");
    WOAssert(self.currentState == WOAudioscrobblerIdle);
    [self requestHandshake];
}

- (void)refreshSession
{
    // cancel any in-progress URL requests
    if (self.connection)
    {
        [self.connection cancel];
        self.connection = nil;
        self.receivedData = nil;
    }

    // reset state and request the handshake again
    self.currentState = WOAudioscrobblerIdle;
    WOAudioscrobblerLog(@"Refresh Audioscrobbler session");
    [self requestHandshake];
}

- (void)submitSong:(NSString *)track artist:(NSString *)artist album:(NSString *)album length:(unsigned)length
{
    NSParameterAssert(length >= 30);
    if (!track || [track isEqualToString:@""])
    {
        // doubtful that this will ever happen as iTunes always seems to define a title, even if it is only the filename
        NSLog(@"Cannot submit to last.fm if track has no title");
        return;
    }

    // "all the post variables noted here MUST be supplied for each entry, even if they are blank."
    if (!artist)    artist = @"";
    if (!album)     album = @"";
    NSString        *mbid = @"";

    NSDictionary *song = [NSDictionary dictionaryWithObjectsAndKeys:
        track,                                      WO_TRACK_KEY,
        artist,                                     WO_ARTIST_KEY,
        album,                                      WO_ALBUM_KEY,
        mbid,                                       WO_MBID_KEY,
        [NSNumber numberWithUnsignedInt:length],    WO_LENGTH_KEY,
        [self dateString],                          WO_DATE_KEY, nil];
    WOAudioscrobblerLog(@"Adding song to submission queue; song information: %@", song);
    [self enqueue:song];
}

- (void)finalizeSession
{
    WOAudioscrobblerLog(@"Finalize Audioscrobbler session");
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    self.currentState = WOAudioscrobblerIdle;
}

#pragma mark -
#pragma mark Low-level utility methods

- (void)willTerminate:(NSNotification *)aNotification
{
    [self finalizeSession];
}

- (BOOL)startConnectionWithURL:(NSURL *)aURL body:(NSData *)aData isPost:(BOOL)post
{
    WOAudioscrobblerLog(@"Starting connection attempt");
    if (self.connection)
        WOAudioscrobblerLog(@"warning: existing connection still active");
    NSParameterAssert(aURL != nil);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:aURL
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:WO_DEFAULT_URL_REQUEST_TIMEOUT];
    [request setValue:[self userAgent] forHTTPHeaderField:WO_USER_AGENT];

    if (aData)
        [request setHTTPBody:aData];

    if (post)
        // "Submissions MUST be sent using an HTTP POST request to the URL obtained from the HANDSHAKE process."
        [request setHTTPMethod:@"POST"];

    self.receivedData = [NSMutableData data];
    self.connection = [NSURLConnection connectionWithRequest:request delegate:self]; // deep-copies the request
    if (!self.connection)
        NSLog(@"NSURLConnection failed for URL %@", aURL);
    return self.connection ? YES : NO;
}

- (NSString *)escapedString:(NSString *)aString;
{
    // "UTF-8 encoding is used first, then URL encoding"
    if (!aString) return nil;

    // also escape legal-but-reserved characters as defined in RFC 2396: <http://www.ietf.org/rfc/rfc2396.txt>
    return NSMakeCollectable(CFURLCreateStringByAddingPercentEscapes
        (NULL, (CFStringRef)aString, NULL, CFSTR(";/?:@&=+$,"), kCFStringEncodingUTF8));
}

- (NSString *)dateString
{
    // "The date format uses the ISO 8601 format except that the time zone specifier MUST NOT be used, the date/time separator MUST be a single space, and all values MUST be expressed with UTC times. For example, a time of 7AM, Pacific Standard Time (UTC + 8) would normally be expressed in ISO 8601 as 2006-02-12T07:00:00+0800. For submission it would be expressed as 2006-02-11 23:00:00."
    return [[NSDate date] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S"
                                               timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]
                                                 locale:nil];
}

- (NSURL *)handshakeURL
{
    // http://post.audioscrobbler.com/?hs=true&p=1.1&c=osx&v=&u=
    //  hs = true           : "a handshake is requested"
    //  p = 1.1             : "the Audioscrobbler protocol version"
    //  c = clientid = osx  : "Applescriptable MacOS X Application (iTunes)"
    //  v = clientver       : "is the version of the APP plugin"
    //  u = user            : "the user name"

    NSURL *URL = [NSURL URLWithString:WO_STRING(@"%@?hs=true&p=%@&c=%@&v=%@&u=%@", WO_HANDSHAKE_URL_BASE, WO_PROTOCOL_VERSION,
                                          WO_ASSIGNED_PLUGIN_ID, WO_ASSIGNED_PLUGIN_VERSION, [self escapedString:[self user]])];

    WOAudioscrobblerLog(@"Handshake URL is %@", URL);
    return URL;
}

- (void)requestHandshake
{
    // don't even bother trying unless both username and password are non-blank
    if ((self.user && ![self.user isEqualToString:@""]) &&
        (self.password && ![self.password isEqualToString:@""]))
    {
        WOAudioscrobblerLog(@"Will request handshake");
        NSURL *URL = [self handshakeURL];
        if ([self startConnectionWithURL:URL body:nil isPost:NO])
        {
            WOAudioscrobblerLog(@"Waiting for handshake reply");
            self.currentState = WOAudioscrobblerWaitingForHandshake;
        }
        else
        {
            WOAudioscrobblerLog(@"Failed before handshake reply received");
            self.currentState = WOAudioscrobblerHandshakeFailed;
        }
    }
    else
    {
        WOAudioscrobblerLog(@"Not proceeding with handshake (neither the username nor the password may be blank)");
        self.currentState = WOAudioscrobblerNoAuth;
    }
}

- (void)processHandshake:(NSArray *)lines;
{
    WOAudioscrobblerLog(@"Processing handshake reply");
    NSParameterAssert(lines != nil);
    unsigned count = [lines count];
    NSParameterAssert(count >= 1);
    NSString *firstLine = [lines objectAtIndex:0];
    if ([firstLine hasPrefix:WO_UP_TO_DATE])
    {
        WOAudioscrobblerLog(@"Received UPTODATE message");
        // UPTODATE ("your version is up to date")
        // <md5 challenge>
        // <url to submit script>
        // INTERVAL n ("the number of seconds you must wait between sending updates", 0 or more)

        if (count < 3)
        {
            NSLog(@"Handshake response too short:\n%@", lines);
            self.currentState = WOAudioscrobblerHandshakeFailed;
            return;
        }

        self.challenge      = [lines objectAtIndex:1];
        self.submissionURL  = [NSURL URLWithString:[lines objectAtIndex:2]];
        self.currentState   = WOAudioscrobblerHandshakeSucceeded;
        badauthRetries = 0; // reset
    }
    else if ([firstLine hasPrefix:WO_UPDATE])
    {
        WOAudioscrobblerLog(@"Received UPDATE message");
        // UPDATE <updateurl> ("If you are using an outdated version of a plugin, you will see something like this, indicating an update is available")
        // <md5 challenge>
        // <url to submit script>
        // INTERVAL n (as above)

        if ([firstLine length] > [WO_UPDATE length])
        {
            NSString *updateURL = [firstLine substringFromIndex:[WO_UPDATE length]];
            NSLog(@"last.fm reports new version available from %@", updateURL);
        }

        if (count < 3)
        {
            NSLog(@"Handshake response too short:\n%@", lines);
            self.currentState = WOAudioscrobblerHandshakeFailed;
            return;
        }

        self.challenge      = [lines objectAtIndex:1];
        self.submissionURL  = [NSURL URLWithString:[lines objectAtIndex:2]];
        self.currentState   = WOAudioscrobblerHandshakeSucceeded;
        badauthRetries = 0; // reset
    }
    else if ([firstLine hasPrefix:WO_FAILED])
    {
        WOAudioscrobblerLog(@"Received FAILED message");
        // "If the request fails, you will get:"
        // FAILED <reason>
        // INTERVAL n

        if ([firstLine length] > [WO_FAILED length])
        {
            NSString *failureReason = [firstLine substringFromIndex:[WO_FAILED length]];
            NSLog(@"last.fm handshake failed; reported reason: \"%@\"", failureReason);
        }
        else
            NSLog(@"last.fm handshake failed");

        self.currentState = WOAudioscrobblerHandshakeFailed;
    }
    else if ([firstLine hasPrefix:WO_BADUSER])
    {
        WOAudioscrobblerLog(@"Received BADUSER message");
        // "If the user is invalid:"
        // BADUSER
        // INTERVAL n

        NSLog(@"last.fm handshake failed; returned result: %@", firstLine);
        self.currentState = WOAudioscrobblerBadUser;
    }
    else
    {
        NSLog(@"Unrecognized handshake response:\n%@", lines);
        self.currentState = WOAudioscrobblerHandshakeFailed;
    }
}

- (NSString *)challengeResponse
{
    // "The MD5 response is md5(md5(your_password) + challenge), where MD5 is the ascii-encoded, lowercase MD5 representation, and + represents concatenation. MD5 strings must be converted to their hex value before concatenation with the challenge string and before submission to the final MD5 response."

    // "The ascii-encoded, lowercase MD5 representation MUST be used, and MD5 strings MUST be converted to their hex value before concatenation with the challenge string and before submission to the final MD5 response. "

    // calculate password hash
    NSData *passwordData = [self.password dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char *digest = MD5([passwordData bytes], [passwordData length], NULL);
    NSMutableString *string = [NSMutableString string];
    for (int i = 0; i < MD5_DIGEST_LENGTH; i++)
        [string appendFormat:@"%02x", *digest++];

    // append challenge (salt)
    [string appendString:self.challenge];

    // calculate and return digest of whole
    NSData *response = [string dataUsingEncoding:NSUTF8StringEncoding];
    digest = MD5([response bytes], [response length], NULL);
    [string setString:@""];
    for (int i = 0; i < MD5_DIGEST_LENGTH; i++)
        [string appendFormat:@"%02x", *digest++];
    return string;
}

- (void)next
{
    unsigned delay = self.lastKnownInterval;
    WOAudioscrobblerLog(@"Will handle next item on the queue after delay (Audioscrobbler specified delay in seconds: %d)", delay);

    // handle the next item on the queue
    [self performSelector:@selector(nextOperation:) withObject:nil afterDelay:delay];
}

// called when the Audioscrobbler-specified delay interval has passed and the next operation can be performed
- (void)nextOperation:(id)ignored
{
    if ([self queueIsEmpty])
    {
        WOAudioscrobblerLog(@"Queue is empty, not proceeding");
        return;
    }

    switch (self.currentState)
    {
        case WOAudioscrobblerIdle:
        case WOAudioscrobblerHandshakeSucceeded:
        case WOAudioscrobblerWaitingToRetrySubmission:
        case WOAudioscrobblerSubmissionSucceeded:
            WOAudioscrobblerLog(@"Will proceed with submission");
            [self doSubmission:[self firstObjectInQueue]];
            break;
        case WOAudioscrobblerSubmissionFailed:
            // "A Handshake should occur just once during a SESSION, e.g. when the APP first loads, or after the APP detects 3 catastrophic (i.e. DNS resolution or connection refused) failures in submitting. In this case, the APP should not handshake more than once every 30 minutes. If the APP fails to connect to the handshake URL, the user should be informed."
            WOAudioscrobblerLog(@"Submission previously failed, will retry");
            [self doSubmission:[self firstObjectInQueue]];
            break;
        case WOAudioscrobblerHandshakeFailed:
            WOAudioscrobblerLog(@"Handshake previously failed, will retry");
            [self requestHandshake];
            break;
        case WOAudioscrobblerNoAuth:
            WOAudioscrobblerLog(@"Missing username or password; cannot proceed");
            break;
        case WOAudioscrobblerBadAuth:
            // "If it returns BADAUTH, you may need to re-handshake (you're likely to get temporarily blocked if you're attempting to resubmit at one-second intervals after getting repeated BADAUTH errors)."
            if (badauthRetries < 3) // the limit of 3 is not specified in the protocol but it seems like a nice number
            {
                WOAudioscrobblerLog(@"Previously received a bad auth error; will try again to handshake");
                badauthRetries++;   // will reset to 0 if handshake is successful
                [self requestHandshake];
            }
            else
                WOAudioscrobblerLog(@"Previously received 3 bad auth errors; cannot proceed");
            break;
        case WOAudioscrobblerBadUser:
            WOAudioscrobblerLog(@"Previously received a bad user error; cannot proceed");
            // non-recoverable errors
            break;
        case WOAudioscrobblerWaitingForHandshake:
            // should never get here, right? this is a programmer error
            WOAudioscrobblerLog(@"Error: did not expect WOAudioscrobblerWaitingForHandshake status; please report");
            break;
        case WOAudioscrobblerWaitingForSubmissionResponse:
            // should never get here, right? this is a programmer error
            WOAudioscrobblerLog(@"Error: did not expect WOAudioscrobblerWaitingForSubmissionResponse status; please report");
            break;
        default:
            // programmer error again
            WOAudioscrobblerLog(@"Error: did not expect status %d; please report", [self currentState]);
            break;
    }
}

#pragma mark -
#pragma mark Queue helper methods

- (BOOL)queueIsEmpty
{
    return (self.queue.count == 0) ? YES : NO;
}

- (void)enqueue:(id)object
{
    WOAudioscrobblerLog(@"Enqueuing object: %@", object);
    NSParameterAssert(object != nil);
    BOOL empty = [self queueIsEmpty];
    [self.queue addObject:object];
    WOAudioscrobblerLog(@"Number of items currently on the queue: %d", self.queue.count);

    // special case handling for items added to empty queues: process immediately
    if (empty)
    {
        WOAudioscrobblerLog(@"Queue was empty: processing item");
        [self next];
    }
    else
    {
        // some states are also worth submitting
        switch (self.currentState)
        {
            case WOAudioscrobblerIdle:
            case WOAudioscrobblerHandshakeSucceeded:
            case WOAudioscrobblerSubmissionSucceeded:
            case WOAudioscrobblerWaitingToRetrySubmission:
                WOAudioscrobblerLog(@"Queue was non-empty, but ready to submit: processing item");
                [self next];
                break;
            case WOAudioscrobblerSubmissionFailed:
            case WOAudioscrobblerHandshakeFailed:
            case WOAudioscrobblerBadAuth:
                WOAudioscrobblerLog(@"Queue was non-empty, last attempt failed: processing item");
                [self next];
                break;
            case WOAudioscrobblerBadUser:
            case WOAudioscrobblerWaitingForHandshake:
            case WOAudioscrobblerWaitingForSubmissionResponse:
            case WOAudioscrobblerNoAuth:
            default:
                WOAudioscrobblerLog(@"Queue was non-empty, but not ready to submit: not processing item");
                break;
        }
    }
}

- (void)dequeueFirstObject
{
    WOAudioscrobblerLog(@"Dequeueing first object");
    [self.queue removeObjectAtIndex:0];
}

// return first object in the queue without actually dequeuing it; returns nil if queue is empty
- (NSDictionary *)firstObjectInQueue
{
    return [self queueIsEmpty] ? nil : [self.queue objectAtIndex:0];
}

#pragma mark -
#pragma mark High-level methods

- (void)doSubmission:(NSDictionary *)songInfo
{
    NSString *artist    = [songInfo objectForKey:WO_ARTIST_KEY];
    NSString *track     = [songInfo objectForKey:WO_TRACK_KEY];
    NSString *album     = [songInfo objectForKey:WO_ALBUM_KEY];
    NSString *mbid      = [songInfo objectForKey:WO_MBID_KEY];
    unsigned length     = [[songInfo objectForKey:WO_LENGTH_KEY] unsignedIntValue];
    NSString *date      = [songInfo objectForKey:WO_DATE_KEY];

    // u=<user>&s=<MD5 response>&a[0]=<artist>&t[0]=<track>&b[0]=<album>&m[0]=<mbid>&l[0]=<length>&i[0]=<time>
    //  <user>: last.fm username (MUST be the same as the username given in the HANDSHAKE)
    // <MD5 response>: Demonstrates the HANDSHAKE credentials.
    // <artist>: The name of the artist
    // <track>: The name of the track
    // <album>: The name of the album the track is from
    // <mbid>: The MusicBrainz? ID of the track
    // <length>: The length (duration) of the track in whole (integer) seconds
    // <time>: The date and time the track was played, described in a modified ISO 8601 format.

    // Submissions MUST be sent using an HTTP POST request to the URL obtained from the HANDSHAKE process.
    // The submission is formatted as if it were an x-www-urlencoded HTML form response, with the body of the HTTP request containing a single line with key-value pairs separated by =, with multiple pairs separated by &.
    // The submission MUST be correctly double-encoded.
    // The value of each field is expressed as a UTF-8 encoded string and then URL encoded.
    // All the characters not part of a value are already valid UTF-8 and MUST NOT be further URL encoded.
    NSString *string = WO_STRING(@"u=%@&s=%@&a[0]=%@&t[0]=%@&b[0]=%@&m[0]=%@&l[0]=%d&i[0]=%@",
                                 [self escapedString:[self user]],
                                 [self escapedString:[self challengeResponse]],
                                 [self escapedString:artist],
                                 [self escapedString:track],
                                 [self escapedString:album],
                                 [self escapedString:mbid],
                                 length,
                                 [self escapedString:date]);
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];

    if (self.submissionURL)
        WOAudioscrobblerLog(@"Will perform submission using URL: %@", self.submissionURL);
    else
    {
        WOAudioscrobblerLog(@"Cannot perform submission because do not have a submission URL");
        self.currentState = WOAudioscrobblerSubmissionFailed;
        return;
    }

    WOAudioscrobblerLog(@"Submission as URL-encoded string is: %@", string);
    WOAudioscrobblerLog(@"Submission as data is: %@", data);

    if ([self startConnectionWithURL:self.submissionURL body:data isPost:YES])
    {
        WOAudioscrobblerLog(@"Waiting for submission response");
        self.currentState = WOAudioscrobblerWaitingForSubmissionResponse;
    }
    else
    {
        WOAudioscrobblerLog(@"Failed before submission response received");
        self.currentState = WOAudioscrobblerSubmissionFailed;
    }
}

- (void)processSubmissionResponse:(NSArray *)lines
{
    WOAudioscrobblerLog(@"Processing submission response");
    NSParameterAssert(lines != nil);
    unsigned count = [lines count];
    NSParameterAssert(count >= 1);
    NSString *firstLine = [lines objectAtIndex:0];
    if ([firstLine hasPrefix:WO_OK])
    {
        WOAudioscrobblerLog(@"Received OK response");
        // OK
        // INTERVAL n
        // "If the server returns OK, you should remove the submitted tracks from your plugin's cache. "
        self.currentState = WOAudioscrobblerSubmissionSucceeded;
        [self dequeueFirstObject];
        [self next];
    }
    else if ([firstLine hasPrefix:WO_FAILED])
    {
        WOAudioscrobblerLog(@"Received FAILED response");
        // FAILED <reason>
        // INTERVAL n
        // "If it returns FAILED <reason>: The space after FAILED followed by an error message is optional."
        // "This indicates something went wrong, and you should cache the submission and retry later."
        if ([firstLine length] > [WO_FAILED length])
        {
            NSString *failureReason = [firstLine substringFromIndex:[WO_FAILED length]];
            NSLog(@"last.fm submission failed; reported reason: \"%@\"", failureReason);
        }
        else
            NSLog(@"last.fm submission failed");

        // will retry next time asked to submit a track
        self.currentState = WOAudioscrobblerWaitingToRetrySubmission;
    }
    else if ([firstLine hasPrefix:WO_BADAUTH])
    {
        WOAudioscrobblerLog(@"Received BADAUTH response");
        // BADAUTH
        // INTERVAL n
        // "If it returns BADAUTH, you may need to re-handshake"
        self.currentState = WOAudioscrobblerBadAuth;

    }
    else
    {
        NSLog(@"Unrecognized submission response:\n%@", lines);
        self.currentState = WOAudioscrobblerSubmissionFailed;
    }
}

#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    // was a bug; see: <http://wincent.com/a/support/bugs/show_bug.cgi?id=641>
    //  *** -[NSConcreteData setLength:]: unrecognized selector sent to instance 0x1065590
    [self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    // clean up (this is the last message sent by the connection)
    self.connection = nil;
    self.receivedData = nil;
    NSLog(@"NSURLConnection for URL %@ returned error: %@", [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey],
          [error localizedDescription]);
    switch (self.currentState)
    {
        case (WOAudioscrobblerWaitingForHandshake):
            self.currentState = WOAudioscrobblerHandshakeFailed;
            break;
        case (WOAudioscrobblerWaitingForSubmissionResponse):
            self.currentState = WOAudioscrobblerSubmissionFailed;
            break;
        default:
            break;
    }
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // clean up (this is the last message sent by the connection)
    WOAudioscrobblerLog(@"Connection to Audioscrobbler did finish loading (response received)");
    self.connection = nil;
    NSString *string = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
    if (!string)
    {
        NSLog(@"warning: last.fm returned empty string");
        switch (self.currentState)
        {
            case (WOAudioscrobblerWaitingForHandshake):
                self.currentState = WOAudioscrobblerHandshakeFailed;
                break;
            case (WOAudioscrobblerWaitingForSubmissionResponse):
                self.currentState = WOAudioscrobblerSubmissionFailed;
                break;
            default:
                break;
        }
        return; // no point in continuing
    }

    // split into lines and remove blank lines
    NSMutableArray *lines = [NSMutableArray array];
    NSEnumerator *enumerator = [[string componentsSeparatedByString:@"\n"] objectEnumerator];
    NSString *line;
    while ((line = [enumerator nextObject]))
    {
        if (![line isEqualToString:@""])
            [lines addObject:line];
    }
    if ([lines count] == 0)
    {
        WOAudioscrobblerLog(@"Response contained no non-blank lines; not proceeding");
        return; // no point in continuing
    }

    // "INTERVAL commands can be at the end of any response block, but don't expect them to be. Always observe the latest INTERVAL you get."
    NSString *lastLine = [lines lastObject];
    if ([lastLine hasPrefix:WO_INTERVAL])
    {
        WOAudioscrobblerLog(@"Received an INTERVAL directive");
        NSScanner *scanner = [NSScanner scannerWithString:lastLine];
        [scanner scanString:WO_INTERVAL intoString:NULL];
        int interval;
        if ([scanner scanInt:&interval] && (interval > 0))
        {
            WOAudioscrobblerLog(@"Storing interval value: %d", interval);
            self.lastKnownInterval = (unsigned)interval;
        }
        else
            NSLog(@"Invalid interval specification received from last.fm: %@", lastLine);
    }

    // now handle the rest of the response
    switch (self.currentState)
    {
        case WOAudioscrobblerWaitingForHandshake:
            [self processHandshake:lines];
            break;
        case WOAudioscrobblerWaitingForSubmissionResponse:
            [self processSubmissionResponse:lines];
            break;
        default:
            break;
    }
}

#pragma mark -
#pragma mark Properties

@synthesize protocolVersion;
@synthesize currentState;
@synthesize queue;
@synthesize lastKnownInterval;
@synthesize connection;

// cannot synthesize this setter because it would send a copy rather than a mutableCopy message
- (void)setReceivedData:(NSMutableData *)aReceivedData
{
    if (aReceivedData != receivedData)
        receivedData = [aReceivedData mutableCopy];
}

@synthesize receivedData;
@synthesize submissionURL;
@synthesize challenge;
@synthesize userAgent;
@synthesize user;
@synthesize password;

@end
