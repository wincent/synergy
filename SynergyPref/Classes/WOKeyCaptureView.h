//
//  WOKeyCaptureView.h
//  Synergy
//
//  Created by Greg Hurrell on Wed Jan 01 2003.
//  Copyright 2003-present Greg Hurrell.

#import <AppKit/AppKit.h>

@interface WOKeyCaptureView : NSView {

    // current (most recently captured) key code
    unsigned short  keyCode;

    // current (most recently captured) modifiers
    unsigned int    modifierFlags;

    // current (most recently captured) key-press (unichar representation)
    unichar         representation;
    /*

     The trick here is that although this is stored internally as a unichar
     (unsigned short), the current implementation of the Synergy preferences
     code chooses to store the Unicode representation as a string in hex
     notation (eg. 0xf712 and similar).

     The code that deploys this custom view needs to do the conversions. For
     example:

     1. Reading from the prefs file yields a string in hex notation; convert
     that to an unsigned int before storing it here.

     2. Writing back to the prefs file will require the unsigned short here to
     be converted to a string containing the hex notation.

     This design decision was made because I wanted to put the more
     human-readable form in the prefs file (the hex); and I found that if I
     stored it inside <integer></integer> keys then it could read in a value
     in hex notation correctly, but it would always write it back in decimal
     notation. I therefore had to store it as a string to ensure it always
     appears in hex notation.

     */

    // displays the current key combination
    IBOutlet NSTextField *keyComboTextField;
}

// converts Cocoa modifier flags into Carbon format
+ (unsigned int)cocoaModifiersToCarbon:(unsigned int)cocoaModifiers;

// converts Carbon modifier flags to Cocoa format
+ (unsigned int)carbonModifiersToCocoa:(unsigned int)carbonModifiers;

// converts Cocoa modifier flags to a human-readable NSString
+ (NSString *)cocoaModifiersToHumanReadable:(unsigned int)cocoaModifiers;

// converts Carbon modifier flags to a human-readable NSString
+ (NSString *)carbonModifiersToHumanReadable:(unsigned int)carbonModifiers;

// returns human-readable string for unicode unichar
+ (NSString *)stringForUnicode:(unsigned short)theUnicode;

// returns human-readable, localised string version of current key combo
- (NSString *)keyComboString;

// accessor methods:
- (unsigned short)keyCode;
- (void)setKeyCode:(unsigned short)newKeyCode;

- (unsigned int)modifierFlags;
- (void)setModifierFlags:(unsigned int)newModifierFlags;

- (unichar)representation;
- (void)setRepresentation:(unichar)newRepresentation;

@end
