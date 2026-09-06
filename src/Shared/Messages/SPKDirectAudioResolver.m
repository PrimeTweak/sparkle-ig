#import "SPKDirectAudioResolver.h"
#import "SPKStrings.h"

#import <objc/message.h>
#import <objc/runtime.h>

#import "../../Utils.h"
#import "../Audio/SPKAudioDownloadCoordinator.h"
#import "../Gallery/SPKGallerySaveMetadata.h"
#import "../UI/SPKIGAlertPresenter.h"
#import "../UI/SPKNotificationCenter.h"
#import "SPKDirectReflection.h"

static id SPKDirectAudioCandidateObject(UIView *view);

static BOOL SPKDirectAudioUsernameLooksUsable(NSString *username) {
    if (username.length == 0)
        return NO;
    NSString *lower = username.lowercaseString;
    if ([lower isEqualToString:@"direct"] || [lower isEqualToString:@"audio"] || [lower isEqualToString:@"media"])
        return NO;
    if ([lower hasPrefix:@"http://"] || [lower hasPrefix:@"https://"] || [lower hasPrefix:@"instagram://"])
        return NO;
    if ([username rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location != NSNotFound)
        return NO;
    if (username.length > 30)
        return NO;
    return YES;
}

static NSString *SPKDirectAudioStringForNames(id object, NSArray<NSString *> *names) {
    for (NSString *name in names) {
        NSString *string = SPKDirectStringValue(SPKDirectValueForSelectorNamed(object, name));
        if (!string)
            string = SPKDirectStringValue(SPKDirectValueForKey(object, name));
        if (SPKDirectAudioUsernameLooksUsable(string))
            return string;
    }
    return nil;
}

static BOOL SPKDirectAudioStringMatchesPK(NSString *string, NSString *pk) {
    if (string.length == 0 || pk.length == 0)
        return NO;
    return [string isEqualToString:pk];
}

static NSString *SPKDirectAudioPKForNames(id object, NSArray<NSString *> *names) {
    for (NSString *name in names) {
        NSString *string = SPKDirectStringValue(SPKDirectValueForSelectorNamed(object, name));
        if (!string)
            string = SPKDirectStringValue(SPKDirectValueForKey(object, name));
        if (string.length > 0)
            return string;
    }
    return nil;
}

static BOOL SPKDirectAudioShouldTraverseForUsername(id object) {
    if (!object)
        return NO;
    if ([object isKindOfClass:NSString.class] ||
        [object isKindOfClass:NSNumber.class] ||
        [object isKindOfClass:NSDate.class] ||
        [object isKindOfClass:NSURL.class] ||
        [object isKindOfClass:NSData.class] ||
        [object isKindOfClass:UIImage.class] ||
        [object isKindOfClass:UIView.class] ||
        [object isKindOfClass:UIViewController.class]) {
        return NO;
    }
    NSString *name = NSStringFromClass([object class]);
    return [name containsString:@"Direct"] ||
           [name containsString:@"Message"] ||
           [name containsString:@"Sender"] ||
           [name containsString:@"User"] ||
           [name containsString:@"Participant"] ||
           [name containsString:@"GraphQL"] ||
           [name containsString:@"GQL"] ||
           [name containsString:@"Model"];
}

static NSString *SPKDirectAudioSenderPKFromObject(id object, NSMutableSet<NSValue *> *visited, NSUInteger depth) {
    if (!object || depth > 5)
        return nil;
    if ([object isKindOfClass:NSDictionary.class]) {
        NSString *direct = SPKDirectAudioPKForNames(object, @[ @"senderPk", @"senderPK", @"senderId", @"senderID", @"messageSenderId", @"messageSenderID" ]);
        if (direct)
            return direct;
        for (NSString *key in @[ @"messageMetadata", @"metadata", @"messageCellViewModel", @"viewModel", @"message", @"item" ]) {
            NSString *pk = SPKDirectAudioSenderPKFromObject([(NSDictionary *)object objectForKey:key], visited, depth + 1);
            if (pk)
                return pk;
        }
        return nil;
    }
    if ([object isKindOfClass:NSArray.class] || [object isKindOfClass:NSSet.class])
        return nil;

    NSValue *identity = [NSValue valueWithNonretainedObject:object];
    if ([visited containsObject:identity])
        return nil;
    [visited addObject:identity];

    NSString *direct = SPKDirectAudioPKForNames(object, @[ @"senderPk", @"senderPK", @"senderId", @"senderID", @"messageSenderId", @"messageSenderID" ]);
    if (direct)
        return direct;

    for (NSString *name in @[ @"messageMetadata", @"metadata", @"messageCellViewModel", @"viewModel", @"message", @"item" ]) {
        id nested = SPKDirectValueForSelectorNamed(object, name) ?: SPKDirectValueForKey(object, name);
        if (nested && nested != object) {
            NSString *pk = SPKDirectAudioSenderPKFromObject(nested, visited, depth + 1);
            if (pk)
                return pk;
        }
    }
    return nil;
}

static BOOL SPKDirectAudioObjectMatchesPK(id object, NSString *pk) {
    NSString *objectPK = SPKDirectAudioPKForNames(object, @[ @"pk", @"PK", @"userPk", @"userPK", @"userId", @"userID", @"id", @"identifier" ]);
    return SPKDirectAudioStringMatchesPK(objectPK, pk);
}

static NSString *SPKDirectAudioUsernameForPKFromObject(id object, NSString *pk, NSMutableSet<NSValue *> *visited, NSUInteger depth) {
    if (!object || pk.length == 0 || depth > 7)
        return nil;

    if ([object isKindOfClass:NSDictionary.class]) {
        NSDictionary *dict = (NSDictionary *)object;
        id keyedValue = [dict objectForKey:pk];
        NSString *username = SPKDirectAudioUsernameForPKFromObject(keyedValue, pk, visited, depth + 1);
        if (username)
            return username;

        NSString *dictPK = SPKDirectAudioPKForNames(dict, @[ @"pk", @"PK", @"userPk", @"userPK", @"userId", @"userID", @"id", @"identifier" ]);
        if (SPKDirectAudioStringMatchesPK(dictPK, pk)) {
            NSString *direct = SPKDirectAudioStringForNames(dict, @[ @"username", @"userName", @"profileUsername", @"displayUsername" ]);
            if (direct)
                return direct;
        }

        for (NSString *key in @[ @"sender", @"senderUser", @"user", @"author", @"owner", @"participant", @"profile", @"threadUsers", @"users", @"participants", @"userMap" ]) {
            username = SPKDirectAudioUsernameForPKFromObject([dict objectForKey:key], pk, visited, depth + 1);
            if (username)
                return username;
        }
        for (id value in dict.allValues) {
            username = SPKDirectAudioUsernameForPKFromObject(value, pk, visited, depth + 1);
            if (username)
                return username;
        }
        return nil;
    }

    if ([object isKindOfClass:NSArray.class] || [object isKindOfClass:NSSet.class]) {
        for (id value in object) {
            NSString *username = SPKDirectAudioUsernameForPKFromObject(value, pk, visited, depth + 1);
            if (username)
                return username;
        }
        return nil;
    }

    if ([object isKindOfClass:NSString.class] ||
        [object isKindOfClass:NSNumber.class] ||
        [object isKindOfClass:NSDate.class] ||
        [object isKindOfClass:NSURL.class] ||
        [object isKindOfClass:NSData.class] ||
        [object isKindOfClass:UIImage.class]) {
        return nil;
    }

    NSValue *identity = [NSValue valueWithNonretainedObject:object];
    if ([visited containsObject:identity])
        return nil;
    [visited addObject:identity];

    if (SPKDirectAudioObjectMatchesPK(object, pk)) {
        NSString *direct = SPKDirectAudioStringForNames(object, @[ @"username", @"userName", @"profileUsername", @"displayUsername" ]);
        if (direct)
            return direct;
    }

    for (NSString *name in @[
             @"sender", @"senderUser", @"senderInfo", @"senderViewModel", @"messageSender",
             @"threadMessageSenderViewModel", @"messageSenderViewModel", @"user", @"author",
             @"owner", @"participant", @"profile", @"threadUsers", @"users", @"participants",
             @"userMap", @"message", @"messageMetadata", @"metadata", @"viewModel",
             @"messageViewModel", @"audioMessageViewModel", @"messageCellViewModel", @"model", @"item"
         ]) {
        id nested = SPKDirectValueForSelectorNamed(object, name) ?: SPKDirectValueForKey(object, name);
        if (nested && nested != object) {
            NSString *username = SPKDirectAudioUsernameForPKFromObject(nested, pk, visited, depth + 1);
            if (username)
                return username;
        }
    }

    if (!SPKDirectAudioShouldTraverseForUsername(object))
        return nil;
    for (Class cls = [object class]; cls && cls != NSObject.class; cls = class_getSuperclass(cls)) {
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList(cls, &count);
        for (unsigned int i = 0; i < count; i++) {
            Ivar ivar = ivars[i];
            const char *encoding = ivar_getTypeEncoding(ivar);
            if (!encoding || encoding[0] != '@')
                continue;
            const char *name = ivar_getName(ivar);
            NSString *ivarName = name ? [NSString stringWithUTF8String:name] : @"";
            NSString *lower = ivarName.lowercaseString;
            BOOL priority = [lower containsString:@"sender"] || [lower containsString:@"user"] || [lower containsString:@"participant"] || [lower containsString:@"message"] || [lower containsString:@"metadata"];
            if (!priority && depth > 3)
                continue;
            id value = nil;
            @try {
                value = object_getIvar(object, ivar);
            } @catch (__unused NSException *exception) {
                value = nil;
            }
            NSString *username = SPKDirectAudioUsernameForPKFromObject(value, pk, visited, depth + 1);
            if (username) {
                free(ivars);
                return username;
            }
        }
        free(ivars);
    }
    return nil;
}

static NSString *SPKDirectAudioUsernameFromObject(id object, NSMutableSet<NSValue *> *visited, NSUInteger depth) {
    if (!object || depth > 6)
        return nil;
    if ([object isKindOfClass:NSDictionary.class]) {
        NSString *direct = SPKDirectAudioStringForNames(object, @[ @"username", @"userName", @"senderUsername", @"senderUserName", @"sender_name" ]);
        if (direct)
            return direct;
        for (NSString *key in @[ @"sender", @"senderUser", @"user", @"author", @"owner", @"participant", @"profile", @"message", @"viewModel", @"messageMetadata" ]) {
            id nested = [(NSDictionary *)object objectForKey:key];
            NSString *username = SPKDirectAudioUsernameFromObject(nested, visited, depth + 1);
            if (username)
                return username;
        }
        for (id value in [(NSDictionary *)object allValues]) {
            NSString *username = SPKDirectAudioUsernameFromObject(value, visited, depth + 1);
            if (username)
                return username;
        }
        return nil;
    }
    if ([object isKindOfClass:NSArray.class] || [object isKindOfClass:NSSet.class]) {
        for (id value in object) {
            NSString *username = SPKDirectAudioUsernameFromObject(value, visited, depth + 1);
            if (username)
                return username;
        }
        return nil;
    }

    NSValue *identity = [NSValue valueWithNonretainedObject:object];
    if ([visited containsObject:identity])
        return nil;
    [visited addObject:identity];

    NSString *direct = SPKDirectAudioStringForNames(object, @[
        @"username", @"userName", @"senderUsername", @"senderUserName",
        @"senderName", @"senderDisplayName", @"displayUsername", @"profileUsername"
    ]);
    if (direct)
        return direct;

    for (NSString *name in @[
             @"sender", @"senderUser", @"senderInfo", @"senderViewModel", @"messageSender",
             @"threadMessageSenderViewModel", @"messageSenderViewModel", @"user", @"author",
             @"owner", @"participant", @"profile", @"message", @"messageMetadata", @"viewModel",
             @"messageViewModel", @"audioMessageViewModel", @"model", @"item"
         ]) {
        id nested = SPKDirectValueForSelectorNamed(object, name) ?: SPKDirectValueForKey(object, name);
        if (nested && nested != object) {
            NSString *username = SPKDirectAudioUsernameFromObject(nested, visited, depth + 1);
            if (username)
                return username;
        }
    }

    if (!SPKDirectAudioShouldTraverseForUsername(object))
        return nil;
    for (Class cls = [object class]; cls && cls != NSObject.class; cls = class_getSuperclass(cls)) {
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList(cls, &count);
        for (unsigned int i = 0; i < count; i++) {
            Ivar ivar = ivars[i];
            const char *encoding = ivar_getTypeEncoding(ivar);
            if (!encoding || encoding[0] != '@')
                continue;
            const char *name = ivar_getName(ivar);
            NSString *ivarName = name ? [NSString stringWithUTF8String:name] : @"";
            NSString *lower = ivarName.lowercaseString;
            BOOL priority = [lower containsString:@"sender"] || [lower containsString:@"user"] || [lower containsString:@"participant"] || [lower containsString:@"message"];
            if (!priority && depth > 2)
                continue;
            id value = nil;
            @try {
                value = object_getIvar(object, ivar);
            } @catch (__unused NSException *exception) {
                value = nil;
            }
            NSString *username = SPKDirectAudioUsernameFromObject(value, visited, depth + 1);
            if (username) {
                free(ivars);
                return username;
            }
        }
        free(ivars);
    }
    return nil;
}

NSString *SPKDirectAudioResolvedUsername(id object) {
    NSString *username = SPKDirectAudioUsernameFromObject(object, [NSMutableSet set], 0);
    if (username)
        return username;

    NSString *senderPK = SPKDirectAudioSenderPKFromObject(object, [NSMutableSet set], 0);
    if (!senderPK)
        return nil;
    return SPKDirectAudioUsernameForPKFromObject(object, senderPK, [NSMutableSet set], 0);
}

static NSString *SPKDirectAudioResolvedUsernameNearView(UIView *view, id primaryObject) {
    NSString *username = SPKDirectAudioResolvedUsername(primaryObject);
    if (username)
        return username;

    NSString *senderPK = SPKDirectAudioSenderPKFromObject(primaryObject, [NSMutableSet set], 0);
    for (UIView *candidateView = view; candidateView && candidateView != candidateView.window; candidateView = candidateView.superview) {
        id candidateObject = SPKDirectAudioCandidateObject(candidateView);
        username = SPKDirectAudioResolvedUsername(candidateObject);
        if (username)
            return username;

        if (senderPK.length > 0) {
            username = SPKDirectAudioUsernameForPKFromObject(candidateObject, senderPK, [NSMutableSet set], 0);
            if (username)
                return username;
        }
    }
    return nil;
}

static id SPKDirectAudioCandidateObject(UIView *view) {
    NSArray<NSString *> *selectors = @[ @"viewModel", @"messageViewModel", @"audioMessageViewModel", @"model", @"message", @"item" ];
    for (NSString *selector in selectors) {
        id value = SPKDirectValueForSelectorNamed(view, selector);
        if (value)
            return value;
    }
    for (NSString *ivar in @[ @"_viewModel", @"_messageViewModel", @"_audioMessageViewModel", @"_model", @"_message", @"_item" ]) {
        id value = SPKDirectIvarValue(view, ivar.UTF8String);
        if (value)
            return value;
    }
    return view;
}

SPKAudioItem *SPKDirectAudioItemForView(UIView *view, SPKAudioSource source) {
    id object = SPKDirectAudioCandidateObject(view);
    SPKAudioItem *item = [SPKAudioDownloadCoordinator audioItemFromMediaObject:object source:source];
    if (!item && view.superview) {
        item = [SPKAudioDownloadCoordinator audioItemFromMediaObject:SPKDirectAudioCandidateObject(view.superview) source:source];
    }
    if (!item)
        return nil;
    NSString *username = SPKDirectAudioResolvedUsernameNearView(view, object);
    if (username.length > 0) {
        item.artist = username;
    } else if (!item.artist.length) {
        item.artist = @"direct";
    }
    return item;
}

void SPKDirectPresentAudioActions(UIView *view, SPKAudioSource source) {
    SPKAudioItem *item = SPKDirectAudioItemForView(view, source);
    if (!item) {
        SPKNotify(kSPKNotificationDownloadShare, SPKL(@"GENERAL_AUDIO_PAGE_DOWNLOAD_COULD_NOT_FIND_AUDIO_URL_TEXT"), SPKL(@"MESSAGES_DIRECT_MESSAGE_MENU_REFRESH_THREAD_TRY_AGAIN_IF_URL_EXPIRED_TEXT"), @"error_filled", SPKNotificationToneError);
        return;
    }

    SPKGallerySaveMetadata *metadata = [[SPKGallerySaveMetadata alloc] init];
    metadata.source = (int16_t)[item gallerySource];
    metadata.sourceUsername = item.artist.length > 0 ? item.artist : @"direct";
    metadata.sourceMediaPK = item.mediaIdentifier;
    metadata.sourceMediaURLString = item.sourceURLString ?: item.url.absoluteString;

    UIViewController *presenter = [SPKUtils viewControllerForAncestralView:view] ?: topMostController();
    [SPKIGAlertPresenter presentActionSheetFromViewController:presenter
                                                        title:SPKL(@"MESSAGES_DIRECT_MESSAGE_MENU_AUDIO_TITLE")
                                                      message:nil
                                                      actions:@[
                                                          [SPKIGAlertAction actionWithTitle:SPKL(@"ALERT_ACTION_SAVE_AUDIO_FILES")
                                                                                      style:SPKIGAlertActionStyleDefault
                                                                                    handler:^{
                                                                                        [SPKAudioDownloadCoordinator performAction:SPKAudioActionSaveToFiles item:item presenter:presenter sourceView:view metadata:metadata notificationIdentifier:kSPKNotificationDownloadAudio];
                                                                                    }],
                                                          [SPKIGAlertAction actionWithTitle:SPKL(@"ALERT_ACTION_SHARE_AUDIO")
                                                                                      style:SPKIGAlertActionStyleDefault
                                                                                    handler:^{
                                                                                        [SPKAudioDownloadCoordinator performAction:SPKAudioActionConvertAndShare item:item presenter:presenter sourceView:view metadata:metadata notificationIdentifier:kSPKNotificationDownloadAudioShare];
                                                                                    }],
                                                          [SPKIGAlertAction actionWithTitle:SPKL(@"ALERT_ACTION_SAVE_AUDIO_GALLERY")
                                                                                      style:SPKIGAlertActionStyleDefault
                                                                                    handler:^{
                                                                                        [SPKAudioDownloadCoordinator performAction:SPKAudioActionConvertAndSaveToGallery item:item presenter:presenter sourceView:view metadata:metadata notificationIdentifier:kSPKNotificationDownloadAudioGallery];
                                                                                    }],
                                                          [SPKIGAlertAction actionWithTitle:SPKL(@"ALERT_ACTION_PLAY_AUDIO")
                                                                                      style:SPKIGAlertActionStyleDefault
                                                                                    handler:^{
                                                                                        [SPKAudioDownloadCoordinator performAction:SPKAudioActionPlay item:item presenter:presenter sourceView:view metadata:metadata notificationIdentifier:kSPKNotificationPlayAudio];
                                                                                    }],
                                                          [SPKIGAlertAction actionWithTitle:SPKL(@"ALERT_ACTION_COPY_AUDIO_DOWNLOAD_URL")
                                                                                      style:SPKIGAlertActionStyleDefault
                                                                                    handler:^{
                                                                                        [SPKAudioDownloadCoordinator performAction:SPKAudioActionCopyURL item:item presenter:presenter sourceView:view metadata:metadata notificationIdentifier:kSPKNotificationCopyAudioURL];
                                                                                    }],
                                                          [SPKIGAlertAction actionWithTitle:SPKL(@"ALERT_ACTION_CANCEL")
                                                                                      style:SPKIGAlertActionStyleCancel
                                                                                    handler:nil]
                                                      ]];
}
