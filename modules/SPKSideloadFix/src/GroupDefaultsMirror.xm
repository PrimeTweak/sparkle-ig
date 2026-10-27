#import <objc/runtime.h>

#import "Header.h"

// Extensions read group defaults from the container SideloadFix.xm redirects. The
// main app keeps its original suites and mirrors its writes there, so extensions
// see the current account and session.

@interface NSUserDefaults (SPKSideloadPrivate)
- (NSString *)_identifier;
- (instancetype)_initWithSuiteName:(NSString *)suiteName container:(NSURL *)container;
@end

static const void *kSPKMirroredDefaultsTagKey = &kSPKMirroredDefaultsTagKey;

static NSString *SPKDefaultsSuiteName(NSUserDefaults *defaults) {
	if (![defaults respondsToSelector:@selector(_identifier)]) return nil;
	id identifier = [defaults _identifier];
	return [identifier isKindOfClass:NSString.class] ? identifier : nil;
}

static NSUserDefaults *SPKMirroredDefaultsForSuite(NSString *suiteName) {
	static NSMutableDictionary<NSString *, NSUserDefaults *> *cache;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		cache = [NSMutableDictionary dictionary];
	});

	@synchronized(cache) {
		NSUserDefaults *existing = cache[suiteName];
		if (existing) return existing;

		NSURL *sharedRoot = getAppGroupPathIfExists();
		if (!sharedRoot) return nil;

		NSURL *container = [sharedRoot URLByAppendingPathComponent:suiteName isDirectory:YES];
		NSURL *preferences = [[container URLByAppendingPathComponent:@"Library" isDirectory:YES]
			URLByAppendingPathComponent:@"Preferences" isDirectory:YES];
		if (!createDirectoryIfNotExists(preferences.path)) return nil;

		NSUserDefaults *mirror = [[NSUserDefaults alloc] _initWithSuiteName:suiteName container:container];
		if (!mirror) return nil;

		objc_setAssociatedObject(mirror, kSPKMirroredDefaultsTagKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		cache[suiteName] = mirror;
		return mirror;
	}
}

static NSUserDefaults *SPKMirrorTargetForDefaults(NSUserDefaults *defaults) {
	if (isAppExtensionProcess()) return nil;
	if (objc_getAssociatedObject(defaults, kSPKMirroredDefaultsTagKey)) return nil;

	NSString *suiteName = SPKDefaultsSuiteName(defaults);
	if (![suiteName hasPrefix:@"group"]) return nil;
	return SPKMirroredDefaultsForSuite(suiteName);
}

%hook NSUserDefaults

- (void)setObject:(id)value forKey:(NSString *)key {
	%orig;
	NSUserDefaults *target = SPKMirrorTargetForDefaults(self);
	if (target) [target setObject:value forKey:key];
}

- (void)setBool:(BOOL)value forKey:(NSString *)key {
	%orig;
	NSUserDefaults *target = SPKMirrorTargetForDefaults(self);
	if (target) [target setBool:value forKey:key];
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)key {
	%orig;
	NSUserDefaults *target = SPKMirrorTargetForDefaults(self);
	if (target) [target setInteger:value forKey:key];
}

- (void)setDouble:(double)value forKey:(NSString *)key {
	%orig;
	NSUserDefaults *target = SPKMirrorTargetForDefaults(self);
	if (target) [target setDouble:value forKey:key];
}

- (void)setFloat:(float)value forKey:(NSString *)key {
	%orig;
	NSUserDefaults *target = SPKMirrorTargetForDefaults(self);
	if (target) [target setFloat:value forKey:key];
}

- (void)setURL:(NSURL *)value forKey:(NSString *)key {
	%orig;
	NSUserDefaults *target = SPKMirrorTargetForDefaults(self);
	if (target) [target setURL:value forKey:key];
}

- (void)removeObjectForKey:(NSString *)key {
	%orig;
	NSUserDefaults *target = SPKMirrorTargetForDefaults(self);
	if (target) [target removeObjectForKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key {
	%orig;
	NSUserDefaults *target = SPKMirrorTargetForDefaults(self);
	if (!target) return;
	if (value) {
		[target setValue:value forKey:key];
	} else {
		[target removeObjectForKey:key];
	}
}

%end
