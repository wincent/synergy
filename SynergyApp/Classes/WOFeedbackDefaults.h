//
//  WOFeedbackDefaults.m
//  Synergy
//
//  Created by Wincent Colaiuta on Sat Jan 25 2003.
//  Copyright 2003-2008 Wincent Colaiuta.

// These settings will produce a feedback window reminiscent of Apple's volume/
// mute/eject overlays:

// left edge is this many pixels from the middle of the screen
#define FEEDBACK_LATERAL_OFFSET_FROM_MIDDLE     106

// bottom edge is this many pixels from the bottom of the screen (Dock ignored)
#define FEEDBACK_VERTICAL_INSET_FROM_BOTTOM     140

// feedback window is this many pixels wide
#define FEEDBACK_WIDTH                          214

// feedback window is this many pixels high
#define FEEDBACK_HEIGHT                         206

// corner radius on feedback window in pixels
#define FEEDBACK_CORNER_RADIUS                  22

// number of segments in the feedback bar (if any)
#define FEEDBACK_BAR_SEGMENTS                   16

// feedback bar begins this many pixels to the left of the middle of the screen
#define FEEDBACK_BAR_LATERAL_OFFSET_FROM_MIDDLE 71

// feedback bar is this many pixels from the bottom of the window (Dock ignored)
#define FEEDBACK_BAR_VERTICAL_INSET_FROM_BOTTOM 28

// each segment of feedback bar is this many pixels wide
#define FEEDBACK_BAR_SEGMENT_WIDTH              7

// each segment of feedback bar is this many pixels high
#define FEEDBACK_BAR_SEGMENT_HEIGHT             9

// add this many pixels to get from end of one segment to beginning of next
#define FEEDBACK_BAR_SEGMENT_GAP                2

// window (view) background alpha
#define FEEDBACK_BACKGROUND_ALPHA               0.125

// default number of segments that should be "on" in the bar
#define FEEDBACK_BAR_ENABLED_SEGMENTS           0

// whether or not to show bar
#define FEEDBACK_BAR_ENABLED                    NO

// interval between "frames" in the fade out process
#define FEEDBACK_FADE_FRAMES_PER_SECOND         20
#define FEEDBACK_FADE_INTERVAL                  (1.0 / (float)FEEDBACK_FADE_FRAMES_PER_SECOND)

// number of seconds feedback remains on screen before fading out
#define FEEDBACK_DURATION                       0.5
