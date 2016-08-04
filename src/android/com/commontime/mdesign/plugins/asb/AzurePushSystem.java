package com.commontime.mdesign.plugins.asb;

import android.text.TextUtils;
import android.util.Base64;
import android.util.Log;

import com.commontime.mdesign.plugins.base.CTLog;
import com.commontime.mdesign.plugins.base.HttpConnection;
import com.commontime.mdesign.plugins.base.Prefs;
import com.commontime.mdesign.plugins.base.Utils;
import com.commontime.mdesign.plugins.notificationsbase.MessageReceiveObserver;
import com.commontime.mdesign.plugins.notificationsbase.PushEngine;
import com.commontime.mdesign.plugins.notificationsbase.PushSystem;
import com.commontime.mdesign.plugins.notificationsbase.SingleCheckObserver;
import com.commontime.mdesign.plugins.notificationsbase.db.DBInterface;
import com.commontime.mdesign.plugins.notificationsbase.db.PushMessage;
import com.commontime.mdesign.plugins.notificationsbase.exceptions.MDesignConnectionException;

import org.apache.commons.io.IOUtils;
import org.apache.cordova.CordovaResourceApi;
import org.apache.log4j.Priority;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.io.OutputStream;
import java.io.StringReader;
import java.io.UnsupportedEncodingException;
import java.net.HttpURLConnection;
import java.net.ProtocolException;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TimeZone;
import java.util.concurrent.Callable;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

public class AzurePushSystem extends PushSystem implements MessageReceiveObserver, Runnable {

	private final static String BROKER_TYPE_QUEUE = "queue";
	private final static String BROKER_TYPE_TOPIC = "topic";
	private final static String DEFAULT_BROKER_TYPE = BROKER_TYPE_QUEUE;
	private final static boolean DEFAULT_BROKER_AUTO_CREATE = true;
	private boolean singleCheck;
	private SingleCheckObserver singleCheckObserver;
	private int reconnectBackOff = 1;
	public static final String AZURE_SERVICEBUS = "azure.servicebus";

	public AzurePushSystem(PushEngine engine) {
		super(engine);
	}

	public boolean getIsSingleCheck() {
		return singleCheck;
	}

	private enum AuthenticationType {
		AccessControlService,
		SharedAccessSignature
	}

	public class SharedAccessProperties {
		private final String mKeyName;
		private final String mKey;

		public SharedAccessProperties(String keyName, String key) {
			mKeyName = keyName;
			mKey = key;
		}

		public String getKeyName() {
			return mKeyName;
		}

		public String getKey() {
			return mKey;
		}
	}

	public class AccessControlProperties {
		private final String mHostname;
		private final String mNamespaceOwner;
		private final String mNamespaceKey;

		public AccessControlProperties(String hostname, String namespaceOwner, String namespaceKey) {
			mHostname = hostname;
			mNamespaceOwner = namespaceOwner;
			mNamespaceKey = namespaceKey;
		}

		public String getHostname() {
			return mHostname;
		}

		public String getNamespaceOwner() {
			return mNamespaceOwner;
		}

		public String getNamespaceKey() {
			return mNamespaceKey;
		}
	}

	private String sbHostName;
	private String serviceNamespace;
	private String baseAddress;

	private AuthenticationType authenticationType;
	private AccessControlProperties accessControl;
	private SharedAccessProperties sharedAccess;

	private AzureMessageBroker broker;
	private boolean brokerAutoCreate = false;

	private String accessControlToken = "";
	private Map<String, String> sharedAccessTokens = new HashMap<String, String>();

	private ExecutorService executor;
	private ExecutorService singleExecutor = Executors.newSingleThreadExecutor();

	private ConcurrentHashMap<String, AzureMessageReceiver> channelReceiverMap = new ConcurrentHashMap<String, AzureMessageReceiver>();

	private State state = State.idle;
	private List<String> initialChannels;
	private DBInterface mDb;
	private boolean mListen;

	private boolean started = false;
	private List<String> inChannelsCreated = new ArrayList<String>();
	private List<String> outChannelsCreated = new ArrayList<String>();

	@Override
	public synchronized void stop() {
		CTLog.getInstance().log("shell", Priority.DEBUG_INT, "ASB Push System stop()");

		started = false;

		for (String channel : channelReceiverMap.keySet()) {
			unsubscribeChannel(channel);
		}

		disconnect();

		clearTokens();

		CTLog.getInstance().log("shell", Priority.DEBUG_INT, "ASB Push System stop finished");
	}

