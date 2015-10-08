//
//  ViewController.h
//  bnhktn
//
//  Created by KUMATA Tomokatsu on 9/28/15.
//  Copyright © 2015 KUMATA Tomokatsu. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SRWebSocket.h"

@interface ViewController : UIViewController <SRWebSocketDelegate> {
    SRWebSocket *socket;
}

@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentRole;

- (IBAction)findKonashi:(id)sender;
- (IBAction)postGeo:(id)sender;
- (IBAction)getRole:(id)sender;
- (IBAction)getRole2:(id)sender;
- (IBAction)pacmanItem:(id)sender;
- (IBAction)accessServer:(id)sender;

- (IBAction)showQuestionAction:(id)sender;

- (IBAction)LED2ON:(id)sender;

@end

