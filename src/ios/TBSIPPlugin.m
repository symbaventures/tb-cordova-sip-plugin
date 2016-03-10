//
//  TBSIPPlugin.m
//  TraceBust
//
//  Created by Andrey Chuprina on 3/1/16.
//
//

#import "TBSIPPlugin.h"
#import <pjsua-lib/pjsua.h>
#import <AVFoundation/AVFoundation.h>

@interface TBSIPPlugin()

@property(nonatomic, strong) NSString *registerCallbackId;
@property(nonatomic, strong) NSString *incomingCallCallbackId;
@property(nonatomic, strong) NSString *acceptIncomingCallCallbackId;
@property(nonatomic, strong) NSString *declineIncomingCallCallbackId;
@property(nonatomic, strong) NSString *callToCallbackId;
@property(nonatomic, strong) NSString *muteCallbackId;
@property(nonatomic, strong) NSString *speakerCallbackId;
@property(nonatomic, strong) NSString *dtmfCallbackId;
@property(nonatomic, strong) NSString *hangupCallbackId;

@property BOOL registered;

@end

@implementation TBSIPPlugin

#pragma mark - C sip callbacks
static TBSIPPlugin *selfCPointer;

/* Callback called by the library upon receiving incoming call */
static void on_incoming_call_callback(pjsua_acc_id acc_id, pjsua_call_id call_id, pjsip_rx_data *rdata) {
    pjsua_call_info ci;

    PJ_UNUSED_ARG(acc_id);
    PJ_UNUSED_ARG(rdata);

    pjsua_call_get_info(call_id, &ci);

    PJ_LOG(3,("TBSIP", "Incoming call from %.*s!!",
              (int)ci.remote_info.slen,
              ci.remote_info.ptr));

    /* Automatically answer incoming calls with 200/OK */
    //pjsua_call_answer(call_id, 200, NULL, NULL);
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:call_id];
    [selfCPointer.commandDelegate sendPluginResult:pluginResult callbackId:selfCPointer.incomingCallCallbackId];
    
}

/* Callback called by the library when call's media state has changed */
static void on_call_media_state(pjsua_call_id call_id) {
    pjsua_call_info ci;
    pjsua_call_get_info(call_id, &ci);
    if (ci.media_status == PJSUA_CALL_MEDIA_ACTIVE) {
        // When media is active, connect call to sound device.
        pjsua_conf_connect(ci.conf_slot, 0);
        pjsua_conf_connect(0, ci.conf_slot);
    }
}

/* Callback called by the library when call's state has changed */
static void on_call_state(pjsua_call_id call_id, pjsip_event *e) {
    pjsua_call_info ci;
    PJ_UNUSED_ARG(e);
    pjsua_call_get_info(call_id, &ci);
    PJ_LOG(3,("TBSIP", "Call %d state=%.*s", call_id, (int)ci.state_text.slen, ci.state_text.ptr));

    void (^onCallStateChangedInMainQueue)(TBSIPCallState) = ^(TBSIPCallState state) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [selfCPointer onCallStateChanged:state];
        });
    };
    
    switch (ci.state) {
        case PJSIP_INV_STATE_NULL: {
            onCallStateChangedInMainQueue(TBSIPCallStateNull);
            break;
        }
        case PJSIP_INV_STATE_CALLING: {
            onCallStateChangedInMainQueue(TBSIPCallStateCalling);
            break;
        }
        case PJSIP_INV_STATE_INCOMING: {
            onCallStateChangedInMainQueue(TBSIPCallStateIncoming);
            break;
        }
        case PJSIP_INV_STATE_EARLY: {
            onCallStateChangedInMainQueue(TBSIPCallStateEarly);
            break;
        }
        case PJSIP_INV_STATE_CONNECTING: {
            onCallStateChangedInMainQueue(TBSIPCallStateConnecting);
            break;
        }
        case PJSIP_INV_STATE_CONFIRMED: {
            onCallStateChangedInMainQueue(TBSIPCallStateConfirmed);
            break;
        }
        case PJSIP_INV_STATE_DISCONNECTED: {
            onCallStateChangedInMainQueue(TBSIPCallStateDisconected);
            break;
        }
        default:
        break;
    }
}

