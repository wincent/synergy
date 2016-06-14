// WOCoverDownloader.m
// Synergy
//
// Copyright 2003-present Greg Hurrell. All rights reserved.

#import "SynergyController.h"
#import "WOCoverDownloader.h"
#import "WOSongInfo.h"
#import "WODebug.h"
#import "WOExceptions.h"
#import "WOSynergyGlobal.h"
#import "NSString+WOExtensions.h"

// important header is WSMethodInvocation.h
#import <CoreServices/CoreServices.h>

// for finding out if a host is reachable (if ppp/network connection is up)
#import <SystemConfiguration/SystemConfiguration.h>

// for finding "Application Support" folder
#import "WONSFileManagerExtensions.h"

// for AWS ECS 4.0 signatures
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import <openssl/bio.h>
#import <openssl/evp.h>

@class WOSongInfo;

void WOAmazonLog(NSString *format, ...)
{
    if (!format)
        return;
    Boolean valid;
    if (CFPreferencesGetAppBooleanValue(CFSTR("LogAmazonEvents"), CFSTR("org.wincent.Synergy"), &valid) && valid)
    {
        va_list args;
        va_start(args, format);
        NSLog(@"Amazon: %@", [[NSString alloc] initWithFormat:format arguments:args]);
        va_end(args);
    }
}

@interface WOCoverDownloader (_private)

// private methods:

// method (launched in a separate thread) to download album covers to disk
+ (void)_downloadCover:(WOSongInfo *)songInfo;

// query xml.amazon.com for URL to the album cover
//+ (NSURL *)_searchForAlbumCover:(WOSongInfo *)song;
+ (void)_searchForAlbumCover:(WOSongInfo *)song;

//     // scan an XML string (source) for material between startTag and endTag
// + (NSString *)_scanString:(NSString *)source
//                  startTag:(NSString *)startTag
//                    endTag:(NSString *)endTag;

// do the actual downloading
//+ (void)_downloadAlbumCover:(WOSongInfo *)song;
+ (BOOL)_downloadAlbumCover:(WOSongInfo *)song;

    // queue management methods
+ (void)_removeFromQueue:(WOSongInfo *)song;
+ (void)_addToQueue:(WOSongInfo *)song;
+ (void)_processNextItemInQueue;

+ (void)_startTimer;
+ (void)_suspendTimer;

+ (BOOL)_netConnectionEstablished;

// used in determining if net connection is available
static Boolean UnsolicitedAllowedSCF(const char *serverName);

    // filesystem routines
+ (NSString *)_filenameWithPath:(WOSongInfo *)song;

+ (NSString *)_albumCoversPath;

@end

@implementation WOCoverDownloader
/*"

Using amazon.com web services, we are limited to one query per second. Yet if a
user rapidly skips through tracks, this could result in more than one query per
second.

Therefore it is necessary to maintain a queue. The downloads are processed in
"last in, first out" order, although any download that is already in progress is
completed before a new download begins. This effectively means that when new
downloads are inserted just behind the head (the currently downloading file) of
the queue.

Every one second, the class marks another download as ready to begin, and spawns
a new thread in which the download will take place. The management of this queue
is completely transparent to the programmer.

If there is a connection failure or other error, items in the queue will
automatically be retried, at an increasing interval. This ensures that problems
aren't exacerbated at the server end if it is overloaded.

On each failure, the item in question is moved down one place in the queue so
that other waiting items have a chance at getting a download. In addition to
the moving down the queue, the interval is doubled for each failure, up to a
limit of 512 seconds. So, the intervals run like so: 1, 2, 4, 8, 16, 32, 64,
128, 256 and 512 seconds.

*** note, I've massively increased these numbers to reduce load on the amazon servers.... we now go
10, 20, 40, 80, 160, 320, 640, 1280, 2560, 5120 seconds

Once finished, the completed download is moved to:
~/Library/Application Support/Synergy/Album Covers/

"*/

// Constants:

// initial capacity of the download queue, will grow if necessary
#define WO_INITIAL_QUEUE_CAPACITY (unsigned)100

// minimum interval (secs) between cover downloads
#define WO_COVER_DOWNLOAD_INTERVAL  (float)10.0

// amazon.com associate ID (define as @"" if no associate ID)
#define WO_AMAZON_ASSOCIATE_ID  @""

// Amazon ECS 4.0 (March 2008 onwards) requires new keys
// - first added in 4.1a release
// - old keys revoked and new keys added (from new AWS account) 25 February
//   (4.4b2 release) to isolate from my EC2 account
#define WO_ECS_4_ACCESS_KEY_ID  @"key"
#define WO_AWS_HMAC_SECRET      @"secret"

