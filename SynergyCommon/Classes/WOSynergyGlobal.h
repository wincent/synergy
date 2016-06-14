// WOSynergyGlobal.h
// Copyright 2002-present Greg Hurrell. All rights reserved.
//
// Global header file for the Synergy project

// version number string
#define WO_SYNERGY_VERSION_STRING         @"0453" /* equals 4.5.2+ */
#define WO_SYNERGY_MINOR_VERSION_STRING   @"1"    /* BUG: ignored by trial checking code */

// update-checking target URL
#define WO_UPDATE_URL                     @"http://wincent.com:80/a/products/synergy-classic/version.plist"

// check reachability of this host before doing an update check
#define WO_UPDATE_HOST                    @"wincent.com"

// dictionary keys for version.plist
#define WO_UPDATE_MAJOR_VERSION           @"Current major version"
#define WO_UPDATE_MINOR_VERSION           @"Current minor version"
#define WO_UPDATE_VERSION_STRING          @"Version string"
#define WO_UPDATE_RELEASE_DATE            @"Release date"
#define WO_UPDATE_VERSION_URL             @"Version URL"

// define this to use NSMenuExtra (private) -- otherwise use public NSStatusItem
#define WO_NS_MENU_EXTRA                  1

// compensate for Cocoa's poor estimation of string sizes
#define WO_COCOA_TEXT_BUG_FACTOR          (1.15)

// used with NSNotificationCenter to notify main thread when download is done
#define WO_DOWNLOAD_DONE_NOTIFICATION     @"WODownloadDone"
#define WO_DOWNLOADED_SONG_ID             @"WODownloadedSongID"

// and for when "Buy Now" link becomes available
#define WO_BUY_NOW_LINK_NOTIFICATION      @"WOBuyNowLinkObtained"
#define WO_BUY_NOW_LINK_SONG_ID           @"WOBuyNowSongID"

// used when no screen number is known (for floater placement)
#define WONoScreenNumber                  0

// delay (seconds) before volume hot key produces a key repeat
#define WO_VOLUME_KEY_REPEAT_DELAY        0.10

// base directory containing the button sets for the menu bar controls
#define WO_BUTTON_SETS_BASE_DIRECTORY     @"buttons/"

// button styles for menu bar controls
#define WO_STANDARD_BUTTON_STYLE          @"Standard"
#define WO_3D_BUTTON_STYLE                @"3D"
#define WO_UNREMARKABLE_BUTTON_STYLE      @"Unremarkable"
#define WO_MULTI_COLORED_BUTTON_STYLE     @"Multicolored"
#define WO_SAFARI_BUTTON_STYLE            @"Safari"
#define WO_SAFARI_AQUA_BUTTON_STYLE       @"Safari Aqua"
#define WO_SYNERAMA_BUTTON_STYLE          @"Synerama"
#define WO_SPACESAVER_BUTTON_STYLE        @"Spacesaver"
#define WO_XSCOPE_BUTTON_STYLE            @"xScope"
#define WO_APPLE_BUTTON_STYLE             @"Apple"
#define WO_SIMPLE_BUTTON_STYLE            @"Simple"
#define WO_TABBED_BUTTON_STYLE            @"Tabbed"
#define WO_DIVIDE_BUTTON_STYLE            @"Divide"
#define WO_BRUSHED_BUTTON_STYLE           @"Brushed"
#define WO_CLEAN_BUTTON_STYLE             @"Clean"
#define WO_BLACK_BUTTON_STYLE             @"Black"
#define WO_WAREHOUSE_BUTTON_STYLE         @"Warehouse"
#define WO_RINGS_BUTTON_STYLE             @"Rings"
#define WO_WALT_BUTTON_STYLE              @"Walt"
#define WO_GARAGEBAND_BUTTON_STYLE        @"GarageBand"
#define WO_TRIB_BUTTON_STYLE              @"Trib"
#define WO_KONFUNCTION_BUTTON_STYLE       @"Kunfunction"
#define WO_XIDIUS_BUTTON_STYLE            @"Xidius' Transparent Bar"

#define WO_NUMBER_OF_BUTTON_SETS          23
#define WO_BUTTON_SET_MAX_INDEX           (WO_NUMBER_OF_BUTTON_SETS - 1)

// default button style
#define WO_DEFAULT_BUTTON_SET             WO_XIDIUS_BUTTON_STYLE

// color schemes:

// default scheme: white on black
#define WO_WHITE_FG                       1.0
#define WO_BLACK_BG                       0.0
#define WO_WHITE_ON_BLACK_BG_ALPHA        0.20

// alternative scheme: black on white
#define WO_BLACK_FG                       0.0
#define WO_WHITE_BG                       1.0
#define WO_BLACK_IN_WHITE_BG_ALPHA        0.20

// parameters for communications with iTunes
#define WO_MIN_POLLING_INTERVAL           1.0
#define WO_MAX_POLLING_INTERVAL           10.0

// unicode char used for rating stars

#define WO_USE_SOLID_RATING_STAR          1

#ifdef WO_USE_SOLID_RATING_STAR
// "BLACK STAR"
#define WO_RATING_STAR_UNICODE_CHAR       0x2605
#else
// "OUTLINED BLACK STAR"
#define WO_RATING_STAR_UNICODE_CHAR       0x272D
#endif

#define WO_ALT_RATING_STAR                0x2606

// unicode char used for Global Menu

#define WO_USE_SEMI_QUAVER_GLOBAL_MENU    1

#ifdef WO_USE_SEMI_QUAVER_GLOBAL_MENU
// "BEAMED SIXTEENTH NOTES"
#define WO_GLOBAL_MENU_UNICODE_CHAR       0x266C
#else
// "BEAMED EIGHTH NOTES"
#define WO_GLOBAL_MENU_UNICODE_CHAR       Ox266B
#endif

#define WO_LEFT_POINTING_DOUBLE_ANGLE_QUOTATION_MARK_UNICODE_CHAR 0x00AB
#define WO_RIGHT_POINTING_DOUBLE_ANGLE_QUOTATION_MARK_UNICODE_CHAR 0x00BB

// enable contextual menu click for play/pause button?
// commenting out because only works inconsistently for me
// #define WO_ENABLE_RIGHT_CLICK_FOR_GLOBAL_MENU 1