static void on_reg_started2(pjsua_acc_id acc_id, pjsua_reg_info *info) {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsNSInteger:TBSIPRegisterStateRegistering];
    [pluginResult setKeepCallbackAsBool:YES];
    dispatch_async(dispatch_get_main_queue(), ^{
        [selfCPointer.commandDelegate sendPluginResult:pluginResult callbackId:selfCPointer.registerCallbackId];
    });
}

static void on_reg_state2(pjsua_acc_id acc_id, pjsua_reg_info *info) {
    CDVPluginResult* pluginResult = nil;
    if (info->renew) {
        if (info->cbparam->status == PJ_SUCCESS) {
            int code = info->cbparam->code;
            if (code < 200 || code > 299) {
                NSString *errorString = [NSString stringWithFormat:@"Registration fail; Status code: %d;\nReason: %.*s", code, (int)info->cbparam->reason.slen, info->cbparam->reason.ptr];
                [selfCPointer showErrorWithStatus:info->cbparam->status message:errorString];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorString];
            } else {
                if (!selfCPointer.registered) {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsNSInteger:TBSIPRegisterStateRegistered];
                    selfCPointer.registered = YES;
                } else {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsNSInteger:TBSIPRegisterStateRenew];
                }
            }
        } else {
            [selfCPointer showErrorWithStatus:info->cbparam->status message:@"Some went wrong in registration module"];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Some went wrong in registration module"];
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsNSInteger:TBSIPRegisterStateUnregistered];
        selfCPointer.registered = NO;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (pluginResult) {
            [pluginResult setKeepCallbackAsBool:YES];
            [selfCPointer.commandDelegate sendPluginResult:pluginResult callbackId:selfCPointer.registerCallbackId];
        }
    });
}

#pragma mark - Plugin code
- (void)pluginInitialize {
    [super pluginInitialize];
    selfCPointer = self;
    _currentCallId = -1;
    _accountId = -1;
    self.registered = NO;
    [self pjsuaInit];
}

- (void)showErrorWithStatus:(pj_status_t)status message:(NSString*)message {
    pjsua_perror("TBSIP", message.UTF8String, status);
    pjsua_destroy();
}

- (void)pjsuaInit {
    pj_status_t status;
    status = pjsua_create();
    if (status != PJ_SUCCESS) {
        [self showErrorWithStatus:status message:@"pjsua_create fail"];
        return;
    }

    pjsua_config config;
    pjsua_config_default(&config);
    config.cb.on_incoming_call = &on_incoming_call_callback;
    config.cb.on_call_media_state = &on_call_media_state;
    config.cb.on_call_state = &on_call_state;
    config.cb.on_reg_started2 = &on_reg_started2;
    config.cb.on_reg_state2 = &on_reg_state2;

    pjsua_logging_config log_config;
    pjsua_logging_config_default(&log_config);
    log_config.console_level = 4;

    status = pjsua_init(&config, &log_config, NULL);
    if (status != PJ_SUCCESS) {
        [self showErrorWithStatus:status message:@"pjsua_init fail"];
        return;
    }

    pjsua_transport_config transport_config;
    pjsua_transport_config_default(&transport_config);
    transport_config.port = 5060;

    status = pjsua_transport_create(PJSIP_TRANSPORT_UDP, &transport_config, NULL);
    if (status != PJ_SUCCESS) {
        [self showErrorWithStatus:status message:@"pjsua_transport_create fail"];
        return;
    }

    status = pjsua_start();
    if (status != PJ_SUCCESS) {
        [self showErrorWithStatus:status message:@"pjsua_start fail"];
        return;
    }
}

- (void)registerWithUsername:(NSString*)username password:(NSString*)password sipDomain:(NSString*)sipDomain {
    pjsua_acc_config acc_config;
    pjsua_acc_config_default(&acc_config);
    NSString *idStr = [NSString stringWithFormat:@"sip:%@@%@", username, sipDomain];
    NSString *regURI = [NSString stringWithFormat:@"sip:%@", sipDomain];
    acc_config.id = pj_str((char*)idStr.UTF8String);
    acc_config.reg_uri = pj_str((char*)regURI.UTF8String);
    acc_config.cred_count = 1;

    acc_config.cred_info[0].realm = pj_str((char*)sipDomain.UTF8String);
    acc_config.cred_info[0].scheme = pj_str("digest");
    acc_config.cred_info[0].username = pj_str((char*)username.UTF8String);
    acc_config.cred_info[0].data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
    acc_config.cred_info[0].data = pj_str((char*)password.UTF8String);

    pjsua_acc_id acc_id;
    pj_status_t status = pjsua_acc_add(&acc_config, PJ_TRUE, &acc_id);
    if (status != PJ_SUCCESS) {
        [self showErrorWithStatus:status message:@"pjsua_acc_add fail"];
    } else {
        _accountId = acc_id;
        _username = username;
        _sipDomain = sipDomain;
    }
}

