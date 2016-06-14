//
//  WOKeyCaptureView.m
//  Synergy
//
//  Created by Greg Hurrell on Wed Jan 01 2003.
//  Copyright 2003-present Greg Hurrell.

#import <Carbon/Carbon.h>

#import "WOKeyCaptureView.h"
#import "WODebug.h"
#import "WOCommon.h"

#pragma mark -
#pragma mark Global variables (not garbage collected)

static NSMutableDictionary *_unicodes;

@interface WOKeyCaptureView (_private)

+ (NSDictionary *)_unicodes;
- (void)capture:(NSEvent *)theEvent;

@end

@implementation WOKeyCaptureView
/*"
 WOKeyCaptureView is an NSView subclass designed to capture and record key-press
 events. It is specifically intended to capture "hot-keys" or "key combinations"
 such as Command+Shift+F10, Control-A, Option-Shift-X, and so forth. It provides
 accessor methods for setting and accessing the "current" key combination, in
 addition to automatically updating the stored combination whenever it has
 first responder status and its parent window is key.

 When I reimpliment this for WOBase, make it a lower level subclass, like NSTextField, or even NSTextFieldCell. I want it to be useable from inside NSTextFields, or within NSTableViews. perhaps will need to do provide both? NSTextField does use NSTextFieldCell, and NSTextColumn uses it too.
"*/
- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        [self setKeyCode:0];
        [self setModifierFlags:0];
        [self setRepresentation:0];

        // NSTextField should already be in view (done with Interface Builder)
    }
    return self;
}

- (void)drawRect:(NSRect)rect
{
    // Update the NSTextField to show the "current key combo"

    // compute human-readable string of current key combo and put it in text
    // field
    [keyComboTextField setStringValue:[self keyComboString]];
}

- (NSString *)keyComboString
{
    // build up an NSString containing the new contents for the field
    NSString        *fieldString    = @"";
    unsigned short  code            = [self keyCode];
    unsigned int    flags           = [self modifierFlags];

    // if modifier is 0, there is no current hot key
    if (flags == 0)
    {
        fieldString = NSLocalizedStringFromTableInBundle
        (@"(none)", @"", [NSBundle bundleForClass:[self class]],
         @"No hot-key set");

        // disable text field to make it clear that there's no key combo
        [keyComboTextField setEnabled:NO];
    }
    else
    {
        // key code is non-zero, non-nil: proceed, starting with modifier string
        NSString *modifierString =
            [[self class] carbonModifiersToHumanReadable:flags];

        // now build rest of string
        NSString *keyString = @"";

        // if representation is 0, we have no unicode representation for
        // string, so output raw keyCode (should never happen if we are called
        // correctly and both are values are stored)
        if ([self representation] == 0)
            keyString = [NSString stringWithFormat:@"(%d)", code];
        else
            keyString = [[self class] stringForUnicode:[self representation]];

        // glue together modifier string + "the rest"
        fieldString = [modifierString stringByAppendingString:keyString];

        // enable text field to make it clear that there IS a key combo
        [keyComboTextField setEnabled:YES];

    }

    return fieldString;
}

- (BOOL)acceptsFirstResponder
/*"
 Override for the acceptsFirstResponder method of NSResponder.
"*/
{
    return YES;
}

- (BOOL)resignFirstResponder
/*"
 Override for the resignFirstResponder method of NSView which always returns NO.
 This class is a %capture view for keypresses, and so it must always try to
 keep first responder status.
"*/
{
    // we only want to resign first responder status if it's due to a mouse click
    return NO; // effectively, this means always return NO
}

- (BOOL)isFirstResponder
{
    if (![[self window] isKeyWindow])
        return NO;

    return ([[self window] firstResponder] == self);
}

- (void)capture:(NSEvent *)theEvent
{
    // ignore lower 16 bits (device-dependent)
    unsigned int flags = [theEvent modifierFlags] & 0xffff0000;

    // convert Cocoa modifiers to Carbon format
    unsigned int carbonFlags = [[self class] cocoaModifiersToCarbon:flags];

    if (carbonFlags == 0)
        // in the present version, we insist on there being at least one modifier
        return; // exit without storing any modifier or keycode data

    // store the updated modifier flags (in Carbon format)
    [self setModifierFlags:carbonFlags];

    // store the updated keycode...
    [self setKeyCode:[theEvent keyCode]];

    // store the updated unicode representation...
    [self setRepresentation:
        [[theEvent charactersIgnoringModifiers] characterAtIndex:0]];

    // we need to update to reflect the new keysetting in the UI
    [self setNeedsDisplay:YES];
}

- (void)keyDown:(NSEvent *)theEvent
{
    [self capture:theEvent];
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
    [self capture:theEvent];

    // prevent the key equivalent from travelling down the view hierarchy
    return YES;
}

// converts Cocoa modifier flags into Carbon format
+ (unsigned int)cocoaModifiersToCarbon:(unsigned int)cocoaModifiers
{
    static unsigned int cocoaToCarbon[5][2] =
    {
    { NSCommandKeyMask,     cmdKey },
    { NSAlternateKeyMask,   optionKey },
    { NSControlKeyMask,     controlKey },
    { NSShiftKeyMask,       shiftKey },
    { NSFunctionKeyMask,    kEventKeyModifierFnMask}
    //{ NSFunctionKeyMask,  NSFunctionKeyMask} // the Cocoa mask works in Carbon!
    };

    unsigned int carbonModifiers = 0;
    int i;

    for (i = 0; i < 5; i++)
        if (cocoaModifiers & cocoaToCarbon[i][0])
            carbonModifiers += cocoaToCarbon[i][1];

    return carbonModifiers;
}

