// WOSynergyFloaterWindow.m
// Copyright 2003-2011 Wincent Colaiuta. All rights reserved.

#import "WOSynergyFloaterView.h"

#import "WOSynergyGlobal.h"

// Cocoa reports that text is higher than it really is
#define WO_COCOA_TEXT_BUG_FACTOR  (1.15)

@implementation WOSynergyFloaterView

NSSize originalSynergyImageSize;

- (id)initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect]))
    {
        // this one should work from the app and from the prefPane
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];

        synergyImage = [[NSImage alloc] initByReferencingFile:
            [bundle pathForResource:@"SynergyLarge" ofType:@"png"]];

        noCoverArtImage = [[NSImage alloc] initByReferencingFile:
            [bundle pathForResource:@"NoCoverArt" ofType:@"png"]];

        albumImage = nil;

        // initialise this global for later use when drawing the icon (helps us
        // decide whether we need to resize or not)
        originalSynergyImageSize = [synergyImage size];

        // this needs to be set to YES or our icon will get cropped rather than shrink
        [synergyImage setScalesWhenResized:YES];
        [noCoverArtImage setScalesWhenResized:YES];

        // set reasonable default values:
        bgAlpha         = DEFAULT_ALPHA_FOR_FLOATER_WINDOW;
        cornerRadius    = DEFAULT_CORNER_RADIUS;
        insetSpacer     = DEFAULT_INSET_FROM_BOTTOM_LEFT;
        floaterIconType = WOFloaterIconSynergyIcon;

        fgColor = [NSColor colorWithDeviceWhite:WO_WHITE_FG alpha:1.0];
        bgColor = [NSColor colorWithDeviceWhite:WO_BLACK_BG alpha:WO_WHITE_ON_BLACK_BG_ALPHA];

        // by default, don't draw the text
        [self setDrawText:NO];

        // by default, behave as though we're registered (don't draw reminder)
        registrationStatus = YES;

        // by default, don't draw star ratings...
        [self setCurrentRating:WONoStarRatingDisplay];

        // and pre-set opaque white as default text colour
        textColor = [NSColor colorWithDeviceWhite:1.0 alpha:1.0];

        // prepare other instance variables
        trackName = [NSMutableString string];
        artistName = [NSMutableString string];
        composerName = [NSMutableString string];
        albumName = [NSMutableString string];

        // defaults for testing purposes:
        [trackName setString:@""];
        [artistName setString:@""];
        [albumName setString:@""];
    }
    return self;
}


- (void)awakeFromNib
{
    //tell ourselves that we need displaying
    [self setNeedsDisplay:YES];
}

// allows drag on first click, even if we are not the key window
- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
    return YES;
}

- (void)clearView
{
    //erase whatever graphics were in view before with clear
    [[NSColor clearColor] set];
    NSRectFill([self frame]);
}

- (void)drawBackground
    /*"
    Fills in background with rounded corners, using appropriate alpha value and
     arc radius on the corners.
     "*/
{
    NSBezierPath *rectangle = [NSBezierPath bezierPath];
    NSRect bounds = [self bounds];

    // black transparent bg
    [[NSColor colorWithDeviceWhite:0.0 alpha:bgAlpha] set];

    [rectangle appendBezierPathWithRoundedRectangle:bounds
                                             radius:cornerRadius];

    [rectangle fill];
}

- (void)drawIcon
{
    // now stick Synergy icon in the view
    NSPoint synergyIconPoint;

    // icon/image should already be at correct size by this point....

    // display album image if we have it and are supposed to display it
    if (albumImage && (floaterIconType == WOFloaterIconAlbumCover))
    {

        // handle non-square album images: they should be centred and not bottom/left aligned
        NSSize currentAlbumSize = [albumImage size];

        if (currentAlbumSize.width > currentAlbumSize.height)
        {
            synergyIconPoint.x = floor(cornerRadius);
            synergyIconPoint.y = floor(cornerRadius + (currentAlbumSize.width - currentAlbumSize.height) / 2);
        }
        else if (currentAlbumSize.height > currentAlbumSize.width)
        {
            synergyIconPoint.x = floor(cornerRadius + (currentAlbumSize.height - currentAlbumSize.width) / 2);
            synergyIconPoint.y = floor(cornerRadius);
        }
        else // a square cover
        {
            synergyIconPoint.x = floor(cornerRadius);  // inset it from bottomLeft corner
            synergyIconPoint.y = floor(cornerRadius);  // by radius
        }

        [albumImage dissolveToPoint:synergyIconPoint
                           fraction:WO_ICON_ALPHA];
    }
    // display icon if we are supposed to
    else if (floaterIconType == WOFloaterIconSynergyIcon)
    {
        NSSize iconSize = [synergyImage size];
        NSSize viewSize = [self bounds].size;

        synergyIconPoint.x =
            floor((viewSize.height / 2.0) - (iconSize.height / 2.0));
        synergyIconPoint.y = synergyIconPoint.x;

        [synergyImage dissolveToPoint:synergyIconPoint
                             fraction:WO_ICON_ALPHA];
    }
    // or if we are supposed to display album but don't have one
    else if (!albumImage && (floaterIconType == WOFloaterIconAlbumCover))
    {
        NSSize iconSize = [noCoverArtImage size];
        NSSize viewSize = [self bounds].size;

        synergyIconPoint.x =
            floor((viewSize.height / 2.0) - (iconSize.height / 2.0));
        synergyIconPoint.y = synergyIconPoint.x;

        [noCoverArtImage dissolveToPoint:synergyIconPoint
                                fraction:WO_ICON_ALPHA];
    }
    else
    {
        // don't actually draw anything
    }
}

