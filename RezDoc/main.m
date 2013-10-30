/*
 * Copyright (c) 2013, Petroules Corporation
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Cocoa/Cocoa.h>

NSString* const kCorePasteboardFlavorType_TEXT = @"CorePasteboardFlavorType 0x54455854";
NSString* const kCorePasteboardFlavorType_styl = @"CorePasteboardFlavorType 0x7374796C";

@interface NSData (RezDoc)

- (NSString *)rezStringWithBlockCode:(NSString *)blockCode andResourceID:(NSUInteger)resID comments:(BOOL)comments;

@end

int main(int argc, const char *argv[])
{
    if (argc != 4) {
        printf("Usage: %s rtf-file rez-file resource-id\n", argv[0]);
        printf("Converts a rich or plain text file (doc, docx, odt, rtf, txt, xml) to a Carbon resource file (.r)\n");
        return -1;
    }

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // Read the RTF document and convert it to an array of bytes
    NSAttributedString *rtf = [[NSAttributedString alloc] initWithPath:
                               [NSString stringWithUTF8String:argv[1]] documentAttributes:nil];
    if (!rtf) {
        [pool release];
        fprintf(stderr, "Error reading file: %s\n", argv[1]);
        return -1;
    }

    NSData *data = [rtf RTFFromRange:NSMakeRange(0, [rtf length]) documentAttributes:nil];
    [rtf release];

    // Put the RTF data into the pasteboard...
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard declareTypes:[NSArray arrayWithObject:NSRTFPboardType] owner:nil];
    [pasteboard setData:data forType:NSRTFPboardType];

    // Now get it back out as TEXT and styl resources
    NSData *text = [pasteboard dataForType:kCorePasteboardFlavorType_TEXT];
    NSData *styl = [pasteboard dataForType:kCorePasteboardFlavorType_styl];

    // Now write a Rez file with these
    NSMutableString *str = [NSMutableString string];
    NSUInteger resID = (NSUInteger)[[NSString stringWithUTF8String:argv[3]] integerValue];
    [str appendString:[text rezStringWithBlockCode:@"TEXT" andResourceID:resID comments:YES]];
    [str appendString:[styl rezStringWithBlockCode:@"styl" andResourceID:resID comments:YES]];

    BOOL written = [str writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES
                           encoding:NSMacOSRomanStringEncoding error:nil];

    [pool release];

    if (!written) {
        fprintf(stderr, "Error writing file: %s\n", argv[2]);
        return -1;
    }

    return 0;
}

@implementation NSData (RezDoc)

- (NSString *)rezStringWithBlockCode:(NSString *)blockCode andResourceID:(NSUInteger)resID comments:(BOOL)comments
{
    NSMutableString *hex = [NSMutableString stringWithCapacity:[self length] * 2];
    [hex appendFormat:@"data '%@' (%lu) {\n", blockCode, (unsigned long)resID];

    const unsigned char *bytes = (const unsigned char*)[self bytes];
    const NSUInteger length = [self length];
    for (NSUInteger i = 0; i < length; ++i) {
        // Lines start with this
        if (i % 16 == 0)
            [hex appendString:@"    $\""];

        // Insert spaces every two bytes
        if (i % 2 == 0 && i % 16 != 0)
            [hex appendString:@" "];

        [hex appendFormat:@"%02X", bytes[i]];

        // Lines end with this
        if ((i + 1) % 16 == 0 || i == length - 1) {
            [hex appendString:@"\""];

            if (comments) {
                NSInteger remainingBytesThisLine = (15 - i) % 16;
                for (NSUInteger s = 0; s < (remainingBytesThisLine * 2) + (remainingBytesThisLine / 2); ++s)
                    [hex appendString:@" "];

                [hex appendString:@"            /* "];

                for (NSUInteger j = i - (i % 16); j <= i; ++j) {
                    if (isprint(bytes[j]) || bytes[j] > 127) {
                        [hex appendFormat:@"%c", bytes[j]];
                    } else {
                        [hex appendString:@"."];
                    }
                }

                [hex appendString:@" */"];
            }
            
            [hex appendString:@"\n"];
        }
    }
    
    [hex appendString:@"};\n"];
    return hex;
}

@end