// converts Carbon modifier flags to Cocoa format
+ (unsigned int)carbonModifiersToCocoa:(unsigned int)carbonModifiers
{
    // this method is exactly like the cocoaToCarbonModifiers method, except
    // the direction of the comparison/substitution is reversed

    static unsigned int carbonToCocoa[5][2] = {
    { NSCommandKeyMask, 	cmdKey },
    { NSAlternateKeyMask, 	optionKey },
    { NSControlKeyMask, 	controlKey },
    { NSShiftKeyMask, 		shiftKey },
    { NSFunctionKeyMask,	kEventKeyModifierFnMask}};

    unsigned int cocoaModifiers = 0;
    int i;

    for (i = 0; i < 4; i++)
        if (carbonModifiers & carbonToCocoa[i][1])
            cocoaModifiers += carbonToCocoa[i][0];

    return cocoaModifiers;
}

// converts Cocoa modifier flags to a human-readable NSString
+ (NSString *)cocoaModifiersToHumanReadable:(unsigned int)cocoaModifiers
{
    // for converting between Cocoa modifier flags and their Unicode
    // representations:
#ifdef __BIG_ENDIAN__ /* ppc */
    static long modifiersToChar[4][2] = {
    { NSCommandKeyMask, 	0x23180000 },
    { NSAlternateKeyMask,	0x23250000 },
    { NSControlKeyMask,		0x005E0000 },
    { NSShiftKeyMask,		0x21e70000 }
    /* no character displayed for function key mask */};
#else /* little endian (i386) */
    static long modifiersToChar[4][2] = {
    { NSCommandKeyMask, 	0x00002318 },
    { NSAlternateKeyMask,	0x00002325 },
    { NSControlKeyMask,		0x0000005E },
    { NSShiftKeyMask,		0x000021e7 }
        /* no character displayed for function key mask */};
#endif

    NSMutableString* humanReadable = [NSMutableString string];
    int i;

    for(i = 0; i < 4; i++)
    {
        if(cocoaModifiers & modifiersToChar[i][0])
        {
            [humanReadable appendString:
                [NSString stringWithCharacters:
                    (const unichar*)&modifiersToChar[i][1]
                                        length:1]];
        }
    }
    return humanReadable;
}

// converts Carbon modifier flags to a human-readable NSString
+ (NSString *)carbonModifiersToHumanReadable:(unsigned int)carbonModifiers
{
    // convert Carbon flags to Cocoa format first
   unsigned int cocoaModifiers = [[self class] carbonModifiersToCocoa:
       carbonModifiers];

    // then into human-readable
    return [[self class] cocoaModifiersToHumanReadable:cocoaModifiers];
}

// returns human-readable string for unicode unichar
+ (NSString *)stringForUnicode:(unsigned short)theUnicode
{
    /*

     There is an interesting problem here with hardware dependence. We must
     store the raw keycode (which is hardware dependent) because this is what
     we must later use with Carbon in order to register hotkeys.

     But because of the hardware dependence, we cannot know whether the 0x0065
     keycode that meant F9 on one machine, will correspond to F9 on other
     hardware. So we store the unicode representation as well -- 0xf70c in this
     example -- which is guaranteed to remain constant on all machines.

     It is then easy for us to translate between the unicode representation and
     a human-readable string like "F9". So we keep the raw keycode for passing
     to Carbon, and the unicode representation for displaying the setting to the
     user.

     The hardware-dependence issue makes it impossible to derive one from the
     other, so both must be stored in the user preferences file.

     The dictionary used in this conversion is stored as a plist file on the
     disk, thus permitting easy localisation of the key names.

     */

    // convert theUnicode into a string (for use as a dictionary key)
    NSString *dictionaryKey = [NSString stringWithFormat:@"0x%04x", theUnicode];

    // in dictionary, look up descriptive string for key code
    NSString *objectForUnicode;

     if ((objectForUnicode = [[self _unicodes] objectForKey:dictionaryKey]))
        // return entry from dictionary, if it exists
         return objectForUnicode;
    else
        // if it does not exist, return the unicode char itself as an NSString
        // (which will produce straightforward output for most characters eg.
        // a, b, c, d, e, f etc but might not produce a meaninful display for
        // special keys eg. function keys)
        return [NSString stringWithFormat:@"%C", theUnicode];
}

// private method returns the dictionary containing unicode/string pairs read
// from disk
+ (NSDictionary *)_unicodes
{
    // if this is the first time called, initialise the dictionary from the disk
    if (_unicodes == nil)
    {
        // set up unicodes dictionary from unicodes.plist file (permits
        // localisation)
        NSString *pathToUnicodes = [[NSBundle bundleForClass:[self class]] pathForResource:@"Unicodes" ofType:@"plist"];
        _unicodes = [[NSMutableDictionary alloc] initWithContentsOfFile:pathToUnicodes];
    }

    return _unicodes;
}

// accessor methods:
- (unsigned short)keyCode
{
    return keyCode;
}

- (void)setKeyCode:(unsigned short)newKeyCode
{
    keyCode = newKeyCode;
}

- (unsigned int)modifierFlags
{
    return modifierFlags;
}

- (void)setModifierFlags:(unsigned int)newModifierFlags
{
    modifierFlags = newModifierFlags;
}

- (unichar)representation
{
    // return unichar representation (really an unsigned short)
    return representation;
}

- (void)setRepresentation:(unichar)newRepresentation
{
    // store unichar representation (really an unsigned short)
    representation = newRepresentation;
}

@end