// this version of the resizeIcon method takes into account the height of the
// text in the floater
- (void)resizeIconWithTextHeight:(float)textHeight
{
    if (albumImage)
    {
        NSSize currentAlbumSize = [albumImage size];

        // desired height/width is related to corner radius
        // by the time this routine is called, [self bounds].size should already
        // return the correct size
        float desiredHeightWidth =
            floor([self bounds].size.height - (cornerRadius * 2));

        NSSize desiredSize;

        // handle non-square album art: longest side will be desiredHeightWidth
        if (currentAlbumSize.width > currentAlbumSize.height)
        {
            desiredSize = NSMakeSize(desiredHeightWidth,
                                     (currentAlbumSize.height / currentAlbumSize.width) * desiredHeightWidth);
        }
        else if (currentAlbumSize.height > currentAlbumSize.width)
        {
            desiredSize = NSMakeSize((currentAlbumSize.width / currentAlbumSize.height) * desiredHeightWidth,
                                     desiredHeightWidth);
        }
        else // the art is square
        {
            desiredSize = NSMakeSize(desiredHeightWidth, desiredHeightWidth);
        }

        // only resize if not at correct size
        if (!NSEqualSizes(currentAlbumSize, desiredSize))
            [albumImage setSize:desiredSize];
    }
    else
    {
        // if no image exists, the previously existing code will be fine
        [self resizeIcon];
    }
}

- (void)resizeIcon
{
    // check if icon needs to be resized and resize it if necessary

    // different rules for albums as opposed to icons

    // with albums we scale all the way up to 128 pixels
    if (albumImage && (floaterIconType == WOFloaterIconAlbumCover))
    {
        NSSize currentAlbumSize = [albumImage size];

        // desired height/width is related to corner radius
        // by the time this routine is called, [self bounds].size should already
        // return the correct size

        float desiredHeightWidth;

        if (cornerRadius <= 8.0)
        {
            desiredHeightWidth = 16.0;
        }
        else
        {
            desiredHeightWidth =
            floor([self bounds].size.height - (cornerRadius * 2));
        }

        NSSize desiredSize;

        // handle non-square album art: longest side will be desiredHeightWidth
        if (currentAlbumSize.width > currentAlbumSize.height)
        {
            desiredSize = NSMakeSize(desiredHeightWidth,
                                     (currentAlbumSize.height / currentAlbumSize.width) * desiredHeightWidth);
        }
        else if (currentAlbumSize.height > currentAlbumSize.width)
        {
            desiredSize = NSMakeSize((currentAlbumSize.width / currentAlbumSize.height) * desiredHeightWidth,
                                     desiredHeightWidth);
        }
        else // the art is square
        {
            desiredSize = NSMakeSize(desiredHeightWidth, desiredHeightWidth);
        }

        // only resize if not at correct size
        if (!NSEqualSizes(currentAlbumSize, desiredSize))
            [albumImage setSize:desiredSize];

    }
    else if (!albumImage && (floaterIconType == WOFloaterIconAlbumCover))
    {
        NSSize synergyImageSize = [noCoverArtImage size];

        if (cornerRadius > 16)
        {
            // draw at maximum size...
            if (NSEqualSizes(synergyImageSize, originalSynergyImageSize) == NO)
            {
                //image is not at maximum size... resize it...
                [noCoverArtImage setSize:originalSynergyImageSize];
            }
        }
        else if (cornerRadius <= 8.0)
        {
            // special case for minimum cornerRadius size -- this is the floater
            // "mini-mode"
            NSSize newSynergyImageSize;

            newSynergyImageSize = NSMakeSize(16.0, 16.0);

            if (NSEqualSizes(synergyImageSize, newSynergyImageSize) == NO)
            {
                // only resize if there's been a change since last time...
                [noCoverArtImage setSize:newSynergyImageSize];
            }
        }
        else
        {
            // draw at a scaled size
            // at min cornerRadius (8), the icon is half its original size
            // at default cornerRadius (16), the icon is at original size
            NSSize newSynergyImageSize;
            newSynergyImageSize.width = floor(originalSynergyImageSize.width * (cornerRadius / 16));
            newSynergyImageSize.height = floor(originalSynergyImageSize.height * (cornerRadius / 16));

            if (NSEqualSizes(synergyImageSize, newSynergyImageSize) == NO)
            {
                // only resize if there's been a change since last time...
                [noCoverArtImage setSize:newSynergyImageSize];
            }
        }
    }
    // with icons we never scale beyond the original icon size (48.0 x 48.0)
    else
    {
        NSSize synergyImageSize = [synergyImage size];

        if (cornerRadius > 16)
        {
            // draw at maximum size...
            if (NSEqualSizes(synergyImageSize, originalSynergyImageSize) == NO)
            {
                //image is not at maximum size... resize it...
                [synergyImage setSize:originalSynergyImageSize];
            }
        }
        else if (cornerRadius <= 8.0)
        {
            // special case for minimum cornerRadius size -- this is the floater
            // "mini-mode"
            NSSize newSynergyImageSize;

            newSynergyImageSize = NSMakeSize(16.0, 16.0);

            if (NSEqualSizes(synergyImageSize, newSynergyImageSize) == NO)
            {
                // only resize if there's been a change since last time...
                [synergyImage setSize:newSynergyImageSize];
            }
        }
        else
        {
            // draw at a scaled size
            // at min cornerRadius (8), the icon is half its original size
            // at default cornerRadius (16), the icon is at original size
            NSSize newSynergyImageSize;
            newSynergyImageSize.width = floor(originalSynergyImageSize.width * (cornerRadius / 16));
            newSynergyImageSize.height = floor(originalSynergyImageSize.height * (cornerRadius / 16));

            if (NSEqualSizes(synergyImageSize, newSynergyImageSize) == NO)
            {
                // only resize if there's been a change since last time...
                [synergyImage setSize:newSynergyImageSize];
            }
        }
    }
}

