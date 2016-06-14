//
//  NSString+WOExtensions.m
//  Synergy
//
//  Created by Greg Hurrell on Wed Apr 09 2003.
//  Copyright 2003-present Greg Hurrell.

// category header
#import "NSString+WOExtensions.h"

// system headers
#import <CoreServices/CoreServices.h>

// WOPublic headers
#import "WOPublic/WOMemory.h"

@implementation NSString (WOExtensions)

// scan a string for material between startTag and endTag
- (NSString *)stringBetweenStartTag:(NSString *)startTag endTag:(NSString *)endTag
{
    NSScanner *scanner = [NSScanner scannerWithString:self];
    NSString  *result;

    [scanner scanUpToString:startTag intoString:nil];

    if ([scanner scanString:startTag intoString:nil])
    {
        if ([scanner scanUpToString:endTag intoString:&result])
            return result;
    }

    return nil;
}

// scan a string for material, removing said material
- (NSString *)stringByRemoving:(NSString *)removeString
{
    NSScanner   *scanner  = [NSScanner scannerWithString:self];
    NSString    *result;

    // used to build up string that will be returned
    NSMutableString *finalValue = [NSMutableString string];

    while (![scanner isAtEnd])
    {
        // scan up to target string
        if([scanner scanUpToString:removeString intoString:&result])
            // keep scanned portion
            [finalValue appendString:result];

        // scan past target string
        [scanner scanString:removeString intoString:nil];
    }
    return finalValue;
}

- (NSString *)stringByResolvingAliasesInPath
{
    NSString *basePath      = [self stringByStandardizingPath];
    NSString *resolvedPath  = nil;
    CFURLRef url = WOMakeCollectable(CFURLCreateWithFileSystemPath(NULL, (CFStringRef)basePath, kCFURLPOSIXPathStyle, NO));
    if(url != NULL)
    {
        FSRef fsRef;
        if(CFURLGetFSRef(url, &fsRef))
        {
            Boolean targetIsFolder, wasAliased;
            if (FSResolveAliasFile (&fsRef, true, &targetIsFolder, &wasAliased) == noErr && wasAliased)
            {
                CFURLRef resolvedUrl = WOMakeCollectable(CFURLCreateFromFSRef(NULL, &fsRef));
                if(resolvedUrl != NULL)
                    resolvedPath = [NSMakeCollectable(CFURLCopyFileSystemPath(resolvedUrl, kCFURLPOSIXPathStyle)) copy];
            }
        }
    }
    return resolvedPath;
}

@end
