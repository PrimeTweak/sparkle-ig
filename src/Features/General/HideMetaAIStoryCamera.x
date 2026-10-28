// Drops the Meta AI tools from the story camera's side menu before the menu lays
// them out, so the remaining tools close the gap. Driven by the Creation tools
// option of Hide Meta AI; tools are matched by their language-independent identifier.

#import "../../InstagramHeaders.h"
#import "../../Utils.h"

static BOOL SPKIsStoryCameraGenAITool(id tool) {
    if (![tool respondsToSelector:@selector(identifier)])
        return NO;
    id identifier = [tool identifier];
    return [identifier isKindOfClass:NSString.class] && [identifier hasPrefix:@"kIGStoryCameraToolIdentifierGenAI"];
}

static id SPKStoryCameraToolsWithoutGenAI(id tools) {
    if (![SPKUtils getBoolPref:@"general_hide_meta_ai_creation"] || ![tools isKindOfClass:NSArray.class])
        return tools;

    NSIndexSet *kept = [(NSArray *)tools indexesOfObjectsPassingTest:^BOOL(id tool, NSUInteger idx, BOOL *stop) {
        return !SPKIsStoryCameraGenAITool(tool);
    }];
    if (kept.count == [(NSArray *)tools count])
        return tools;
    return [(NSArray *)tools objectsAtIndexes:kept];
}

%group SPKHideMetaAIStoryCameraHooks

%hook IGCameraToolsMenu

- (id)initWithTools:(id)tools store:(id)store {
    return %orig(SPKStoryCameraToolsWithoutGenAI(tools), store);
}

- (id)initWithTools:(id)tools userSession:(id)session {
    return %orig(SPKStoryCameraToolsWithoutGenAI(tools), session);
}

%end

%end

void SPKInstallHideMetaAIStoryCameraHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (NSClassFromString(@"IGCameraToolsMenu")) {
            %init(SPKHideMetaAIStoryCameraHooks);
        }
    });
}
