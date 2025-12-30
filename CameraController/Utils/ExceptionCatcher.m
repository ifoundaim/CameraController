//
//  ExceptionCatcher.m
//  CameraController
//

#import "ExceptionCatcher.h"

id _Nullable CCObjCTryCatch(id _Nullable (^ _Nonnull block)(void), NSString * _Nullable __autoreleasing * _Nullable errorOut) {
    @try {
        return block();
    } @catch (NSException *exception) {
        if (errorOut) {
            *errorOut = exception.reason ?: @"Unknown NSException";
        }
        return nil;
    }
}
