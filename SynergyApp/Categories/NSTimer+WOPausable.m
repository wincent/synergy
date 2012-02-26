// NSTimer+WOPausable.m
// Synergy
//
// Copyright 2006-2009 Wincent Colaiuta. All rights reserved.

// TODO: move this to WOPublic

// category header
#import "NSTimer+WOPausable.h"

// WOPublic headers
#import "WOPublic/WODebugMacros.h"

// hideous hack required because Apple makes it difficult or impossible to usefully subclass NSTimer
static NSMapTable           *WOPauseableTimerIVarOldFireDate    = NULL;
static NSMapTable           *WOPauseableTimerIVarPauseDate      = NULL;
static NSMapTable           *WOPauseableTimerIVarPauseStack     = NULL;

@implementation NSTimer (WOPausable)

#pragma mark -
#pragma mark NSObject overrides

+ (void)load
{
    static volatile BOOL initializationComplete  = NO;
    @synchronized([NSTimer class])
    {
        if (!initializationComplete)
        {
            WOPauseableTimerIVarOldFireDate = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 0);
            WOPauseableTimerIVarPauseDate   = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 0);
            WOPauseableTimerIVarPauseStack  = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks, NSIntegerMapValueCallBacks, 0);
            initializationComplete = YES;
        }
    }
}

#pragma mark -
#pragma mark Custom methods

- (void)pause
{
    // this is slow because NSMapInsert is not threadsafe, requiring class-wide synchronization
    // (a proper NSTimer subclass with instance variables wouldn't need locks)
    // although clearly, callers would be unwise to manipulate an NSTimer from multiple threads in any case
    if ([self isValid])
    {
        @synchronized (WOPauseableTimerIVarPauseStack)
        {
            int pauseStack = (int)NSMapGet(WOPauseableTimerIVarPauseStack, self) + 1;
            NSMapInsert(WOPauseableTimerIVarPauseStack, self, (void *)pauseStack);
            if (pauseStack == 1)
            {
                NSMapInsert(WOPauseableTimerIVarOldFireDate, self, [self fireDate]);
                [self setFireDate:[NSDate distantFuture]];
                NSMapInsert(WOPauseableTimerIVarPauseDate, self, [NSDate date]);
            }
        }
    }
}

- (void)resume
{
    if ([self isValid])
    {
        @synchronized (WOPauseableTimerIVarPauseStack)
        {
            int pauseStack = (int)NSMapGet(WOPauseableTimerIVarPauseStack, self) - 1;
            WOAssert(pauseStack >= 0);
            NSMapInsert(WOPauseableTimerIVarPauseStack, self, (void *)pauseStack);
            if (pauseStack == 0)
            {
                NSDate *pauseDate   = NSMapGet(WOPauseableTimerIVarPauseDate, self);
                NSDate *oldFireDate = NSMapGet(WOPauseableTimerIVarOldFireDate, self);
                [self setFireDate:[oldFireDate dateByAddingTimeInterval:-[pauseDate timeIntervalSinceNow]]];
                NSMapRemove(WOPauseableTimerIVarOldFireDate, self);
                NSMapRemove(WOPauseableTimerIVarPauseDate, self);
                NSMapRemove(WOPauseableTimerIVarPauseStack, self);
            }
        }
    }
}

- (BOOL)isPaused
{
    if ([self isValid])
    {
        @synchronized (WOPauseableTimerIVarPauseStack)
        {
             if ((int)NSMapGet(WOPauseableTimerIVarPauseStack, self) > 0)
                 return YES;
        }
    }
    return NO;
}

- (void)cancel
{
    if ([self isValid])
        [self invalidate];

    @synchronized (WOPauseableTimerIVarPauseStack)
    {
        NSMapRemove(WOPauseableTimerIVarOldFireDate, self);
        NSMapRemove(WOPauseableTimerIVarPauseDate, self);
        NSMapRemove(WOPauseableTimerIVarPauseStack, self);
    }
}

@end