	private synchronized void connect() throws MDesignConnectionException {
		CTLog.getInstance().log("shell", Priority.DEBUG_INT, "ASB Push System connect()");

		setState(State.connected);

		CTLog.getInstance().log("shell", Priority.INFO_INT, "Subscribing to channels in DB");
		initialChannels = mDb.getChannels();
		for (String channel : initialChannels) {
			CTLog.getInstance().log("secure", Priority.INFO_INT, "Channel: " + channel);
			subscribeChannel(channel);
		}
		CTLog.getInstance().log("shell", Priority.INFO_INT, "Finished subscribing to channels");

		CTLog.getInstance().log("shell", Priority.DEBUG_INT, "ASB Push System connect finished");
	}

	private void setState(State state) {
		this.state = state;

		if( observer != null )
			observer.connectionStateChange(state);
	}

	private synchronized void disconnect() {

		for (AzureMessageReceiver receiver : channelReceiverMap.values()) {
			receiver.cancel();
		}

		channelReceiverMap.clear();
	}

//	public synchronized void reconnect() {
//		CTLog.getInstance().log("shell", Priority.INFO_INT, "Reconnection");
//		setState(State.idle);
//		stop();
//
//		if( !singleCheck ) {
//
//			new Thread( new Runnable() {
//				public void run() {
//					try {
//						Thread.sleep(reconnectBackOff * 1000);
//						AzurePushSystem.this.start();
//					} catch (InterruptedException e) {
//						e.printStackTrace();
//					}
//				}
//			}).start();
//
//			if( reconnectBackOff < 30 )
//				reconnectBackOff += 5;
//		}
//
//		CTLog.getInstance().log("shell", Priority.DEBUG_INT, "Reconnection completed");
//	}

	@Override
	public void subscribeChannel(String channel) {
		if (state == State.connected) {
			synchronized (channelReceiverMap) {
				if (!channelReceiverMap.containsKey(channel)) {
					AzureMessageReceiver receiver = new AzureMessageReceiver(this, channel, this, singleCheck);
					executor.execute(receiver);
					channelReceiverMap.put(channel, receiver);
				}
			}
		}
	}

	@Override
	public void unsubscribeChannel(String channel) {
		synchronized (channelReceiverMap) {
			if (channelReceiverMap.containsKey(channel)) {
				channelReceiverMap.get(channel).cancel();
				channelReceiverMap.remove(channel);
			}
		}
	}

	@Override
	public void messageReceived(PushMessage message) {
		// Notify the engine
		observer.messageReceived(message);
	}