// this seems to work if called from drawRect
// but not if called from elsewhere (eg. from controller) even if followed by a refresh
- (void)drawTextAndSeparator
{
    // special case: floater is in "mini-mode"
    if (cornerRadius <= 8.0)
    {
        [self drawTextForMiniFloater];
        return;
    }
    // otherwise proceed as normal

    // use this later in determining position of text
    //NSSize synergyImageSize = [synergyImage size];

    // now draw some text - this makes some assumptions about the size of the
    // text and the image
    // eg. if the image is too small, then text could flow off bottom of view
    // will need to add star rating to floater...

    float baseSize = floor(cornerRadius - (cornerRadius / 2.0) + 8.0);

    // set up text and attributes (track name) -- tied to cornerRadius
    NSFont *bigSystemFont = [NSFont systemFontOfSize:floor(baseSize)];

    NSMutableDictionary *bigAttributes = [NSMutableDictionary dictionary];
    [bigAttributes setObject:bigSystemFont forKey:NSFontAttributeName];
    [bigAttributes setObject:textColor forKey:NSForegroundColorAttributeName];
    NSMutableDictionary *mediumAttributes = [NSMutableDictionary dictionaryWithDictionary:bigAttributes];
    NSMutableDictionary *smallAttributes = [NSMutableDictionary dictionaryWithDictionary:bigAttributes];


    // specify where text will be drawn
    NSRect titleTextBounds = NSZeroRect;
    titleTextBounds.size = [trackName sizeWithAttributes:bigAttributes];

    titleTextBounds.origin.y = floor(cornerRadius + (baseSize * 5 * WO_COCOA_TEXT_BUG_FACTOR) - 5);

    // draw album name if available (set string with space if not @" ")

    NSFont *mediumSystemFont = [NSFont systemFontOfSize:floor(baseSize - 2.0)];

    [mediumAttributes setObject:mediumSystemFont
                   forKey:NSFontAttributeName];

    NSRect albumTextBounds = NSZeroRect;
    albumTextBounds.size = [albumName sizeWithAttributes:mediumAttributes];
    albumTextBounds.origin.y = floor((titleTextBounds.origin.y - ((albumTextBounds.size.height + baseSize) * WO_COCOA_TEXT_BUG_FACTOR)) * WO_COCOA_TEXT_BUG_FACTOR);

    // draw artist name if available (set string with space if not @" ")
    // this one in a smaller font and inset to the right
    NSFont *smallSystemFont = [NSFont systemFontOfSize:floor(baseSize - 4.0)];

    [smallAttributes setObject:smallSystemFont
                   forKey:NSFontAttributeName];

    NSRect artistTextBounds = NSZeroRect;

    NSString *tempArtistName;
    if ([composerName isEqual:@""] || [composerName isEqual:@" "])
        tempArtistName = artistName;
    else if ([artistName isEqual:@""] || [artistName isEqual:@" "])
        tempArtistName = composerName;
    else
        tempArtistName = [NSString stringWithFormat:@"%@ (%@)", artistName, composerName];

    artistTextBounds.size = [tempArtistName sizeWithAttributes:smallAttributes];
    artistTextBounds.origin.y = floor((albumTextBounds.origin.y - ((artistTextBounds.size.height + (baseSize * 0.5)) * WO_COCOA_TEXT_BUG_FACTOR)) * WO_COCOA_TEXT_BUG_FACTOR);

    // draw the rating stars if appropriate
    if ([self currentRating] != WONoStarRatingDisplay)
    {
        [self drawRatingStars];
    }

    // total height
    float totalHeight =
        titleTextBounds.size.height +
        baseSize +                      // spacer
        albumTextBounds.size.height +
        (baseSize * 0.5) +              // spacer
        artistTextBounds.size.height +
        (baseSize * 0.5) +              // spacer
        artistTextBounds.size.height;   // for rating stars

    // now we know the total y height, we can work out the image size and
    // therefore the x component

    float imageWidth = totalHeight;


    if (floaterIconType == WOFloaterIconNoIcon)
    {
        titleTextBounds.origin.x = floor(cornerRadius);
    }
    else
    {
        titleTextBounds.origin.x = floor((cornerRadius * 2) + imageWidth);
    }

    albumTextBounds.origin.x = titleTextBounds.origin.x;

    // make this flush as well, unlike the old days...
    artistTextBounds.origin.x = titleTextBounds.origin.x;

    // draw the text
    [trackName drawAtPoint:titleTextBounds.origin
            withAttributes:bigAttributes];

    // draw it
    [albumName drawAtPoint:albumTextBounds.origin
            withAttributes:mediumAttributes];

    // draw the text
    [tempArtistName drawAtPoint:artistTextBounds.origin
                 withAttributes:smallAttributes];

    // separator line -- should be long enough to cover title OR artist OR album (whichever longest)
    float longestBoundingBox = MAX((artistTextBounds.size.width + cornerRadius),
                                   (MAX(titleTextBounds.size.width, albumTextBounds.size.width)));

    // only draw the separator is alpha is > 0
    if ([fgColor alphaComponent] > 0)
    {
        NSRect separator;
        separator.origin.x = titleTextBounds.origin.x;
        separator.origin.y = floor(cornerRadius + (4.5 * baseSize * WO_COCOA_TEXT_BUG_FACTOR) - 5);
        separator.size.width = floor(longestBoundingBox + cornerRadius);
        separator.size.height = 2.0; // 1 pixel high

        // same color for separator as used for text
        [fgColor set];

        // draw the line
        NSRectFill(separator);
    }
    // there is a little bug here, probably related to precision which means a
    // tiny part of the separator is still visible when the alpha is 0!
    // get around it by not drawing at all when alpha is > 0
}

