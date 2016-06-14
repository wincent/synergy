//
//  WORoundedRect.h
//  RoundTransparentWindow
//
//  Created by Greg Hurrell on Tue Jan 14 2003.
//  Copyright 2003-present Greg Hurrell.

#import <Cocoa/Cocoa.h>

@interface NSBezierPath (WORoundedRect)

- (void)appendBezierPathWithRoundedRectangle:(NSRect)aRect
                                      radius:(float)radius;

@end