	@Override
	public synchronized Future<SendResult> sendMessage(final PushMessage msg) {

		final ExecutorService service = Executors.newSingleThreadScheduledExecutor();

		return service.submit(new Callable<SendResult>() {

			@Override
			public SendResult call() throws Exception {

				if( msg.expired() ) {
					CTLog.getInstance().log("notify-send", Priority.DEBUG_INT, "Message has expired: " + msg.getId());
					return SendResult.FailedDoNotRetry;
				}

				String channel = msg.getChannel();

				createOutChannel(channel);

				CTLog.getInstance().log("notify-send", Priority.INFO_INT, "Sending message " + msg.getId() + " via ASB");

				JSONObject jso;

				try {
					jso = msg.getJSONObject();

					String fullAddress = baseAddress + msg.getChannel() + "/messages" + "?timeout=";
					if( getIsSingleCheck() ) {
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
					connection.addRequestProperty("Authorization", getToken(channel));
					connection.setDoOutput(true);
					connection.setConnectTimeout(130000);
					connection.setReadTimeout(130000);
					try {
						connection.setRequestMethod("POST");
					} catch (ProtocolException e) {
						e.printStackTrace();
					}

					long date = msg.getDate();
					long expiry = msg.getExpiry();
					if (expiry > date) {
						long timeToLive = (expiry - date) / 1000;
						JSONObject brokerProperties = new JSONObject();
						brokerProperties.put("TimeToLive", timeToLive);
						connection.addRequestProperty("BrokerProperties", brokerProperties.toString());
					}
					try {
						OutputStream os = connection.getOutputStream();
						IOUtils.copy(new StringReader(jso.toString()), os);
					} catch (IOException e) {
						e.printStackTrace();
					}

					CTLog.getInstance().log("notify-send", Priority.WARN_INT, "Executing HTTP POST to send message");
					connection.connect();
					int statusCode = connection.getResponseCode();
					CTLog.getInstance().log("notify-send", Priority.WARN_INT, "HTTP POST to send message completed: " + statusCode);

					CTLog.getInstance().log("notify-send", Priority.INFO_INT, "ASB response: " + connection.getResponseMessage());

					if (statusCode == 401) {
						// reconnect();
						System.out.println(7/0);
						// TODO: Fix.
						return SendResult.Failed;
					}

					if(statusCode == 201) {
						resetBackOff();
						return SendResult.Success;
					}

					return SendResult.FailedDoNotRetry;

				} catch (JSONException e) {
					CTLog.getInstance().log("notify-send", Priority.ERROR_INT, "Failed during sendMessage: " + e.getMessage());
				} catch (UnsupportedEncodingException e) {
					CTLog.getInstance().log("notify-send", Priority.ERROR_INT, "Failed during sendMessage: " + e.getMessage());
				} catch (IOException e) {
					CTLog.getInstance().log("notify-send", Priority.ERROR_INT, "Failed during sendMessage: " + e.getMessage());
					return SendResult.Failed;
				}

				return SendResult.FailedDoNotRetry;

			}
		});
	}

	private void clearTokens() {
		setToken("");
		synchronized (sharedAccessTokens) {
			sharedAccessTokens.clear();
		}
	}

	public String getToken(String channel) {
		switch (this.authenticationType) {
			case AccessControlService:
				return accessControlToken;
			case SharedAccessSignature:
				synchronized (sharedAccessTokens) {
					if (!sharedAccessTokens.containsKey(channel)) {
						generateSharedAccessSignature(channel);
					}
					return this.sharedAccessTokens.get(channel);
				}
			default:
				return "";
		}
	}

	private void generateSharedAccessSignature(String channel) {
		String uri = baseAddress + channel;

		// Use lowercase URL encode for SAS signature
		String encodedUri = Utils.urlEncodeLower(uri);

		TimeZone tz = TimeZone.getTimeZone("UTC");
		Calendar cal = Calendar.getInstance(tz);
		cal.add(Calendar.HOUR, 1);
		long expiry = cal.getTimeInMillis() / 1000;

		String toSign = encodedUri + '\n' + expiry;
		byte[] signatureBytes = Utils.hmacSHA256(this.sharedAccess.getKey(), toSign);

		// Make sure we don't add a newline on to the end
		String signature = Base64.encodeToString(signatureBytes, Base64.NO_WRAP);

		String token = String.format("SharedAccessSignature sig=%s&se=%s&skn=%s&sr=%s",
				Utils.urlEncodeLower(signature),
				expiry,
				this.sharedAccess.getKeyName(),
				encodedUri);
		sharedAccessTokens.put(channel, token);
	}


	public void setToken(String token) {
		this.accessControlToken = token;
	}

	public String getBaseAddress() {
		return baseAddress;
	}

	public void createInChannel(String inChannel) throws IOException {
		if(broker == null)
			return;
		
		if (!brokerAutoCreate) {
			return;
		}

		for( String ch : inChannelsCreated ) {
			if( ch.equals(inChannel))
				return;
		}

		int code = 0;
		for (HttpURLConnection putConnection : broker.getCreateInRequest(inChannel)) {

			putConnection.connect();
			code = putConnection.getResponseCode();

			CTLog.getInstance().log("shell", Priority.INFO_INT, "broker created: " + code);
		}

		if(code == 201 ) {
			// The queue was created
			inChannelsCreated.add(inChannel);
		}

	}

	public void createOutChannel(String outChannel) throws IOException {
		if (!brokerAutoCreate) {
			return;
		}

		for( String ch : outChannelsCreated ) {
			if( ch.equals(outChannel))
				return;
		}

		int code = 0;
		for (HttpURLConnection putConnection : broker.getCreateOutRequest(outChannel)) {
			putConnection.connect();
			code = putConnection.getResponseCode();

			CTLog.getInstance().log("shell", Priority.INFO_INT, "broker created: " + code);
		}

		if(code == 201 ) {
			// The queue was created
			outChannelsCreated.add(outChannel);
		}

	}

	public void resetBackOff() {
		reconnectBackOff = 1;
	}

	@Override
	public void run() {
		try {
			connect();
		} catch (MDesignConnectionException e) {
			CTLog.getInstance().log("shell", Priority.ERROR_INT, "Connected failed on start");
		}

		if( singleCheck ) {

			CTLog.getInstance().log("shell", Priority.INFO_INT, "Will shut down after single check");
			executor.shutdown();

			try {
				executor.awaitTermination(5, TimeUnit.MINUTES);
			} catch (InterruptedException e) {
			}

			CTLog.getInstance().log("shell", Priority.INFO_INT, "ASB Single check terminated");

			singleCheckObserver.checkComplete();
		}
	}

	@Override
	public synchronized void start(DBInterface db) {

		if( !Prefs.get().getBoolean(ASBPlugin.ASB_CONFIGURED, false) ) {
			return;
		}

		mDb = db;
		singleCheck = false;
		start();
	}

	@Override
	public void checkOnce(DBInterface notificationsDB, SingleCheckObserver singleCheckObserver) {
		mDb = notificationsDB;
		singleCheck = true;
		mListen = true;
		this.singleCheckObserver = singleCheckObserver;
		start();
	}

	@Override
	public void prepareMessage(PushMessage msg, CordovaResourceApi cordovaResourceApi) throws JSONException {

	}

	private void start() {
		CTLog.getInstance().log("shell", Priority.DEBUG_INT, "Starting ASB Push System");

		if (started)
			stop();

		executor = Executors.newCachedThreadPool();

		started = true;

		getConfig();

		singleExecutor.execute(this);
	}

	private void getConfig() {

		this.sbHostName = Prefs.get().getString("sbHostName", "");
		Log.d("shell", this.sbHostName);
		this.serviceNamespace = Prefs.get().getString("serviceNamespace", "");
		Log.d("shell", this.serviceNamespace);
		this.baseAddress = "https://" + serviceNamespace + "." + sbHostName + "/";
		Log.d("shell", this.baseAddress);
		this.accessControl = new AccessControlProperties(
				Prefs.get().getString("acsHostName", ""),
				Prefs.get().getString("owner", ""),
				Prefs.get().getString("key", ""));

		this.sharedAccess = new SharedAccessProperties(
				Prefs.get().getString("sasKeyName", ""),
				Prefs.get().getString("sasKey", ""));

		this.authenticationType = TextUtils.isEmpty(this.sharedAccess.getKey()) ?
				AuthenticationType.AccessControlService : AuthenticationType.SharedAccessSignature;

		String brokerType = Prefs.get().getString("brokerType", DEFAULT_BROKER_TYPE);
		Log.d("shell", brokerType);
		this.brokerAutoCreate = Prefs.get().getBoolean("brokerAutoCreate", DEFAULT_BROKER_AUTO_CREATE);
		if (BROKER_TYPE_QUEUE.equalsIgnoreCase(brokerType)) {
			this.broker = new AzureQueueBroker(this);
		} else if (BROKER_TYPE_TOPIC.equalsIgnoreCase(brokerType)) {
			this.broker =  new AzureTopicBroker(this);
		} else {
			CTLog.getInstance().log("shell", Priority.DEBUG_INT, "unknown brokerType '" + brokerType + "' - must be 'topic' or 'queue'");
		}
	}

	@Override
	public void setNetworkConnected(boolean connected) {

	}

	@Override
	public void configure(String config) {
		String[] configs = config.split(",");
		int commaCount = configs.length - 1;
		if (commaCount == 5 || commaCount == 7 || commaCount == 8 || commaCount == 9) {
			String sbHostName = configs[1];
			String acsHostName = configs[2];
			String serviceNamespace = configs[3];
			String key = configs[4];
			String owner = configs[5];

			String sasKeyName = "";
			String sasKey = "";
			if (commaCount > 5) {
				sasKeyName = configs[6];
				sasKey = configs[7];
			}

			String brokerType = DEFAULT_BROKER_TYPE;
			if (commaCount > 7 && configs[8].length() > 0) {
				brokerType = configs[8];
			}

			boolean autoCreate = DEFAULT_BROKER_AUTO_CREATE;
			if (commaCount > 8 && configs[9].length() > 0) {
				autoCreate = Boolean.parseBoolean(configs[9]);
			}

			Prefs.get().edit().putString("sbHostName", sbHostName).commit();
			Prefs.get().edit().putString("acsHostName", acsHostName).commit();
			Prefs.get().edit().putString("serviceNamespace", serviceNamespace).commit();
			Prefs.get().edit().putString("key", key).commit();
			Prefs.get().edit().putString("owner", owner).commit();
			Prefs.get().edit().putString("sasKeyName", sasKeyName).commit();
			Prefs.get().edit().putString("sasKey", sasKey).commit();
			Prefs.get().edit().putString("brokerType", brokerType).commit();
			Prefs.get().edit().putBoolean("brokerAutoCreate", autoCreate).commit();

		} else {
			CTLog.getInstance().log("shell", Priority.ERROR_INT, "Failed to completely configure azure push: expected 5, 7, 8 or 9 commas but found " + commaCount);
		}

	}

	public AzureMessageBroker getBroker() {
		return broker;
	}

	@Override
	public String getName() {
		return AZURE_SERVICEBUS;
	}
}
