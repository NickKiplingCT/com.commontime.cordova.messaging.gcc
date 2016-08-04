
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

		log : function (logName, priority, data) {

			function done() {}

			try {
				if (exec) {
					exec(done, done, 'Log', 'log', [logName, priority, data]);
				}
			} catch (e) {
				logmessage("Logger: " + data + " error: " + e);
			}
		},

		enableLogging : function () {

			function done() {}

			try {
				if (exec) {
					exec(done, done, 'Log', 'enable', []);
				}
			} catch (e) {
				logmessage("Logger: " + data + " error: " + e);
			}
		},

		disableLogging : function () {

			function done() {}

			try {
				if (exec) {
					exec(done, done, 'Log', 'disable', []);
				}
			} catch (e) {
				logmessage("Logger: " + data + " error: " + e);
			}
		},

		uploadLogs : function (success, fail, uri) {
			
			try {
				if (exec) {
					exec(success, fail, 'Log', 'upload', [uri]);
				}
			} catch (e) {
				logmessage("Log.uploadLogs: error: " + e);
			}
		},

		mailLogs : function (success, fail, email) {
			
			try {
				if (exec) {
					exec(success, fail, 'Log', 'mail', [email]);
				}
			} catch (e) {
				logmessage("Log.uploadLogs: error: " + e);
			}
		},

		deleteLogFiles : function (success, fail) {
			
			try {
				if (exec) {
					exec(success, fail, 'Log', 'deleteLogFiles', []);
				}
			} catch (e) {
				logmessage("Log.uploadLogs: error: " + e);
			}
		}
	};

