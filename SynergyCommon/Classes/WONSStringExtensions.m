// WONSStringExtensions.m
// Synergy
//
// Copyright 2003-2010 Wincent Colaiuta. All rights reserved.

#import "WONSStringExtensions.h"
#import "WODebug.h"

// getuid()
#import <sys/types.h>
#import <unistd.h>

// S_IWGRP, S_IWOTH
#import <sys/types.h>
#import <sys/stat.h>

#pragma mark -
#pragma mark Global variables

@implementation NSString (WONSStringExtensions)

// these two come from the WinSwitch source (3.0 I think)
- (BOOL)pathIsOwnedByCurrentUser
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSDictionary *attributes = [manager attributesOfItemAtPath:self error:NULL];
    NSNumber *tmp = [attributes fileOwnerAccountID];
    if (!tmp) return NO; // attributes dictionary had no matching key
    unsigned long user = [tmp unsignedLongValue];

    return (BOOL)(getuid() == (uid_t)user);
}

- (BOOL)pathIsWritableOnlyByCurrentUser
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSDictionary *attributes = [manager attributesOfItemAtPath:self error:NULL];
    if (!attributes) return NO; // probably was not a valid path
    unsigned long perms = [attributes filePosixPermissions];
    if (perms == 0) return NO; // attributes dictionary had no matching key

    if ((perms & S_IWGRP) || (perms & S_IWOTH)) // "group" or "other" can write!
        return NO;

    return YES;
}

@end
