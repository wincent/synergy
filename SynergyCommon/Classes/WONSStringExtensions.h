// WONSStringExtensions.h
// Synergy
//
// Copyright 2003-present Greg Hurrell. All rights reserved.

#import <Foundation/Foundation.h>

@interface NSString (WONSStringExtensions)

// these two come from the WinSwitch source (3.0 I think)
- (BOOL)pathIsOwnedByCurrentUser;
- (BOOL)pathIsWritableOnlyByCurrentUser;

@end
