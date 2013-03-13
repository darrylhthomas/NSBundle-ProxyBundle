//
//  NSProxy+ProxyBundle.m
//  BundleFly
//
//  Created by Darryl H. Thomas on 3/11/13.
//  Copyright (c) 2013 Darryl H. Thomas. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import <objc/runtime.h>
#import "NSBundle+ProxyBundle.h"

@interface BPRProxyBundle : NSBundle

+ (void)bpr_swizzleMethods;
+ (void)setSubstitutionBundle:(NSBundle *)bundle;
+ (void)invalidateCaches;

@end

static BPRProxyBundle *BPRMainBundleInstance = nil;
static NSBundle *BPRSubstitutionBundle = nil;

#if TARGET_OS_IPHONE
static NSCache *BPRImageCache = nil;

@interface BPRImage : UIImage

+ (UIImage *)bpr_imageNamed:(NSString *)name;
+ (void)bpr_swizzleMethods;

@end

@implementation BPRImage

+(void)initialize
{
    BPRImageCache = [[NSCache alloc] init];
    BPRImageCache.name = @"BPRImageCache";
}

+ (NSString *)bpr_pathForFile:(NSString *)filename inDirectories:(NSArray *)directories
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *result = nil;
    for (NSString *directoryPath in directories) {
        NSString *filePath = [directoryPath stringByAppendingPathComponent:filename];
        if ([fileManager fileExistsAtPath:filePath]) {
            result = filePath;
            break;
        }
    }
    return result;
}

// These possible filenames are based on observation of the order files [UIImage imageNamed:] looks for.
// It's fragile, since Apple could change this in future releases.
+ (NSString *)bpr_resolvePathForImageName:(NSString *)name inDirectories:(NSArray *)searchDirectories
{
    NSString *baseName = [name stringByDeletingPathExtension];
    NSString *extension = [name pathExtension];
    if (![extension length]) {
        extension = @"png";
    }
    NSString *deviceString = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad ? @"ipad" : @"iphone";
    int scaleInt = (int)roundf([[UIScreen mainScreen] scale]);
    
    NSString *possibleFilename = nil;
    NSString *resolvedPath = nil;
    if (scaleInt != 1) {
        possibleFilename = [NSString stringWithFormat:@"%1$@@%3$dx~%4$@.%2$@", baseName, extension, scaleInt, deviceString];
        resolvedPath = [BPRImage bpr_pathForFile:possibleFilename inDirectories:searchDirectories];
        
        if (!resolvedPath) {
            possibleFilename = [NSString stringWithFormat:@"%1$@_%3$donly_@%3$dx~%4$@.%2$@", baseName, extension, scaleInt, deviceString];
            resolvedPath = [BPRImage bpr_pathForFile:possibleFilename inDirectories:searchDirectories];
        }
        
        if (!resolvedPath) {
            possibleFilename = [NSString stringWithFormat:@"%1$@@%3$dx.%2$@", baseName, extension, scaleInt];
            resolvedPath = [BPRImage bpr_pathForFile:possibleFilename inDirectories:searchDirectories];
        }
        
        if (!resolvedPath) {
            possibleFilename = [NSString stringWithFormat:@"%1$@_%3$donly_@%3$dx.%2$@", baseName, extension, scaleInt];
            resolvedPath = [BPRImage bpr_pathForFile:possibleFilename inDirectories:searchDirectories];
        }
    }
    
    if (!resolvedPath) {
        possibleFilename = [NSString stringWithFormat:@"%1$@~%3$@.%2$@", baseName, extension, deviceString];
        resolvedPath = [BPRImage bpr_pathForFile:possibleFilename inDirectories:searchDirectories];
        
        if (!resolvedPath) {
            possibleFilename = [NSString stringWithFormat:@"%1$@.%2$@", baseName, extension];
            resolvedPath = [BPRImage bpr_pathForFile:possibleFilename inDirectories:searchDirectories];
        }
        
        if (!resolvedPath) {
            possibleFilename = [NSString stringWithFormat:@"%1$@@1x~%3$@.%2$@", baseName, extension, deviceString];
            resolvedPath = [BPRImage bpr_pathForFile:possibleFilename inDirectories:searchDirectories];
        }
        
        if (!resolvedPath) {
            possibleFilename = [NSString stringWithFormat:@"%1$@_1only_~%3$@.%2$@", baseName, extension, deviceString];
            resolvedPath = [BPRImage bpr_pathForFile:possibleFilename inDirectories:searchDirectories];
        }
        
        if (!resolvedPath) {
            possibleFilename = [NSString stringWithFormat:@"%1$@@1x.%2$@", baseName, extension];
            resolvedPath = [BPRImage bpr_pathForFile:possibleFilename inDirectories:searchDirectories];
        }
        
        if (!resolvedPath) {
            possibleFilename = [NSString stringWithFormat:@"%1$@_1only_.%2$@", baseName, extension];
            resolvedPath = [BPRImage bpr_pathForFile:possibleFilename inDirectories:searchDirectories];
        }
        
        if (!resolvedPath) {
            possibleFilename = [NSString stringWithFormat:@"%1$@~%2$@", baseName, deviceString];
            resolvedPath = [BPRImage bpr_pathForFile:possibleFilename inDirectories:searchDirectories];
        }
        
        if (!resolvedPath) {
            possibleFilename = baseName;
            resolvedPath = [BPRImage bpr_pathForFile:possibleFilename inDirectories:searchDirectories];
        }
        
    }

    return resolvedPath;
}

