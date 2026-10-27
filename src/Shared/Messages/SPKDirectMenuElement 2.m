#import "SPKDirectMenuElement.h"

#import <objc/message.h>
#import <objc/runtime.h>

#import "../../AssetUtils.h"
#import "../../Utils.h"

static const void *kSPKDirectSparkleRowKey = &kSPKDirectSparkleRowKey;

// The shape is worked out from the class rather than measured, so the first
// submenu on each IG version is probed: the flag goes in before IG is handed one
// and comes out once it has survived. A launch that finds it still set knows the
// last attempt died, and submenus are dropped for that version.
static NSString *const kSPKPrismSubmenuProbeKey = @"spk_prism_submenu_probe_pending";
static NSString *const kSPKPrismSubmenuBlockedKey = @"spk_prism_submenu_derived_blocked";

static BOOL sSPKPrismSubmenuShapeKnown = NO;
static uint64_t sSPKPrismSubmenuSubtype = 0;
static Class sSPKPrismSubmenuItemClass = Nil;

@implementation SPKDirectMenuAction

+ (instancetype)actionWithTitle:(NSString *)title image:(UIImage *)image handler:(void (^)(void))handler {
    if (title.length == 0 || !handler)
        return nil;
    SPKDirectMenuAction *action = [[SPKDirectMenuAction alloc] init];
    action->_title = [title copy];
    action->_image = image;
    action->_handler = [handler copy];
    return action;
}

@end

static id SPKDirectIvarObject(id object, const char *name) {
    if (!object || !name)
        return nil;
    Ivar ivar = class_getInstanceVariable([object class], name);
    if (!ivar)
        return nil;
    const char *encoding = ivar_getTypeEncoding(ivar);
    if (!encoding || encoding[0] != '@')
        return nil;
    return object_getIvar(object, ivar);
}

static BOOL SPKDirectReadSubtype(id element, uint64_t *outSubtype) {
    Ivar subtypeIvar = element ? class_getInstanceVariable([element class], "_subtype") : NULL;
    if (!subtypeIvar)
        return NO;
    if (outSubtype) {
        *outSubtype = *(uint64_t *)((uint8_t *)(__bridge void *)element + ivar_getOffset(subtypeIvar));
    }
    return YES;
}

// Index of the case owning `group`, from the order of the payload ivar groups.
// Gives 1 for the submenu case on both IG 410 and IG 441, matching what those
// builds use. It can only be wrong if a case carrying no payload precedes `group`.
static BOOL SPKDirectSubtypeForIvarGroup(Class cls, NSString *group, uint64_t *outSubtype) {
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(cls, &count);
    if (!ivars)
        return NO;

    NSMutableArray<NSString *> *groups = [NSMutableArray array];
    for (unsigned int i = 0; i < count; i++) {
        const char *name = ivar_getName(ivars[i]);
        if (!name || name[0] != '_' || strcmp(name, "_subtype") == 0)
            continue;
        NSString *ivarName = @(name + 1);
        NSRange separator = [ivarName rangeOfString:@"_"];
        if (separator.location == NSNotFound)
            continue;
        NSString *ivarGroup = [ivarName substringToIndex:separator.location];
        if (![groups.lastObject isEqualToString:ivarGroup])
            [groups addObject:ivarGroup];
    }
    free(ivars);

    NSUInteger index = [groups indexOfObject:group];
    if (index == NSNotFound)
        return NO;
    if (outSubtype)
        *outSubtype = (uint64_t)index;
    return YES;
}

// Tags the probe with both the IG version and a Sparkle-side generation, so a
// build that fixes how submenus are constructed is not held back by a block from
// an earlier, broken attempt.
static NSString *SPKDirectSubmenuProbeToken(void) {
    return [NSString stringWithFormat:@"%@#4", [SPKUtils IGVersionString] ?: @""];
}

static BOOL SPKDirectSubmenuBlocked(void) {
    static BOOL blocked = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        NSString *token = SPKDirectSubmenuProbeToken();
        blocked = [[defaults stringForKey:kSPKPrismSubmenuBlockedKey] isEqualToString:token];
        if (blocked || ![[defaults stringForKey:kSPKPrismSubmenuProbeKey] isEqualToString:token])
            return;

        blocked = YES;
        [defaults setObject:token forKey:kSPKPrismSubmenuBlockedKey];
        [defaults removeObjectForKey:kSPKPrismSubmenuProbeKey];
        SPKWarnLog(@"PrismMenu", @"Submenu did not survive IG %@, using flat rows", token);
    });
    return blocked;
}