// Globals:

// global to indicate whether new downloads should begin immediately (initiating
// a new net connection if necessary) or wait until a net connection is
// available
static BOOL             _connectOnDemand;

// whether or not to pre-process search keywords
static BOOL             _preprocess;

// global timer to ensure new downloads are at least one second apart
static NSTimer          *_downloadTimer;

// global storage for download queue, an array of WOSongInfo objs
static NSMutableArray   *_downloadQueue;

// locks for thread safety
// TODO: for Synergy 3.5 will break compatibility with Jaguar, so can start using @synchronized and @try etc
static NSLock           *_downloadQueueLock;
static NSLock           *_connectOnDemandLock;
static NSLock           *_preprocessLock;

static NSString *WOCoverDownloaderAlbumCoversPath = nil;
static NSString *WOCoverDownloaderTempAlbumCoversPath = nil;

+ (void)initialize
{
    _connectOnDemand        = YES;
    _preprocess             = YES;
    _downloadQueue          = [[NSMutableArray alloc] initWithCapacity:WO_INITIAL_QUEUE_CAPACITY];
    _downloadQueueLock      = [[NSLock alloc] init];
    _connectOnDemandLock    = [[NSLock alloc] init];
    _preprocessLock         = [[NSLock alloc] init];
    _downloadTimer          = nil;   // timer will get started when first item is added to queue
}

+ (void)_startTimer
{
    // only works if called from main thread
    if (!_downloadTimer)
    {
        _downloadTimer = [NSTimer scheduledTimerWithTimeInterval:WO_COVER_DOWNLOAD_INTERVAL  // fires every 10 seconds
                                                          target:self
                                                        selector:@selector(_processNextItemInQueue:)
                                                        userInfo:nil
                                                         repeats:YES];
    }
}

+ (void)_suspendTimer
{
    if (_downloadTimer)
    {
        [_downloadTimer invalidate];
        _downloadTimer = nil;
    }
}

// queue management methods (all private)

+ (void)_removeFromQueue:(WOSongInfo *)song
{
    [_downloadQueueLock lock];

    [_downloadQueue removeObject:song];

    // no need to stop timer if queue is now empty (this is handled in
    // _processNextItemInQueue)

    [_downloadQueueLock unlock];
}

+ (void)_addToQueue:(WOSongInfo *)song
/*"
Adds a new item to the queue. If the timer is suspended then reinstate it.
"*/
{
    [_downloadQueueLock lock];

    unsigned queueLength = [_downloadQueue count];

    // check for duplicates
    BOOL isDuplicate = NO;

    if (queueLength != 0)
    {
        NSEnumerator *enumerator = [_downloadQueue reverseObjectEnumerator];

        WOSongInfo *queueItem;

        while ((queueItem = [enumerator nextObject]))
        {
            // should be testing based on *duplicate search strings*... or at least, that's what I think we should be doing...
            if ([[queueItem song] isEqualToString:[song song]] &&
                [[queueItem album] isEqualToString:[song album]] &&
                [[queueItem artist] isEqualToString:[song artist]])
            {
                isDuplicate = YES;
                break;
            }
        }
    }

    // insert item at head of queue if not a duplicate
    if (!isDuplicate)
        [_downloadQueue insertObject:song atIndex:queueLength];

    [_downloadQueueLock unlock];

    if (!_downloadTimer)
        [self _startTimer];
}

+ (void)_processNextItemInQueue:(NSTimer *)timer
/*"
 Called once per second, when the global timer fires, this method checks the
 connectOnDemand setting and the current network connection status to see
 whether it is permissible to start a new download. It then examines the global
 download queue and if any items are waiting spawns a new thread to process
 the download of the highest priority item.

 When the last item is removed from the queue, the timer-driven updates are
 suspended to conserve CPU usage. As soon as new item is added to the queue they
 are reinstated. This is useful during normal listening when several minutes
 may pass without the need to initiate any new downloads.
"*/
{
    // find first eligible item in queue
    [_downloadQueueLock lock];

    // check for a zero-length queue; if found, suspend timer
    if ([_downloadQueue count] == 0)
        [self _suspendTimer];
    else
    {
        // step through queue looking for eligible download
        NSEnumerator *enumerator = [_downloadQueue reverseObjectEnumerator];

        WOSongInfo *queueItem;

        while ((queueItem = [enumerator nextObject]))
        {
            if ( // brand new queue item, no download ever attempted
                 ([queueItem attemptedDownload] == NO) ||
                 // older (failed) queue item that is ready to retry
                 ([queueItem readyToRetry]))
            {
                // eligible item found! start download in new thread
                [NSThread detachNewThreadSelector:@selector(_downloadCover:)
                                         toTarget:self
                                       withObject:queueItem];
                break;
            }
        }
    }
    [_downloadQueueLock unlock];
}

