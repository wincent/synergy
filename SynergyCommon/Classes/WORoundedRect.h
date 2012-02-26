//
//  WORoundedRect.h
//  RoundTransparentWindow
//
//  Created by Wincent Colaiuta on Tue Jan 14 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import <Cocoa/Cocoa.h>

@interface NSBezierPath (WORoundedRect)

- (void)appendBezierPathWithRoundedRectangle:(NSRect)aRect
                                      radius:(float)radius;

@end