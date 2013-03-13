# NSBundle-ProxyBundle

NSBundle+ProxyBundle replaces the implementation of [NSBundle mainBundle] with one that returns a proxy bundle that looks for resources in the supplied substitution bundle before falling back to the actual main bundle. (Where appropriate, results are merged from the two sources.)

This allows developers to swap out/side-load resources without having to re-build and install their targets.

The supplied base path of the substitution bundle should mirror the structure of a standard application bundle. (Currently, only iOS-style bundles have been tested.)

## Warning:
NSBundle+ProxyBundle is intended for use as a developer tool and should not be included in production builds under any circumstances!! To achieve its goal, NSBundle+ProxyBundle makes use of method swizzling of Foundation classes and should be considered extremely fragile.

I recommend using the pre-processor to exclude the invocation of NSBundle+ProxyBundle methods from non-development builds and would suggest not including NSBundle+ProxyBundle.m in your production targets.

## Usage:
Include NSBundle+ProxyBundle.h in your application delegate's implementation file and set a substitution bundle:

    #import "ExampleAppDelegate.h"
    #import "NSBundle+ProxyBundle.h"
    
    @implementation ExampleAppDelegate
    
    - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
    {
        NSURL *auxBundleURL = nil;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *cacheDirectories = [fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask];
        if ([cacheDirectories count]) {
            NSURL *cacheDirURL = cacheDirectories[0];
            auxBundleURL = [cacheDirURL URLByAppendingPathComponent:@"aux_bundle" isDirectory:YES];
            if (![fileManager fileExistsAtPath:[auxBundleURL path]]) {
                [fileManager createDirectoryAtURL:auxBundleURL withIntermediateDirectories:YES attributes:nil error:NULL];
            }
        }
    
        if (auxBundleURL) {
            NSBundle *auxBundle = [[NSBundle alloc] initWithURL:auxBundleURL];
			
			// This is the important part
            [NSBundle bpr_setMainBundleSubstitutionBundle:auxBundle];
        }
    
        self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        self.window.rootViewController = [[UIViewController alloc] initWithNibName:nil inBundle:nil];
        [self.window makeKeyAndVisible];
        return YES;
    }

In the example above, a subdirectory in the caches directory named "aux_bundle" is used as a substitute bundle. Any images, nibs, localization files, etc located in this directory would be loaded as though they were part of the main application bundle. The contents of the substitute bundle override the main bundle, but if a resource is not found in the substitute bundle, an attempt will be made to find it in the main bundle.

## [UIImage imageNamed:] and Cache Invalidation
NSBundle+ProxyBundle also replaces the implementation of UIImage +imageNamed: so that substitute resources can be used. As with the existing +imageNamed: implementation, a cache is used to speed up subsequent requests for the same image resource.

Because you may wish to change the contents of your substitution bundle while the app is still running, you can call [NSBundle +bpr_invalidateCaches] to purge the cache and force fresh loads of requested images.
