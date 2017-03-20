//
//  ViewController.m
//  EAAccessoryExample
//
//  Created by ray.lee on 2017/3/3.
//  Copyright © 2017年 Ray Lee. All rights reserved.
//

#import "ViewController.h"


@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self setUpSPPManager];
    [self initView];
}

- (void)setUpSPPManager{
    [[SPPManager shared] setSPPManagerListener:self];
}

- (void)initView{
    UIButton *connectBtn = [[UIButton alloc]initWithFrame:CGRectMake(0, 20, 100, 50)];
    [connectBtn setTitle:@"connect" forState:UIControlStateNormal];
    [connectBtn setBackgroundColor:[UIColor blueColor]];
    
    [connectBtn addTarget:self action:@selector(connect) forControlEvents:UIControlEventTouchUpInside];
  
    [self.view addSubview:connectBtn];
    
    
    UIButton *disconnectBtn = [[UIButton alloc]initWithFrame:CGRectMake(0, 75, 100, 50)];
    [disconnectBtn setTitle:@"disconnect" forState:UIControlStateNormal];
    [disconnectBtn setBackgroundColor:[UIColor redColor]];
    
    [disconnectBtn addTarget:self action:@selector(disconnect) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:disconnectBtn];
    
    
    UIButton *sendBtn = [[UIButton alloc]initWithFrame:CGRectMake(0, 130, 100, 50)];
    [sendBtn setTitle:@"send" forState:UIControlStateNormal];
    [sendBtn setBackgroundColor:[UIColor greenColor]];
    
    [sendBtn addTarget:self action:@selector(send) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:sendBtn];


}

-(void)connect{
    [[SPPManager shared] connect];
}

-(void)disconnect{
    [[SPPManager shared] disconnect];
}

-(void)send{
    Byte byte = 0x01;
    NSData *data = [[NSData alloc] initWithBytes:&byte length:1];
    [[SPPManager shared] write:data];
}

- (void)onConnected{
    NSLog(@"onConnected");
}

- (void)onDisconnected{
    NSLog(@"onDisconnected");
}

- (void)onRead:(nonnull NSData *)data{
    NSLog(@"onRead:%@", data);

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