+ (UIImage *)bpr_imageNamed:(NSString *)name
{
    UIImage *result = [BPRImageCache objectForKey:name];
    if (!result) {
        if (BPRSubstitutionBundle) {
            NSArray *searchDirectories = @[
                                           [BPRSubstitutionBundle bundlePath],
                                           [[NSBundle mainBundle] bundlePath],
                                           ];
            
            NSString *path = [BPRImage bpr_resolvePathForImageName:name inDirectories:searchDirectories];
            
            if (path) {
                result = [UIImage imageWithContentsOfFile:path];
            }
        } else {
            result = [BPRImage bpr_imageNamed:name];
        }
        
        if (result) {
            [BPRImageCache setObject:result forKey:name];
        }
    }
    
    return result;
}

+ (void)bpr_swizzleMethods
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class myClass = objc_getClass("BPRImage");
        Class uiImageClass = objc_getClass("UIImage");
        Method bprMethod = class_getClassMethod(myClass, @selector(bpr_imageNamed:));
        Method uiMethod = class_getClassMethod(uiImageClass, @selector(imageNamed:));
        
        method_exchangeImplementations(bprMethod, uiMethod);
    });
}

@end

#endif

@implementation BPRProxyBundle
{
    NSBundle *_proxiedBundle;
}

+ (NSBundle *)bpr_mainBundle
{
    if (BPRMainBundleInstance == nil) {
        BPRMainBundleInstance = [[BPRProxyBundle alloc] initWithProxiedBundle:[BPRProxyBundle bpr_mainBundle]];
    }
    
    return BPRMainBundleInstance;
}

+ (void)bpr_swizzleMethods
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class myClass = objc_getClass("BPRBundle");
        Class nsBundleClass = objc_getClass("NSBundle");
        Method bprMethod = class_getClassMethod(myClass, @selector(bpr_mainBundle));
        Method nsMethod = class_getClassMethod(nsBundleClass, @selector(mainBundle));
        
        method_exchangeImplementations(bprMethod, nsMethod);
        
#if TARGET_OS_IPHONE
        [BPRImage bpr_swizzleMethods];
#endif
        
    });
}

+ (void)setSubstitutionBundle:(NSBundle *)bundle
{
    [BPRProxyBundle bpr_swizzleMethods];
    BPRSubstitutionBundle = bundle;
#if TARGET_OS_IPHONE
    [BPRImageCache removeAllObjects];
#endif
}

