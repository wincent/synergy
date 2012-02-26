//
//  WODebug.h
//  (Originally part of Synergy project)
//
//  Created by Wincent Colaiuta on Thu Dec 12 2002.
//  Copyright 2002-2008 Wincent Colaiuta.

/*

 Global header file for debugging/logging macros

 Activate by defining -DDEBUG in OTHER_CFLAGS section of Project Builder

 Notes: Excellent tutorial on defining pre-processor macros can be found
 at http://www-es.fernuni-hagen.de/cgi-bin/info2html?(cpp)Macros

 */

//  debugging macros:
#ifdef DEBUG

/*"
These macros take effect when the "DEBUG" flag is passed to the compiler
(either on the command line using the -D switch, or in the "Other C Compiler
Flags" field in Project Builder). Each macro is essentially a wrapper for the
NSLog() function call.

Use #LOG() when you wish to pass a log message directly to NSLog() with no
modification. Multiple arguments are acceptable, for example:

 !{LOG(@"Added \%d units to the total", widthAdded);}

Use #DEBUG_ONLY() when you wish to define a block of code that is to appear in
debug builds only. For example:

!{DEBUG_ONLY(
    \// This call will only appear in debug builds:
    [FunClass newFunObject];
);}

Use #VLOG() when you want more detail in your log entries. "VLOG" standards for
"Verbose Log". You pass arguments to #VLOG() exactly as you would to NSLog() or
#LOG(). Multiple arguments are acceptable. The macro will insert additional
information in the log entry that may be useful for debugging purposes. This
includes the class name, source file line number and method name. A sample
log entry, in this case produced by !{VLOG(@"Your.app is not running")}, is:

!{[Class: ClassName, Line: 780] Your.app is not running (isAppRunning).}

Use #ELOG() when you want to output error messages that will appear even when
the DEBUG flag is not present. In DEBUG mode, the usage and output of #ELOG()
is identical to that of #VLOG().

Note that in all cases a trailing semicolon must be present.
"*/

// LOG = "log" a debugging message
#define LOG(args...) \
        do { NSLog(args); } while (0)

// DEBUG_ONLY = define a block of code for debug builds only
#define DEBUG_ONLY(codeblock) \
        do { codeblock } while (0)

// VLOG = "verbose log" (log additional debugging info)
#define VLOG(args...) \
        do { \
            /* make class string: [Class: name, Line: %d] */ \
            NSString *classString = \
                [NSString stringWithFormat:@"[Class: %@, Line: %d]", \
                [self class], \
                __LINE__]; \
                \
            /* make string from submitted log message */ \
            NSString *messageString = [NSString stringWithFormat:args]; \
                \
            /* make string with method name */ \
            NSString *methodString = \
                [NSString stringWithString:NSStringFromSelector(_cmd)];\
                \
            /* construct log entry from class, message and method strings */ \
            NSString *logString = \
                [NSString stringWithFormat:@"%@ %@ (%@).", \
                classString, \
                messageString, \
                methodString]; \
                \
            /* output it to the log */ \
            NSLog(logString);    \
        } while (0)

// The do {} while (0) block also allows us to append a trailing
// semicolon to the macro whenever we call it, thus making it appear
// more like a function call to the casual reader of the source:
// see http://www-es.fernuni-hagen.de/cgi-bin/info2html?(cpp)Swallow%20Semicolon

// ELOG = "error log" (log error with additional debugging info)
#define ELOG(args...) \
        do { \
            /* make class string: [Class: name, Line: %d] */ \
            NSString *classString = \
                [NSString stringWithFormat:@"[Class: %@, Line: %d]", \
                [self class], \
                __LINE__]; \
                \
            /* make string from submitted log message */ \
            NSString *messageString = [NSString stringWithFormat:args]; \
                \
            /* make string with method name */ \
            NSString *methodString = \
                [NSString stringWithString:NSStringFromSelector(_cmd)];\
                \
            /* construct log entry from class, message and method strings */ \
            NSString *logString = \
                [NSString stringWithFormat:@"%@ %@ (%@).", \
                classString, \
                messageString, \
                methodString]; \
                \
            /* output it to the log */ \
            NSLog(logString);    \
        } while (0)

#else

// when DEBUG is not defined, produce less (or no) code:

/*"

When the DEBUG flag is not defined, most of the macros will produce no code. In
this way you can control whether or not your application writes log entries by
changing a compiler option (using one Build Style for development and one for
deployment).

#LOG(), #DEBUG_ONLY() and #VLOG() produce no code when DEBUG is not defined.

#ELOG() produces code which wraps the NSLog() function and outputs any entries
to the log. The output is less verbose than in the case where DEBUG is defined.
For example:

!{ELOG(@"Error writing preferences to disk");}

produces exactly the same code as if you had written:

!{NSLog(@"Error writing preferences to disk");}

Again note that in all cases a trailing semicolon must be present.
 "*/

#define LOG(args... ) do {} while (0)
#define DEBUG_ONLY(args...) do {} while (0)
#define VLOG(args...) do {} while (0)

// except for ELOG (error log) case, where we produce minimal logging:
#define ELOG(args...) \
        do { NSLog(args); } while (0)

#endif


/*"

 Example usage:

!{LOG(@"cleanup routine called %d times", callCount);

 VLOG(@"passed object is %@ and width is %d", inputObject, itemWidth);

 ELOG(@"Error writing preferences to disk");

 DEBUG_ONLY(
    {
        NSString *name;
        [[self explode] usingString:name];
    }
 );}

 "*/