- (void)onCallStateChanged:(TBSIPCallState)state {
    if (state == TBSIPCallStateNull || state == TBSIPCallStateDisconected) {
        _currentCallId = -1;
    }
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsNSInteger:state];
    [pluginResult setKeepCallbackAsBool:(self.currentCallId != -1)];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callToCallbackId];
}

#pragma mark - cordova plugin functions
- (void)registration:(CDVInvokedUrlCommand*)command {
    if (self.accountId != -1) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Allready registered!"];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.registerCallbackId];
        return;
    }
    
    NSString *username = [command argumentAtIndex:0 withDefault:nil];
    NSString *password = [command argumentAtIndex:1 withDefault:nil];
    NSString *domain = [command argumentAtIndex:2 withDefault:nil];
    
    if (username && password && domain) {
        self.registerCallbackId = command.callbackId;
        [self registerWithUsername:username password:password sipDomain:domain];
    }
}

- (void)incomingCallCallback:(CDVInvokedUrlCommand*)command {
    self.incomingCallCallbackId = command.callbackId;
}

- (void)acceptIncomingCall:(CDVInvokedUrlCommand*)command {
    self.acceptIncomingCallCallbackId = command.callbackId;
    CDVPluginResult *pluginResult = nil;
    NSNumber *callId = [command argumentAtIndex:0 withDefault:nil];
    if (callId) {
        pj_status_t status = pjsua_call_answer(callId.intValue, 200, NULL, NULL);
        if (status != PJ_SUCCESS) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incoming call accepting error"];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Incoming call accepted"];
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Call id not passed!"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.acceptIncomingCallCallbackId];
}

- (void)declineIncomingCall:(CDVInvokedUrlCommand*)command {
    self.declineIncomingCallCallbackId = command.callbackId;
    CDVPluginResult *pluginResult = nil;
    NSNumber *callId = [command argumentAtIndex:0 withDefault:nil];
    if (callId) {
        pj_status_t status = pjsua_call_answer(callId.intValue, 603, NULL, NULL);
        if (status != PJ_SUCCESS) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incoming call decline error"];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Incoming call declined"];
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Call id not passed!"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.declineIncomingCallCallbackId];
}

- (void)callTo:(CDVInvokedUrlCommand*)command {
    if (self.currentCallId != -1) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Allready calling..."];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callToCallbackId];
        return;
    }
    
    NSString *uri = [command argumentAtIndex:0 withDefault:nil];
    if (uri) {
        NSArray *words = [uri componentsSeparatedByString:@"@"];
        if (words.count < 2) {
            uri = [NSString stringWithFormat:@"%@@%@", uri, self.sipDomain];
        }
        
        if ([self isValidURI:uri]) {
            if (![uri hasPrefix:@"sip:"]) {
                uri = [NSString stringWithFormat:@"sip:%@", uri];
            }
            self.callToCallbackId = command.callbackId;
            pj_str_t sip_uri = pj_str((char *)uri.UTF8String);
            pjsua_call_id call_id;
            pj_status_t status = pjsua_call_make_call((pjsua_call_id)self.accountId, &sip_uri, 0, NULL, NULL, &call_id);
            if (status != PJ_SUCCESS) {
                [self showErrorWithStatus:status message:@"pjsua_call_make_call fail"];
                NSString *errorString = [NSString stringWithFormat:@"Error while try calling to: %@", uri];
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorString];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callToCallbackId];
            } else {
                _currentCallId = call_id;
            }
        }
    }
}

