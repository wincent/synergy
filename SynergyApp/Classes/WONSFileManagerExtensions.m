//
//  WONSFileManagerExtensions.m
//  Synergy
//
//  Created by Greg Hurrell on 25 March 2003.
//  Copyright 2003-present Greg Hurrell.

// category header
#import "WONSFileManagerExtensions.h"

// WOPublic headers
#import "WOPublic/WOMemory.h"

/*

 Example usage: locating user's "Application Support" folder

 NSString *applicationSupportFolder = [[NSFileManager defaultManager]
 findSystemFolderType:kApplicationSupportFolderType
            forDomain:kUserDomain];

 Returns nil on error

 Code based on posting to cocoa-dev list:
 http://cocoa.mamasam.com/COCOADEV/2002/12/1/51637.php

 */

@implementation NSFileManager (WONSFileManagerExtensions)

- (NSString *)findSystemFolderType:(int)folderType forDomain:(int)domain creating:(BOOL)createFolder
{
    NSString *folderPath = nil;

    // attempt to create the folder if necessary and user requests it
    Boolean createFlag = (createFolder ? kCreateFolder : kDontCreateFolder);
    FSRef folder;
    OSErr err = FSFindFolder(domain, folderType, createFlag, &folder);
    if (err == noErr)
    {
        CFURLRef url = WOMakeCollectable(CFURLCreateFromFSRef(kCFAllocatorDefault, &folder));
        if (url)
            folderPath = [NSString stringWithString:[(NSURL *)url path]];
    }
    return folderPath;
}

@end