+ (BOOL)_netConnectionEstablished
/*"
Checks to see if a connection to the network is already established. If so,
 returns YES, otherwise NO. Specifically, it does this by testing to see if
 "ecs.amazonaws.com" is classified as "reachable" by the SystemConfiguration
 framework.
"*/
{
    return UnsolicitedAllowedSCF("ecs.amazonaws.com") ? YES : NO;
}

// public method that can be used to test reachability of an arbitrary host
+ (BOOL)hostIsReachable:(NSString *)host
{
    if (UnsolicitedAllowedSCF([host UTF8String]))
        return YES;
    else
        return NO;
}

static Boolean UnsolicitedAllowedSCF(const char *serverName)
{
    SCNetworkReachabilityFlags flags = 0;
    SCNetworkReachabilityRef target = SCNetworkReachabilityCreateWithName(NULL, serverName);
    Boolean ok = SCNetworkReachabilityGetFlags(target, &flags);
    CFRelease(target);
    return ok &&
        !(flags & kSCNetworkFlagsConnectionRequired) &&
        (flags & kSCNetworkFlagsReachable);
}

// for those callers who would rather receive a BOOL confirming that the album cover exists on the disk
+ (BOOL)albumCoverExists:(WOSongInfo *)song
{
    // unfortunately, we can't *really* know if the image exists on disk without actually trying to load it...
    return [[self class] albumCover:song] ? YES : NO;
}

+ (NSImage *)albumCover:(WOSongInfo *)song
/*"
Given an identifier, this method returns an NSImage containing the album cover
 corresponding to that identifier. If no image exists on disk, returns nil. In
 such cases, automatically adds the song to the download queue and once (if) the
 image is obtained posts an AlbumCoverImageAvailable notification to the
 default notifcation centre.

 This method is not called every time through the program's main timer loop:
 only the first time a new track is encountered.
"*/
{
    NSImage *image = nil;

    // grab filename (format is like "Album-BrandNewDay,Artist-String.jpg")
    NSString *filename = [self _filenameWithPath:song];

    // only proceed if filename is not nil (nil would mean there is not enough
    // information to construct a filename, or couldn't construct path)
    if (!filename)
        return nil;

    if ([[NSFileManager defaultManager] fileExistsAtPath:filename])
        image = [[NSImage alloc] initWithContentsOfFile:filename];

    if (!image)
    {
        // if no image file, as a last-ditch effort try with .tiff extension instead
        NSString *altFilename =
        [[filename stringByDeletingPathExtension] stringByAppendingPathExtension:
            @"tiff"];

        if ([[NSFileManager defaultManager] fileExistsAtPath:altFilename])
            image = [[NSImage alloc] initWithContentsOfFile:altFilename];

        // if we have a tiff, better update the songinfo object correspondingly
        if (image)
        {
            NSString *newFilename = [altFilename lastPathComponent];
            [song setFilename:newFilename]; // no effect!
        }
    }

    // still no image found, add to download queue
    if (!image)
        // the _addToQueue method is smart enough to avoid adding a duplicate
        [self _addToQueue:song];

    return image;
}


// method (launched in a separate thread) to download album covers to disk
+ (void)_downloadCover:(WOSongInfo *)song
/*"
 This method should be called in a separate thread using
 detachNewThreadSelector:toTarget:withObject. Note that multiple concurrent
 threads could be running if the user rapidly skips through tracks. It is left
 up to the SynergyController class to determine whether or not calling this
 method is the appropriate action; in other words, it must first check whether
 the album cover image already exists on disk, and whether the user preferences
 allow network connections for the purpose of downloading cover images.

 The download starts immediately if an interval of one second or more has
 elapsed since the last download started. This is achieved by adding the object
 to the queue and firing the timer immediately. This should only happen when
 there are no other objects in the queue. Otherwise, the object is merely added
 to the queue and handled later on by the timer-driven _processNextItemInQueue
 method.
"*/
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // are we allowed to connect on demand?
    // or failing that, is there a network connection already established?
    if ([[SynergyController sharedInstance] hitAmazon] &&
        ([self connectOnDemand] || [self _netConnectionEstablished]))
        // will also do the download if it finds a suitable candidate
        [self _searchForAlbumCover:song];

    [pool drain];
}


