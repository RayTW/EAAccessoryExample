//
//  SPPManager.m
//  EAAccessoryExample
//
//  Created by ray.lee on 2017/3/3.
//  Copyright © 2017年 Ray Lee. All rights reserved.
//

#import "SPPManager.h"

# define READ_BUFFER 255

@interface IOThread : NSThread
- (NSRunLoop *)currentRunLoop;
@end

@implementation IOThread{
    NSRunLoop *mRunLoop;
}

-(void)main{
    mRunLoop = [NSRunLoop currentRunLoop];
    [mRunLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
    
    while (![self isCancelled]) {
        [mRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

- (NSRunLoop *)currentRunLoop{
    return mRunLoop;
}
@end


static SPPManager *sInstance;

@implementation SPPManager{
    NSString *mProtocolString;
    EAAccessory *mEAAccessory;
    EASession *mEASession;
    IOThread *mIOThread;
    NSThread *mSendThread;
    NSMutableData *mWriteData;
    NSCondition *mCondition;
    Byte *mReadBuf;//必須記得 free(mReadBuf)
    id<SPPManagerListener> mSPPManagerListener;
    BOOL mIsConnected;
    NSObject *mIsCOnnectedLock;
}

+ (instancetype)shared{
    if(sInstance == nil){
        @synchronized ([SPPManager class]) {
            if(sInstance == nil){
                sInstance = [[SPPManager alloc] init];
            }
        }
    }
    return sInstance;
}

- (instancetype)init{
    if(self = [super init]){
        mReadBuf = (Byte*)malloc(READ_BUFFER);
        mWriteData = [[NSMutableData alloc] init];
        mIsCOnnectedLock = [[NSObject alloc] init];
        mIOThread = [[IOThread alloc] init];
        [mIOThread start];
        mCondition = [[NSCondition alloc]init];
        mSendThread = [[NSThread alloc] initWithTarget:self selector:@selector(doWrite) object:nil];
        [mSendThread start];
        mIsConnected = NO;
    }
    
    return self;
}

- (void)registerEAAccessoryManagerNotifications{
    NSArray *protocols = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UISupportedExternalAccessoryProtocols"];
    
    [self setProtocolString: [protocols firstObject]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accessoryDidConnect:) name:EAAccessoryDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accessoryDidDisconnect:) name:EAAccessoryDidDisconnectNotification object:nil];
    [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
}

- (void)unregisterEAAccessoryManagerNotifications{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EAAccessoryDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EAAccessoryDidDisconnectNotification object:nil];
    [[EAAccessoryManager sharedAccessoryManager] unregisterForLocalNotifications];
}

- (void)setProtocolString:(NSString *)protocolString{
    mProtocolString = protocolString;
}

- (void)setSPPManagerListener:(id<SPPManagerListener>)listener{
    mSPPManagerListener = listener;
}

- (void)write:(NSData *) data{
    [mCondition lock];
    [mWriteData appendBytes:data.bytes length:[data length]];
    [mCondition unlock];
    
    [mCondition signal];
}

- (void)connect{
    if(mIsConnected){
        return;
    }
    
    NSMutableArray *accessoryList = [[NSMutableArray alloc] initWithArray:[[EAAccessoryManager sharedAccessoryManager] connectedAccessories]];
    
    
    for(int i = 0; i < accessoryList.count; i++){
        EAAccessory *obj = [accessoryList objectAtIndex:i];
        
        if([obj isConnected]){
            if([self isSupported:mProtocolString withAccessory:obj]){
                [self setUpEAAccessory:obj withProtocolString:mProtocolString];
                break;
            }
        }
    }
}

- (void)disconnect{
    [self closeSession];
}

- (void)setUpEAAccessory:(EAAccessory *) connectedAccessory withProtocolString:(NSString *)protocolString{
    mEAAccessory = connectedAccessory;
    [mEAAccessory setDelegate:self];
    
    if(mEASession != nil){
        [[mEASession inputStream] removeFromRunLoop:[mIOThread currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[mEASession outputStream] removeFromRunLoop:[mIOThread currentRunLoop] forMode:NSDefaultRunLoopMode];
    }
    
    mEASession = [[EASession alloc] initWithAccessory:mEAAccessory forProtocol:protocolString];
    
    if (mEASession){
        [[mEASession inputStream] setDelegate:self];
        [[mEASession outputStream] setDelegate:self];
        
        [[mEASession inputStream] scheduleInRunLoop:[mIOThread currentRunLoop]
                                            forMode:NSDefaultRunLoopMode];
        [[mEASession outputStream] scheduleInRunLoop:[mIOThread currentRunLoop]
                                             forMode:NSDefaultRunLoopMode];
        [[mEASession inputStream] open];
        [[mEASession outputStream] open];
    }
}

- (void)accessoryDidConnect:(NSNotification *)notification {
    EAAccessory *connectedAccessory = [[notification userInfo] objectForKey:EAAccessoryKey];
    
    
    if([self isSupported:mProtocolString withAccessory:connectedAccessory]){
        [self setUpEAAccessory:connectedAccessory withProtocolString:mProtocolString];
    }
}

- (void)accessoryDidDisconnect:(EAAccessory *)accessory{
    [mEAAccessory setDelegate:nil];
    [self closeSession];
}

- (void)closeSession{
    [mEAAccessory setDelegate:nil];
    EASession *session = mEASession;

    if(session){
        [[session inputStream] close];
        [[session inputStream] removeFromRunLoop:[mIOThread currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[session inputStream] setDelegate:nil];
        [[session outputStream] close];
        [[session outputStream] removeFromRunLoop:[mIOThread currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[session outputStream] setDelegate:nil];
    }
    
    @synchronized (mIsCOnnectedLock) {
        if(mIsConnected){
            mIsConnected = NO;
            if(mSPPManagerListener != nil){
                [mSPPManagerListener onDisconnected];
            }
        }
    }
    mEASession = nil;
    [mCondition lock];
    [mWriteData setLength:0];
    [mCondition unlock];
}


-(BOOL)isSupported:(NSString *)protocolString withAccessory:(EAAccessory *)connectedAccessory {
    NSArray *protocolStrings = connectedAccessory.protocolStrings;
    
    for(int i = 0; i < protocolStrings.count; i++){
        NSString *protocol = [protocolStrings objectAtIndex:i];
        
        if([protocol isEqualToString:protocolString]){
            return YES;
        }
    }

    return NO;
}

-(void)doWrite{
    while(![[NSThread currentThread] isCancelled]){
        NSOutputStream *output = [mEASession outputStream];
        NSData *writeData = nil;
        
        [mCondition lock];
        writeData = [NSData dataWithBytes:mWriteData.bytes length:mWriteData.length];
        [mCondition unlock];
        
     
        if(output != nil && [output hasSpaceAvailable] && writeData.length > 0){
            @try {
                NSInteger bytesWritten = [output write:[writeData bytes] maxLength:[writeData length]];
                
                if (bytesWritten == -1){
                    break;
                }else if (bytesWritten > 0){
                    [mCondition lock];
                    if(mWriteData.length >= bytesWritten){
                        [mWriteData replaceBytesInRange:NSMakeRange(0, bytesWritten) withBytes:NULL length:0];
                    }
                    [mCondition unlock];
                }
            }@catch (NSException *exception) {
                NSLog(@"Transport Exception[%@], reason[%@] %@",[exception name],[exception reason],[exception callStackSymbols]);
            }
            
        }else{
            //wait
            [mCondition lock];
            [mCondition wait];
            [mCondition unlock];
        }
    }
    mSendThread = nil;
    mWriteData = nil;
}

- (void)doRead: (NSInputStream *)input{
    NSUInteger count = [input read:mReadBuf maxLength:READ_BUFFER];

    if(count != -1){
        NSData *readData = [NSData dataWithBytes:mReadBuf length:count];
        
        if(mSPPManagerListener != nil){
            [mSPPManagerListener onRead:readData];
        }
    }else{
        [[mEASession inputStream] close];
        [[mEASession outputStream] close];
        
        if(mSPPManagerListener != nil){
            [mSPPManagerListener onConnected];
        }
    }
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode{
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            
            if([[mEASession inputStream] streamStatus] == NSStreamStatusOpen &&
               [[mEASession outputStream] streamStatus] == NSStreamStatusOpen){
                
                @synchronized (mIsCOnnectedLock) {
                    if(!mIsConnected){
                        mIsConnected = YES;
                        if(mSPPManagerListener != nil){
                            [mSPPManagerListener onConnected];
                        }
                    }
                }
            }
            
            
            break;
        case NSStreamEventHasBytesAvailable:
            [self doRead:  (NSInputStream *)aStream];
            break;
        case NSStreamEventHasSpaceAvailable:
            [mCondition signal];
            break;
        case NSStreamEventErrorOccurred:
            
            break;
        case NSStreamEventEndEncountered:

            break;
        default:
            break;
    }
}

@end
