#ifdef __cplusplus
extern "C" {
#endif
void SPKInstallMessageSeenButtonHooksIfNeeded(void);
void SPKInstallStorySeenButtonHooksIfNeeded(void);
void SPKInstallStoryMentionsButtonHooksIfNeeded(void);
void SPKInstallDirectVisualSeenButtonHooksIfNeeded(void);
#ifdef __cplusplus
}
#endif

void SPKInstallSeenButtonHooksIfNeeded(void) {
    SPKInstallMessageSeenButtonHooksIfNeeded();
    SPKInstallStorySeenButtonHooksIfNeeded();
    SPKInstallStoryMentionsButtonHooksIfNeeded();
    SPKInstallDirectVisualSeenButtonHooksIfNeeded();
}