+ (void)invalidateCaches
{
#if TARGET_OS_IPHONE
    [BPRImageCache removeAllObjects];
#endif
}

- (id)initWithProxiedBundle:(NSBundle *)bundle
{
    self = [super init];
    if (self) {
        _proxiedBundle = bundle;
    }
    
    return self;
}

- (BOOL)load
{
    return [_proxiedBundle load];
}

- (BOOL)isLoaded
{
    return [_proxiedBundle isLoaded];
}

- (BOOL)unload
{
    return [_proxiedBundle unload];
}

- (BOOL)preflightAndReturnError:(NSError *__autoreleasing *)error
{
    return [_proxiedBundle preflightAndReturnError:error];
}

- (BOOL)loadAndReturnError:(NSError *__autoreleasing *)error
{
    return [_proxiedBundle loadAndReturnError:error];
}

- (NSURL *)bundleURL
{
    return [_proxiedBundle bundleURL];
}

- (NSURL *)resourceURL
{
    return [_proxiedBundle resourceURL];
}

- (NSURL *)executableURL
{
    return [_proxiedBundle executableURL];
}

- (NSURL *)URLForAuxiliaryExecutable:(NSString *)executableName
{
    return [_proxiedBundle URLForAuxiliaryExecutable:executableName];
}

- (NSURL *)privateFrameworksURL
{
    return [_proxiedBundle privateFrameworksURL];
}

- (NSURL *)sharedFrameworksURL
{
    return [_proxiedBundle sharedFrameworksURL];
}

- (NSURL *)sharedSupportURL
{
    return [_proxiedBundle sharedSupportURL];
}

- (NSURL *)builtInPlugInsURL
{
    return [_proxiedBundle builtInPlugInsURL];
}

- (NSURL *)appStoreReceiptURL
{
#if TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE)
    if ([_proxiedBundle respondsToSelector:@selector(appStoreReceiptURL)]) {
        return [_proxiedBundle appStoreReceiptURL];
    }
#endif
    return nil;
}

- (NSString *)bundlePath
{
    return [_proxiedBundle bundlePath];
}

- (NSString *)resourcePath
{
    return [_proxiedBundle resourcePath];
}

- (NSString *)executablePath
{
    return [_proxiedBundle executablePath];
}

- (NSString *)pathForAuxiliaryExecutable:(NSString *)executableName
{
    return [_proxiedBundle pathForAuxiliaryExecutable:executableName];
}

- (NSString *)privateFrameworksPath
{
    return [_proxiedBundle privateFrameworksPath];
}

- (NSString *)sharedFrameworksPath
{
    return [_proxiedBundle sharedFrameworksPath];
}

- (NSString *)sharedSupportPath
{
    return [_proxiedBundle sharedSupportPath];
}

- (NSString *)builtInPlugInsPath
{
    return [_proxiedBundle builtInPlugInsPath];
}

- (NSURL *)URLForResource:(NSString *)name withExtension:(NSString *)ext
{
    NSURL *result = [BPRSubstitutionBundle URLForResource:name withExtension:ext];
    if (!result) {
        result = [_proxiedBundle URLForResource:name withExtension:ext];
    }
    return result;
}

- (NSURL *)URLForResource:(NSString *)name withExtension:(NSString *)ext subdirectory:(NSString *)subpath
{
    NSURL *result = [BPRSubstitutionBundle URLForResource:name withExtension:ext subdirectory:subpath];
    if (!result) {
        result = [_proxiedBundle URLForResource:name withExtension:ext subdirectory:subpath];
    }
    return result;
}

- (NSURL *)URLForResource:(NSString *)name withExtension:(NSString *)ext subdirectory:(NSString *)subpath localization:(NSString *)localizationName
{
    NSURL *result = [BPRSubstitutionBundle URLForResource:name withExtension:ext subdirectory:subpath localization:localizationName];
    if (!result) {
        result = [_proxiedBundle URLForResource:name withExtension:ext subdirectory:subpath localization:localizationName];
    }
    return result;
}

