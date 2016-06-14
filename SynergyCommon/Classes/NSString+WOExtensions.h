//
//  NSString+WOExtensions.h
//  Synergy
//
//  Created by Greg Hurrell on Wed Apr 09 2003.
//  Copyright 2003-present Greg Hurrell.

#import <Foundation/Foundation.h>

@interface NSString (WOExtensions)

// scan a string for material between startTag and endTag
- (NSString *)stringBetweenStartTag:(NSString *)startTag endTag:(NSString *)endTag;

// scan a string for material, removing said material
- (NSString *)stringByRemoving:(NSString *)removeString;

- (NSString *)stringByResolvingAliasesInPath;

@end
