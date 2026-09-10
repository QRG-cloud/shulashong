#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSString *DTDayKey(NSDate *date) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd";
    });
    return [formatter stringFromDate:date];
}

static NSString *DTInteger(NSInteger value) {
    static NSNumberFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
    });
    return [formatter stringFromNumber:@(value)] ?: [NSString stringWithFormat:@"%ld", (long)value];
}

static NSString *DTDistance(double meters) {
    if (meters < 1.0) return [NSString stringWithFormat:@"%.0f 厘米", meters * 100.0];
    if (meters < 10.0) return [NSString stringWithFormat:@"%.1f 米", meters];
    if (meters < 1000.0) return [NSString stringWithFormat:@"%.0f 米", meters];
    if (meters < 10000.0) return [NSString stringWithFormat:@"%.2f 公里", meters / 1000.0];
    return [NSString stringWithFormat:@"%.1f 公里", meters / 1000.0];
}

static NSString *DTPercent(double ratio) {
    return ratio < 0.1
        ? [NSString stringWithFormat:@"%.1f%%", ratio * 100.0]
        : [NSString stringWithFormat:@"%.0f%%", ratio * 100.0];
}

static NSArray<NSDictionary *> *DTDistanceStories(void) {
    static NSArray<NSDictionary *> *stories;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        stories = @[
            @{@"route": @"工位 → 茶水间", @"meters": @12.0},
            @{@"route": @"工位 → 电梯口", @"meters": @30.0},
            @{@"route": @"小区门口 → 楼下", @"meters": @100.0},
            @{@"route": @"标准操场一圈", @"meters": @400.0},
            @{@"route": @"外滩漫步一段", @"meters": @1500.0},
            @{@"route": @"西湖环湖一圈", @"meters": @10800.0},
            @{@"route": @"北京 → 天津", @"meters": @120000.0},
            @{@"route": @"上海 → 杭州", @"meters": @170000.0}
        ];
    });
    return stories;
}

static NSDictionary *DTDistanceStory(double meters) {
    for (NSDictionary *story in DTDistanceStories()) {
        if (meters <= [story[@"meters"] doubleValue]) return story;
    }
    return DTDistanceStories().lastObject;
}

static NSString *DTWritingTitle(NSInteger count) {
    if (count == 0) return @"故事还在酝酿";
    if (count < 50) return @"写出了一个开场白";
    if (count < 300) return @"写完了一条长消息";
    if (count < 1000) return @"写完了一封完整邮件";
    if (count < 5000) return @"写完了一篇千字短文";
    if (count < 20000) return @"写完了一个小说章节";
    if (count < 100000) return @"写出了一部短篇小说";
    return @"写出了一部长篇小说";
}

static NSString *DTNovelProgress(NSInteger count) {
    double ratio = MAX(0, count) / 100000.0;
    if (ratio < 1.0) return [NSString stringWithFormat:@"十万字长篇进度 %@", DTPercent(ratio)];
    return [NSString stringWithFormat:@"相当于 %.1f 部十万字长篇", ratio];
}

static NSArray<NSString *> *DTGraphemes(NSString *text) {
    if (![text isKindOfClass:[NSString class]] || text.length == 0) return @[];
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *substring, NSRange substringRange,
                                       NSRange enclosingRange, BOOL *stop) {
        if (substring) [result addObject:substring];
    }];
    return result;
}

// Count only graphemes inserted by the settled edit. Deletions never reduce the daily total.
static NSInteger DTInsertedCharacterCount(NSString *before, NSString *after) {
    NSArray<NSString *> *oldParts = DTGraphemes(before ?: @"");
    NSArray<NSString *> *newParts = DTGraphemes(after ?: @"");
    NSInteger prefix = 0;
    NSInteger shared = MIN(oldParts.count, newParts.count);
    while (prefix < shared && [oldParts[prefix] isEqualToString:newParts[prefix]]) prefix++;

    NSInteger suffix = 0;
    while (suffix < oldParts.count - prefix && suffix < newParts.count - prefix &&
           [oldParts[oldParts.count - 1 - suffix] isEqualToString:newParts[newParts.count - 1 - suffix]]) {
        suffix++;
    }
    return MAX(0, (NSInteger)newParts.count - prefix - suffix);
}

