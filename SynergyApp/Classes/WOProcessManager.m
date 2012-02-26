// WOProcessManager.m
// Synergy
//
// Copyright 2003-2009 Wincent Colaiuta. All rights reserved.

#import "WOProcessManager.h"

// Simple wrapper class for Carbon Process Manager functions.
@implementation WOProcessManager

// used for comparisons with "NoProcess" value
static ProcessSerialNumber noProcess;

+ (void)initialize
{
    // set up "noProcess" constant
    noProcess.highLongOfPSN = 0;
    noProcess.lowLongOfPSN = kNoProcess;
}

+ (BOOL)PSNEqualsNoProcess:(ProcessSerialNumber)PSN
{
    return [[self class] process:PSN isSameAs:noProcess];
}

// Compare two Process Serial Numbers (PSNs) to see if they refer to the
// same process. Returns YES on match, and NO otherwise.
+ (BOOL)process:(ProcessSerialNumber)firstProcess
       isSameAs:(ProcessSerialNumber)secondProcess
{
    Boolean result;
    if ((SameProcess(&firstProcess, &secondProcess, &result)) == noErr)
        // comparison successfully performed
        return !!result;

    // we only get this far if an error occurs
    ELOG(@"Error comparing Process Serial Numbers.");
    return NO;
}

// Returns yes if a process is running matching the submitted Process Serial
// Number (PSN). Does this by scanning the list of running processes for a
// match.
+ (BOOL)processRunningWithPSN:(ProcessSerialNumber)PSN
{
    // begin with "noProcess" -- the start of the list
    ProcessSerialNumber process = noProcess;
    while ((GetNextProcess(&process)) == noErr)
    {
        // is this the process we're looking for?
        if ([[self class] process:PSN isSameAs:process])
            // found a match -- process is running
            return YES;
    }

    // did not find process in list of running processes
    return NO;
}

+ (BOOL)processRunningWithSignature:(UInt32)signature
{
    // begin with "noProcess" -- the start of the list
    ProcessSerialNumber process = noProcess;

    // storage for process information
    ProcessInfoRec processInfo;

    // initialise processInfo
    processInfo.processInfoLength = sizeof(ProcessInfoRec);
    processInfo.processName = NULL;
    processInfo.processAppSpec = NULL;

    // we will scan for processes with of type "APPL" (application)
    static OSType applicationType = 'APPL';

    while ((GetNextProcess(&process)) == noErr)
    {
        if ((GetProcessInformation(&process, &processInfo)) == noErr)
        {
            // is this the process we're looking for?
            if ((processInfo.processType == applicationType) &&
                (processInfo.processSignature == signature))
                // found a match -- process is running
                return YES;
        }
        else
            ELOG(@"Error obtaining process information");
    }

    // did not find process in list of running processes
    return NO;
}

+ (ProcessSerialNumber)PSNForSignature:(UInt32)signature
{
    // begin with "noProcess" -- the start of the list
    ProcessSerialNumber process = noProcess;

    // storage for process information
    ProcessInfoRec processInfo;

    // initialise processInfo
    processInfo.processInfoLength = sizeof(ProcessInfoRec);
    processInfo.processName = NULL;
    processInfo.processAppSpec = NULL;

    // we will scan for processes with of type "APPL" (application)
    static OSType applicationType = 'APPL';

    while ((GetNextProcess(&process)) == noErr)
    {
        if ((GetProcessInformation(&process, &processInfo)) == noErr)
        {
            // is this the process we're looking for?
            if ((processInfo.processType == applicationType) &&
                (processInfo.processSignature == signature))
                // found a match -- process is running -- return the PSN
                return processInfo.processNumber;
        }
        else
            ELOG(@"Error obtaining process information");
    }

    // did not find process in list of running processes
    return noProcess;
}

@end