//+ (NSURL *)_searchForAlbumCover:(WOSongInfo *)song
+ (void)_searchForAlbumCover:(WOSongInfo *)song
/*"
This is the method that does the actual work of formatting an appropriate query
 and sending it to xml.amazon.com using XML/HTTP.

 This is the search order --
 1. Album name + artist -> on failure, give up
 2. If no album name: song name + artist -> on failure, give up
 3. If no artist: album name, then song name, then give up

 No return value here. The _downloadAlbumCover method posts a notification to
 the default notification centre to let the main thread know when the download
 is done.

 "*/
{
    // note that download has been attempted
    [song setAttemptedDownload:YES];

    // Old ECS 3.0 example query string:
    //      http://xml.amazon.com/onca/xml2?
    //          t=blah&
    //          dev-t=blah&
    //          type=lite&
    //          mode=music&
    //          page=1&
    //          f=xml&
    //          KeywordSearch=Sting%20Sacred%20Love
    //
    // New ECS 4.0 format:
    //      http://ecs.amazonaws.com/onca/xml?
    //          AWSAccessKeyId=blah&
    //          AssociateTag=blah&
    //          ItemPage=1&
    //          Keywords=Sting%20Sacred%20Love&
    //          Operation=ItemSearch&
    //          ResponseGroup=Images&
    //          SearchIndex=Music&
    //          Service=AWSECommerceService&
    //          Timestamp=2009-09-19T02%3A30%3A15Z&
    //          Version=2009-07-01&
    //          Signature=...
    //
    // Where "Signature" is signed version of:
    //
    //      GET
    //      ecs.amazonaws.com
    //      /onca/xml
    //      AWSAccessKeyId=...&AssociateTag=... (etc, all on one line)
    //
    // Note that commas/colons need to be percent escaped, for example, in the
    // Timestamp, the colons are actually %3A
    //
    // Private signing salt: blah
    // Signature algorithm: RFC 2104-compliant HMAC with the SHA256 hash
    // + and = characters in signature must be URL-encoded
    //
    // See: http://docs.amazonwebservices.com/AWSECommerceService/latest/DG/index.html?rest-signature.html

    // build the query string, component by component (for readability, a
    // lengthy format string is not used here)
    NSMutableArray *queryComponents = [NSMutableArray arrayWithObjects:
        @"AWSAccessKeyId=" WO_ECS_4_ACCESS_KEY_ID,
        @"AssociateTag=" WO_AMAZON_ASSOCIATE_ID,
        @"ItemPage=1", nil];

    // assemble search keywords
    NSMutableString *searchKeywords = [NSMutableString string];
    NSString *album = [song album];
    NSString *artist = [song artist];
    NSString *title = [song song];
    if (album && [album length] > 0 &&
        artist && [artist length] > 0)
        [searchKeywords appendFormat:@"%@ %@", album, artist];
    else if (title && [title length] > 0 &&
             artist && [artist length] > 0)
        [searchKeywords appendFormat:@"%@ %@", title, artist];
    else if (album && [album length] > 0)
        [searchKeywords appendFormat:@"%@", album];
    else if (title && [title length] > 0)
        [searchKeywords appendFormat:@"%@", title];
    else
    {
        // failure is assured! no album, artist, or song info! (should never happen)
        // no point in trying again
        [self _removeFromQueue:song];
        return;
    }
    WOAmazonLog(@"Search keywords (before filtering): %@", searchKeywords);

    // additional filtering/pre-processing
    if ([self preprocess])
    {
        // should I also convert accented characters to non-accented versions?
        // amazon seems to choke on them...

        // strip out things between () if first search fails?
        // strip out stuff after "-" if fails?

        // words to strip -- words are stripped in order, so important to strip
        // "(Disc 1)" before "Disc 1"
        NSArray *filterWords = [NSArray arrayWithObjects:
            @"(Disc 1)",
            @"Disc 1",
            @"(Disc 2)",
            @"Disc 2",
            @"(OST)",
            @"OST",
            @"soundtrack",
            @"(single)",
            @"(CD1)",
            @"CD1",
            @"(CD2)",
            @"CD2",
            @"(remix)",

            // and for the French
            @"Disque 1",
            @"Disque 2",

            // other reader suggestions
            @"[Bonus Tracks]",

            nil];

        // strip out the filtered words
        for (NSString *filterWord in filterWords)
            [searchKeywords setString:[searchKeywords stringByRemoving:filterWord]];
    }
    WOAmazonLog(@"Search keywords (after filtering): %@", searchKeywords);

    // want to escape all "reserved" characters as defined in RFC 3986
    // http://www.ietf.org/rfc/rfc3986.txt
    // see also: http://wincent.com/a/support/bugs/show_bug.cgi?id=566
    NSString *escapedKeywords = NSMakeCollectable(CFURLCreateStringByAddingPercentEscapes
        (NULL,
         (CFStringRef)searchKeywords,
         NULL,
         CFSTR(":/?#[]@!$&'()*+,;="),
         kCFStringEncodingUTF8));
    if (escapedKeywords && [escapedKeywords length] > 0)
        [queryComponents addObject:[NSString stringWithFormat:@"Keywords=%@", escapedKeywords]];
    else
    {
        // without keywords no point in trying
        [self _removeFromQueue:song];
        return;
    }
    WOAmazonLog(@"Escaped keywords: %@", escapedKeywords);
    [queryComponents addObject:@"Operation=ItemSearch"];
    [queryComponents addObject:@"ResponseGroup=Images"];
    [queryComponents addObject:@"SearchIndex=Music"];
    [queryComponents addObject:@"Service=AWSECommerceService"];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH'%3A'mm'%3A'ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    WOAmazonLog(@"Timestamp: %@", timestamp);

    [queryComponents addObject:[NSString stringWithFormat:@"Timestamp=%@", timestamp]];
    [queryComponents addObject:@"Version=2009-07-01"];

    NSMutableString *queryString = [NSMutableString stringWithString:[queryComponents componentsJoinedByString:@"&"]];
    WOAmazonLog(@"Base query string: %@", queryString);
    NSString *plaintext = [NSString stringWithFormat:
        @"GET\n"
        @"ecs.amazonaws.com\n"
        @"/onca/xml\n"
        @"%@", queryString];
    WOAmazonLog(@"Plaintext for signing: %@", plaintext);

    // create the HMAC signature
    const char *secret  = [WO_AWS_HMAC_SECRET UTF8String];
    const char *data    = [plaintext UTF8String];
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, secret, strlen(secret), data, strlen(data), cHMAC);
    NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC
                                          length:sizeof(cHMAC)];
    WOAmazonLog(@"HMAC data: %@", HMAC);

    // base-64 encode it
    BIO *encoded = BIO_new(BIO_s_mem());
    BIO *base64filter = BIO_new(BIO_f_base64());
    BIO_set_flags(base64filter, BIO_FLAGS_BASE64_NO_NL);
    encoded = BIO_push(base64filter, encoded);
    BIO_write(encoded, [HMAC bytes], [HMAC length]);
    (void)BIO_flush(encoded);
    char *cHMACString;
    long base64Length = BIO_get_mem_data(encoded, &cHMACString);
    NSString *HMACString = [[NSString alloc] initWithBytes:cHMACString
                                                    length:base64Length
                                                  encoding:NSUTF8StringEncoding];
    BIO_free_all(encoded);
    WOAmazonLog(@"HMAC data, base-64 encoded: %@", HMACString);

    // URL-encode "+" and "=" characters before appending to query string
    HMACString = NSMakeCollectable(CFURLCreateStringByAddingPercentEscapes(NULL,
        (CFStringRef)HMACString, NULL, CFSTR("+="), kCFStringEncodingUTF8));
    WOAmazonLog(@"HMAC data after sanitization: %@", HMACString);
    [queryString appendFormat:@"&Signature=%@", HMACString];

    // now prepend scheme, host etc
    NSString *URLString = [NSString stringWithFormat:
        @"http://ecs.amazonaws.com/onca/xml?%@", queryString];
    NSURL *queryURL = [NSURL URLWithString:URLString];

    // perform the search
    //
    // XML result:
    //      ItemSearchResponse
    //          Items
    //              Item
    //                  SmallImage
    //                      URL
    //                  MediumImage
    //                      URL
    //                  LargeImage
    //                      URL
    WOAmazonLog(@"Query URL: %@", queryURL);
    NSError *error = nil;
    NSXMLDocument *xml = [[NSXMLDocument alloc] initWithContentsOfURL:queryURL
                                                              options:NSDataReadingUncached
                                                                error:&error];
    if (error)
    {
        WOAmazonLog(@"-[NSXMLDocument initWithContentsOfURL:options:error:] failed: %@",
            [error localizedDescription]);
        [song incrementRetryInterval];
        return;
    }
    WOAmazonLog(@"Result: %@", [xml XMLString]);

    // first, try for large version of image
    BOOL haveURL = NO; // distinguish between network failure and no image
    NSString *imageURL = nil;

    NSArray *images = [xml nodesForXPath:@".//Item[1]/LargeImage/URL" error:&error];
    if ([images count] > 0)
    {
        imageURL = [[images objectAtIndex:0] objectValue];
        WOAmazonLog(@"Large image URL: %@", imageURL);
        haveURL = YES;
        [song setURL:[NSURL URLWithString:imageURL]];
        if (![self _downloadAlbumCover:song])
            imageURL = nil;
    }

    // fallback to medium image if necessary
    if (!imageURL)
    {
        images = [xml nodesForXPath:@".//Item[1]/MediumImage/URL" error:&error];
        if ([images count] > 0)
        {
            imageURL = [[images objectAtIndex:0] objectValue];
            WOAmazonLog(@"Medium image URL: %@", imageURL);
            haveURL = YES;
            [song setURL:[NSURL URLWithString:imageURL]];
            if (![self _downloadAlbumCover:song])
                imageURL = nil;
        }
    }

    // fallback to small image
    if (!imageURL)
    {
        images = [xml nodesForXPath:@".//Item[1]/SmallImage/URL" error:&error];
        if ([images count] > 0)
        {
            imageURL = [[images objectAtIndex:0] objectValue];
            WOAmazonLog(@"Small image URL: %@", imageURL);
            haveURL = YES;
            [song setURL:[NSURL URLWithString:imageURL]];
            if (![self _downloadAlbumCover:song])
                imageURL = nil;
        }
    }

    // if no URL found, we've failed
    if (!imageURL)
    {
        // failure
        //
        // this is the kind of failure from which we are unlikely to recover
        // do we want this kind of thing to hang around in the queue forever,
        // taking up memory and resources?
        //
        // likely cause for failure: not found in amazon database
        // likely remedy: no remedy
        //
        // likely cause: transient network failure
        // likely remedy: eventual restoration of network connectivity
        //
        // in the former case, we definitely don't want it hanging around the
        // queue
        //
        // in the latter case, it's ok if it hangs around the queue
        //
        if (haveURL)
            // only return item to queue if the failure is not likely to be
            // permanent
            [song incrementRetryInterval];
        else
            // remove the item from the queue
            // policy change 27 March 2004: don't retry here... I suspect what
            // was happening was it was getting re-added straight away (ie. not
            // when the song was played again, but literally three seconds
            // later...) so now, it will only retry on next Synergy run...
            // benefit: less load on Amazon servers, cost: additional memory
            // used because song stays in queue
            [song setReadyToRetry:NO];
    }
}

