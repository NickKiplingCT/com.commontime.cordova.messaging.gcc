package com.commontime.mdesign.plugins.notificationsbase;

import com.commontime.mdesign.plugins.notificationsbase.db.DBInterface;
import com.commontime.mdesign.plugins.notificationsbase.db.PushMessage;

import org.apache.cordova.CordovaResourceApi;
import org.json.JSONException;

import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.util.concurrent.Future;

public interface PushSystemInterface {

	@Retention(value=RetentionPolicy.RUNTIME)
	public @interface PushSystemName {
		String value();
	}

	public static enum SendResult {
		Success,
		Failed,
		FailedDoNotRetry
	}

	public void stop();
	public void subscribeChannel(String channel);
	public void unsubscribeChannel(String channel);
	public void setObserver(PushSystemObserver observer);
	public Future<SendResult> sendMessage(PushMessage msg);
	public void start(DBInterface db);
	public void setNetworkConnected(boolean connected);
	public String getName();
	public void configure(String config);
	public void checkOnce(DBInterface notificationsDB, SingleCheckObserver singleCheckObserver);
	public void prepareMessage(PushMessage msg, CordovaResourceApi cordovaResourceApi) throws JSONException;

}