//
//  WONSFileManagerExtensions.h
//  Synergy
//
//  Created by Wincent Colaiuta on 25 March 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import <Foundation/Foundation.h>

@interface NSFileManager (WONSFileManagerExtensions)

- (NSString *)findSystemFolderType:(int)folderType forDomain:(int)domain creating:(BOOL)createFolder;

@end