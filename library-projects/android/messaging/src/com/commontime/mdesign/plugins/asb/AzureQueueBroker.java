package com.commontime.mdesign.plugins.asb;

import com.commontime.mdesign.plugins.base.HttpConnection;

import org.apache.commons.io.IOUtils;

import java.io.IOException;
import java.io.OutputStream;
import java.io.StringReader;
import java.net.HttpURLConnection;
import java.net.ProtocolException;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;

public class AzureQueueBroker implements AzureMessageBroker {
	
	private AzurePushSystem system;
	
	public AzureQueueBroker(AzurePushSystem system) {
		this.system = system;
	}
	
	@Override
	public HttpURLConnection[] getCreateInRequest(String channel) {
		String queueAddress = system.getBaseAddress() + channel;
	
		String putData = "<entry xmlns=\"http://www.w3.org/2005/Atom\">"
				+ "<title type=\"text\">"
				+ channel
				+ "</title>"
				+ "<content type=\"application/xml\">"
				+ "<QueueDescription xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns=\"http://schemas.microsoft.com/netservices/2010/10/servicebus/connect\">"
				+ "<LockDuration>PT10S</LockDuration></QueueDescription>"
				+ "</content>" + "</entry>";

		HttpURLConnection connection = null;
		try {
			connection = HttpConnection.create(queueAddress);
		} catch (KeyManagementException e) {
			e.printStackTrace();
		} catch (NoSuchAlgorithmException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}
		connection.addRequestProperty("Authorization", system.getToken(channel));
		connection.setDoOutput(true);
		connection.setDoInput(true);
		connection.setConnectTimeout(130000);
		connection.setReadTimeout(130000);
		try {
			connection.setRequestMethod("PUT");
		} catch (ProtocolException e) {
			e.printStackTrace();
		}
		try {
			OutputStream os = connection.getOutputStream();
			IOUtils.copy(new StringReader(putData), os);
		} catch (IOException e) {
			e.printStackTrace();
		}


		return new HttpURLConnection[] {connection};
	}
	
	@Override
	public HttpURLConnection[] getCreateOutRequest(String channel) {
		return getCreateInRequest(channel);
	}

	@Override
	public HttpURLConnection getReceiveConnection(String channel) {
		String fullAddress = system.getBaseAddress() + channel + "/messages/head" + "?timeout=";
		if( system.getIsSingleCheck() ) {
			fullAddress+="0";
		} else {
			fullAddress+="55";
		}
		HttpURLConnection connection = null;
		try {
			connection = HttpConnection.create(fullAddress);
		} catch (KeyManagementException e) {
			e.printStackTrace();
		} catch (NoSuchAlgorithmException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}
		connection.addRequestProperty("Authorization", system.getToken(channel));
		connection.setDoOutput(true);
		connection.setConnectTimeout(130000);
		connection.setReadTimeout(130000);
		try {
			connection.setRequestMethod("POST");
		} catch (ProtocolException e) {
			e.printStackTrace();
		}

		return connection;
	}

	@Override
	public HttpURLConnection getDeleteConnection(String channel, String messageId, String lockToken) {
		String deleteAddress = system.getBaseAddress() + channel + "/messages/" + messageId + "/" + lockToken;
		HttpURLConnection connection = null;
		try {
			connection = HttpConnection.create(deleteAddress);
		} catch (KeyManagementException e) {
			e.printStackTrace();
		} catch (NoSuchAlgorithmException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}
		connection.addRequestProperty("Authorization", system.getToken(channel));
		connection.setConnectTimeout(130000);
		connection.setReadTimeout(130000);
		try {
			connection.setRequestMethod("DELETE");
		} catch (ProtocolException e) {
			e.printStackTrace();
		}
		return connection;
	}

}
