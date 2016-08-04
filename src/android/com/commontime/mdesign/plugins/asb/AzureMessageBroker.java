package com.commontime.mdesign.plugins.asb;

import java.net.HttpURLConnection;

interface AzureMessageBroker {
	//HttpPut[] getCreateInRequest(String channel) throws UnsupportedEncodingException;
	//HttpPut[] getCreateOutRequest(String channel) throws UnsupportedEncodingException;
	//HttpPost getReceiveRequest(String channel);
	//HttpDelete getDeleteRequest(String channel, String messageId, String lockToken);

	HttpURLConnection[] getCreateInRequest(String inChannel);
	HttpURLConnection[] getCreateOutRequest(String outChannel);

	HttpURLConnection getReceiveConnection(String channel);
	HttpURLConnection getDeleteConnection(String channel, String messageId, String lockToken);
}
