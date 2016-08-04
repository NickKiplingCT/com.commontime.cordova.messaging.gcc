package com.commontime.mdesign.plugins.asb;

import com.commontime.mdesign.plugins.base.CTLog;
import com.commontime.mdesign.plugins.notificationsbase.MessageReceiveObserver;
import com.commontime.mdesign.plugins.notificationsbase.db.PushMessage;

import org.apache.commons.io.IOUtils;
import org.apache.log4j.Priority;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.io.InputStream;
import java.io.StringWriter;
import java.net.HttpURLConnection;
import java.util.concurrent.Semaphore;

public class AzureMessageReceiver implements Runnable {

	private final boolean singleCheck;
	private boolean cancelled = false;

	private AzurePushSystem system;
	private String channel;
	private MessageReceiveObserver messageReceiver;

	private HttpURLConnection receiveConnection;
	private HttpURLConnection deleteConnection;

	public AzureMessageReceiver(AzurePushSystem system, String channel, MessageReceiveObserver messageReceiver, boolean singleCheck) {
		this.system = system;
		this.channel = channel;
		this.messageReceiver = messageReceiver;
		this.singleCheck = singleCheck;
	}

	public void cancel() {
 		CTLog.getInstance().log("shell", Priority.INFO_INT, "Cancelling ASB Receiver: " + this.toString());
		
		cancelled = true;

		final Semaphore s = new Semaphore(0);

		// Can't be done in the main thread.
		new Thread(new Runnable() {

			@Override
			public void run() {

				disconnect();

				s.release();
			}

		}).start();
		
		try {
			s.acquire();
		} catch (InterruptedException e) {
			e.printStackTrace();
		}
		
		CTLog.getInstance().log("shell", Priority.INFO_INT, "Cancelled ASB Receiver: " + this.toString());
	}

	private void disconnect() {
		if( receiveConnection != null )
            receiveConnection.disconnect();

		if( deleteConnection != null )
            deleteConnection.disconnect();
	}

	@Override
	public void run() {

		Thread.currentThread().setName(this.toString());

		try {
			system.createInChannel(channel);
			//createTopic();
			//createSubscription();
			//createRule();
			
			while (!cancelled) {

				String responseString = receiveAndDeleteMessage();
				system.resetBackOff();

				if (responseString != null ) {
					// Parse the message here
					JSONObject obj = null;
					PushMessage message = null;
					try {
						obj = new JSONObject(responseString);

						// Parse the message
						message = new PushMessage(obj);

						message.setProvider(AzurePushSystem.AZURE_SERVICEBUS);

						// Send the message to the receiver
						messageReceiver.messageReceived(message);

					} catch (JSONException e) {
						// e.printStackTrace();
						CTLog.getInstance().log("shell", Priority.ERROR_INT, "Invalid message received: " + e.getMessage());
					}
				} else {
					if (singleCheck)
						break;
				}
			}
		} catch (IOException e) {
			// e.printStackTrace();
			CTLog.getInstance().log("shell", Priority.ERROR_INT, "Error during receive: " + e.getMessage());
			// TODO: Fix
			// if (!cancelled && !singleCheck)
				// system.reconnect();
		}

		CTLog.getInstance().log("shell", Priority.INFO_INT, "Exiting ASB Receiver thread" );
	}

	private String receiveAndDeleteMessage() throws IOException {
		
		CTLog.getInstance().log("shell", Priority.INFO_INT, "Waiting to receive message on channel: " + channel);

		receiveConnection = system.getBroker().getReceiveConnection(channel);
		
		CTLog.getInstance().log("shell", Priority.WARN_INT, "Executing HTTP POST for new message");
		CTLog.getInstance().log("shell", Priority.INFO_INT, receiveConnection.getURL().toString());

		receiveConnection.connect();
		int statusCode = receiveConnection.getResponseCode();

		CTLog.getInstance().log("shell", Priority.WARN_INT, "HTTP POST to receive message completed");
		CTLog.getInstance().log("shell", Priority.INFO_INT, "ASB response:" + receiveConnection.getResponseMessage());

		if (statusCode == 401) {
			// Need new token
			disconnect();
			// system.reconnect();
			// TODO: Fix
			return null;
		} else 

		if (statusCode == 204) {
			// timed out
			disconnect();
			return null;
		}

		if (statusCode == 404 || statusCode == 410) {
			// No such queue - report this
			disconnect();
			CTLog.getInstance().log("shell", Priority.ERROR_INT, "Response on channel: " + statusCode);
		} else 

		if (statusCode == 201) {
			// got a message

			String brokerProperties = receiveConnection.getHeaderField("BrokerProperties");

			String lockToken = "", messageId = "";
			try {
				JSONObject jso = new JSONObject(brokerProperties);
				lockToken = jso.getString("LockToken");
				messageId = jso.getString("MessageId");
			} catch (JSONException e) {
				CTLog.getInstance().log("shell", Priority.ERROR_INT, "Message did not contain valid id: " + e.getMessage());
				e.printStackTrace();
			}

			InputStream is = receiveConnection.getInputStream();

			StringWriter writer = new StringWriter();
			IOUtils.copy(is, writer, "UTF-8");
			String responseString = writer.toString();
			
			CTLog.getInstance().log("shell", Priority.DEBUG_INT, channel + " (read): " + statusCode);

			receiveConnection.disconnect();

			// Now we need to delete
			deleteConnection = system.getBroker().getDeleteConnection(channel, messageId, lockToken);

			CTLog.getInstance().log("shell", Priority.WARN_INT, "Executing HTTP DELETE for new message");
			deleteConnection.connect();
			CTLog.getInstance().log("shell", Priority.WARN_INT, "HTTP DELETE completed");

			statusCode = deleteConnection.getResponseCode();

			CTLog.getInstance().log("shell", Priority.DEBUG_INT, channel + " (del): " + statusCode);
			deleteConnection.disconnect();

			return responseString;
		} else {		
			
			CTLog.getInstance().log("shell", Priority.ERROR_INT, "Response: " + statusCode );
			disconnect();
		}

		return null;

	}
}