//
//  NSImage+WOAdditions.m
//  Synergy
//
//  Created by Greg Hurrell on 09/06/06.
//  Copyright 2006-present Greg Hurrell.

#import "NSImage+WOAdditions.h"

#import <QuickTime/QuickTime.h>

@implementation NSImage (WOAdditions)

- (NSData *)PICTRepresentation
{
    // try shortcut first
    NSEnumerator    *enumerator = [[self representations] objectEnumerator];
    id              rep         = nil;
    while ((rep = [enumerator nextObject]))
    {
        if ([rep respondsToSelector:@selector(PICTRepresentation)])
            return [rep PICTRepresentation];
    }

    // try using QuickTime to perform the conversion
    MovieImportComponent importer = OpenDefaultComponent(GraphicsImporterComponentType, kQTFileTypeTIFF);
    if (!importer) return nil;

    Handle      source      = NULL;
    PicHandle   destination = NULL;
    NSData      *PICTData   = nil;
    NSData      *TIFFData   = [self TIFFRepresentation];
    if (TIFFData)
    {
        if (PtrToHand([TIFFData bytes], &source, (long)[TIFFData length]) == noErr)   // allocates the memory and copies the data
        {
            // docs: "you must not dispose this handle until the graphics importer has been closed"
            if (GraphicsImportSetDataHandle(importer, source) == noErr)
            {
                    if (GraphicsImportGetAsPicture(importer, &destination) == noErr)
                    {
                        PICTData = [NSData dataWithBytes:*destination length:(unsigned)GetHandleSize((Handle)destination)];
                        DisposeHandle((Handle)destination);
                    }
            }
        }
    }
    CloseComponent(importer);
    if (source)
        DisposeHandle(source);

    return PICTData;
}

@end