static id DTCopyAXAttribute(AXUIElementRef element, CFStringRef attribute) {
    if (!element) return nil;
    CFTypeRef value = NULL;
    if (AXUIElementCopyAttributeValue(element, attribute, &value) != kAXErrorSuccess || !value) return nil;
    return CFBridgingRelease(value);
}

@interface DTAppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenu *menu;
@property(nonatomic, strong) NSMenuItem *stateItem;
@property(nonatomic, strong) NSMenuItem *distanceItem;
@property(nonatomic, strong) NSMenuItem *typingItem;
@property(nonatomic, strong) NSMenuItem *distanceStoryItem;
@property(nonatomic, strong) NSMenuItem *writingStoryItem;
@property(nonatomic, strong) NSMenuItem *keyboardModeItem;
@property(nonatomic, strong) NSMenuItem *pauseItem;
@property(nonatomic, strong) NSMenuItem *saveErrorItem;
@property(nonatomic, strong) NSMenu *historyMenu;
@property(nonatomic, strong) id mouseMonitor;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong) NSTimer *typingTimer;
@property(nonatomic, strong) NSMutableDictionary *records;
@property(nonatomic, strong) NSURL *dataURL;
@property(nonatomic, copy) NSString *todayKey;
@property(nonatomic) NSPoint previousMouseLocation;
@property(nonatomic) BOOL hasPreviousMouseLocation;
@property(nonatomic) BOOL dirty;
@property(nonatomic) BOOL paused;
@property(nonatomic) BOOL accessibilityTrusted;
@property(nonatomic, strong) id observedAXElement;
@property(nonatomic) pid_t observedPID;
@property(nonatomic, copy) NSString *committedText;
@property(nonatomic, copy) NSString *pendingText;
@property(nonatomic, strong) NSDate *pendingSince;
@end

@implementation DTAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    self.todayKey = DTDayKey([NSDate date]);
    self.dataURL = [self defaultDataURL];
    self.records = [self loadRecords];
    self.paused = [[NSUserDefaults standardUserDefaults] boolForKey:@"DayTrace.isPaused"];
    self.accessibilityTrusted = AXIsProcessTrusted();
    [self ensureRecordForKey:self.todayKey];
    [self buildMenu];
    [self startMonitors];
    [self refreshUI];
    [self persist:YES];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                  target:self
                                                selector:@selector(timerFired:)
                                                 userInfo:nil
                                                 repeats:YES];
    self.typingTimer = [NSTimer scheduledTimerWithTimeInterval:0.2
                                                        target:self
                                                      selector:@selector(typingTimerFired:)
                                                      userInfo:nil
                                                       repeats:YES];
    if (!self.accessibilityTrusted) {
        NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
        AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self persist:YES];
    if (self.mouseMonitor) [NSEvent removeMonitor:self.mouseMonitor];
}

- (NSURL *)defaultDataURL {
    NSURL *base = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                         inDomains:NSUserDomainMask].firstObject;
    return [[base URLByAppendingPathComponent:@"DayTrace" isDirectory:YES]
            URLByAppendingPathComponent:@"daily-stats.json" isDirectory:NO];
}

- (NSMutableDictionary *)loadRecords {
    NSData *data = [NSData dataWithContentsOfURL:self.dataURL];
    if (!data) return [NSMutableDictionary dictionary];
    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    return [object isKindOfClass:[NSDictionary class]] ? [object mutableCopy] : [NSMutableDictionary dictionary];
}