- (BOOL)isValidURI:(NSString*)uri {
    NSString *tempURI = uri;
    if ([tempURI hasPrefix:@"sip:"]) {
        tempURI = [tempURI substringFromIndex:4];
    }
    NSString *emailRegex = @"[A-Z0-9a-z]+([._%+-]{1}[A-Z0-9a-z]+)*@[A-Z0-9a-z]+([.-]{1}[A-Z0-9a-z]+)*(\\.[A-Za-z]{2,4}){0,1}";
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    if ([emailTest evaluateWithObject:tempURI]) {
        return YES;
    }
    return NO;
}

- (void)hangUp:(CDVInvokedUrlCommand*)command {
    if (self.currentCallId > -1) {
        self.hangupCallbackId = command.callbackId;
        CDVPluginResult *pluginResult = nil;
        pj_status_t status = pjsua_call_hangup((pjsua_call_id)self.currentCallId, 603, NULL, NULL);
        if (status != PJ_SUCCESS) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Set mute failed!"];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Set mute ok"];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.hangupCallbackId];
    }
}

- (void)setMute:(CDVInvokedUrlCommand*)command {
    if (self.currentCallId > -1) {
        NSNumber *mute = [command argumentAtIndex:0 withDefault:nil];
        self.muteCallbackId = command.callbackId;
        CDVPluginResult *pluginResult = nil;
        if (mute) {
            pjsua_call_info call_info;
            pj_status_t status;
            
            status = pjsua_call_get_info((pjsua_call_id)self.currentCallId, &call_info);
            if (status != PJ_SUCCESS) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Getting call info error!"];
            } else {
                
                if (mute.boolValue) {
                    status = pjsua_conf_disconnect(0, call_info.conf_slot);
                } else {
                    status = pjsua_conf_connect(0, call_info.conf_slot);
                }
                
                if (status != PJ_SUCCESS) {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Set mute failed!"];
                } else {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Set mute ok"];
                }
            }
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No params passed!"];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.muteCallbackId];
    }
}

- (void)setSpeakerEnable:(CDVInvokedUrlCommand*)command {
    if (self.currentCallId > -1) {
        NSNumber *enable = [command argumentAtIndex:0 withDefault:nil];
        self.speakerCallbackId = command.callbackId;
        
        void(^finishBlock)(CDVPluginResult*) = ^(CDVPluginResult *pluginResult){
            [self.commandDelegate sendPluginResult:pluginResult callbackId:self.speakerCallbackId];
        };
        
        if (enable) {
            AVAudioSession* session = [AVAudioSession sharedInstance];
            BOOL success;
            NSError* error;
            success = [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
            
            if (!success) {
                NSString *message = [NSString stringWithFormat:@"Speaker %@ failed!", enable.boolValue ? @"enable" : @"disable"];
                finishBlock([CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message]);
                return;
            }
            
            AVAudioSessionPortOverride override = enable.boolValue ? AVAudioSessionPortOverrideSpeaker : AVAudioSessionPortOverrideNone;
            success = [session overrideOutputAudioPort:override error:&error];
            if (!success) {
                NSString *message = [NSString stringWithFormat:@"Speaker %@ failed!", enable.boolValue ? @"enable" : @"disable"];
                finishBlock([CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message]);
                return;
            }
            success = [session setActive:YES error:&error];
            if (!success) {
                NSString *message = [NSString stringWithFormat:@"Speaker %@ failed!", enable.boolValue ? @"enable" : @"disable"];
                finishBlock([CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message]);
            } else {
                NSString *message = [NSString stringWithFormat:@"Speaker %@ ok", enable.boolValue ? @"enable" : @"disable"];
                finishBlock([CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:message]);
            }
            
        } else {
            finishBlock([CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No params passed!"]);
        }
        
    }

}

- (void)sendDTFM:(CDVInvokedUrlCommand*)command {
    NSNumber *dtmfValue = [command argumentAtIndex:0 withDefault:nil];
    self.dtmfCallbackId = command.callbackId;
    CDVPluginResult *pluginResult = nil;
    if (dtmfValue && self.currentCallId > -1) {
        pj_str_t digits = pj_str((char *)dtmfValue.stringValue.UTF8String);
        pj_status_t status = pjsua_call_dial_dtmf((pjsua_call_id)self.currentCallId, &digits);
        if (status != PJ_SUCCESS) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Send call DTMF fail!"];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Send call DTMF ok"];
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No params passed!"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.dtmfCallbackId];
}

@end