+ (BOOL)_downloadAlbumCover:(WOSongInfo *)song
/*"
  Given a URL to an album cover image, this method does the actual downloading.
 Returns YES if a download was completed or otherwise taken care of -- for
 example, by being added to back of queue -- and NO if the download wasn't
 handled, for example, if the download succeeded but only returned a 1x1 pixel
 place-holder gif.
"*/
{
    NSURL *cover = [song URL];

    // assume everything will be all right
    BOOL returnStatus = YES;

    NS_DURING
        // this will block until the data is completely retrieved
        NSImage *coverImage = [[NSImage alloc] initWithContentsOfURL:cover];

        // did it work?
        if (!coverImage)
        {
            [NSException raise:WO_DOWNLOAD_ALBUM_COVER_IMAGE_FAILURE
                        format:WO_DOWNLOAD_ALBUM_COVER_IMAGE_FAILURE_TEXT];
        }

        // check to see if it's one of Amazon's 1x1 pixel gifs!
        NSSize imageSize = [coverImage size];

        if ((imageSize.width == 1) ||
            (imageSize.height == 1))
        {
            // consider this a failure
            returnStatus = NO;
        }
        else
        {
            // save a copy to disk; make a jpeg
            NSData *tiffData =
            [coverImage TIFFRepresentationUsingCompression:NSTIFFCompressionLZW
                                                    factor:1.0];
            NSBitmapImageRep    *rep = [NSBitmapImageRep imageRepWithData:tiffData];
            NSNumber            *quality = [NSNumber numberWithFloat:0.80];
            NSDictionary        *properties = [NSDictionary dictionaryWithObject:quality
                                                                          forKey:NSImageCompressionFactor];
            NSData *coverData = [rep representationUsingType:NSJPEGFileType properties:properties];

            // actually write the jpg out to disk
            if (![coverData writeToFile:[self _filenameWithPath:song]
                             atomically:YES])
            {
                [NSException raise:WO_DOWNLOAD_ALBUM_COVER_IMAGE_FAILURE
                            format:WO_DOWNLOAD_ALBUM_COVER_IMAGE_FAILURE_TEXT];
            }

            // note that download is done....
            [song setReadyToRetry:NO];

            // remove from queue -- this isn't happening!
            [self _removeFromQueue:song];

            // post notification to default download centre
            NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

            NSDictionary *userInfo =
                [NSDictionary dictionaryWithObject:song
                                            forKey:WO_DOWNLOADED_SONG_ID];

            //NSLog(@"Posting notification");
            [center postNotificationName:WO_DOWNLOAD_DONE_NOTIFICATION
                                  object:nil
                                userInfo:userInfo];
        }

    NS_HANDLER
        ELOG(@"%@", [localException reason]);

        // although we failed to get the image, we still return YES here
        // because in returning the download to the end of the queue we are
        // still successfully "handling" the download request
        returnStatus = YES;

        // return download to *end* of queue, extending timer as necessary

        [_downloadQueueLock lock];

        // first remove it from the queue
        [_downloadQueue removeObject:song];

        // increment its retry interval
        [song incrementRetryInterval];

        // then add it back in at the end
        [_downloadQueue insertObject:song atIndex:0];

        [_downloadQueueLock unlock];

    NS_ENDHANDLER

    return returnStatus;
}