- (NSMutableDictionary *)ensureRecordForKey:(NSString *)key {
    id existing = self.records[key];
    NSMutableDictionary *record;
    if ([existing isKindOfClass:[NSMutableDictionary class]]) {
        record = existing;
    } else if ([existing isKindOfClass:[NSDictionary class]]) {
        record = [existing mutableCopy];
    } else {
        record = [@{@"date": key, @"distanceMillimeters": @0.0, @"characters": @0} mutableCopy];
    }
    self.records[key] = record;
    return record;
}

- (NSMutableDictionary *)todayRecord {
    return [self ensureRecordForKey:self.todayKey];
}

- (void)buildMenu {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.image = [NSImage imageWithSystemSymbolName:@"computermouse.fill"
                                            accessibilityDescription:@"鼠拉松"];
    self.statusItem.button.imagePosition = NSImageLeft;

    self.menu = [[NSMenu alloc] initWithTitle:@"鼠拉松"];
    self.menu.delegate = self;
    self.statusItem.menu = self.menu;

    NSMenuItem *title = [self disabledItem:@"鼠拉松 · 今天的移动与文字"];
    title.attributedTitle = [[NSAttributedString alloc] initWithString:title.title attributes:@{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:14]
    }];
    [self.menu addItem:title];
    self.stateItem = [self disabledItem:@""];
    [self.menu addItem:self.stateItem];
    [self.menu addItem:[NSMenuItem separatorItem]];

    self.distanceItem = [self disabledItem:@""];
    self.distanceItem.image = [NSImage imageWithSystemSymbolName:@"cursorarrow.motionlines" accessibilityDescription:nil];
    [self.menu addItem:self.distanceItem];
    self.typingItem = [self disabledItem:@""];
    self.typingItem.image = [NSImage imageWithSystemSymbolName:@"keyboard" accessibilityDescription:nil];
    [self.menu addItem:self.typingItem];
    [self.menu addItem:[NSMenuItem separatorItem]];

    self.distanceStoryItem = [self disabledItem:@""];
    self.distanceStoryItem.image = [NSImage imageWithSystemSymbolName:@"figure.walk" accessibilityDescription:nil];
    [self.menu addItem:self.distanceStoryItem];
    self.writingStoryItem = [self disabledItem:@""];
    self.writingStoryItem.image = [NSImage imageWithSystemSymbolName:@"book.closed" accessibilityDescription:nil];
    [self.menu addItem:self.writingStoryItem];

    NSMenuItem *historyItem = [[NSMenuItem alloc] initWithTitle:@"最近 7 天" action:nil keyEquivalent:@""];
    self.historyMenu = [[NSMenu alloc] initWithTitle:@"最近 7 天"];
    historyItem.submenu = self.historyMenu;
    historyItem.image = [NSImage imageWithSystemSymbolName:@"chart.bar" accessibilityDescription:nil];
    [self.menu addItem:historyItem];
    [self.menu addItem:[NSMenuItem separatorItem]];

    self.keyboardModeItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(requestAccessibility:) keyEquivalent:@""];
    self.keyboardModeItem.target = self;
    [self.menu addItem:self.keyboardModeItem];

    self.pauseItem = [[NSMenuItem alloc] initWithTitle:@"暂停记录"
                                                 action:@selector(togglePaused:)
                                          keyEquivalent:@""];
    self.pauseItem.target = self;
    [self.menu addItem:self.pauseItem];

    NSMenuItem *exportItem = [[NSMenuItem alloc] initWithTitle:@"导出全部数据为 CSV…"
                                                         action:@selector(exportCSV:)
                                                  keyEquivalent:@""];
    exportItem.target = self;
    exportItem.image = [NSImage imageWithSystemSymbolName:@"square.and.arrow.up" accessibilityDescription:nil];
    [self.menu addItem:exportItem];

    NSMenuItem *openDataItem = [[NSMenuItem alloc] initWithTitle:@"打开本地数据文件夹"
                                                           action:@selector(openDataFolder:)
                                                    keyEquivalent:@""];
    openDataItem.target = self;
    [self.menu addItem:openDataItem];

    self.saveErrorItem = [self disabledItem:@""];
    self.saveErrorItem.hidden = YES;
    [self.menu addItem:self.saveErrorItem];
    [self.menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *resetItem = [[NSMenuItem alloc] initWithTitle:@"清空今天的数据…"
                                                        action:@selector(resetToday:)
                                                 keyEquivalent:@""];
    resetItem.target = self;
    [self.menu addItem:resetItem];

    NSMenuItem *privacyItem = [self disabledItem:@"🔒 只保存总数，不保存输入内容或轨迹"];
    [self.menu addItem:privacyItem];
    [self.menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"退出鼠拉松"
                                                       action:@selector(terminate:)
                                                keyEquivalent:@"q"];
    quitItem.target = NSApp;
    [self.menu addItem:quitItem];
}

