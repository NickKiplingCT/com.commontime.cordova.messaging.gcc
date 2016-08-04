function startZumo () {
  function success () {
    var test = document.getElementById('test')

    test.style.display = 'block'
  }

  function error (message) {
    window.alert('Failed to start Azure Mobile Services: ' + message)
  }

  var options = {
    url: 'https://ct-testteam.azure-mobile.net/',
    applicationKey: 'tGCcPEPZeJeNanJUbRaCVNMhMiPIqI35',
    authenticationMethod: 'windowsazureactivedirectory',
    useBlobStorage: true
  }

  plugins.zumo.start(success, error, options)
}

// This sends the actual ZUMOrequets by forming the config into a message.
// The receiver is who is interested in getting the response when it comes back;
// the responseCallback function is called when we detect the response in the
// inbox.
function sendZumoRequest(content, receiver, responseCallback) {
  var channel = "testzumo";
  var subchannel = "response_" + Math.random();

  function callback(error, messageId) {
    if (error === undefined) {
      console.log('sent ZUMO request');

      plugins.notify.receiveMessageNotification(receiver, channel, subchannel, responseCallback);
    }
    else {
      console.log("failed to send ZUMO request" + error);
    }
  }

  var message = {
    channel: channel,
    subchannel: subchannel,
    provider: 'azure.mobileservices',
    content: content
  }

  plugins.notify.sendMessage(message, callback);
}

// This calls the message API, which just requires the Application Key to authenticate,
// and returns a simple JSON object.
function makeMessageRequest()
{
  var receiver = "request_" + Math.random()

  // This callback deals with the HTTP response of the REST message when we
  // receive it. The response data will be in the data field of the message content
  function receivedResponse (error, message) {
    if (error === undefined) {
      console.log(JSON.stringify(message.content))

      document.getElementById('makeMessageResponse').innerHTML = message.content.response.data.message

      plugins.notify.deleteMessage(message.id)
    }
    else {
      console.log('received error response');
    }

    plugins.notify.cancelMessageNotification(receiver, function () { });
  }

  var content = {
    transport: {
      type: 'zumoDirect',
      httpMethod: 'POST',
      api: 'message'
    }
  }

  sendZumoRequest(content, receiver, receivedResponse);
}

// This calls the messageauth API, which needs AAD to authenticate, and returns
// a fixed JSON object.
function makeMessageAuthRequest()
{
  var receiver = "request_" + Math.random()

  // This callback deals with the HTTP response of the REST message when we
  // receive it. The response data will be in the data field of the message content
  function receivedResponse (error, message) {
    if (error === undefined) {
      console.log(JSON.stringify(message.content))

      document.getElementById('makeMessageAuthResponse').innerHTML = message.content.response.data.message

      plugins.notify.deleteMessage(message.id)
    }
    else {
      console.log('received error response');
    }

    plugins.notify.cancelMessageNotification(receiver, function () { });
  }

  var content = {
    transport: {
      type: 'zumoDirect',
      httpMethod: 'POST',
      api: 'messageauth'
    }
  }

  sendZumoRequest(content, receiver, receivedResponse);
}

// This calls the photo upload API method, which requires AAD authentication,
// which takes a photo and uploads it to blob storage.
function makePhotoRequest () {
  function onSuccess(imageURI) {
    var receiver = "request_" + Math.random()

    // This callback deals with the HTTP response of the REST message when we
    // receive it. The response data will be in the data field of the message content
    function receivedResponse (error, message) {
      if (error === undefined) {
        window.alert('Uploaded photo!')

        plugins.notify.deleteMessage(message.id)
      }
      else {
        console.log('received error response');
      }

      plugins.notify.cancelMessageNotification(receiver, function () { });
    }

    var content = {
      transport: {
        type: 'zumoDirect',
        httpMethod: 'POST',
        api: 'photo'
      },
      data: '#fileref:' + imageURI
    }

    sendZumoRequest(content, receiver, receivedResponse)
  }

  function onFail(message) {
    alert('Failed because: ' + message)
  }

  navigator.camera.getPicture(onSuccess, onFail, { quality: 75, destinationType: Camera.DestinationType.FILE_URI })
}