// returns path to album covers folder
+ (NSString *)albumCoversPath
{
    return [self _albumCoversPath];
}

+ (NSString *)_filenameWithPath:(WOSongInfo *)song
/*"
 Returns a suitable file name and full path for which an album cover image. The
 filename is comprised of album-artist with a jpg extension; the WOSongInfo
 object handles construction of the filename based on its artist and album
 instance variables.
"*/
{
    NSString *filenameWithPath = nil;

    // filename should already be in the WOSongInfo object
    if (![song filename])
        // not enough information to construct filename!
        return nil;

    // but need to calculate path
    filenameWithPath =
        [[self _albumCoversPath] stringByAppendingPathComponent:
            [song filename]];

    return filenameWithPath;
}

+ (NSString *)_albumCoversPath
/*"
  Returns an NSString pointing to the album covers folder, creating it if
 necessary. Returns nil on failure. The path should resemble:
 ~/Library/Application Support/Synergy/Album Covers/
"*/
{
    if (WOCoverDownloaderAlbumCoversPath)
        return WOCoverDownloaderAlbumCoversPath;

    NS_DURING
        NSFileManager *fm = [NSFileManager defaultManager];

        // will attempt to create Application Support folder if not found
        NSString *applicationSupportFolder =
            [fm findSystemFolderType:kApplicationSupportFolderType
                           forDomain:kUserDomain
                            creating:YES];

        // nil if failed to find/create Application Support folder
        if (!applicationSupportFolder)
            [NSException raise:WO_ALBUM_COVER_FOLDER
                        format:WO_ALBUM_COVER_FOLDER_TEXT];

        // construct path to Synergy folder
        NSString *synergyFolder =
            [[applicationSupportFolder stringByAppendingPathComponent:
                @"Synergy"] stringByResolvingSymlinksInPath];

        // test for the existence of the Synergy folder
        BOOL isDir;

        if (![fm fileExistsAtPath:synergyFolder isDirectory:&isDir])
        {
            // attempt to create folder using default attributes
            if (![fm createDirectoryAtPath:synergyFolder
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:NULL])
                [NSException raise:WO_ALBUM_COVER_FOLDER
                            format:WO_ALBUM_COVER_FOLDER_TEXT];
        }
        else
        {
            // "Synergy" already exists: make sure it is a directory
            if (!isDir)
            {
                // if not a directory, check if its an alias to a directory
                NSDictionary *synAttributes;

                // use our category extending NSString
                synergyFolder = [synergyFolder stringByResolvingAliasesInPath];

                synAttributes =
                    [fm attributesOfItemAtPath:synergyFolder
                                         error:NULL];
                if ([synAttributes fileType] != NSFileTypeDirectory)
                    [NSException raise:WO_ALBUM_COVER_FOLDER
                                format:WO_ALBUM_COVER_FOLDER_TEXT];
            }
        }

        // now test for existence of "Album Covers" folder
        NSString *albumCoversFolder =
            [[synergyFolder stringByAppendingPathComponent:@"Album Covers"]
                stringByResolvingSymlinksInPath];

        if (![fm fileExistsAtPath:albumCoversFolder isDirectory:&isDir])
        {
            // attempt to create folder using default attributes
            if (![fm createDirectoryAtPath:albumCoversFolder
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:NULL])
                [NSException raise:WO_ALBUM_COVER_FOLDER
                            format:WO_ALBUM_COVER_FOLDER_TEXT];
        }
        else
        {
            // "Album Covers" already exists: make sure it is a directory
            if (!isDir)
            {
                // if not a directory, check if its an alias to a directory
                NSDictionary *albumsAttributes;

                // use our category extending NSString
                albumCoversFolder =
                    [albumCoversFolder stringByResolvingAliasesInPath];

                albumsAttributes =
                    [fm attributesOfItemAtPath:albumCoversFolder
                                         error:NULL];
                if ([albumsAttributes fileType] != NSFileTypeDirectory)
                    [NSException raise:WO_ALBUM_COVER_FOLDER
                                format:WO_ALBUM_COVER_FOLDER_TEXT];
            }
        }

        // "Synergy/Album Covers" exists and it is a folder, return that value
        WOCoverDownloaderAlbumCoversPath = albumCoversFolder;

    NS_HANDLER
        ELOG(@"%@", [localException reason]);

        WOCoverDownloaderAlbumCoversPath = nil;

    NS_ENDHANDLER

    return WOCoverDownloaderAlbumCoversPath;
}