- (NSMenuItem *)disabledItem:(NSString *)title {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
    item.enabled = NO;
    return item;
}

- (void)startMonitors {
    __weak typeof(self) weakSelf = self;
    NSEventMask mouseMask = NSEventMaskMouseMoved | NSEventMaskLeftMouseDragged |
                            NSEventMaskRightMouseDragged | NSEventMaskOtherMouseDragged;
    self.mouseMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:mouseMask handler:^(NSEvent *event) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf recordMouseAt:[NSEvent mouseLocation]];
        });
    }];
}

- (void)timerFired:(NSTimer *)timer {
    [self rolloverIfNeeded];
    [self persist:NO];
    [self refreshUI];
}

- (void)rolloverIfNeeded {
    NSString *key = DTDayKey([NSDate date]);
    if ([key isEqualToString:self.todayKey]) return;
    self.todayKey = key;
    [self ensureRecordForKey:key];
    self.hasPreviousMouseLocation = NO;
    self.dirty = YES;
}

- (void)recordMouseAt:(NSPoint)location {
    [self rolloverIfNeeded];
    if (self.paused) {
        self.hasPreviousMouseLocation = NO;
        return;
    }
    if (!self.hasPreviousMouseLocation) {
        self.previousMouseLocation = location;
        self.hasPreviousMouseLocation = YES;
        return;
    }

    NSScreen *currentScreen = [self screenContainingPoint:location];
    NSScreen *previousScreen = [self screenContainingPoint:self.previousMouseLocation];
    NSPoint previous = self.previousMouseLocation;
    self.previousMouseLocation = location;
    if (!currentScreen || currentScreen != previousScreen) return;

    NSNumber *displayNumber = currentScreen.deviceDescription[@"NSScreenNumber"];
    if (!displayNumber) return;
    CGSize sizeMM = CGDisplayScreenSize((CGDirectDisplayID)displayNumber.unsignedIntValue);
    NSRect frame = currentScreen.frame;
    if (frame.size.width <= 0 || frame.size.height <= 0 || sizeMM.width <= 0 || sizeMM.height <= 0) return;

    double dx = (location.x - previous.x) * sizeMM.width / frame.size.width;
    double dy = (location.y - previous.y) * sizeMM.height / frame.size.height;
    double segmentMM = hypot(dx, dy);
    if (!isfinite(segmentMM) || segmentMM <= 0 || segmentMM >= 500) return;

    NSMutableDictionary *record = [self todayRecord];
    record[@"distanceMillimeters"] = @([record[@"distanceMillimeters"] doubleValue] + segmentMM);
    self.dirty = YES;
    [self refreshUI];
}

- (NSScreen *)screenContainingPoint:(NSPoint)point {
    for (NSScreen *screen in NSScreen.screens) {
        if (NSMouseInRect(point, screen.frame, NO)) return screen;
    }
    return nil;
}

