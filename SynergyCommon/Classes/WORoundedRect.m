//
//  WORoundedRect.m
//  RoundTransparentWindow
//
//  Created by Wincent Colaiuta on Tue Jan 14 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

#import "WORoundedRect.h"


@implementation NSBezierPath (WORoundedRect)

- (void)appendBezierPathWithRoundedRectangle:(NSRect)aRect
                                      radius:(float)radius
/*"
 NSBezierPath category based on p 432 example of "Cocoa Programming" by
 Anguish et al.
"*/
{
    NSPoint topMiddle = NSMakePoint(NSMidX(aRect), NSMaxY(aRect));
    NSPoint topLeft = NSMakePoint(NSMinX(aRect), NSMaxY(aRect));
    NSPoint topRight = NSMakePoint(NSMaxX(aRect), NSMaxY(aRect));
    NSPoint bottomRight = NSMakePoint(NSMaxX(aRect), NSMinY(aRect));

    [self moveToPoint:topMiddle];

    [self appendBezierPathWithArcFromPoint:topLeft
                                   toPoint:aRect.origin
                                    radius:radius];

    [self appendBezierPathWithArcFromPoint:aRect.origin
                                   toPoint:bottomRight
                                    radius:radius];

    [self appendBezierPathWithArcFromPoint:bottomRight
                                   toPoint:topRight
                                    radius:radius];

    [self appendBezierPathWithArcFromPoint:topRight
                                   toPoint:topLeft
                                    radius:radius];

    [self closePath];
}

@end
