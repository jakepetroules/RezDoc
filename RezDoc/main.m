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

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>

typedef struct LPic {
    UInt16 defaultLanguage;
    UInt16 count;
    struct {
        RegionCode regionCode;
        UInt16 resourceID;
        UInt16 multibyteEncoding;
    } item[1024];
} LPic;

NSString* const kCorePasteboardFlavorType_TEXT = @"CorePasteboardFlavorType 0x54455854";
NSString* const kCorePasteboardFlavorType_styl = @"CorePasteboardFlavorType 0x7374796C";

#ifdef __BIG_ENDIAN__
#define NATIVE_ENDIAN true
#else
#define NATIVE_ENDIAN false
#endif

@interface NSData (RezDoc)

- (NSString *)rezStringWithBlockCode:(NSString *)blockCode locale:(RegionCode)regionCode;

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        BOOL generateLpicResource = NO;
        NSString *outputFileName = nil;
        int c;
        while ((c = getopt(argc, argv, "lo:")) != -1)
        {
            switch (c)
            {
                case 'l':
                    generateLpicResource = YES;
                    break;
                case 'o':
                    outputFileName = [NSString stringWithUTF8String:optarg];
                    break;
                case 'h':
                    fprintf(stderr, "Converts rich or plain text files "
                                    "(doc, docx, odt, rtf, txt, xml) "
                                    "to a Carbon resource file (.r)\n");
                    return 1;
                default:
                    fprintf(stderr, "Usage: %s [-l] -o outfile [plistfile | locale1 file1 locale2 file2 ...]\n",
                            [[[NSProcessInfo processInfo] processName] UTF8String]);
                    return EXIT_FAILURE;
            }
        }

        if (optind >= argc) {
            fprintf(stderr, "%s: error: no input files\n",
                    [[[NSProcessInfo processInfo] processName] UTF8String]);
            return EXIT_FAILURE;
        }

        NSString *plistBasePath = [[NSFileManager defaultManager] currentDirectoryPath];
        NSMutableArray *licenses = [NSMutableArray array];
        NSInteger remainingArguments = argc - optind;
        if (remainingArguments == 1) {
            // Read a property list file containing the license dictionary
            NSString *firstInputFile = [NSString stringWithUTF8String:argv[optind]];
            NSString *errorString = 0;
            id plist = [NSPropertyListSerialization propertyListFromData:[NSData dataWithContentsOfFile:firstInputFile]
                                                        mutabilityOption:NSPropertyListImmutable
                                                                  format:nil
                                                        errorDescription:&errorString];
            if (!plist) {
                fprintf(stderr, "%s: error reading property list: %s\n", [[[NSProcessInfo processInfo] processName] UTF8String],
                        [errorString UTF8String]);
                return EXIT_FAILURE;
            }

            licenses = plist;
            /*licenses = [plist objectForKey:@"Licenses"];
            if (!licenses) {
                fprintf(stderr, "%s: error: property list missing Licenses key\n",
                        [[[NSProcessInfo processInfo] processName] UTF8String]);
                return EXIT_FAILURE;
            }*/

            if (![licenses isKindOfClass:[NSArray class]]) {
                fprintf(stderr, "%s: error: property list Licenses key is not an array\n",
                                [[[NSProcessInfo processInfo] processName] UTF8String]);
                return EXIT_FAILURE;
            }

            plistBasePath = [firstInputFile stringByDeletingLastPathComponent];
        } else if (remainingArguments % 2 == 0) {
            // Read a list of localizations and license files from the command line arguments
            for (NSInteger i = optind; i < argc; i += 2) {
                NSString *locale = [NSString stringWithUTF8String:argv[i]];
                NSString *fileName = [NSString stringWithUTF8String:argv[i + 1]];
                [licenses addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                     locale, @"Locale",
                                     fileName, @"Filename", nil]];
            }
        } else {
            fprintf(stderr, "%s: error: odd number of arguments; must specify a single property "
                            "list file or a list of locales and text files",
                            [[[NSProcessInfo processInfo] processName] UTF8String]);
            return EXIT_FAILURE;
        }

        // Build the data for an LPic record
        LPic lpic;
        NSInteger lpicIndex = 0;
        lpic.defaultLanguage = 0;
        lpic.count = OSSwapHostToBigInt16([licenses count]);

        NSMutableArray *processedLocales = [NSMutableArray array];
        NSMutableString *outputBuffer = [NSMutableString string];
        for (NSDictionary *license in licenses)
        {
            NSString *localeIdentifier = [license objectForKey:@"Locale"];
            if (!localeIdentifier || ![localeIdentifier isKindOfClass:[NSString class]]) {
                fprintf(stderr, "%s: error: file is missing required Locale key or wrong data type",
                        [[[NSProcessInfo processInfo] processName] UTF8String]);
                return EXIT_FAILURE;
            }

            NSString *filename = [license objectForKey:@"Filename"];
            if (!filename || ![filename isKindOfClass:[NSString class]]) {
                fprintf(stderr, "%s: error: file is missing required Locale key or wrong data type",
                        [[[NSProcessInfo processInfo] processName] UTF8String]);
                return EXIT_FAILURE;
            }

            if ([processedLocales containsObject:localeIdentifier]) {
                fprintf(stderr, "%s: error: duplicate entry for locale %s\n",
                                [[[NSProcessInfo processInfo] processName] UTF8String],
                                [localeIdentifier UTF8String]);
                return -1;
            }

            [processedLocales addObject:localeIdentifier];

            RegionCode regionCode;
            LocaleStringToLangAndRegionCodes(
                                             [[NSLocale canonicalLanguageIdentifierFromString:localeIdentifier] UTF8String],
                                             NULL, &regionCode);

            CFStringEncoding encoding = kCFStringEncodingMacRoman;
            if (regionCode == verJapan)
                encoding = kCFStringEncodingMacJapanese;
            else if (regionCode == verKorea)
                encoding = kCFStringEncodingMacKorean;
            else if (regionCode == verChina)
                encoding = kCFStringEncodingMacChineseSimp;
            else if (regionCode == verTaiwan)
                encoding = kCFStringEncodingMacChineseTrad;

            NSString *inputFileName = [plistBasePath stringByAppendingPathComponent:filename];

            // Read the text document as an attributed string
            NSAttributedString *textDocument = [[NSAttributedString alloc] initWithPath:inputFileName
                                                                     documentAttributes:nil];
            if (!textDocument) {
                fprintf(stderr, "%s: error: could not create attributed string: %s\n",
                        [[[NSProcessInfo processInfo] processName] UTF8String],
                        [inputFileName UTF8String]);
                return EXIT_FAILURE;
            }

            // Now convert that attributed string to a binary RTF representation
            NSData *rawDocumentData = [textDocument RTFFromRange:NSMakeRange(0, [textDocument length])
                                              documentAttributes:nil];
            if (!rawDocumentData) {
                fprintf(stderr, "%s: error: could not create RTF data from attributed string\n",
                        [[[NSProcessInfo processInfo] processName] UTF8String]);
                return EXIT_FAILURE;
            }

            // Put the binary RTF data into the pasteboard...
            NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
            [pasteboard declareTypes:[NSArray arrayWithObject:NSRTFPboardType] owner:nil];
            [pasteboard setData:rawDocumentData forType:NSRTFPboardType];

            // Now get it back out as TEXT and styl resources
            NSData *text = [pasteboard dataForType:kCorePasteboardFlavorType_TEXT];
            NSData *styl = [pasteboard dataForType:kCorePasteboardFlavorType_styl];
            if (!text || !styl)
            {
                fprintf(stderr, "%s: error: could not read TEXT/styl resources from pasteboard\n",
                        [[[NSProcessInfo processInfo] processName] UTF8String]);
                return -1;
            }

            // The TEXT resource is in the wrong encoding for these... get the right one
            // Unfortunately we must also forego the style
            if (encoding == kCFStringEncodingMacChineseTrad || encoding == kCFStringEncodingMacJapanese)
            {
                NSMutableString *str = [NSMutableString stringWithString:[textDocument string]];
                [str replaceOccurrencesOfString:@"\n" withString:@"\r" options:NSLiteralSearch range:NSMakeRange(0, [str length])];
                text = [str dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(encoding)];
                styl = nil;
            }

#if !defined(__has_feature) || !__has_feature(objc_arc)
            [textDocument release];
#endif

            // styl data needs to be in big endian; so flip it if necessary
            if (styl) {
                char *stylBytes = (char*)malloc([styl length]);
                [styl getBytes:stylBytes length:[styl length]];
                if (CoreEndianFlipData(kCoreEndianResourceManagerDomain, 'styl', 0, stylBytes,
                                       [styl length], NATIVE_ENDIAN) != 0) {
                    free(stylBytes);
                    fprintf(stderr, "%s: error: could not flip styl resource endianness",
                            [[[NSProcessInfo processInfo] processName] UTF8String]);
                    return EXIT_FAILURE;
                }
                styl = [NSData dataWithBytesNoCopy:stylBytes length:[styl length] freeWhenDone:YES];
            }

            // Turn the TEXT and styl data into strings formatted for a Carbon resource file
            [outputBuffer appendString:[text rezStringWithBlockCode:@"TEXT" locale:regionCode]];

            if (styl)
                [outputBuffer appendString:[styl rezStringWithBlockCode:@"styl" locale:regionCode]];

            // The first localization will be the default one
            if (lpicIndex == 0) {
                lpic.defaultLanguage = OSSwapHostToBigInt16(regionCode);
            }

            lpic.item[lpicIndex].regionCode = OSSwapHostToBigInt16(regionCode);
            lpic.item[lpicIndex].resourceID = OSSwapHostToBigInt16(regionCode);
            lpic.item[lpicIndex].multibyteEncoding = OSSwapHostToBigInt16(encoding != kCFStringEncodingMacRoman ? 1 : 0);
            lpicIndex++;
        }

        NSMutableData *lpicData = [NSMutableData data];
        [lpicData appendBytes:&lpic.defaultLanguage length:sizeof(UInt16)];
        [lpicData appendBytes:&lpic.count length:sizeof(UInt16)];

        for (NSUInteger i = 0; i < [licenses count]; ++i) {
            [lpicData appendBytes:&lpic.item[i].regionCode length:sizeof(RegionCode)];
            [lpicData appendBytes:&lpic.item[i].resourceID length:sizeof(UInt16)];
            [lpicData appendBytes:&lpic.item[i].multibyteEncoding length:sizeof(UInt16)];
        }

        // Turn the LPic data into a string formatted for a Carbon resource file
        if (generateLpicResource) {
            [outputBuffer insertString:[lpicData rezStringWithBlockCode:@"LPic" locale:0] atIndex:0];
        }

        if (outputFileName) {
            // Rez files must be encoded in Mac OS Roman
            BOOL written = [outputBuffer writeToFile:outputFileName atomically:YES
                                            encoding:NSMacOSRomanStringEncoding error:nil];
            if (!written) {
                fprintf(stderr, "%s: error: could not write file: %s\n",
                        [[[NSProcessInfo processInfo] processName] UTF8String],
                        [outputFileName UTF8String]);
                return EXIT_FAILURE;
            }
        } else {
            printf("%s", [outputBuffer UTF8String]);
        }

        return 0;
    }
}