- (void)drawRatingStars
{
    NSString *starString = nil;
    NSString *unlitString = nil;

    // prepare colours and fonts for drawing
    NSColor *unlitColor = [NSColor colorWithDeviceWhite:0.0 alpha:0.5];

    NSFont *smallSystemFont = nil;

    float baseSize = floor(cornerRadius - (cornerRadius / 2.0) + 8.0);

    // size is proportional to cornerRadius, except when cornerRadius less than
    // 12 (stars become "unreadable")
    if (cornerRadius >= 12.0)
    {
        smallSystemFont = [NSFont systemFontOfSize:(baseSize - 2)];
    }
    else // BUG: both of these are exactly the same!
    {
        smallSystemFont = [NSFont systemFontOfSize:(baseSize - 2)];
    }

    // http://daringfireball.net/2005/08/star_star
    // first choice: "Hiragino Kaku Gothic Pro" (must use postscript name)
    NSFont *altFont = [NSFont fontWithName:@"HiraKakuPro-W3" size:(baseSize - 2)];

    // second choice: "Osaka"
    if (!altFont) altFont = [NSFont fontWithName:@"Osaka" size:(baseSize - 2)];

    // third choice: "Zapf Dingbats"
    if (!altFont) altFont = [NSFont fontWithName:@"ZapfDingbatsITC" size:(baseSize - 2)];
    if (altFont) smallSystemFont = altFont;

    NSMutableDictionary *starAttributes = [NSMutableDictionary dictionary];

    [starAttributes setObject:smallSystemFont
                       forKey:NSFontAttributeName];

    [starAttributes setObject:textColor
                       forKey:NSForegroundColorAttributeName];

    NSMutableDictionary *unlitAttributes = [NSMutableDictionary dictionary];

    [unlitAttributes setObject:smallSystemFont
                        forKey:NSFontAttributeName];

    [unlitAttributes setObject:unlitColor
                        forKey:NSForegroundColorAttributeName];

    unichar star = WO_RATING_STAR_UNICODE_CHAR;

    // draw the unlit stars first
    unlitString = [NSString stringWithFormat:@"%C%C%C%C%C", star, star,
        star, star, star];

    // specify where the unlit stars will be drawn
    NSRect starBarBounds = NSZeroRect;
    starBarBounds.size = [unlitString sizeWithAttributes:unlitAttributes];

    // calculate origin
    NSRect view = [self bounds];

    // two cases: when cornerRadius is 16 or less, do a "normal origin"
    // (proportional to cornerRadius), but when it is greater, space becomes
    // tight (potential crowding against album title), so move stars closer to
    // corner

    // "x" origin
    starBarBounds.origin.x =
    floor((view.size.width - cornerRadius) - starBarBounds.size.width);

    // "y" origin
    starBarBounds.origin.y = floor(cornerRadius);

    // draw the unlit stars
    [unlitString drawAtPoint:starBarBounds.origin
              withAttributes:unlitAttributes];

    // now (over-)draw lit stars
    switch ([self currentRating])
    {
        case WO0StarRating: // no stars
            starString = @"";
            break;

        case WO1StarRating: // one star
            starString = [NSString stringWithFormat:@"%C", star];
            break;

        case WO2StarRating: // two stars
            starString = [NSString stringWithFormat:@"%C%C", star, star];
            break;

        case WO3StarRating: // three stars
            starString = [NSString stringWithFormat:@"%C%C%C", star, star, star];
            break;

        case WO4StarRating: // four stars
            starString = [NSString stringWithFormat:@"%C%C%C%C", star, star, star,
                star];
            break;

        case WO5StarRating: // five stars
            starString = [NSString stringWithFormat:@"%C%C%C%C%C", star, star,
                star, star, star];
            break;

        default:
            // illegal number of stars!
            ELOG(@"Error: only star ratings between 0 and 5 are permitted");
            starString = @"";
            break;
    }

    [starString drawAtPoint:starBarBounds.origin
             withAttributes:starAttributes];
}