- (NSArray *)URLsForPaths:(NSArray *)paths
{
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:[paths count]];
    for (NSString *path in paths) {
        NSURL *url = [NSURL fileURLWithPath:path];
        [result addObject:url];
    }
    
    return [result copy];
}

- (NSArray *)URLsForResourcesWithExtension:(NSString *)ext subdirectory:(NSString *)subpath
{
    NSArray *paths = [self pathsForResourcesOfType:ext inDirectory:subpath];
    
    return [self URLsForPaths:paths];
}

- (NSArray *)URLsForResourcesWithExtension:(NSString *)ext subdirectory:(NSString *)subpath localization:(NSString *)localizationName
{
    NSArray *paths = [self pathsForResourcesOfType:ext inDirectory:subpath forLocalization:localizationName];
    
    return [self URLsForPaths:paths];
}

- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)ext
{
    NSString *result = [BPRSubstitutionBundle pathForResource:name ofType:ext];
    if (!result) {
        result = [_proxiedBundle pathForResource:name ofType:ext];
    }
    return result;
}

- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)ext inDirectory:(NSString *)subpath
{
    NSString *result = [BPRSubstitutionBundle pathForResource:name ofType:ext inDirectory:subpath];
    if (!result) {
        result = [_proxiedBundle pathForResource:name ofType:ext inDirectory:subpath];
    }
    return result;
}

- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)ext inDirectory:(NSString *)subpath forLocalization:(NSString *)localizationName
{
    NSString *result = [BPRSubstitutionBundle pathForResource:name ofType:ext inDirectory:subpath forLocalization:localizationName];
    if (!result) {
        result = [_proxiedBundle pathForResource:name ofType:ext inDirectory:subpath forLocalization:localizationName];
    }
    return result;
}

- (NSArray *)reconcileSubstitutePaths:(NSArray *)substitutePaths againstProxiedPaths:(NSArray *)proxiedPaths
{
    NSMutableArray *result = [proxiedPaths mutableCopy];
    NSString *proxiedBasePath = [_proxiedBundle bundlePath];
    NSUInteger proxiedBasePathLength = [proxiedBasePath length];
    NSMutableArray *relativePaths = [[NSMutableArray alloc] initWithCapacity:[result count]];
    for (NSString *proxiedPath in result) {
        NSString *relativePath = [proxiedPath substringWithRange:NSMakeRange(proxiedBasePathLength, [proxiedPath length] - proxiedBasePathLength)];
        [relativePaths addObject:relativePath];
    }
    
    NSString *substituteBasePath = [BPRSubstitutionBundle bundlePath];
    NSUInteger substituteBasePathLength = [substituteBasePath length];
    for (NSString *substitutePath in substitutePaths) {
        NSString *relativePath = [substitutePath substringWithRange:NSMakeRange(substituteBasePathLength, [substitutePath length] - substituteBasePathLength)];
        NSUInteger index = [relativePaths indexOfObject:relativePath];
        if (index == NSNotFound) {
            [result addObject:substitutePath];
        } else {
            [result replaceObjectAtIndex:index withObject:substitutePath];
        }
    }
    
    return [result copy];
}

- (NSArray *)pathsForResourcesOfType:(NSString *)ext inDirectory:(NSString *)subpath
{
    NSArray *substitutePaths = [BPRSubstitutionBundle pathsForResourcesOfType:ext inDirectory:subpath];
    NSArray *proxiedPaths = [_proxiedBundle pathsForResourcesOfType:ext inDirectory:subpath];
    
    return [self reconcileSubstitutePaths:substitutePaths againstProxiedPaths:proxiedPaths];
}