// IG rejects a wrongly shaped array either while building the menu or while
// expanding it, and both are the user's next few seconds, so the probe is retired
// on a delay rather than on a signal that only some builds emit.
static void SPKDirectMarkSubmenuProbe(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults stringForKey:kSPKPrismSubmenuProbeKey])
        return;
    [defaults setObject:SPKDirectSubmenuProbeToken() forKey:kSPKPrismSubmenuProbeKey];
    [defaults synchronize];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kSPKPrismSubmenuProbeKey];
    });
}

static BOOL SPKDirectDeriveSubmenuShape(void) {
    Class elementClass = NSClassFromString(@"IGDSPrismMenuElement");
    uint64_t subtype = 0;
    if (!elementClass || !class_getInstanceVariable(elementClass, "_subMenu_subMenuItems"))
        return NO;
    if (SPKDirectSubmenuBlocked())
        return NO;
    if (!SPKDirectSubtypeForIvarGroup(elementClass, @"subMenu", &subtype))
        return NO;

    // What a submenu nests changed with the menu API: the newer generation nests
    // whole elements, the original one nests items, and IG rejects the array
    // outright when this is wrong. The two are told apart by the case list itself,
    // read from the shipped binaries: IG 410 has item/subMenu/header only, while the
    // generation that switched to nesting elements also added the spacer, attributed
    // text and horizontal cases.
    BOOL nestsElements = class_getInstanceVariable(elementClass, "_verticalSpacer_height") != NULL;
    Class childClass = nestsElements ? elementClass : NSClassFromString(@"IGDSPrismMenuItem");
    if (!childClass)
        return NO;

    sSPKPrismSubmenuSubtype = subtype;
    sSPKPrismSubmenuItemClass = childClass;
    sSPKPrismSubmenuShapeKnown = YES;
    SPKLog(@"PrismMenu", @"Derived submenu shape: subtype=%llu childClass=%@",
           (unsigned long long)subtype, childClass);
    return YES;
}

BOOL SPKDirectPrismSubmenuAvailable(void) {
    if (!sSPKPrismSubmenuShapeKnown)
        SPKDirectDeriveSubmenuShape();
    return sSPKPrismSubmenuShapeKnown && sSPKPrismSubmenuItemClass != Nil;
}

// Builds a single row of the derived child type. IG nests whole elements rather
// than bare items, so a child is normally another element of the template's class;
// the item forms are kept for builds shaped differently.
static id SPKDirectSubmenuChild(id templateElement, SPKDirectMenuAction *action) {
    Class itemClass = sSPKPrismSubmenuItemClass;
    if (!itemClass || !action)
        return nil;

    // Children are elements: reuse the plain-row builder, which copies the
    // template's subtype and so produces an item-case element.
    void (^handler)(void) = action.handler;

    if ([itemClass isSubclassOfClass:[templateElement class]] ||
        [[templateElement class] isSubclassOfClass:itemClass]) {
        return SPKDirectPrismMenuElement(templateElement, action.title, action.image, handler);
    }

    Class prismItemClass = NSClassFromString(@"IGDSPrismMenuItem");
    if (prismItemClass && [itemClass isSubclassOfClass:prismItemClass]) {
        Class builderClass = NSClassFromString(@"IGDSPrismMenuItemBuilder");
        if (!builderClass || ![builderClass instancesRespondToSelector:@selector(initWithTitle:)])
            return nil;
        id builder = ((id (*)(id, SEL, id))objc_msgSend)([builderClass alloc], @selector(initWithTitle:), action.title);
        if (action.image && [builderClass instancesRespondToSelector:@selector(withImage:)])
            builder = ((id (*)(id, SEL, id))objc_msgSend)(builder, @selector(withImage:), action.image);
        builder = ((id (*)(id, SEL, id))objc_msgSend)(builder, @selector(withHandler:), handler);
        return ((id (*)(id, SEL))objc_msgSend)(builder, @selector(build));
    }

    SEL initTitleImageHandler = @selector(initWithTitle:image:handler:);
    if ([itemClass instancesRespondToSelector:initTitleImageHandler]) {
        void (^itemHandler)(id) = ^(__unused id item) {
            handler();
        };
        return ((id (*)(id, SEL, id, id, id))objc_msgSend)([itemClass alloc],
                                                           initTitleImageHandler,
                                                           action.title,
                                                           action.image,
                                                           itemHandler);
    }
    return nil;
}

