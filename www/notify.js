var argscheck = require('cordova/argscheck'),
exec = require('cordova/exec');

// TODO: Centralise these log message functions ^^ add dependency
if (logmessage === undefined) {
		var logmessage = function (msg) {
      if (console) {
        console.warn(msg);
      }
    };
}
if (logerror === undefined) {
		var logerror = function (msg) {
      if (console) {
        console.error(msg);
      }
      alert(msg);
    };
}

module.exports = {
  
		addChannel : function (channel, callback) {
      var s;
      function success(channel) {
        logmessage("Notify.addChannel success: " + channel);
        if (callback) {
          callback(undefined, channel);
        }
      }
      function error(s) {
        logerror("Notify.addChannel error: " + s);
        if (callback) {
          callback(s)
        }
      }
      logmessage("Notify.addChannel");
      try {
        if (exec) {
          channel = channel || '';
          return exec(success, error, 'Notify', 'addChannel', [channel]);
        } else {
          error('Restricted mode');
        }
      } catch (e) {
        s = "Notify.addChannel exception: " + e.message;
        logerror(s);
        if (callback) {
          callback(s)
        }
      }
    },
  
		removeChannel : function (channel, callback) {
      var s;
      function success(channel) {
        logmessage("Notify.removeChannel success: " + channel);
        if (callback) {
          callback(undefined, channel);
        }
      }
      function error(s) {
        logerror("Notify.removeChannel error: " + s);
        if (callback) {
          callback(s)
        }
      }
      logmessage("Notify.removeChannel");
      try {
        if (exec) {
          channel = channel || '';
          exec(success, error, 'Notify', 'removeChannel', [channel]);
        } else {
          error('Restricted mode');
        }
      } catch (e) {
        s = "Notify.removeChannel error: " + e.message;
        logerror(s);
        if (callback) {
          callback(s);
        }
      }
    },
  
		listChannels : function (callback) {
      var s;
      function success(channels) {
        logmessage("Notify.listChannels success: " + channels);
        if (callback) {
          callback(undefined, channels);
        }
      }
      function error(s) {
        logerror("Notify.listChannels: " + s);
        if (callback) {
          callback(s)
        }
      }
      logmessage("Notify.listChannels");
      try {
        if (exec) {
          exec(success, error, 'Notify', 'listChannels', []);
        } else {
          error('Restricted mode');
        }
      } catch (e) {
        s = "Notify.listChannels error: " + e.message;
        logerror(s);
        if (callback) {
          callback(s);
        }
      }
    },
  
		sendMessage : function (message, callback) {
      var s;
      function success(messageid) {
        //logmessage("Notify.sendMessage success: " + messageid);
        if (callback) {
          callback(undefined, messageid);
        }
      }
      function error(s) {
        //logerror("Notify.sendMessage: " + s);
        if (callback) {
          callback(s)
        }
      }
      //logmessage("Notify.sendMessage");
      try {
        if (exec) {
          if (message.expiry === 0) {
            var msgId;
            var callbackId = Math.random().toString(36).substring(7);
            function sent(messageid) {
              msgId = messageid;
            }
            function notSent(s) {
              logerror("Notify.sendMessage: " + s);
            }
            window.plugins.notify.receiveOutboxChanges(callbackId, function (x, y) {
                                                       if (y.message.id == msgId) {
                                                       
                                                       // If sent, then pop up a box to say sent
                                                       if (y.action == "SENT") {
                                                       window.plugins.notify.cancelOutboxChanges(callbackId, function (x, y) {});
                                                       success(msgId);
                                                       }
                                                       
                                                       // If failed, then pop up a box to say sent
                                                       if (y.action == "FAILED") {
                                                       window.plugins.notify.cancelOutboxChanges(callbackId, function (x, y) {});
                                                       error();
                                                       }
                                                       }
                                                       });
            exec(sent, notSent, 'Notify', 'sendMessage', [message]);
          } else {
            exec(success, error, 'Notify', 'sendMessage', [message]);
          }
        } else {
          error('Restricted mode');
        }
      } catch (e) {
        s = "Notify.sendMessage error: " + e.message;
        //logerror(s);
        if (callback) {
          callback(s);
        }
      }
    },
  
		getMessages : function (channel, subchannel, callback) {
      var s;
      function success(messages) {
        logmessage("Notify.getMessages success: " + messages);
        if (callback) {
          callback(undefined, messages);
        }
      }
      function error(s) {
        logerror("Notify.getMessages: " + s);
        if (callback) {
          callback(s)
        }
      }
      logmessage("Notify.getMessages");
      try {
        if (exec) {
          channel = channel || '';
          subchannel = subchannel || '';
          exec(success, error, 'Notify', 'getMessages', [channel, subchannel]);
        } else {
          error('Restricted mode');
        }
      } catch (e) {
        s = "Notify.getMessages error: " + e.message;
        logerror(s);
        if (callback) {
          callback(s);
        }
      }
    },
  
		getUnreadMessages : function (receiver, channel, subchannel, callback) {
      var s;
      function success(messages) {
        logmessage("Notify.getUnreadMessages success: " + messages);
        if (callback) {
          callback(undefined, messages);
        }
      }
      function error(s) {
        logerror("Notify.getUnreadMessages: " + s);
        if (callback) {
          callback(s)
        }
      }
      logmessage("Notify.getUnreadMessages");
      try {
        if (exec) {
          channel = channel || '';
          subchannel = subchannel || '';
          receiver = receiver || '';
          exec(success, error, 'Notify', 'getUnreadMessages', [receiver, channel, subchannel]);
        } else {
          error('Restricted mode');
        }
      } catch (e) {
        s = "Notify.getUnreadMessages error: " + e.message;
        logerror(s);
        if (callback) {
          callback(s);
        }
      }
    },
  
		deleteMessage : function (id, callback) {
      var s;
      function success(messageid) {
        logmessage("Notify.deleteMessage success: " + messageid);
        if (callback) {
          callback(undefined, messageid);
        }
      }
      function error(s) {
        logerror("Notify.deleteMessage: " + s);
        if (callback) {
          callback(s)
        }
      }
      logmessage("Notify.deleteMessage");
      try {
        if (exec) {
          id = id || '';
          exec(success, error, 'Notify', 'deleteMessage', [id]);
        } else {
          error('Restricted mode');
        }
      } catch (e) {
        s = "Notify.deleteMessage error: " + e.message;
        logerror(s);
        if (callback) {
          callback(s);
        }
      }
    },
  
		receiveMessageNotification : function (receiver, channel, subchannel, callback) {
      var s;
      function success(message) {
        logmessage("Notify.receiveMessageNotification success: " + message);
        if (callback) {
          callback(undefined, message);
        }
      }
      function error(s) {
        logerror("Notify.receiveMessageNotification: " + s);
        if (callback) {
          callback(s)
        }
      }
      logmessage("Notify.receiveMessageNotification");
      try {
        if (exec) {
          channel = channel || '';
          subchannel = subchannel || '';
          receiver = receiver || '';
          exec(success, error, 'Notify', 'receiveMessageNotification', [receiver, channel, subchannel]);
        } else {
          error('Restricted mode');
        }
      } catch (e) {
        s = "Notify.receiveMessageNotification error: " + e.message;
        logerror(s);
        return s; // Error is returned here instead of in the callback
      }
    },
  
		messageReceivedAck : function (receiver, messageid, callback) {
      var s;
      function success(messageInfo) {
        logmessage("Notify.messageReceivedAck success: " + messageInfo);
        if (callback) {
          callback();
        }
      }
      function error(s) {
        logerror("Notify.messageReceivedAck: " + s);
        if (callback) {
          callback(s)
        }
      }
      logmessage("Notify.messageReceivedAck");
      try {
        if (exec) {
          receiver = receiver || '';
          messageid = messageid || '';
          exec(success, error, 'Notify', 'messageReceivedAck', [receiver, messageid]);
        } else {
          error('Restricted mode');
        }
      } catch (e) {
        s = "Notify.messageReceivedAck error: " + e.message;
        logerror(s);
        if (callback) {
          callback(s);
        }
      }
    },
  
		cancelMessageNotification : function (receiver, callback) {
      var s;
      function success(receiver) {
        logmessage("Notify.cancelMessageNotification success: " + receiver);
        if (callback) {
          callback(undefined, receiver);
        }
      }
      function error(s) {
        logerror("Notify.cancelMessageNotification: " + s);
        if (callback) {
          callback(s)
        }
      }
      logmessage("Notify.cancelMessageNotification");
      try {
        if (exec) {
          receiver = receiver || '';
          exec(success, error, 'Notify', 'cancelMessageNotification', [receiver]);
        } else {
          error('Restricted mode');
        }
      } catch (e) {
        s = "Notify.cancelMessageNotification error: " + e.message;
        logerror(s);
        if (callback) {
          callback(s);
        }
      }
    },
  
		cancelAllMessageNotifications : function (callback) {
      var s;
      function success() {
        logmessage("Notify.cancelAllMessageNotifications success:");
        if (callback) {
          callback();
        }
      }
      function error(s) {
        logerror("Notify.cancelAllMessageNotifications: " + s);
        if (callback) {
          callback(s)
        }
      }
      logmessage("Notify.cancelAllMessageNotifications");
      try {
        if (exec) {
          exec(success, error, 'Notify', 'cancelAllMessageNotifications', []);
        } else {
          error('Restricted mode');
        }
      } catch (e) {
        s = "Notify.cancelAllMessageNotifications error: " + e.message;
        logerror(s);
        if (callback) {
          callback(s);
        }
      }
    },
  
		receiveInboxChanges : function (receiver, callback) {
      var s;
      function success(message) {
        logmessage("Notify.receiveInboxChanges success: " + message);
        if (callback) {
          callback(undefined, message);
        }
      }
      function error(s) {
        logerror("Notify.receiveInboxChanges: " + s);
        if (callback) {
          callback(s)
        }
      }
      logmessage("Notify.receiveInboxChanges");
      try {
        if (exec) {
          receiver = receiver || '';
          exec(success, error, 'Notify', 'receiveInboxChanges', [receiver]);
        } else {
          error('Restricted mode');
        }
      } catch (e) {
        s = "Notify.receiveInboxChanges error: " + e.message;
        logerror(s);
        if (callback) {
          callback(s);
        }
      }
    },
  
		cancelInboxChanges : function (receiver, callback) {
      var s;
      function success() {
        logmessage("Notify.cancelInboxChanges success:");
        if (callback) {
          callback();
        }
      }
      function error(s) {
        logerror("Notify.cancelInboxChanges: " + s);
        if (callback) {
          callback(s)
        }
      }
      logmessage("Notify.cancelInboxChanges");
      try {
        if (exec) {
          receiver = receiver || '';
          exec(success, error, 'Notify', 'cancelInboxChanges', [receiver]);
        } else {
          error('Restricted mode');
        }
      } catch (e) {
        s = "Notify.cancelInboxChanges error: " + e.message;
        logerror(s);
        if (callback) {
          callback(s);
        }
      }
    },
  
		receiveOutboxChanges : function (receiver, callback) {
      var s;
      function success(message) {
        logmessage("Notify.receiveOutboxChanges success: " + message);
        if (callback) {
          callback(undefined, message);
        }
      }
      function error(s) {
        logerror("Notify.receiveOutboxChanges: " + s);
        if (callback) {
          callback(s)
        }
      }
      logmessage("Notify.receiveOutboxChanges");
      try {
        if (exec) {
          receiver = receiver || '';
          exec(success, error, 'Notify', 'receiveOutboxChanges', [receiver]);
        } else {
          error('Restricted mode');
        }
      } catch (e) {
        s = "Notify.receiveOutboxChanges error: " + e.message;
        logerror(s);
        if (callback) {
          callback(s);
        }
      }
    },
  
		cancelOutboxChanges : function (receiver, callback) {
      var s;
      function success() {
        logmessage("Notify.cancelOutboxChanges success:");
        if (callback) {
          callback();
        }
      }
      function error(s) {
        logerror("Notify.cancelOutboxChanges: " + s);
        if (callback) {
          callback(s)
        }
      }
      logmessage("Notify.cancelOutboxChanges");
      try {
        if (exec) {
          receiver = receiver || '';
          exec(success, error, 'Notify', 'cancelOutboxChanges', [receiver]);
        } else {
          error('Restricted mode');
        }
      } catch (e) {
        s = "Notify.cancelOutboxChanges error: " + e.message;
        logerror(s);
        if (callback) {
          callback(s);
        }
      }
    },
  
  setOptions : function(successCallback, errorCallback, options) {
    cordova.exec(successCallback, errorCallback, "Notify", "setOptions", [options]);
  }
};
