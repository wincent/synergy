//
//  NSAppleScript+WOAdditions.m
//  Synergy
//
//  Created by Wincent Colaiuta on 09/06/06.
//  Copyright 2006-2008 Wincent Colaiuta.

#import "NSAppleScript+WOAdditions.h"

@implementation NSAppleScript (WOAdditions)

- (NSAppleEventDescriptor *)executeWithParameters:(NSArray *)parameters error:(NSDictionary **)errorInfo
{
    NSParameterAssert(parameters != nil);
    NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass
                                                                             eventID:kAEOpen
                                                                    targetDescriptor:nil
                                                                            returnID:kAutoGenerateReturnID
                                                                       transactionID:kAnyTransactionID];
    NSAppleEventDescriptor *directObject = [NSAppleEventDescriptor listDescriptor];
    for (unsigned int i = 0, max = [parameters count]; i < max; i++)
    {
        id parameter = [parameters objectAtIndex:i];
        if ([parameter isKindOfClass:[NSAppleEventDescriptor class]])
            [directObject insertDescriptor:parameter atIndex:i];
        else if ([parameter isKindOfClass:[NSString class]])
            [directObject insertDescriptor:[NSAppleEventDescriptor descriptorWithString:parameter] atIndex:i];
        else if ([parameter respondsToSelector:@selector(intValue)])
            [directObject insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:[parameter intValue]] atIndex:i];
    }
    [event setDescriptor:directObject forKeyword:keyDirectObject];
    return [self executeAppleEvent:event error:errorInfo];
}

@end
