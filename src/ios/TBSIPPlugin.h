//
//  TBSIPPlugin.h
//  TraceBust
//
//  Created by Andrey Chuprina on 3/1/16.
//
//

#import <Cordova/CDVPlugin.h>

typedef enum {
    TBSIPRegisterStateRegistering,
    TBSIPRegisterStateRenew,
    TBSIPRegisterStateRegistered,
    TBSIPRegisterStateUnregistered
} TBSIPRegisterState;


typedef enum {
    TBSIPCallStateNull,
    TBSIPCallStateCalling,
    TBSIPCallStateIncoming,
    TBSIPCallStateEarly,
    TBSIPCallStateConnecting,
    TBSIPCallStateConfirmed,
    TBSIPCallStateDisconected
} TBSIPCallState;

@interface TBSIPPlugin : CDVPlugin

@property(readonly) NSString *username;
@property(readonly) NSString *sipDomain;
@property(readonly) NSInteger accountId;
@property(readonly) NSInteger currentCallId;

- (void)registration:(CDVInvokedUrlCommand*)command;
- (void)incomingCallCallback:(CDVInvokedUrlCommand*)command;
- (void)acceptIncomingCall:(CDVInvokedUrlCommand*)command;
- (void)declineIncomingCall:(CDVInvokedUrlCommand*)command;
- (void)callTo:(CDVInvokedUrlCommand*)command;
- (void)hangUp:(CDVInvokedUrlCommand*)command;
- (void)setMute:(CDVInvokedUrlCommand*)command;
- (void)setSpeakerEnable:(CDVInvokedUrlCommand*)command;
- (void)sendDTFM:(CDVInvokedUrlCommand*)command;

@end
