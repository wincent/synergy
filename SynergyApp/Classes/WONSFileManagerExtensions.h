//
//  WONSFileManagerExtensions.h
//  Synergy
//
//  Created by Greg Hurrell on 25 March 2003.
//  Copyright 2003-present Greg Hurrell.

#import <Foundation/Foundation.h>

@interface NSFileManager (WONSFileManagerExtensions)

- (NSString *)findSystemFolderType:(int)folderType forDomain:(int)domain creating:(BOOL)createFolder;

@end
