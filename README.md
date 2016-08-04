# mDesign 10 Messaging

These are the Messaging plugins ported from MD8.

To add the plugins to your project, use:

```
cordova plugins add https://github.com/commontime/com.commontime.cordova.messaging.git
```

or

```xml
<plugin name="com.commontime.mdesign.legacy.messaging" spec="https://github.com/commontime/com.commontime.cordova.messaging.git" />
```

There are currently four plugins, one generic and three specific:

* plugins.notify, which provides the generic messaging system
* plugins.asb, which provides the ASB messaging system
* plugins.rest, which provides the REST messaging system
* plugins.zumo, which provides the Azure Mobile Services (ZUMO) messaging system

### Preferences

The plugins.notify plugin has a single preference, the default push system. This can be specified in the *config.xml* file, e.g.:

```xml
<preference name="defaultPushSystem" value="azure" />
```

or in or using the _setOptions_ method of the notify plugin. Possible values are "asb" and "rest". If this is not specified, you will not be able to receive messages and any sent messages must explicitly set the provider.

The ASB plugin has a number of preferences, which configures the ASB instance. These can be specified in *config.xml*, for e.g.:

```xml
<preference name="sbHostName" value="servicebus.windows.net" />
<preference name="serviceNamespace" value="qa-commontime-sas" />
<preference name="sasKeyName" value="RootManageSharedAccessKey" />
<preference name="sasKey" value="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=" />
<preference name="brokerType" value="queue" />
<preference name="brokerAutoCreate" value="true" />
```

or provide the parameters to the `start` method of the `plugins.asb` class.

The REST plugin has no preferences.

The ZUMO plugin has a number of preferences, which configures the ASB instance. These can be specified in `config.xml`, for e.g.:

```xml
<preference name="zumoUrl" value="..." />
<preference name="zumoApplicationKey" value="..." />
<preference name="zumoAuthenticationMethod" value="..." />
<preference name="zumoUseBlobStorage" value="..." />
```

or provide the parameters to the `start` method of the `plugins.zumo` method.

Note, the `start` method *must* be called to start sending and receiving notifications for a particular provider.

## Calls

_plugins.notify.setOptions_

```javascript
var options =
{
  defaultPushSystem: "azure.servicebus"
};

plugins.notify.setOptions(function() { /* success */ }, function(message) { /* error */}, options);
```

Sets general options for the notification plugins. Currently, only one option is supported,
defaultPushSystem, and that only has three values: "azure.servicebus" (ASB), "rest" (REST) or "azure.mobileservices" (ZUMO).

_plugins.asb.start_

```javascript
var options =
{
  sbHostName: "servicebus.windows.net",
  serviceNamespace: "commontime-test",
  sasKeyName: "RootManageSharedAccessKey",
  sasKey: "xxxxxxxx",
  brokerType: "queue",
  brokerAutoCreate: true
};

plugins.asb.start(function() { /* success */ }, function(message) { /* error */}, options);
```

To use the preferences supplied in the config.xml, omit the *options* parameter.

_plugins.rest.start_

```javascript
plugins.rest.start(function() { /* success */ }, function(message) { /* error */});
```

_plugins.zumo.start_

```javascript
var options =
{
  url: "...",
  authenticationMethod: "...",
  applicationKey: "...",
  useBlobStorage: true
};

plugins.zumo.start(function() { /* success */ }, function(message) { /* error */}, options);
```

To use the preferences supplied in the config.xml, omit the *options* parameter.

_plugins.zumo.logout_

```javascript
plugins.zumo.logout(function() { /* success */ }, function(message) { /* error */});
```

_plugins.notify.addChannel_

```javascript
plugins.notify.addChannel( "newchannel", function( error, channel ) {
  if( error !== null ) console.error(error);
});
```
_plugins.notify.removeChannel_

```javascript
plugins.notify.removeChannel( "oldchannel", function( error, channel ) {
  if( error !== null ) console.error(error);
});
```

_plugins.notify.listChannels_