- (void)drawTextForMiniFloater
{
    // set up text and attributes (track name)
    NSFont *bigSystemFont = [NSFont paletteFontOfSize:10];
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:bigSystemFont
                   forKey:NSFontAttributeName];
    [attributes setObject:textColor
                   forKey:NSForegroundColorAttributeName];

    // build up the string that will appear in the floater
    NSMutableString *floaterString = [NSMutableString string];

    if (([trackName isEqualToString:@""]) || ([trackName isEqualToString:@" "]))
        [floaterString setString:@""];
    else
        [floaterString setString:trackName];

    // handle album name string
    if (([albumName isEqualToString:@""]) || ([albumName isEqualToString:@" "]))
    {
        // nothing to add!
    }
    else
    {
        if ([floaterString isEqualToString:@""] == NO)
            // add separator
            [floaterString appendString:@" - "];
        // add album name
        [floaterString appendString:albumName];
    }

    // handle artist name string
    if (([artistName isEqualToString:@""] || [artistName isEqualToString:@" "]) &&
        ([composerName isEqualToString:@""] || [composerName isEqualToString:@" "]))
    {
        // nothing to add!
    }
    else
    {
        NSString *tempArtistName;
        if ([composerName isEqual:@""] || [composerName isEqual:@" "])
            tempArtistName = artistName;
        else if ([artistName isEqual:@""] || [artistName isEqual:@" "])
            tempArtistName = composerName;
        else
            tempArtistName = [NSString stringWithFormat:@"%@ (%@)", artistName, composerName];

        if ([floaterString isEqualToString:@""] == NO)
            // add separator
            [floaterString appendString:@" - "];
        // add artist name
        [floaterString appendString:tempArtistName];
    }

    // add separator for rating stars if appropriate
    if ([self currentRating] != WONoStarRatingDisplay)
    {
        if ([floaterString isEqualToString:@""] == NO)
            // add separator
            [floaterString appendString:@" - "];
    }

    // specify where text will be drawn
    NSRect stringBounds = NSZeroRect;
    stringBounds.size = [floaterString sizeWithAttributes:attributes];

    // split this across two lines because its more readable than NSMakePoint()

    if (floaterIconType == WOFloaterIconNoIcon)
        stringBounds.origin.x = floor(cornerRadius);
    else
        stringBounds.origin.x = floor((cornerRadius * 2) + 16.0);

    // set in middle of floater
    stringBounds.origin.y =
        floor((((cornerRadius * 2) + 16.0) / 2) -
              (stringBounds.size.height / 2));

    // draw the text
    [floaterString drawAtPoint:stringBounds.origin
                withAttributes:attributes];

    // add the rating stars if appropriate
    if ([self currentRating] != WONoStarRatingDisplay)
    {
        unichar star = WO_RATING_STAR_UNICODE_CHAR;

        // unlit stars first
        NSString *unlitStars = [NSString stringWithFormat:@"%C%C%C%C%C", star, star,
            star, star, star];

        NSColor *unlitColor = [NSColor colorWithDeviceWhite:0.0 alpha:0.5];

        // change color to "unlit"
        [attributes setObject:unlitColor
                       forKey:NSForegroundColorAttributeName];

        // http://daringfireball.net/2005/08/star_star
        // first choice: "Hiragino Kaku Gothic Pro"
        NSFont *starFont = [NSFont fontWithName:@"HiraKakuPro-W3"
                                           size:10];
        // second choice: "Osaka"
        if (!starFont) starFont = [NSFont fontWithName:@"Osaka-Regular"
                                                  size:10];
        // third choice: "Zapf Dingbats"
        if (!starFont) starFont = [NSFont fontWithName:@"ZapfDingbatsITC"
                                                  size:10];
        if (starFont)
            [attributes setObject:starFont forKey:NSFontAttributeName];

        NSRect unlitStarsBounds = NSZeroRect;
        unlitStarsBounds.size = [unlitStars sizeWithAttributes:attributes];

        NSRect viewBounds = [self bounds];

        // x origin, inset from left edge of view
        unlitStarsBounds.origin.x =
            floor(viewBounds.size.width - cornerRadius - unlitStarsBounds.size.width);

        // y origin is same as other text

        unlitStarsBounds.origin.y = ((viewBounds.size.height / 2) -
                                     (unlitStarsBounds.size.height / 2));

        // draw the unlit stars
        [unlitStars drawAtPoint:unlitStarsBounds.origin
                 withAttributes:attributes];

        // now (over-)draw lit stars
        NSString *starString;

        switch ([self currentRating])
        {
            case WO0StarRating: // no stars
                starString = @"";
                break;

            case WO1StarRating: // one star
                starString = [NSString stringWithFormat:@"%C", star];
                break;

            case WO2StarRating: // two stars
                starString = [NSString stringWithFormat:@"%C%C", star, star];
                break;

            case WO3StarRating: // three stars
                starString = [NSString stringWithFormat:@"%C%C%C", star, star, star];
                break;

            case WO4StarRating: // four stars
                starString = [NSString stringWithFormat:@"%C%C%C%C", star, star, star,
                    star];
                break;

            case WO5StarRating: // five stars
                starString = [NSString stringWithFormat:@"%C%C%C%C%C", star, star,
                    star, star, star];
                break;

            default:
                // illegal number of stars!
                ELOG(@"Error: only star ratings between 0 and 5 are permitted");
                starString = @"";
                break;
        }

        // reset color to default text color
        [attributes setObject:textColor
                       forKey:NSForegroundColorAttributeName];

        [starString drawAtPoint:unlitStarsBounds.origin
                 withAttributes:attributes];

    }
}