- (BOOL)isSupportedTextElement:(AXUIElementRef)element {
    NSString *role = DTCopyAXAttribute(element, kAXRoleAttribute);
    NSString *subrole = DTCopyAXAttribute(element, kAXSubroleAttribute);
    NSString *roleLower = role.lowercaseString ?: @"";
    NSString *subroleLower = subrole.lowercaseString ?: @"";
    if ([roleLower containsString:@"secure"] || [roleLower containsString:@"password"] ||
        [subroleLower containsString:@"secure"] || [subroleLower containsString:@"password"]) return NO;
    return [role isEqualToString:(__bridge NSString *)kAXTextFieldRole] ||
           [role isEqualToString:(__bridge NSString *)kAXTextAreaRole] ||
           [role isEqualToString:(__bridge NSString *)kAXComboBoxRole];
}

- (void)clearTypingBaseline {
    self.observedAXElement = nil;
    self.observedPID = 0;
    self.committedText = nil;
    self.pendingText = nil;
    self.pendingSince = nil;
}

- (void)typingTimerFired:(NSTimer *)timer {
    BOOL trusted = AXIsProcessTrusted();
    if (trusted != self.accessibilityTrusted) {
        self.accessibilityTrusted = trusted;
        [self clearTypingBaseline];
        [self refreshUI];
    }
    if (!trusted) return;

    AXUIElementRef system = AXUIElementCreateSystemWide();
    id focusedObject = DTCopyAXAttribute(system, kAXFocusedUIElementAttribute);
    CFRelease(system);
    if (!focusedObject || ![self isSupportedTextElement:(__bridge AXUIElementRef)focusedObject]) {
        [self clearTypingBaseline];
        return;
    }

    id value = DTCopyAXAttribute((__bridge AXUIElementRef)focusedObject, kAXValueAttribute);
    if (![value isKindOfClass:[NSString class]]) {
        [self clearTypingBaseline];
        return;
    }
    NSString *currentText = value;
    pid_t focusedPID = 0;
    AXUIElementGetPid((__bridge AXUIElementRef)focusedObject, &focusedPID);
    BOOL sameElement = self.observedAXElement && self.observedPID == focusedPID &&
        CFEqual((__bridge CFTypeRef)self.observedAXElement, (__bridge CFTypeRef)focusedObject);
    if (!sameElement) {
        self.observedAXElement = focusedObject;
        self.observedPID = focusedPID;
        self.committedText = currentText;
        self.pendingText = nil;
        self.pendingSince = nil;
        return;
    }

    if (self.paused) {
        self.committedText = currentText;
        self.pendingText = nil;
        self.pendingSince = nil;
        return;
    }
    if ([currentText isEqualToString:self.committedText ?: @""]) {
        self.pendingText = nil;
        self.pendingSince = nil;
        return;
    }
    if (![currentText isEqualToString:self.pendingText]) {
        self.pendingText = currentText;
        self.pendingSince = [NSDate date];
        return;
    }
    if (!self.pendingSince || -self.pendingSince.timeIntervalSinceNow < 0.65) return;

    NSInteger inserted = DTInsertedCharacterCount(self.committedText ?: @"", self.pendingText ?: @"");
    NSLog(@"Accurate character count: pid=%d before=%lu after=%lu inserted=%ld",
          focusedPID, (unsigned long)self.committedText.length,
          (unsigned long)self.pendingText.length, (long)inserted);
    self.committedText = self.pendingText;
    self.pendingText = nil;
    self.pendingSince = nil;
    if (inserted <= 0) return;
    NSMutableDictionary *record = [self todayRecord];
    record[@"characters"] = @([record[@"characters"] integerValue] + inserted);
    self.dirty = YES;
    [self refreshUI];
}

