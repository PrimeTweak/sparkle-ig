#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

id SPKObjectForSelector(id target, NSString *selectorName);
id SPKKVCObject(id target, NSString *key);
NSArray *SPKArrayFromCollection(id collection);
NSURL *SPKURLFromValue(id value);
NSString *SPKStringFromValue(id value);
NSString *SPKClassName(id object);

NSString *SPKUsernameFromMediaObject(id media);
NSString *SPKCaptionFromMediaObject(id media);
NSString *SPKSessionUsernameFromController(UIViewController *controller);

id SPKDirectCurrentMessageFromController(UIViewController *controller);
id SPKDirectResolvedMediaFromController(UIViewController *controller);
NSInteger SPKDirectCurrentIndexFromController(UIViewController *controller);
NSString *SPKDirectUsernameFromController(UIViewController *controller);

#ifdef __cplusplus
}
#endif