- (NSSize)calculateSizeNeededForMiniFloater
{
    // return value
    NSSize size;

    // set up text and attributes (track name)
    NSFont *bigSystemFont = [NSFont paletteFontOfSize:10];

    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

    [attributes setObject:bigSystemFont
                   forKey:NSFontAttributeName];

    // build up the string that will appear in the floater
    NSMutableString *floaterString = [NSMutableString string];

    if (([trackName isEqualToString:@""]) ||
        ([trackName isEqualToString:@" "]))
    {
        [floaterString setString:@""];
    }
    else
    {
        [floaterString setString:trackName];
    }

    // handle album name string
    if (([albumName isEqualToString:@""]) ||
        ([albumName isEqualToString:@" "]))
    {
        // nothing to add!
    }
    else
    {
        if ([floaterString isEqualToString:@""] == NO)
        {
            // add separator
            [floaterString appendString:@" - "];
        }

        // add album name
        [floaterString appendString:albumName];
    }

    // handle artist name string
    if (([artistName isEqualToString:@""] || [artistName isEqualToString:@" "]) &&
        ([composerName isEqualToString:@""] || [composerName isEqualToString:@" "]))
    {
        // nothing to add!
    }
    else
    {
        NSString *tempArtistName;
        if ([composerName isEqual:@""] || [composerName isEqual:@" "])
            tempArtistName = artistName;
        else if ([artistName isEqual:@""] || [artistName isEqual:@" "])
            tempArtistName = composerName;
        else
            tempArtistName = [NSString stringWithFormat:@"%@ (%@)", artistName, composerName];

        if ([floaterString isEqualToString:@""] == NO)
        {
            // add separator
            [floaterString appendString:@" - "];
        }

        // add artist name
        [floaterString appendString:tempArtistName];
    }

    // add the rating stars if appropriate
    if ([self currentRating] != WONoStarRatingDisplay)
    {
        if ([floaterString isEqualToString:@""] == NO)
        {
            // add separator
            [floaterString appendString:@" - "];
        }

        unichar star = WO_ALT_RATING_STAR;

        // add stars
        [floaterString appendString:[NSString stringWithFormat:@"%C%C%C%C%C", star, star,
            star, star, star]];
    }

    // specify where text will be drawn
    NSRect stringBounds = NSZeroRect;
    stringBounds.size = [floaterString sizeWithAttributes:attributes];

    stringBounds.size.height = stringBounds.size.height * WO_COCOA_TEXT_BUG_FACTOR;

    // after all that layout, time to put together the return value:

    if (floaterIconType == WOFloaterIconNoIcon)
    {
        stringBounds.origin.x = floor(cornerRadius);
        size.width = floor(stringBounds.size.width + (cornerRadius * 2));
    }
    else
    {
        stringBounds.origin.x = floor((cornerRadius * 2) + 16.0);
        size.width = floor(stringBounds.size.width + 16.0 + (cornerRadius * 3));
    }

    // set in middle of floater
    stringBounds.origin.y =
        floor((((cornerRadius * 2) + 16.0) / 2) -
              (stringBounds.size.height / 2));

    size.height = floor(16.0 + (cornerRadius * 2));

    return size;

}