- (void)refreshUI {
    NSDictionary *record = [self todayRecord];
    double meters = [record[@"distanceMillimeters"] doubleValue] / 1000.0;
    NSInteger keys = [record[@"characters"] integerValue];
    NSString *compactDistance = meters < 1000
        ? [NSString stringWithFormat:@"%.0fm", meters]
        : [NSString stringWithFormat:@"%.1fkm", meters / 1000.0];
    NSString *compactKeys = keys < 1000
        ? [NSString stringWithFormat:@"%ld", (long)keys]
        : [NSString stringWithFormat:@"%.1fk", keys / 1000.0];
    self.statusItem.button.title = [NSString stringWithFormat:@"%@ · %@字", compactDistance, compactKeys];

    if (self.paused) {
        self.stateItem.title = @"● 已暂停";
    } else if (self.accessibilityTrusted) {
        self.stateItem.title = @"● 正在记录 · 精准字数 · 数据仅存本机";
    } else {
        self.stateItem.title = @"● 鼠标记录中 · 打字待辅助功能授权";
    }
    self.distanceItem.title = [NSString stringWithFormat:@"光标里程    %@", DTDistance(meters)];
    self.typingItem.title = [NSString stringWithFormat:@"打字量       %@ 字（最终写入字符）", DTInteger(keys)];

    self.keyboardModeItem.title = self.accessibilityTrusted
        ? @"⌨️ 精准字数已开启 · 原文不落盘"
        : @"开启精准字数统计（需辅助功能）…";
    self.keyboardModeItem.enabled = !self.accessibilityTrusted;

    NSDictionary *story = DTDistanceStory(meters);
    double reference = [story[@"meters"] doubleValue];
    double ratio = reference > 0 ? meters / reference : 0;
    NSString *comparison = ratio < 1
        ? [NSString stringWithFormat:@"完成 %@", DTPercent(ratio)]
        : [NSString stringWithFormat:@"走了 %.1f 趟", ratio];
    self.distanceStoryItem.title = [NSString stringWithFormat:@"相当于：%@ · %@", story[@"route"], comparison];
    self.writingStoryItem.title = [NSString stringWithFormat:@"相当于：%@ · %@", DTWritingTitle(keys), DTNovelProgress(keys)];

    self.pauseItem.title = self.paused ? @"继续记录" : @"暂停记录";
    self.pauseItem.image = [NSImage imageWithSystemSymbolName:(self.paused ? @"play.fill" : @"pause.fill")
                                    accessibilityDescription:nil];
    [self rebuildHistoryMenu];
}

- (void)rebuildHistoryMenu {
    [self.historyMenu removeAllItems];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateFormatter *weekday = [[NSDateFormatter alloc] init];
    weekday.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
    weekday.dateFormat = @"E";
    for (NSInteger offset = 6; offset >= 0; offset--) {
        NSDate *date = [calendar dateByAddingUnit:NSCalendarUnitDay value:-offset toDate:[NSDate date] options:0];
        NSString *key = DTDayKey(date);
        NSDictionary *record = self.records[key];
        if (![record isKindOfClass:[NSDictionary class]]) {
            record = @{@"date": key, @"distanceMillimeters": @0.0, @"characters": @0};
        }
        double meters = [record[@"distanceMillimeters"] doubleValue] / 1000.0;
        NSInteger keys = [record[@"characters"] integerValue];
        NSString *line = [NSString stringWithFormat:@"%@  %@  ·  %@ 字",
                          [weekday stringFromDate:date], DTDistance(meters), DTInteger(keys)];
        NSMenuItem *item = [self disabledItem:line];
        [self.historyMenu addItem:item];
    }
}

- (void)persist:(BOOL)force {
    if (!self.dirty && !force) return;
    NSError *error = nil;
    NSURL *directory = [self.dataURL URLByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtURL:directory
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:&error];
    if (!error) {
        NSMutableDictionary *compactRecords = [NSMutableDictionary dictionary];
        [self.records enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *record, BOOL *stop) {
            BOOL hasActivity = [record[@"distanceMillimeters"] doubleValue] > 0 ||
                               [record[@"characters"] integerValue] > 0 ||
                               [record[@"keystrokes"] integerValue] > 0;
            if (hasActivity || [key isEqualToString:self.todayKey]) compactRecords[key] = record;
        }];
        NSData *data = [NSJSONSerialization dataWithJSONObject:compactRecords
                                                       options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                         error:&error];
        if (data && [data writeToURL:self.dataURL options:NSDataWritingAtomic error:&error]) {
            self.records = compactRecords;
        }
    }
    self.saveErrorItem.hidden = (error == nil);
    self.saveErrorItem.title = error ? [NSString stringWithFormat:@"保存失败：%@", error.localizedDescription] : @"";
    if (!error) self.dirty = NO;
}