```javascript
plugins.notify.listChannels( function( error, channels ) {
  if( error !== null ) console.error(error);
  console.dir(channels);
});
```

_plugins.notify.sendMessage_

```javascript
var message = {
  "channel":"newchannel",
  "subchannel":"control",
  "provider": "azure.servicebus", // or "azure.appservices" or "rest"
  "expiry":0,
  "notification": "",
  "content": {"some":"data"}
};

plugins.notify.sendMessage( message, function( error, messageId ) {
  if( error !== null ) console.error(error);
});
```

_plugins.notify.getMessages_

```javascript
plugins.notify.getMessages( "newchannel", "control", function( error, messages ) {
  if( error !== null ) console.error(error);
  console.dir(messages);
});
```

_plugins.notify.getUnreadMessages_

```javascript
plugins.notify.getUnreadMessages( "receiver1", "newchannel", "control", function( error, messages ) {
  if( error !== null ) console.error(error);
  console.dir(messages);
});

```

_plugins.notify.deleteMessage_

```javascript
plugins.notify.deleteMessage( "e4a8e56a-c10a-4454-b9a9-1dd3f2bd0b4f", function( error, messageId ) {
  if( error !== null ) console.error(error);
});
```

_plugins.notify.receiveMessageNotification_

```javascript
plugins.notify.receiveMessageNotification( "receiver1", "newchannel", "control", function( error, message ) {
  if( error !== null ) console.error(error);
  console.dir(message);
});
```
_plugins.notify.cancelMessageNotification_
```
plugins.notify.cancelMessageNotification( "receiver1", function( error, receiver ) {
  if( error !== null ) console.error(error);
});
```

_plugins.notify.cancelAllMessageNotifications_

```javascript
plugins.notify.cancelAllMessageNotifications( function( error ) {
  if( error !== null ) console.error(error);
});

```

_plugins.notify.messageReceivedAck_

```javascript
plugins.notify.messageReceivedAck( "receiver1", "e4a8e56a-c10a-4454-b9a9-1dd3f2bd0b4f", function( error ) {
  if( error !== null ) console.error(error);
});
```

_plugins.notify.receiveInboxChanges_

```javascript
plugins.notify.receiveInboxChanges( "receiver1", function( error, result ) {
  if( error !== null ) { console.error(error); return; }
  console.log( "Action: " + result.action);
  console.dir( result.message );
});
```

_plugins.notify.cancelReceiveInboxChanges_

```javascript
plugins.notify.cancelReceiveInboxChanges( "receiver1", function( error ) {
  if( error !== null ) console.error(error);
});
```

_plugins.notify.receiveOutboxChanges_

```javascript
plugins.notify.receiveOutboxChanges( "receiver1", function( error, result ) {
  if( error !== null ) { console.error(error); return; }
  console.log( "Action: " + result.action);
  console.dir( result.message );
});
```

_plugins.notify.cancelReceiveOutboxChanges_

```javascript
plugins.notify.cancelReceiveOutboxChanges( "receiver1", function( error ) {
  if( error !== null ) console.error(error);
});
```

## Testing

There are frameworks to test the REST and Azure Mobile Services (ZUMO) functionality
under the `test` directory. Create a new Cordova app; add this plugin; replace the
`index.html` and `www/index.js` with those found in the appropriate test subdirectory
(either `test/rest` or `test/zumo`); and build and run. Further instructions are
contained within the app itself.

The REST test performs a simple GET REST request to the Star Wars API.

The Azure Mobile Services (ZUMO) test performs some requests against the ct-testteam
Azure Mobile Service (https://ct-testteam.azure-mobile.net/).

  * The message test calls the message API method, which returns a simple JSON object. Application Key authentication is required.
  * The messageauth test calls the messageauth API method, which returns a simple JSON object. Azure Active Directory authentication is required. You can use test@cttt1.onmicrosoft.com with password T35tUser.
  * The photo test takes a photo, uploads it to blob storage, and calls the photo API method. Azure Active Directory authentication is required. Note, if you wish to use this you'll have to add the cordova-plugin-camera plugin to the project.
