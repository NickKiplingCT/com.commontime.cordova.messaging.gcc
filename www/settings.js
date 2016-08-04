

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

    getHost: function (successCallback, errorCallback) {
      logmessage("Settings.getHost");
      if (errorCallback == null) { errorCallback = function () { alert('getHost no callback'); }; }

      if (typeof errorCallback != "function") {
        logerror("Settings.getHost failure: failure parameter not a function");
        return;
      }

      if (typeof successCallback != "function") {
        logerror("Settings.getHost success callback parameter must be a function");
        return;
      }

      try {
        exec(successCallback, errorCallback, 'Settings', 'getHost', []);
        logmessage("Settings.getHost initiated");
      } catch (e) {
        logerror("Settings.getHost error: " + e);
      }
    },

    getPort: function (successCallback, errorCallback) {
      logmessage("Settings.getPort");
      if (errorCallback == null) { errorCallback = function () { alert('getPort no callback'); }; }

      if (typeof errorCallback != "function") {
        logerror("Settings.getPort failure: failure parameter not a function");
        return;
      }

      if (typeof successCallback != "function") {
        logerror("Settings.getPort success callback parameter must be a function");
        return;
      }

      try {
        exec(successCallback, errorCallback, 'Settings', 'getPort', []);
        logmessage("Settings.getPort initiated");
      } catch (e) {
        logerror("Settings.getPort error: " + e);
      }
    },

    getUsername: function (successCallback, errorCallback) {
      logmessage("Settings.getUsername");
      if (errorCallback == null) { errorCallback = function () { alert('getUsername no callback'); }; }

      if (typeof errorCallback != "function") {
        logerror("Settings.getUsername failure: failure parameter not a function");
        return;
      }

      if (typeof successCallback != "function") {
        logerror("Settings.getUsername success callback parameter must be a function");
        return;
      }

      try {
        exec(successCallback, errorCallback, 'Settings', 'getUsername', []);
        logmessage("Settings.getUsername initiated");
      } catch (e) {
        logerror("Settings.getUsername error: " + e);
      }
    },

    getSSL: function (successCallback, errorCallback) {
      logmessage("Settings.getSSL");
      if (errorCallback == null) { errorCallback = function () { alert('getSSL no callback'); }; }

      if (typeof errorCallback != "function") {
        logerror("Settings.getSSL failure: failure parameter not a function");
        return;
      }

      if (typeof successCallback != "function") {
        logerror("Settings.getSSL success callback parameter must be a function");
        return;
      }

      try {
        exec(successCallback, errorCallback, 'Settings', 'getSSL', []);
        logmessage("Settings.getSSL initiated");
      } catch (e) {
        logerror("Settings.getSSL error: " + e);
      }
    },

    getURL: function (successCallback, errorCallback) {
      logmessage("Settings.getURL");
      if (errorCallback == null) { errorCallback = function () { alert('getURL no callback'); }; }

      if (typeof errorCallback != "function") {
        logerror("Settings.getURL failure: failure parameter not a function");
        return;
      }

      if (typeof successCallback != "function") {
        logerror("Settings.getURL success callback parameter must be a function");
        return;
      }

      try {
        exec(successCallback, errorCallback, 'Settings', 'getURL', []);
        logmessage("Settings.getURL initiated");
      } catch (e) {
        logerror("Settings.getURL error: " + e);
      }
    },

    getProvisioningURL: function (successCallback, errorCallback) {
      logmessage("Settings.getProvisioningURL");
      if (errorCallback == null) { errorCallback = function () { alert('getProvisioningURL no callback'); }; }

      if (typeof errorCallback != "function") {
        logerror("Settings.getProvisioningURL failure: failure parameter not a function");
        return;
      }

      if (typeof successCallback != "function") {
        logerror("Settings.getProvisioningURL success callback parameter must be a function");
        return;
      }

      try {
        exec(successCallback, errorCallback, 'Settings', 'getProvisioningURL', []);
        logmessage("Settings.getProvisioningURL initiated");
      } catch (e) {
        logerror("Settings.getProvisioningURL error: " + e);
      }
    },

    getClearURL: function (successCallback, errorCallback) {
      logmessage("Settings.getClearURL");
      if (errorCallback == null) { errorCallback = function () { alert('getClearURL no callback'); }; }

      if (typeof errorCallback != "function") {
        logerror("Settings.getClearURL failure: failure parameter not a function");
        return;
      }

      if (typeof successCallback != "function") {
        logerror("Settings.getClearURL success callback parameter must be a function");
        return;
      }

      try {
        exec(successCallback, errorCallback, 'Settings', 'getClearURL', []);
        logmessage("Settings.getClearURL initiated");
      } catch (e) {
        logerror("Settings.getClearURL error: " + e);
      }
    },

    setVersions: function (successCallback, errorCallback, versions) {
      logmessage("Settings.setVersions");

      if (errorCallback == null) {
        errorCallback = function () {
          alert('setVersions no callback');
        };
      }

      if (typeof errorCallback != "function") {
        logerror("Settings.setVersions failure: failure parameter not a function");
        return;
      }

      if (typeof successCallback != "function") {
        logerror("Settings.setVersions success callback parameter must be a function");
        return;
      }

      try {
        exec(successCallback, errorCallback, 'Settings', 'setVersions', [versions]);
      }
      catch (e) {
        logerror("Settings.setVersions error: " + e);
      }
    },

    getApplicationID: function (successCallback, errorCallback) {
      logmessage("Settings.getApplicationID");
      if (errorCallback == null) { errorCallback = function () { alert('getApplicationID no callback'); }; }

      if (typeof errorCallback != "function") {
        logerror("Settings.getApplicationID failure: failure parameter not a function");
        return;
      }

      if (typeof successCallback != "function") {
        logerror("Settings.getApplicationID success callback parameter must be a function");
        return;
      }

      try {
        exec(successCallback, errorCallback, 'Settings', 'getApplicationID', []);
        logmessage("Settings.getApplicationID initiated");
      } catch (e) {
        logerror("Settings.getApplicationID error: " + e);
      }
    },
    
    setUserPreference: function( key, value, successCallback, errorCallback ) {
    	try {
    		exec(successCallback, errorCallback, 'Settings', 'setUserPreference', [key, value]);
            logmessage("Settings.setUserPreference initiated");
        } catch (e) {
        	logerror("Settings.setUserPreference error: " + e);
        }
    },
    
    getUserPreference: function( key, successCallback, errorCallback ) {
    	try {
    		exec(successCallback, errorCallback, 'Settings', 'getUserPreference', [key]);
            logmessage("Settings.getUserPreference initiated");
        } catch (e) {
        	logerror("Settings.getUserPreference error: " + e);
        }
    },
    
    setPreference: function( successCallback, errorCallback, key, value ) {
    	try {
    		exec(successCallback, errorCallback, 'Settings', 'setPreference', [key, value]);
            logmessage("Settings.setPreference initiated");
        } catch (e) {
        	logerror("Settings.setPreference error: " + e);
        }
    },

    getServiceUsername: function(successCallback, errorCallback, serviceName)
    {
        logmessage("Settings.getServiceUsername");
    	
	    if (errorCallback == null) { errorCallback = function() { alert('getServiceUsername no callback'); }; }
    	
        if (typeof errorCallback != "function") {
            logerror("Settings.getServiceUsername failure: failure parameter not a function");
            return;
        }
    	
        if (typeof successCallback != "function") {
            logerror("Settings.getServiceUsername success callback parameter must be a function");
            return;
        }
    	
        try {
            cordova.exec(successCallback, errorCallback, 'Settings', 'getServiceUsername', [serviceName]);
        }
	    catch (e) {
            logerror("Settings.getServiceUsername error: " + e);
        }
    },
	
	openShellSettings: function(successCallback, errorCallback ) {
    	try {
    		exec(successCallback, errorCallback, 'Settings', 'openShellSettings', []);
            logmessage("Settings.openShellSettings initiated");
        } catch (e) {
        	logerror("Settings.openShellSettings error: " + e);
        }
    },
	
	openAbout: function(successCallback, errorCallback ) {
    	try {
    		exec(successCallback, errorCallback, 'Settings', 'openAbout', []);
            logmessage("Settings.openAbout initiated");
        } catch (e) {
        	logerror("Settings.openAbout error: " + e);
        }
    }
  };