+ (NSString *)tempAlbumCoversPath
// return ~/Library/Application Support/Synergy/Temporary Album Covers/
{
    if (WOCoverDownloaderTempAlbumCoversPath)
        return WOCoverDownloaderTempAlbumCoversPath;

    NS_DURING

        NSString *coversPath = [self albumCoversPath];

        NSString *parent = [coversPath stringByDeletingLastPathComponent];

        // now test for existence of "Temporary Album Covers" folder
        NSString *albumCoversFolder =
            [[parent stringByAppendingPathComponent:@"Temporary Album Covers"]
                stringByResolvingSymlinksInPath];

        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL isDir;

        if (![fm fileExistsAtPath:albumCoversFolder isDirectory:&isDir])
        {
            // attempt to create folder using default attributes
            if (![fm createDirectoryAtPath:albumCoversFolder
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:NULL])
                [NSException raise:WO_ALBUM_COVER_FOLDER
                            format:WO_ALBUM_COVER_FOLDER_TEXT];
        }
        else
        {
            // "Album Covers" already exists: make sure it is a directory
            if (!isDir)
            {
                // if not a directory, check if its an alias to a directory
                NSDictionary *albumsAttributes;

                // use our category extending NSString
                albumCoversFolder =
                    [albumCoversFolder stringByResolvingAliasesInPath];

                albumsAttributes =
                    [fm attributesOfItemAtPath:albumCoversFolder
                                         error:NULL];
                if ([albumsAttributes fileType] != NSFileTypeDirectory)
                    [NSException raise:WO_ALBUM_COVER_FOLDER
                                format:WO_ALBUM_COVER_FOLDER_TEXT];
            }
        }

        // "Synergy/Album Covers" exists and it is a folder, return that value
        WOCoverDownloaderTempAlbumCoversPath = albumCoversFolder;

    NS_HANDLER
        ELOG(@"%@", [localException reason]);

        WOCoverDownloaderTempAlbumCoversPath = nil;

    NS_ENDHANDLER

    return WOCoverDownloaderTempAlbumCoversPath;
}

// accessors

+ (BOOL)connectOnDemand
    /*"
    Returns the global connectOnDemand setting for all instances of this class. YES
     indicates that new downloads will initiate a connection to the network even if
     one does not already exist; NO indicates that network queries will not be sent
     unless the network is already established. In the latter case, new downloads
     are added to the queue but not processed until a connection becomes available.
     "*/
{
    [_connectOnDemandLock lock];
    BOOL returnValue = _connectOnDemand;
    [_connectOnDemandLock unlock];
    return returnValue;
}

+ (void)setConnectOnDemand:(BOOL)connectOnDemand
    /*"
    Sets the global connectOnDemand setting for all instances of this class. See
     connectOnDemand.
     "*/
{
    [_connectOnDemandLock lock];
    _connectOnDemand = connectOnDemand;
    [_connectOnDemandLock unlock];
}

+ (BOOL)preprocess
{
    [_preprocessLock lock];
    BOOL returnValue = _preprocess;
    [_preprocessLock unlock];
    return returnValue;
}

+ (void)setPreprocess:(BOOL)preprocess
{
    [_preprocessLock lock];
    _preprocess = preprocess;
    [_preprocessLock unlock];
}

@end