- (NSArray *)pathsForResourcesOfType:(NSString *)ext inDirectory:(NSString *)subpath forLocalization:(NSString *)localizationName
{
    NSArray *substitutePaths = [BPRSubstitutionBundle pathsForResourcesOfType:ext inDirectory:subpath forLocalization:localizationName];
    NSArray *proxiedPaths = [_proxiedBundle pathsForResourcesOfType:ext inDirectory:subpath forLocalization:localizationName];
    
    return [self reconcileSubstitutePaths:substitutePaths againstProxiedPaths:proxiedPaths];
}

- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName
{
    NSString *result = nil;
    NSString *substitutionResult = [BPRSubstitutionBundle localizedStringForKey:key value:value table:tableName];
    // If there was no table entry, we'll get back the key we provided, so lookup the string in the proxied bundle
    if ([substitutionResult isEqualToString:key]) {
        result = [_proxiedBundle localizedStringForKey:key value:value table:tableName];
    } else {
        result = substitutionResult;
    }
    
    return result;
}

- (NSString *)bundleIdentifier
{
    return [_proxiedBundle bundleIdentifier];
}

- (BOOL)hasSubstituteInfoDictionary
{
    if (BPRSubstitutionBundle) {
        NSString *path = [[BPRSubstitutionBundle bundlePath] stringByAppendingPathComponent:@"Info.plist"];
        return ([[NSFileManager defaultManager] fileExistsAtPath:path]);
    }
    
    return NO;
}

- (NSDictionary *)infoDictionary
{
    return [self hasSubstituteInfoDictionary] ? [BPRSubstitutionBundle infoDictionary] : [_proxiedBundle infoDictionary];
}

- (NSDictionary *)localizedInfoDictionary
{
    return [self hasSubstituteInfoDictionary] ? [BPRSubstitutionBundle localizedInfoDictionary] : [_proxiedBundle infoDictionary];
}

- (id)objectForInfoDictionaryKey:(NSString *)key
{
    return [self hasSubstituteInfoDictionary] ? [BPRSubstitutionBundle objectForInfoDictionaryKey:key] : [_proxiedBundle objectForInfoDictionaryKey:key];
}

- (Class)classNamed:(NSString *)className
{
    return [_proxiedBundle classNamed:className];
}

- (Class)principalClass
{
    return [_proxiedBundle principalClass];
}

- (NSArray *)localizations
{
    NSMutableSet *localizationsSet = [[NSMutableSet alloc] init];
    NSArray *localizations = [BPRSubstitutionBundle localizations];
    if (localizations)
        [localizationsSet addObjectsFromArray:localizations];
    localizations = [_proxiedBundle localizations];
    if (localizations)
        [localizationsSet addObjectsFromArray:localizations];
    
    return [localizationsSet allObjects];
}

- (NSArray *)preferredLocalizations
{
    NSArray *result = [[self class] preferredLocalizationsFromArray:[self localizations]];
    
    return result;
}

- (NSString *)developmentLocalization
{
    NSString *result = [BPRSubstitutionBundle developmentLocalization];
    if (!result) {
        result = [_proxiedBundle developmentLocalization];
    }
    return result;
}

- (NSArray *)executableArchitectures
{
    return [_proxiedBundle executableArchitectures];
}

- (NSString *)description
{
    return [[_proxiedBundle description] stringByAppendingString:@" (proxied)"];
}


@end

@implementation NSBundle (ProxyBundle)

+(void)bpr_setMainBundleSubstitutionBundle:(NSBundle *)bundle
{
    BOOL isProxyBundle = [bundle isKindOfClass:[BPRProxyBundle class]];
    NSAssert(!isProxyBundle, @"Substitution bundles must not be proxy bundles.");
    if (isProxyBundle)
        return;
    
    [BPRProxyBundle setSubstitutionBundle:bundle];
}

+(void)bpr_setMainBundleSubstitutionPath:(NSString *)basePath
{
    NSBundle *bundle = nil;
    if (basePath) {
        bundle = [[NSBundle alloc] initWithPath:basePath];
    }
    [self bpr_setMainBundleSubstitutionBundle:bundle];
}

+(void)bpr_invalidateCaches
{
    [BPRProxyBundle invalidateCaches];
}

@end