- (NSSize)calculateSizeNeededForText
    /*"
    Return an NSSize describing the size needed to display the icon and text.
     "*/
{
     // Lots of duplication here between this method and drawTextAndSeparator, so
     // have to edit code in both places if I expect it to work.
    // make sure we're working with the appropriate icon size...

    /*

     When the cornerRadius hits the minimum value (8) the shape of the floater
     changes to consist of a tiny icon and all the text concatenated into one
     single line in a 10-point font.

     */

    if (cornerRadius <= 8.0)
    {
        return [self calculateSizeNeededForMiniFloater];
    }
    // otherwise proceed as normal

    NSSize size;

    // use this later in determining position of text

    // used in calculations of font size
    float baseSize = floor(cornerRadius - (cornerRadius / 2.0) + 8.0);
    // this is a very important factor because the text size influences all
    // other calculations

    // set up text and attributes (track name)
    NSFont *bigSystemFont = [NSFont systemFontOfSize:baseSize];

    // for big font:
    // smallest possible size = 12
    // default size = 16
    // largest = 20 (previously was 30)

    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

    [attributes setObject:bigSystemFont
                   forKey:NSFontAttributeName];

    // specify where text will be drawn
    NSRect titleTextBounds = NSZeroRect;
    titleTextBounds.size = [trackName sizeWithAttributes:attributes];

    // don't know x yet
    titleTextBounds.origin.y = floor(cornerRadius + (baseSize * 5 * WO_COCOA_TEXT_BUG_FACTOR) - 5);

    // album name if available (set string with space if not @" ")
    NSFont *mediumSystemFont = [NSFont systemFontOfSize:(baseSize - 2.0)];
    // one pixel smaller than large...

    [attributes setObject:mediumSystemFont
                   forKey:NSFontAttributeName];

    NSRect albumTextBounds = NSZeroRect;
    albumTextBounds.size = [albumName sizeWithAttributes:attributes];

    // don't know x yet
    albumTextBounds.origin.y = floor(titleTextBounds.origin.y - ((albumTextBounds.size.height - baseSize) * WO_COCOA_TEXT_BUG_FACTOR));

    // artist name if available (set string with space if not @" ")
    // this one in a smaller font and inset to the right
    NSFont *smallSystemFont = [NSFont systemFontOfSize:(baseSize - 4.0)];
    // two pixels smaller than large...

    [attributes setObject:smallSystemFont
                   forKey:NSFontAttributeName];

    NSRect artistTextBounds = NSZeroRect;

    NSString *tempArtistName;
    if ([composerName isEqual:@""] || [composerName isEqual:@" "])
        tempArtistName = artistName;
    else if ([artistName isEqual:@""] || [artistName isEqual:@" "])
        tempArtistName = composerName;
    else
        tempArtistName = [NSString stringWithFormat:@"%@ (%@)", artistName, composerName];

    artistTextBounds.size = [tempArtistName sizeWithAttributes:attributes];

    // don't know x yet
    artistTextBounds.origin.y = floor(albumTextBounds.origin.y - ((artistTextBounds.size.height + (baseSize * 0.5)) * WO_COCOA_TEXT_BUG_FACTOR));

    // total height
    float totalHeight =
        ((titleTextBounds.size.height * 4) - 8) +
        baseSize +                      // spacer
        (baseSize * 0.5) +              // spacer
        (baseSize * 0.5);// +           // spacer

    // now we know the total y height, we can work out the image size and
    // therefore the x component

    float imageWidth = totalHeight;

    titleTextBounds.origin.x = floor((cornerRadius * 2) + imageWidth);
    albumTextBounds.origin.x = titleTextBounds.origin.x;
    artistTextBounds.origin.x = floor(titleTextBounds.origin.x + cornerRadius);

    // separator line -- should be long enough to cover title OR artist OR album (whichever longest)
    float longestBoundingBox = MAX((artistTextBounds.size.width + cornerRadius),
                                   (MAX(titleTextBounds.size.width, albumTextBounds.size.width)));


    NSRect separator;
    separator.origin.x = titleTextBounds.origin.x;
    separator.origin.y = floor(cornerRadius + (4.5 * baseSize * WO_COCOA_TEXT_BUG_FACTOR) - 5);
    separator.size.width = floor(longestBoundingBox + cornerRadius);
    separator.size.height = 1.0; // 1 pixel high

    // after all that layout, time to put together the return value:
    if (floaterIconType == WOFloaterIconNoIcon)
    {
        size.width = floor(separator.size.width + (cornerRadius * 2));
    }
    else
    {
        size.width = floor(separator.size.width + (cornerRadius * 3) + imageWidth);
    }
    size.height = floor(totalHeight + (cornerRadius * 2));

    return size;
}

