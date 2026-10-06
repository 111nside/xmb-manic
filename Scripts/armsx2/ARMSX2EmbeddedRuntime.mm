#import "ARMSX2EmbeddedRuntime.h"

#import <UIKit/UIKit.h>

#import "ARMSX2Bridge.h"
#import "IOS/PCSX2SceneDelegate.h"
#include "IOS/IOSRuntime.h"

#include "common/Console.h"
#include "pcsx2/Config.h"

#include <cstdlib>
#include <string>


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
    if (g_embeddedPrepared &&
        g_embeddedSceneDelegate.window != nil &&
        Host::g_sdl_window != nullptr)
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

    g_embeddedPrepared = (g_embeddedSceneDelegate.window != nil &&
                          g_embeddedSceneDelegate.window.rootViewController != nil &&
                          Host::g_sdl_window != nullptr);
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

+ (void)showGameWindow
{
    void (^show)(void) = ^{
        if (![self prepare] || !g_embeddedSceneDelegate.window)
            return;

        UIWindow *window = g_embeddedSceneDelegate.window;
        window.hidden = NO;
        [window makeKeyAndVisible];

        UIView *rootView = window.rootViewController.view;
        [rootView setNeedsLayout];
        [rootView layoutIfNeeded];

        UIView *gameView = [ARMSX2Bridge gameRenderView];
        [gameView setNeedsLayout];
        [gameView layoutIfNeeded];

        Console.WriteLn("[Embedded] ARMSX2 game window shown window=%p root=%p root_size=%.0fx%.0f game=%p game_size=%.0fx%.0f",
                        window,
                        rootView,
                        rootView.bounds.size.width,
                        rootView.bounds.size.height,
                        gameView,
                        gameView.bounds.size.width,
                        gameView.bounds.size.height);
    };

    if ([NSThread isMainThread])
        show();
    else
        dispatch_async(dispatch_get_main_queue(), show);
}

+ (void)hideGameWindow
{
    void (^hide)(void) = ^{
        if (g_embeddedSceneDelegate.window) {
            g_embeddedSceneDelegate.window.hidden = YES;
            Console.WriteLn("[Embedded] ARMSX2 game window hidden");
        }
    };

    if ([NSThread isMainThread])
        hide();
    else
        dispatch_async(dispatch_get_main_queue(), hide);
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

    void (^prepareAndRequestBoot)(void) = ^{
        // Use ARMSX2's normal iOS boot-request path instead of calling the
        // SceneDelegate's private VM starter directly. The embedded SceneDelegate
        // installs the same boot observer as the standalone app.
        [ARMSX2Bridge bootISO:path];

        UIWindow *window = g_embeddedSceneDelegate.window;
        UIView *rootView = window.rootViewController.view;
        UIView *gameView = [ARMSX2Bridge gameRenderView];
        [rootView layoutIfNeeded];
        [gameView layoutIfNeeded];
        Console.WriteLn("[Embedded] PS2 boot request root=%p game=%p window=%p game_size=%.0fx%.0f",
                        rootView,
                        gameView,
                        window,
                        gameView.bounds.size.width,
                        gameView.bounds.size.height);

        // Let Auto Layout/CAMetalLayer commit the visible game surface before
        // the VM asks Metal for its render window.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            Console.WriteLn("[Embedded] Posting normal ARMSX2 VM boot request");
            [ARMSX2Bridge requestVMBootLoadingLastSaveState:NO];
        });
    };

    if ([NSThread isMainThread])
        prepareAndRequestBoot();
    else
        dispatch_async(dispatch_get_main_queue(), prepareAndRequestBoot);

    return YES;
}

+ (BOOL)bootBIOSBrowser
{
    if (![self prepare])
        return NO;

    if (![ARMSX2Bridge hasBIOS]) {
        Console.Warning("[Embedded] Cannot boot PS2 BIOS browser: no valid BIOS is configured");
        return NO;
    }

    void (^prepareAndRequestBoot)(void) = ^{
        // Boot with no disc and Fast Boot disabled. This enters the real PS2 BIOS
        // Browser/System Configuration UI, including the Memory Card screen.
        [ARMSX2Bridge setINIString:@"GameISO" key:@"BootISO" value:@""];
        [ARMSX2Bridge setINIBool:@"GameISO" key:@"FastBoot" value:NO];
        [ARMSX2Bridge setINIBool:@"EmuCore" key:@"EnableFastBoot" value:NO];
        [ARMSX2Bridge flushINISettings];

        UIWindow *window = g_embeddedSceneDelegate.window;
        UIView *rootView = window.rootViewController.view;
        UIView *gameView = [ARMSX2Bridge gameRenderView];
        [rootView layoutIfNeeded];
        [gameView layoutIfNeeded];
        Console.WriteLn("[Embedded] PS2 BIOS browser boot request root=%p game=%p window=%p game_size=%.0fx%.0f",
                        rootView,
                        gameView,
                        window,
                        gameView.bounds.size.width,
                        gameView.bounds.size.height);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            Console.WriteLn("[Embedded] Posting PS2 BIOS browser VM boot request");
            [ARMSX2Bridge requestVMBootLoadingLastSaveState:NO];
        });
    };

    if ([NSThread isMainThread])
        prepareAndRequestBoot();
    else
        dispatch_async(dispatch_get_main_queue(), prepareAndRequestBoot);

    return YES;
}

+ (void)stop
{
    [ARMSX2Bridge requestVMStop];
}

@end