- (void)togglePaused:(id)sender {
    self.paused = !self.paused;
    self.hasPreviousMouseLocation = NO;
    [self clearTypingBaseline];
    [[NSUserDefaults standardUserDefaults] setBool:self.paused forKey:@"DayTrace.isPaused"];
    [self refreshUI];
}

- (void)resetToday:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"清空今天的数据？";
    alert.informativeText = @"只会清空今天的光标距离和准确字数，历史记录不受影响。";
    [alert addButtonWithTitle:@"清空"];
    [alert addButtonWithTitle:@"取消"];
    alert.alertStyle = NSAlertStyleWarning;
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    self.records[self.todayKey] = [@{@"date": self.todayKey,
                                    @"distanceMillimeters": @0.0,
                                    @"characters": @0} mutableCopy];
    self.hasPreviousMouseLocation = NO;
    self.dirty = YES;
    [self persist:YES];
    [self refreshUI];
}

- (void)exportCSV:(id)sender {
    [self persist:YES];
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.nameFieldStringValue = @"鼠拉松-统计.csv";
    panel.allowedContentTypes = @[UTTypeCommaSeparatedText];
    if ([panel runModal] != NSModalResponseOK) return;

    NSMutableString *csv = [NSMutableString stringWithString:@"\uFEFF日期,光标距离（米）,最终写入字符数\n"];
    NSArray<NSString *> *keys = [[self.records allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *key in keys) {
        NSDictionary *record = self.records[key];
        [csv appendFormat:@"%@,%.3f,%ld\n", key,
         [record[@"distanceMillimeters"] doubleValue] / 1000.0,
         (long)[record[@"characters"] integerValue]];
    }
    NSError *error = nil;
    [csv writeToURL:panel.URL atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
    }
}

- (void)requestAccessibility:(id)sender {
    NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
    AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    if (url) [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)openDataFolder:(id)sender {
    [self persist:YES];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[self.dataURL]];
}

- (void)menuWillOpen:(NSMenu *)menu {
    [self refreshUI];
}

@end

static int DTRunSelfTests(void) {
    BOOL ok = YES;
    ok = ok && [DTDistance(0.42) isEqualToString:@"42 厘米"];
    ok = ok && [DTDistance(9.25) isEqualToString:@"9.2 米"];
    ok = ok && [DTDistance(1250) isEqualToString:@"1.25 公里"];
    ok = ok && [DTDistanceStory(8)[@"route"] isEqualToString:@"工位 → 茶水间"];
    ok = ok && [DTDistanceStory(31)[@"route"] isEqualToString:@"小区门口 → 楼下"];
    ok = ok && [DTWritingTitle(1200) isEqualToString:@"写完了一篇千字短文"];
    ok = ok && [DTWritingTitle(100000) isEqualToString:@"写出了一部长篇小说"];
    ok = ok && DTInsertedCharacterCount(@"", @"你好") == 2;
    ok = ok && DTInsertedCharacterCount(@"你好", @"你好呀") == 1;
    ok = ok && DTInsertedCharacterCount(@"你好", @"你") == 0;
    ok = ok && DTInsertedCharacterCount(@"今天晴", @"今天很好") == 2;
    ok = ok && DTInsertedCharacterCount(@"", @"👨‍👩‍👧‍👦") == 1;
    fprintf(stdout, "%s\n", ok ? "ShuLaSong self-tests passed" : "ShuLaSong self-tests failed");
    return ok ? 0 : 1;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc > 1 && strcmp(argv[1], "--self-test") == 0) return DTRunSelfTests();
        NSApplication *application = [NSApplication sharedApplication];
        DTAppDelegate *delegate = [[DTAppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
