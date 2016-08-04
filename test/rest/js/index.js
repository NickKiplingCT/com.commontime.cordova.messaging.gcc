// This starts REST services. You have to wait until the success callback
// is called before you can make a REST request.
function startRest () {
  function success () {
    var test = document.getElementById('test')

    test.style.display = 'block'
  }

  function error (message) {
    window.alert('Failed to start REST: ' + message)
  }

  plugins.rest.start(success, error)
}

// This sends the actual REST requets by forming the config into a message.
// The receiver is who is interested in getting the response when it comes back;
// the responseCallback function is called when we detect the response in the
// inbox.
function sendRestRequest(config, receiver, responseCallback) {
  var channel = "testrest";
  var subchannel = "response_" + Math.random();

  function callback(error, messageId) {
    if (error === undefined) {
      console.log('sent REST request');

      plugins.notify.receiveMessageNotification(receiver, channel, subchannel, responseCallback);
    }
    else {
      console.log("failed to send REST request" + error);
    }
  }

  var message = {
    channel: channel,
    subchannel: subchannel,
    provider: 'rest',
    content: config
  }

  plugins.notify.sendMessage(message, callback);
}

// This triggers the sending of the REST request by forming up the content/config
// of the message that will ultimately be sent and handing it over to the sending
// function.
function testRest() {
  var receiver = "request_" + Math.random()

  // This callback deals with the HTTP response of the REST message when we
  // receive it. The response data will be in the data field of the message content
  function receivedResponse(error, message) {
    if (error === undefined) {
      var response = message.content

      console.log(JSON.stringify(response))

      document.getElementById('name').innerHTML = message.content.data.name
      document.getElementById('gender').innerHTML = message.content.data.gender

      plugins.notify.deleteMessage(message.id)
    }
    else {
      console.log("received error response");
    }

    plugins.notify.cancelMessageNotification(receiver, function () { });
  }

  var person = document.getElementById('person')

  var config = {
    url: 'http://swapi.co/api/people/' + person.value,
    data: null,
    params: {},
    headers: {},
    downloadAsFile: false
  }

  sendRestRequest(config, receiver, receivedResponse);
}