unsigned char b0byte(const unsigned char *bytes, NSUInteger index, NSString *blockCode)
{
    // If this is a styl resource and we're on the second byte of the StyleField...
    if ([blockCode isEqualToString:@"styl"] && (index + 7) % 20 == 0) {
        // For some reason, the second byte of the StyleField of a styl
        // resource is set to 0xB0 by a commercial fancy DMG tool; whereas
        // Apple's documentation claims these 8 bits are unused
        return 0xb0;
    }

    return bytes[index];
}

@implementation NSData (RezDoc)

- (NSString *)rezStringWithBlockCode:(NSString *)blockCode locale:(RegionCode)regionCode
{
    NSMutableString *hex = [NSMutableString stringWithCapacity:[self length] * 2];
    [hex appendFormat:@"data '%@' (%d) {\n", blockCode, 5000 + regionCode];

    const unsigned char *bytes = (const unsigned char*)[self bytes];
    const NSUInteger length = [self length];
    for (NSUInteger i = 0; i < length; ++i) {
        // Lines start with this
        if (i % 16 == 0)
            [hex appendString:@"    $\""];

        // Insert spaces every two bytes
        if (i % 2 == 0 && i % 16 != 0)
            [hex appendString:@" "];

        [hex appendFormat:@"%02X", b0byte(bytes, i, blockCode)];

        // Lines end with this
        if ((i + 1) % 16 == 0 || i == length - 1) {
            [hex appendString:@"\""];

            // Number of bytes that would be needed for a full line
            NSUInteger remainingBytes = (15 - i) % 16;

            // Add spaces necessary to equal to amount of space the remaining bytes would have taken
            for (NSUInteger s = 0; s < (remainingBytes * 2) + (remainingBytes / 2); ++s)
                [hex appendString:@" "];

            // Add space between end of bytes and start of comment
            [hex appendString:@"            /* "];

            for (NSUInteger j = i - (i % 16); j <= i; ++j) {
                unsigned char byte = b0byte(bytes, j, blockCode);
                if (isprint(byte) || byte > 127) {
                    [hex appendFormat:@"%c", byte];
                } else {
                    [hex appendString:@"."];
                }
            }

            [hex appendString:@" */"];
            [hex appendString:@"\n"];
        }
    }
    
    [hex appendString:@"};\n"];
    return hex;
}

@end
