#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPKActionDescriptor : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *iconName;

+ (instancetype)descriptorWithIdentifier:(NSString *)identifier
                                   title:(NSString *)title
                                iconName:(NSString *)iconName;

+ (nullable instancetype)descriptorForIdentifier:(NSString *)identifier;
+ (NSArray<SPKActionDescriptor *> *)availableSectionIconDescriptors;

@end

FOUNDATION_EXPORT NSString *SPKActionDescriptorDisplayTitle(NSString *identifier, NSString *_Nullable topicTitle);
FOUNDATION_EXPORT NSString *SPKActionDescriptorIconName(NSString *identifier);

NS_ASSUME_NONNULL_END
