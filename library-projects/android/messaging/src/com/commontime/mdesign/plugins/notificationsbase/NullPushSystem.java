package com.commontime.mdesign.plugins.notificationsbase;

import com.commontime.mdesign.plugins.notificationsbase.db.DBInterface;
import com.commontime.mdesign.plugins.notificationsbase.db.PushMessage;

import org.apache.cordova.CordovaResourceApi;
import org.json.JSONException;

import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

@PushSystemInterface.PushSystemName("null")
public class NullPushSystem extends PushSystem {

	public NullPushSystem(PushEngine engine) {
		super(engine);
	}

	@Override
	public void stop() {
	}

	@Override
	public void subscribeChannel(String channel) {		
	}

	@Override
	public void unsubscribeChannel(String channel) {		
	}

	@Override
	public Future<SendResult> sendMessage(PushMessage msg) {
		final ExecutorService service = Executors.newSingleThreadScheduledExecutor();
		return service.submit(new Callable<SendResult>() {
			@Override
			public SendResult call() throws Exception {
				return SendResult.FailedDoNotRetry;
			}
		});
	}

	@Override
	public void start(DBInterface db) {
		if( observer != null )
			observer.connectionStateChange(State.unconfigured);
	}

	@Override
	public void setNetworkConnected(boolean connected) {		
	}

	@Override
	public void configure(String config) {
		// TODO Auto-generated method stub
		
	}

	@Override
	public void prepareMessage(PushMessage msg, CordovaResourceApi cordovaResourceApi) throws JSONException {

	}

	@Override
	public void checkOnce(DBInterface notificationsDB, SingleCheckObserver singleCheckObserver) {
		singleCheckObserver.checkComplete();
	}

	@Override
	public String getName() {
		return "null";
	}

}
