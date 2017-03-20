//
//  SPPManager.h
//  EAAccessoryExample
//
//  Created by ray.lee on 2017/3/3.
//  Copyright © 2017年 Ray Lee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ExternalAccessory/ExternalAccessory.h>

@protocol SPPManagerListener <NSObject>

- (void)onConnected;
- (void)onDisconnected;
- (void)onRead:(nonnull NSData *)data;

@end

@interface SPPManager : NSObject <NSStreamDelegate, EAAccessoryDelegate>

+ (nonnull instancetype)shared;
- (void)registerEAAccessoryManagerNotifications;
- (void)unregisterEAAccessoryManagerNotifications;
- (void)setSPPManagerListener:(nullable id<SPPManagerListener>)listener;
- (void)connect;
- (void)disconnect;
- (void)write:(nullable NSData *) data;
@end
