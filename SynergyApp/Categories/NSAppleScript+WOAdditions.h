//
//  NSAppleScript+WOAdditions.h
//  Synergy
//
//  Created by Greg Hurrell on 9 June 2006.
//  Copyright 2006-present Greg Hurrell.

#import <Cocoa/Cocoa.h>

@interface NSAppleScript (WOAdditions)

/*! Convenience wrapper for executeAppleEvent:error:. */
- (NSAppleEventDescriptor *)executeWithParameters:(NSArray *)parameters error:(NSDictionary **)errorInfo;

@end
