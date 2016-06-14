//
//  WOCommon.h
//  Synergy
//
//  Created by Greg Hurrell on Tue Jan 07 2003.
//  Copyright 2003-present Greg Hurrell.

/*

 Global header file for macros etc

 */

// CURRENT_METHOD = within an Objective-C method, return an NSString containing
//                  the current method name
#define CURRENT_METHOD \
        [NSString stringWithString:NSStringFromSelector(_cmd)]

