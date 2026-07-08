#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>

__attribute__((constructor))
static void picafix_init(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            NSString *p = [NSHomeDirectory() stringByAppendingPathComponent:
                           @"Library/Application Support/Pica/catalog.json"];
            NSData *data = [NSData dataWithContentsOfFile:p];
            if (!data) { NSLog(@"[picafix] no catalog"); return; }
            NSDictionary *j = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSMutableSet *urls = [NSMutableSet set];
            for (NSDictionary *fam in j[@"families"]) {
                for (NSDictionary *style in fam[@"styles"]) {
                    NSString *u = style[@"fileURL"];
                    if (u) [urls addObject:u];
                }
            }
            NSDate *t0 = [NSDate date];
            NSUInteger ok = 0;
            for (NSString *u in urls) {
                NSURL *url = [NSURL URLWithString:u];
                if (!url) continue;
                if (CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url,
                                                     kCTFontManagerScopeProcess, NULL)) ok++;
            }
            NSLog(@"[picafix] registered %lu/%lu font files in %.1fs",
                  (unsigned long)ok, (unsigned long)urls.count,
                  -[t0 timeIntervalSinceNow]);
        }
    });
}