// Index of a case in one of IG's tagged-union value objects, derived from the
// order of its payload ivar groups. Only trustworthy for the first group, since a
// case carrying no payload contributes no ivars and would shift later indices;
// the submenu case is learned from a live element instead.
static BOOL SPKDirectFirstCaseHasPrefix(Class cls, const char *prefix) {
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(cls, &count);
    if (!ivars)
        return NO;
    BOOL matches = NO;
    for (unsigned int i = 0; i < count; i++) {
        const char *name = ivar_getName(ivars[i]);
        if (!name || strcmp(name, "_subtype") == 0)
            continue;
        matches = (strncmp(name, prefix, strlen(prefix)) == 0);
        break;
    }
    free(ivars);
    return matches;
}

// The disclosure chevron IG's own submenu rows carry.
static id SPKDirectSubmenuAccessory(void) {
    Class accessoryClass = NSClassFromString(@"IGDSPrismMenuItemAccessory");
    if (!accessoryClass || !SPKDirectFirstCaseHasPrefix(accessoryClass, "_image_")) {
        SPKWarnLog(@"PrismMenu", @"No image accessory case on %@", accessoryClass);
        return nil;
    }

    UIImage *chevron = [SPKAssetUtils instagramIconNamed:@"chevron_right" pointSize:16.0];
    if (!chevron)
        chevron = [UIImage systemImageNamed:@"chevron.right"];
    Ivar subtypeIvar = class_getInstanceVariable(accessoryClass, "_subtype");
    Ivar imageIvar = class_getInstanceVariable(accessoryClass, "_image_image");
    id accessory = [accessoryClass new];
    if (!chevron || !accessory || !subtypeIvar || !imageIvar)
        return nil;

    *(uint64_t *)((uint8_t *)(__bridge void *)accessory + ivar_getOffset(subtypeIvar)) = 0;
    object_setIvar(accessory, imageIvar, chevron);
    return accessory;
}

