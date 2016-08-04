var argscheck = require('cordova/argscheck'), exec = require('cordova/exec');

module.exports = {
  start: function (successCallback, errorCallback) {
    cordova.exec(successCallback, errorCallback, "REST", "start", []);
  }
};
