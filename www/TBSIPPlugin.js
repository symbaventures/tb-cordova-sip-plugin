  exec = require('cordova/exec')
  var tbsip = {
    /* Return register state in success callback -
    * 0: Registering,
    * 1: Renew,
    * 2: Registered,
    * 3: Unregistered */
    registration: function(username, password, domain, success, failure) {
      exec(
        success || function(){},
        failure || function(){},
        'TBSIPPlugin',
        'registration',
        [username, password, domain]
      );
    },
    incomingCallCallback: function(success, failure) {
      exec(
        success || function(){},
        failure || function(){},
        'TBSIPPlugin',
        'incomingCallCallback',
        []
      );
    },
    acceptIncomingCall: function(callId, success, failure) {
      exec(
        success || function(){},
        failure || function(){},
        'TBSIPPlugin',
        'acceptIncomingCall',
        [callId]
      );
    },
    declineIncomingCall: function(callId, success, failure) {
      exec(
        success || function(){},
        failure || function(){},
        'TBSIPPlugin',
        'declineIncomingCall',
        [callId]
      );
    },
    /* Return call state in success callback -
    * 0: Null,
    * 1: Calling,
    * 2: Incoming,
    * 3: Early,
    * 4: Connecting,
    * 5: Confirmed,
    * 6: Disconected */
    callTo: function(uri, success, failure) {
      exec(
        success || function(){},
        failure || function(){},
        'TBSIPPlugin',
        'callTo',
        [uri]
      );
    },
    hangUp: function(success, failure) {
      exec(
        success || function(){},
        failure || function(){},
        'TBSIPPlugin',
        'hangUp',
        []
      );
    },
    setMute: function(mute, success, failure) {
      exec(
        success || function(){},
        failure || function(){},
        'TBSIPPlugin',
        'setMute',
        [mute]
      );
    },
    setSpeakerEnable: function(enable, success, failure) {
      exec(
        success || function(){},
        failure || function(){},
        'TBSIPPlugin',
        'setSpeakerEnable',
        [enable]
      );
    },
    sendDTFM:function(code,success,failure){
      exec(
            success || function(){},
            failure || function(){},
            'TBSIPPlugin',
            'sendDTFM',
            [code]
      );
    }
  };

  module.exports = tbsip;