- (NSSize)calculateSizeNeededForIcon
    /*"
    Return an NSSize describing the size needed to display the Icon only.
     "*/
{
    NSSize neededSize = [self calculateSizeNeededForText];

    // make sure we're working with the appropriate icon size...
    [self resizeIconWithTextHeight:
        floor(neededSize.height - (2 * cornerRadius))];

    NSSize baseSize;

    baseSize.height = neededSize.height;
    baseSize.width = baseSize.height;

    return baseSize;
}

- (void)drawRect:(NSRect)rect
{
    // http://wincent.com/a/support/bugs/show_bug.cgi?id=128

    [self clearView];
    [self drawBackground];

    // not sure why I need this next line, but if I omit it, the album cover
    // sometimes gets displayed at full size
    [self resizeIcon];

    [self drawIcon];

    if (drawText)
    {
        [self drawTextAndSeparator];
    }

    //the next line resets the CoreGraphics window shadow (calculated around our custom window shape content)
    //so it's recalculated for the new shape, etc.  The API to do this was introduced in 10.2.
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_1)
    {
        [[self window] setHasShadow:NO];
        [[self window] setHasShadow:YES];
    }
    else
        [[self window] invalidateShadow];
}

#pragma mark -
#pragma mark Properties

@synthesize drawText;
@synthesize textColor;
@synthesize fgColor;
@synthesize bgColor;
@synthesize trackName;
@synthesize artistName;
@synthesize composerName;
@synthesize albumName;

- (void)setBgAlpha:(float)newAlpha
{
    if (newAlpha < MIN_ALPHA_FOR_FLOATER_WINDOW)
        bgAlpha = MIN_ALPHA_FOR_FLOATER_WINDOW;
    else if (newAlpha > MAX_ALPHA_FOR_FLOATER_WINDOW)
        bgAlpha = MAX_ALPHA_FOR_FLOATER_WINDOW;
    else
        bgAlpha = newAlpha;
}

@synthesize bgAlpha;

- (void)setCornerRadius:(float)newRadius
{
    if (cornerRadius < MIN_CORNER_RADIUS)
        cornerRadius = MIN_CORNER_RADIUS;
    else if (cornerRadius > MAX_CORNER_RADIUS)
        cornerRadius = MAX_CORNER_RADIUS;
    else
        cornerRadius = newRadius;
}

@synthesize cornerRadius;

- (void)setInsetSpacer:(float)newInset
{
    if (insetSpacer < MIN_INSET_FROM_BOTTOM_LEFT)
        insetSpacer = MIN_INSET_FROM_BOTTOM_LEFT;
    else if (insetSpacer > MAX_INSET_FROM_BOTTOM_LEFT)
        insetSpacer = MAX_INSET_FROM_BOTTOM_LEFT;
    else
        insetSpacer = newInset;
}

@synthesize insetSpacer;
@synthesize currentRating;

// tell floater path to downloaded image
- (void)setAlbumImagePath:(NSString *)path
{
    // quite possible that we'll be "re-setting" this value using the same
    // string, so do the equality check here to spare us unecessary cycles
    if (albumImagePath != path)
    {
        // set new value
        albumImagePath = path;

        // load the image into appropriate ivar
        if (albumImagePath == nil)
            albumImage  = nil;
        else
        {
            // try with jpg (presumably) first
            if ([[NSFileManager defaultManager] fileExistsAtPath:albumImagePath])
                albumImage = [[NSImage alloc] initByReferencingFile:albumImagePath];
            else
            {
                NSString *tiffString = [[albumImagePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"tiff"];
                if ([[NSFileManager defaultManager] fileExistsAtPath:tiffString])
                {
                    albumImage = [[NSImage alloc] initByReferencingFile:tiffString];

                    if ([albumImage isValid])
                        albumImagePath = [tiffString copy];
                }
            }

            if ([albumImage isValid])
            {
                albumImageSize = [albumImage size];
                [albumImage setScalesWhenResized:YES];
            }
            else
                albumImage = nil;
        }
    }
}

@synthesize albumImagePath;
@synthesize albumImage;

// tell floater to display album cover, icon, or nothing
@synthesize floaterIconType;

@end
