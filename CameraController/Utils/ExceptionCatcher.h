//
//  ExceptionCatcher.h
//  CameraController
//
//  A tiny helper to wrap Objective-C exceptions so Swift callers can fail gracefully.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Executes `block` and catches any Objective-C exceptions, returning nil and populating `errorOut`.
id _Nullable CCObjCTryCatch(id _Nullable (^ _Nonnull block)(void), NSString * _Nullable __autoreleasing * _Nullable errorOut);

NS_ASSUME_NONNULL_END
