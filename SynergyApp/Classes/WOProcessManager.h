// WOProcessManager.h
// Synergy
//
// Copyright 2003-2009 Wincent Colaiuta. All rights reserved.

#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

#import "WODebug.h"

// simple wrapper class for Carbon Process Manager functions
@interface WOProcessManager : NSObject {

}

#pragma mark ProcessSerialNumber comparison

+ (BOOL)PSNEqualsNoProcess:(ProcessSerialNumber)PSN;

+ (BOOL)process:(ProcessSerialNumber)firstProcess
       isSameAs:(ProcessSerialNumber)secondProcess;

#pragma mark Detecting if a process is running

+ (BOOL)processRunningWithPSN:(ProcessSerialNumber)PSN;

+ (BOOL)processRunningWithSignature:(UInt32)signature;

#pragma mark Obtaining a ProcessSerialNumber for a process

+ (ProcessSerialNumber)PSNForSignature:(UInt32)signature;

@end