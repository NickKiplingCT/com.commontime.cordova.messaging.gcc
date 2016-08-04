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

public class AzureTopicBroker implements AzureMessageBroker {
	
	private AzurePushSystem system;
	
	public AzureTopicBroker(AzurePushSystem system) {
		this.system = system;
	}

	@Override
	public HttpURLConnection[] getCreateOutRequest(String channel) {
		
		String topicName = channel;
		String topicAddress = system.getBaseAddress() + topicName;
		String putTopicData = "<entry xmlns=\"http://www.w3.org/2005/Atom\">"
				+ "<title type=\"text\">"
				+ topicName
				+ "</title>"
				+ "<content type=\"application/xml\">"
				+ "<TopicDescription xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns=\"http://schemas.microsoft.com/netservices/2010/10/servicebus/connect\" />"
				+ "</content>" + "</entry>";

		HttpURLConnection connection = null;
		try {
			connection = HttpConnection.create(topicAddress);
		} catch (KeyManagementException e) {
			e.printStackTrace();
		} catch (NoSuchAlgorithmException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}
		connection.addRequestProperty("Authorization", system.getToken(topicName));
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
			IOUtils.copy(new StringReader(putTopicData), os);
		} catch (IOException e) {
			e.printStackTrace();
		}

		return new HttpURLConnection[] {connection};
	}
	
	@Override
	public HttpURLConnection[] getCreateInRequest(String channel) {
		String[] parts = channel.split("/");
		
		String topicName = parts[0];
		HttpURLConnection topicHttpPut = getCreateOutRequest(topicName)[0];
		
		String subscriptionName = parts.length == 1 ? parts[0] : parts[1];
		String subscriptionPath = getSubscriptionPath(topicName, subscriptionName);
		String subscriptionAddress = system.getBaseAddress() + subscriptionPath;
		String putSubscriptionData = "<entry xmlns=\"http://www.w3.org/2005/Atom\">"
				+ "<title type=\"text\">"
				+ subscriptionName
				+ "</title>"
				+ "<content type=\"application/xml\">"
				+ "<SubscriptionDescription xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns=\"http://schemas.microsoft.com/netservices/2010/10/servicebus/connect\" />"
				+ "<LockDuration>PT5M</LockDuration>"
				+ "<RequiresSession>false</RequiresSession>"
				+ "</content>" + "</entry>";

		HttpURLConnection connection = null;
		try {
			connection = HttpConnection.create(subscriptionAddress);
		} catch (KeyManagementException e) {
			e.printStackTrace();
		} catch (NoSuchAlgorithmException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}
		connection.addRequestProperty("Authorization", system.getToken(subscriptionPath));
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
			IOUtils.copy(new StringReader(putSubscriptionData), os);
		} catch (IOException e) {
			e.printStackTrace();
		}

		return new HttpURLConnection[] {topicHttpPut, connection};
	}

	@Override
	public HttpURLConnection getReceiveConnection(String channel) {
		String subscriptionPath = getSubscriptionPath(channel);
		String fullAddress = system.getBaseAddress() + subscriptionPath + "/messages/head" + "?timeout=";
		if( system.getIsSingleCheck() ) {
			fullAddress+="0";
		} else {
			fullAddress+="120";
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
		connection.addRequestProperty("Authorization", system.getToken(subscriptionPath));
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
		String subscriptionPath = getSubscriptionPath(channel);
		String deleteAddress = system.getBaseAddress() + subscriptionPath + "/messages/" + messageId + "/" + lockToken;

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
		connection.addRequestProperty("Authorization", system.getToken(subscriptionPath));
		connection.setConnectTimeout(130000);
		connection.setReadTimeout(130000);
		try {
			connection.setRequestMethod("DELETE");
		} catch (ProtocolException e) {
			e.printStackTrace();
		}
		return connection;
	}

	private String getSubscriptionPath(String channel) {
		String[] parts = channel.split("/");
		String topicName = parts[0];
		String subscriptionName = parts.length == 1  ? parts[0] : parts[1];
		return getSubscriptionPath(topicName, subscriptionName);
	}

	private String getSubscriptionPath(String topicName, String subscriptionName) {
		return topicName + "/subscriptions/" + subscriptionName;
	}
}
