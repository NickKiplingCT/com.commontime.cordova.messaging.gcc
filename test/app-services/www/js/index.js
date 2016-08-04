function startZumo () {
  function success () {
    var test = document.getElementById('test')

    test.style.display = 'block'
  }

  function error (message) {
    window.alert('Failed to start Azure Mobile Services: ' + message)
  }

  var options = {
    url: 'https://real-mobile-service.azurewebsites.net/',
    authenticationMethod: 'windowsazureactivedirectory',
    useBlobStorage: true
  }

  plugins.zumo.start(success, error, options)
}

function callKPaxtonOne () {
  callKPaxton('kpaxton_one', 'kPaxtonOneResponse')
}

function callKPaxtonTwo () {
  callKPaxton('kpaxton_two', 'kPaxtonTwoResponse')
}

function callKPaxton (api, responseId) {
  var receiver = 'request_' + Math.random()

  function receivedResponse (error, message) {
    if (error === undefined) {
      console.log(JSON.stringify(message))

      document.getElementById(responseId).innerHTML = message.content.response.data.message

      plugins.notify.deleteMessage(message.id)
    } else {
      console.log('received error response')
    }

    plugins.notify.cancelMessageNotification(receiver, function () { })
  }

  var content = {
    transport: {
      type: 'zumoDirect',
      httpMethod: 'GET',
      api: api
    }
  }

  sendZumoRequest(content, receiver, receivedResponse)
}

function makePhotoRequest () {
  function onSuccess (imageURI) {
    var receiver = 'request_' + Math.random()

    // This callback deals with the HTTP response of the REST message when we
    // receive it. The response data will be in the data field of the message content
    function receivedResponse (error, message) {
      if (error === undefined) {
        if (message.content.errorMessage === '') {
          window.alert('Uploaded photo!')
        } else {
          window.alert('Failed to upload photo: ' + message.content.errorMessage)
        }

        plugins.notify.deleteMessage(message.id)
      } else {
        console.log('received error response')
      }

      plugins.notify.cancelMessageNotification(receiver, function () { })
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
    window.alert('Failed because: ' + message)
  }

  navigator.camera.getPicture(onSuccess, onFail, { quality: 75, destinationType: Camera.DestinationType.FILE_URI })
}

function sendZumoRequest (content, receiver, responseCallback) {
  var channel = 'testzumo';
  var subchannel = 'response_' + Math.random();

  function callback (error, messageId) {
    if (error === undefined) {
      console.log('sent ZUMO request')

      plugins.notify.receiveMessageNotification(receiver, channel, subchannel, responseCallback)
    } else {
      console.log('failed to send ZUMO request: ' + error);
    }
  }

  var message = {
    channel: channel,
    subchannel: subchannel,
    provider: 'azure.appservices',
    content: content
  }

  plugins.notify.sendMessage(message, callback)
}
