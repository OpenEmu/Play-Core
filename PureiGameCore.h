//
//  PureiGameCore.h
//  Play!
//
//  Created by Alexander Strange on 10/24/15.
//
//

#import <Cocoa/Cocoa.h>
#import <OpenEmuBase/OEGameCore.h>
#import "OEPS2SystemResponderClient.h"

OE_EXPORTED_CLASS
@interface PureiGameCore : OEGameCore

@end

extern __weak PureiGameCore *_current;
