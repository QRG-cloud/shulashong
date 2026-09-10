#import <Foundation/Foundation.h>

static void AppendFourCC(NSMutableData *data, const char value[4]) {
    [data appendBytes:value length:4];
}

static void AppendUInt32BE(NSMutableData *data, uint32_t value) {
    uint32_t bigEndian = CFSwapInt32HostToBig(value);
    [data appendBytes:&bigEndian length:sizeof(bigEndian)];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) {
            fprintf(stderr, "usage: IconPack <iconset-directory> <output.icns>\n");
            return 2;
        }

        NSString *directory = [NSString stringWithUTF8String:argv[1]];
        NSString *outputPath = [NSString stringWithUTF8String:argv[2]];
        NSArray<NSDictionary *> *entries = @[
            @{@"type": @"icp4", @"file": @"icon_16x16.png"},
            @{@"type": @"icp5", @"file": @"icon_32x32.png"},
            @{@"type": @"icp6", @"file": @"icon_32x32@2x.png"},
            @{@"type": @"ic07", @"file": @"icon_128x128.png"},
            @{@"type": @"ic08", @"file": @"icon_256x256.png"},
            @{@"type": @"ic09", @"file": @"icon_512x512.png"},
            @{@"type": @"ic10", @"file": @"icon_512x512@2x.png"}
        ];

        NSMutableData *result = [NSMutableData data];
        AppendFourCC(result, "icns");
        AppendUInt32BE(result, 0);

        for (NSDictionary *entry in entries) {
            NSString *path = [directory stringByAppendingPathComponent:entry[@"file"]];
            NSData *png = [NSData dataWithContentsOfFile:path];
            if (!png) {
                fprintf(stderr, "missing icon image: %s\n", path.UTF8String);
                return 1;
            }
            const char *type = [entry[@"type"] UTF8String];
            AppendFourCC(result, type);
            AppendUInt32BE(result, (uint32_t)png.length + 8);
            [result appendData:png];
        }

        uint32_t totalSize = CFSwapInt32HostToBig((uint32_t)result.length);
        [result replaceBytesInRange:NSMakeRange(4, 4) withBytes:&totalSize];

        NSError *error = nil;
        if (![result writeToFile:outputPath options:NSDataWritingAtomic error:&error]) {
            fprintf(stderr, "failed to write icns: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }
        fprintf(stdout, "%s\n", outputPath.UTF8String);
    }
    return 0;
}
