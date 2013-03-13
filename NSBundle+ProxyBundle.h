//
//  NSProxy+ProxyBundle.h
//  BundleFly
//
//  Created by Darryl H. Thomas on 3/11/13.
//  Copyright (c) 2013 Darryl H. Thomas. All rights reserved.
//
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


// IMPORTANT!!!! Do not use this for production builds.
// The functionality provided by NSBundle+ProxyBundle is accomplished through
// the use of runtime hacks and should be considered very fragile.

#import <Foundation/Foundation.h>

@interface NSBundle (ProxyBundle)

/*
 NSBundle+ProxyBundle replaces the implementation of [NSBundle mainBundle] with one that returns a proxy bundle that looks for resources in the supplied substitution bundle before falling back to the actual main bundle. (Where appropriate, results are merged from the two sources.)
 This allows developers to swap out resources without having to re-build and install their targets.
 The supplied base path of the substitution bundle should mirror the structure of a standard application bundle. (Currently, only iOS-style bundles have been tested.)
 */
+(void)bpr_setMainBundleSubstitutionBundle:(NSBundle *)bundle;
+(void)bpr_setMainBundleSubstitutionPath:(NSString *)basePath;

/*
 NSBundle+ProxyBundle replaces the implementation of [UIImage imageNamed:] and uses its own cache to ensure updated files are reflected when calling +imageNamed:, you should call [NSBundle bpr_invalidateCaches] when appropriate.
 */
+(void)bpr_invalidateCaches;

@end
