#import "SPKDirectReflection.h"

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

id SPKDirectIvarValue(id object, const char *name) {
    if (!object || !name)
        return nil;
    @try {
        for (Class cls = [object class]; cls && cls != NSObject.class; cls = class_getSuperclass(cls)) {
            Ivar ivar = class_getInstanceVariable(cls, name);
            if (ivar)
                return object_getIvar(object, ivar);
        }
    } @catch (__unused NSException *exception) {
    }
    return nil;
}

id SPKDirectValueForSelectorNamed(id object, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!object || ![object respondsToSelector:selector])
        return nil;
    @try {
        return ((id (*)(id, SEL))objc_msgSend)(object, selector);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

id SPKDirectValueForKey(id object, NSString *key) {
    if (!object || key.length == 0)
        return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

NSString *SPKDirectStringValue(id value) {
    if ([value isKindOfClass:NSString.class])
        return [(NSString *)value length] > 0 ? value : nil;
    if ([value respondsToSelector:@selector(stringValue)]) {
        NSString *string = [value stringValue];
        return string.length > 0 ? string : nil;
    }
    return nil;
}
