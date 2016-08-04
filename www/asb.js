var argscheck = require('cordova/argscheck'), exec = require('cordova/exec');

module.exports = {
  start : function(successCallback, errorCallback, options) {
    cordova.exec(successCallback, errorCallback, "ASB", "start", [options]);
  }
}