id SPKDirectPrismSubmenuElement(id templateElement, NSString *title, UIImage *image, NSArray<SPKDirectMenuAction *> *actions) {
    if (!SPKDirectPrismSubmenuAvailable() || !templateElement || title.length == 0 || actions.count == 0)
        return nil;

    Class builderClass = NSClassFromString(@"IGDSPrismMenuItemBuilder");
    if (!builderClass || ![builderClass instancesRespondToSelector:@selector(initWithTitle:)])
        return nil;

    NSMutableArray *items = [NSMutableArray arrayWithCapacity:actions.count];
    for (SPKDirectMenuAction *action in actions) {
        id item = SPKDirectSubmenuChild(templateElement, action);
        if (!item) {
            SPKWarnLog(@"PrismMenu", @"Could not build submenu row '%@'", action.title);
            return nil;
        }
        [items addObject:item];
    }

    // The parent row opens the submenu instead of running a handler; the item is
    // only its title and icon.
    id builder = ((id (*)(id, SEL, id))objc_msgSend)([builderClass alloc], @selector(initWithTitle:), title);
    if (image && [builderClass instancesRespondToSelector:@selector(withImage:)])
        builder = ((id (*)(id, SEL, id))objc_msgSend)(builder, @selector(withImage:), image);
    id accessory = [builderClass instancesRespondToSelector:@selector(withAccessory:)] ? SPKDirectSubmenuAccessory() : nil;
    if (accessory)
        builder = ((id (*)(id, SEL, id))objc_msgSend)(builder, @selector(withAccessory:), accessory);
    id parentItem = ((id (*)(id, SEL))objc_msgSend)(builder, @selector(build));
    if (!parentItem)
        return nil;

    Class elementClass = [templateElement class];
    Ivar subtypeIvar = class_getInstanceVariable(elementClass, "_subtype");
    Ivar parentIvar = class_getInstanceVariable(elementClass, "_subMenu_menuItem");
    Ivar itemsIvar = class_getInstanceVariable(elementClass, "_subMenu_subMenuItems");
    Ivar isHeaderIvar = class_getInstanceVariable(elementClass, "_subMenu_isHeader");
    id element = [elementClass new];
    if (!element || !subtypeIvar || !parentIvar || !itemsIvar)
        return nil;

    *(uint64_t *)((uint8_t *)(__bridge void *)element + ivar_getOffset(subtypeIvar)) = sSPKPrismSubmenuSubtype;
    object_setIvar(element, parentIvar, parentItem);
    object_setIvar(element, itemsIvar, [items copy]);
    SPKDirectMarkSubmenuProbe();
    if (isHeaderIvar)
        *(bool *)((uint8_t *)(__bridge void *)element + ivar_getOffset(isHeaderIvar)) = false;
    objc_setAssociatedObject(element, kSPKDirectSparkleRowKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return element;
}

BOOL SPKDirectMenuContainsSparkleSubmenu(NSArray *elements) {
    if (![elements isKindOfClass:NSArray.class])
        return NO;
    for (id element in elements) {
        if (!objc_getAssociatedObject(element, kSPKDirectSparkleRowKey))
            continue;
        id submenuItems = SPKDirectIvarObject(element, "_subMenu_subMenuItems");
        if ([submenuItems isKindOfClass:NSArray.class] && [(NSArray *)submenuItems count] > 0)
            return YES;
    }
    return NO;
}

id SPKDirectPrismMenuElement(id templateElement, NSString *title, UIImage *image, void (^handler)(void)) {
    return SPKDirectPrismMenuElementWithSubtitle(templateElement, title, nil, image, handler);
}

BOOL SPKDirectMenuContainsSparkleRow(NSArray *elements) {
    if (![elements isKindOfClass:NSArray.class])
        return NO;
    for (id element in elements) {
        if (objc_getAssociatedObject(element, kSPKDirectSparkleRowKey))
            return YES;
    }
    return NO;
}

id SPKDirectPrismMenuElementWithSubtitle(id templateElement,
                                         NSString *title,
                                         NSString *subtitle,
                                         UIImage *image,
                                         void (^handler)(void)) {
    Class builderClass = NSClassFromString(@"IGDSPrismMenuItemBuilder");
    if (!builderClass || !templateElement || title.length == 0 || !handler)
        return nil;

    SEL initSelector = @selector(initWithTitle:);
    SEL imageSelector = @selector(withImage:);
    SEL subtitleSelector = @selector(withSubtitle:);
    SEL handlerSelector = @selector(withHandler:);
    SEL buildSelector = @selector(build);
    if (![builderClass instancesRespondToSelector:initSelector] ||
        ![builderClass instancesRespondToSelector:imageSelector] ||
        ![builderClass instancesRespondToSelector:handlerSelector] ||
        ![builderClass instancesRespondToSelector:buildSelector]) {
        return nil;
    }

    id builder = ((id (*)(id, SEL, id))objc_msgSend)([builderClass alloc], initSelector, title);
    if (image)
        builder = ((id (*)(id, SEL, id))objc_msgSend)(builder, imageSelector, image);
    // Not every IG build exposes a subtitle; the row is still worth showing
    // without one.
    BOOL supportsSubtitle = [builderClass instancesRespondToSelector:subtitleSelector];
    if (subtitle.length > 0 && supportsSubtitle)
        builder = ((id (*)(id, SEL, id))objc_msgSend)(builder, subtitleSelector, subtitle);
    if (subtitle.length > 0 && !supportsSubtitle)
        SPKLog(@"GifTitle", @"Builder has no withSubtitle:, dropping '%@'", subtitle);
    builder = ((id (*)(id, SEL, id))objc_msgSend)(builder, handlerSelector, handler);

    id menuItem = ((id (*)(id, SEL))objc_msgSend)(builder, buildSelector);
    if (!menuItem)
        return nil;

    id element = [[templateElement class] new];
    Ivar subtypeIvar = class_getInstanceVariable([templateElement class], "_subtype");
    Ivar itemIvar = class_getInstanceVariable([templateElement class], "_item_menuItem");
    if (!element || !subtypeIvar || !itemIvar)
        return nil;

    ptrdiff_t subtypeOffset = ivar_getOffset(subtypeIvar);
    *(uint64_t *)((uint8_t *)(__bridge void *)element + subtypeOffset) =
        *(uint64_t *)((uint8_t *)(__bridge void *)templateElement + subtypeOffset);
    object_setIvar(element, itemIvar, menuItem);
    objc_setAssociatedObject(element, kSPKDirectSparkleRowKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return element;
}
