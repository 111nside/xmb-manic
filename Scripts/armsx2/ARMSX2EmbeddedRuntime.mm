#import "ARMSX2EmbeddedRuntime.h"

#import <UIKit/UIKit.h>

#import "ARMSX2Bridge.h"
#import "IOS/PCSX2SceneDelegate.h"
#include "IOS/IOSRuntime.h"

#include "common/Console.h"
#include "pcsx2/Config.h"

#include <cstdlib>
#include <string>

@interface PCSX2SceneDelegate (ARMSX2EmbeddedPrivate)
- (void)checkJITAndStartVM;
@end

namespace {

PCSX2SceneDelegate *g_embeddedSceneDelegate = nil;
bool g_embeddedPrepared = false;

static void ARMSX2EmbeddedCreateDirectories(const std::string& dataRoot)
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *root = [NSString stringWithUTF8String:dataRoot.c_str()];
    NSArray<NSString *> *dirs = @[
        @"bios", @"iso", @"logs", @"memcards", @"savestates",
        @"snaps", @"cheats", @"patches", @"cache", @"covers",
        @"gamesettings", @"textures", @"inputprofiles", @"videos",
        @"inis", @"resources"
    ];

    [fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
    for (NSString *name in dirs) {
        [fm createDirectoryAtPath:[root stringByAppendingPathComponent:name]
      withIntermediateDirectories:YES attributes:nil error:nil];
    }

    EmuFolders::DataRoot = dataRoot;
    EmuFolders::Settings = dataRoot + "/inis";
    EmuFolders::Bios = dataRoot + "/bios";
    EmuFolders::Logs = dataRoot + "/logs";
    EmuFolders::Savestates = dataRoot + "/savestates";
    EmuFolders::MemoryCards = dataRoot + "/memcards";
    EmuFolders::Snapshots = dataRoot + "/snaps";
    EmuFolders::Cheats = dataRoot + "/cheats";
    EmuFolders::Patches = dataRoot + "/patches";
    EmuFolders::Cache = dataRoot + "/cache";
    EmuFolders::Covers = dataRoot + "/covers";
    EmuFolders::GameSettings = dataRoot + "/gamesettings";
    EmuFolders::Textures = dataRoot + "/textures";
    EmuFolders::InputProfiles = dataRoot + "/inputprofiles";
    EmuFolders::UserResources = dataRoot + "/resources";
}

static UIWindowScene *ARMSX2EmbeddedForegroundWindowScene(void)
{
    UIWindowScene *fallback = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class])
            continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (!fallback)
            fallback = windowScene;
        if (scene.activationState == UISceneActivationStateForegroundActive)
            return windowScene;
    }
    return fallback;
}

static BOOL ARMSX2EmbeddedPrepareOnMain(void)
{
    if (g_embeddedPrepared && [ARMSX2Bridge gameRenderView] != nil)
        return YES;

    NSArray<NSString *> *documents = NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = documents.firstObject;
    if (documentsDirectory.length == 0)
        return NO;

    NSString *dataRootPath = [documentsDirectory stringByAppendingPathComponent:@"ARMSX2"];
    const std::string dataRoot = dataRootPath.UTF8String;
    ARMSX2EmbeddedCreateDirectories(dataRoot);
    setenv("ARMSX2_EMBEDDED_DATA_ROOT", dataRootPath.UTF8String, 1);

    NSBundle *frameworkBundle = [NSBundle bundleForClass:ARMSX2EmbeddedRuntime.class];
    NSString *resourcePath = frameworkBundle.resourcePath ?: frameworkBundle.bundlePath;
    if (resourcePath.length == 0)
        return NO;

    setenv("ARMSX2_EMBEDDED_BUNDLE_PATH", frameworkBundle.bundlePath.UTF8String, 1);
    EmuFolders::AppRoot = resourcePath.UTF8String;
    EmuFolders::Resources = resourcePath.UTF8String;

    NSArray<NSString *> *cachePaths = NSSearchPathForDirectoriesInDomains(
        NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheRoot = [[cachePaths firstObject] stringByAppendingPathComponent:@"ARMSX2"];
    if (cacheRoot.length > 0) {
        [[NSFileManager defaultManager] createDirectoryAtPath:cacheRoot
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
        setenv("XDG_CACHE_HOME", cacheRoot.UTF8String, 1);
    }

    ARMSX2ConfigureImGuiFonts("embedded-prepare");

    UIWindowScene *windowScene = ARMSX2EmbeddedForegroundWindowScene();
    if (!windowScene) {
        Console.Error("[Embedded] No UIWindowScene is available for ARMSX2 bootstrap");
        return NO;
    }

    if (!g_embeddedSceneDelegate)
        g_embeddedSceneDelegate = [[PCSX2SceneDelegate alloc] init];

    [g_embeddedSceneDelegate scene:windowScene
              willConnectToSession:windowScene.session
                           options:nil];

    g_embeddedPrepared = ([ARMSX2Bridge gameRenderView] != nil);
    Console.WriteLn("[Embedded] ARMSX2 prepare result=%d resources=%s data=%s",
                    g_embeddedPrepared ? 1 : 0,
                    EmuFolders::Resources.c_str(),
                    EmuFolders::DataRoot.c_str());
    return g_embeddedPrepared ? YES : NO;
}

} // namespace

@implementation ARMSX2EmbeddedRuntime

+ (BOOL)prepare
{
    if ([NSThread isMainThread])
        return ARMSX2EmbeddedPrepareOnMain();

    __block BOOL result = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{
        result = ARMSX2EmbeddedPrepareOnMain();
    });
    return result;
}

+ (BOOL)bootISOAtPath:(NSString *)path
{
    if (path.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path])
        return NO;

    if (![self prepare])
        return NO;

    if (![ARMSX2Bridge hasBIOS]) {
        Console.Warning("[Embedded] Cannot boot PS2 game: no valid BIOS is configured");
        return NO;
    }

    void (^prepareAndStart)(void) = ^{
        // Mirror ARMSX2's normal iOS lifecycle before a game boot. In particular,
        // sceneDidBecomeActive prewarms the persistent CPU worker while the JIT
        // grant is fresh, instead of doing all executable-memory setup during
        // the first black frame of gameplay.
        UIWindowScene *windowScene = ARMSX2EmbeddedForegroundWindowScene();
        if (windowScene)
            [g_embeddedSceneDelegate sceneDidBecomeActive:windowScene];

        [ARMSX2Bridge bootISO:path];
        [ARMSX2Bridge prepareGameRenderViewForCurrentRenderer];

        // Give the embedded CAMetalLayer one main-runloop turn to settle on its
        // final bounds/window before entering ARMSX2's JIT gate.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            Console.WriteLn("[Embedded] Starting PS2 VM after render/JIT prewarm");
            [g_embeddedSceneDelegate checkJITAndStartVM];
        });
    };

    if ([NSThread isMainThread])
        prepareAndStart();
    else
        dispatch_async(dispatch_get_main_queue(), prepareAndStart);

    return YES;
}

+ (void)stop
{
    [ARMSX2Bridge requestVMStop];
}

@end
