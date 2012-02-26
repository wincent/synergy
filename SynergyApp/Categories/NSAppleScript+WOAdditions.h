//
//  NSAppleScript+WOAdditions.h
//  Synergy
//
//  Created by Wincent Colaiuta on 9 June 2006.
//  Copyright 2006-2008 Wincent Colaiuta.

#import <Cocoa/Cocoa.h>

@interface NSAppleScript (WOAdditions)

/*! Convenience wrapper for executeAppleEvent:error:. */
- (NSAppleEventDescriptor *)executeWithParameters:(NSArray *)parameters error:(NSDictionary **)errorInfo;

@end
