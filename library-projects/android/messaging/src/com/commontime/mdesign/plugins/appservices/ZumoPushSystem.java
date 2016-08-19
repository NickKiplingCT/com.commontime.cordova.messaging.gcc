package com.commontime.mdesign.plugins.appservices;

import android.os.Build;
import android.os.SystemClock;
import android.util.Pair;
import android.webkit.CookieManager;
import android.webkit.ValueCallback;

import com.commontime.mdesign.plugins.base.CTLog;
import com.commontime.mdesign.plugins.base.Prefs;
import com.commontime.mdesign.plugins.base.Utils;
import com.commontime.mdesign.plugins.notificationsbase.MessageReceiveObserver;
import com.commontime.mdesign.plugins.notificationsbase.PushEngine;
import com.commontime.mdesign.plugins.notificationsbase.PushSystem;
import com.commontime.mdesign.plugins.notificationsbase.SingleCheckObserver;
import com.commontime.mdesign.plugins.notificationsbase.db.DBInterface;
import com.commontime.mdesign.plugins.notificationsbase.db.FileRefHandler;
import com.commontime.mdesign.plugins.notificationsbase.db.FileRefHandlerInterface;
import com.commontime.mdesign.plugins.notificationsbase.db.PushMessage;
import com.google.common.util.concurrent.ListenableFuture;
import com.microsoft.windowsazure.mobileservices.MobileServiceClient;
import com.microsoft.windowsazure.mobileservices.ServiceFilterResponseCallback;
import com.microsoft.windowsazure.mobileservices.authentication.MobileServiceAuthenticationProvider;
import com.microsoft.windowsazure.mobileservices.authentication.MobileServiceUser;
import com.microsoft.windowsazure.mobileservices.http.ServiceFilterResponse;

import org.apache.cordova.CordovaResourceApi;
import org.apache.log4j.Priority;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.net.MalformedURLException;
import java.util.AbstractList;
import java.util.ArrayList;
import java.util.Date;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import javax.net.ssl.SSLHandshakeException;

public class ZumoPushSystem extends PushSystem implements MessageReceiveObserver {

	public static final String FINISHED_ZUMO_LOGIN = "c6WERCaV.K7gaDmDV.zb4kcRLd.FINISHED_ZUMO_LOGIN";
	public static final String CANCELLED_ZUMO_LOGIN = "c6WERCaV.K7gaDmDV.zb4kcRLd.CANCELLED_ZUMO_LOGIN";
	public static final String FAILED_ZUMO_LOGIN = "c6WERCaV.K7gaDmDV.zb4kcRLd.FAILED_ZUMO_LOGIN";
	public static final String ZUMO_LOGOUT = "c6WERCaV.K7gaDmDV.zb4kcRLd.ZUMO_LOGOUT";

	private static final String EXPIRED_TYPE = "expired";
	private static final String AUTH_TYPE = "authentication";
	private static final String OTHER_TYPE = "other";
	public static final String AZURE_APP_SERVICES = "azure.appservices";
	private static final String ZUMO_USER_ID = "zumoUserId";
	private static final String ZUMO_USER_TOKEN = "zumoUserToken";
	private boolean receiverRegistered = false;

	private enum Result {
		fail, retryNow, success, failTryLater
	};

	public enum LoginResult {
		success, failed, cancelled
	};

	public ZumoPushSystem(PushEngine engine) {
		super(engine);
	}

	private FileRefHandlerInterface mFileRefHandler;
	private MobileServiceClient mobileServicesClient;
	private boolean started = false;

	protected boolean sendSuccess;
	protected int zumoResponseCode;
	private boolean activityRunning;
	final ExecutorService service = Executors.newSingleThreadScheduledExecutor();
	private JSONObject syncSendResult;
	
	private com.commontime.mdesign.plugins.appservices.AzureStorageUploadTable history = new com.commontime.mdesign.plugins.appservices.AzureStorageUploadTable();

	@Override
	public void checkOnce(DBInterface notificationsDB, SingleCheckObserver singleCheckObserver) {
		// Probably not needed?
	}

	@Override
	public void prepareMessage(PushMessage msg, CordovaResourceApi cordovaResourceApi) throws JSONException {

	}

	@Override
	public synchronized void stop() {
		CTLog.getInstance().log("shell", Priority.DEBUG_INT, "[zumo] Zumo Push System stop()");

		started = false;
		setState(State.idle);

		CTLog.getInstance().log("shell", Priority.DEBUG_INT, "[zumo] Zumo Push System stop finished");
	}

	private void setState(State state) {
		if( observer != null )
			observer.connectionStateChange(state);
	}

	public boolean login() {
		try {
			pushEngine.setStoppable(false);

			String authType = Prefs.get().getString(ZumoPlugin.ZUMO_AUTHENTICATION_METHOD, MobileServiceAuthenticationProvider.WindowsAzureActiveDirectory.toString());
			if (authType.equalsIgnoreCase(MobileServiceAuthenticationProvider.WindowsAzureActiveDirectory.toString()))
				authType = MobileServiceAuthenticationProvider.WindowsAzureActiveDirectory.toString();
			else if (authType.equalsIgnoreCase(MobileServiceAuthenticationProvider.Facebook.toString()))
				authType = MobileServiceAuthenticationProvider.Facebook.toString();
			else if (authType.equalsIgnoreCase(MobileServiceAuthenticationProvider.Google.toString()))
				authType = MobileServiceAuthenticationProvider.Google.toString();
			else if (authType.equalsIgnoreCase(MobileServiceAuthenticationProvider.MicrosoftAccount.toString()))
				authType = MobileServiceAuthenticationProvider.MicrosoftAccount.toString();
			else if (authType.equalsIgnoreCase(MobileServiceAuthenticationProvider.Twitter.toString()))
				authType = MobileServiceAuthenticationProvider.Twitter.toString();
			else
				authType = MobileServiceAuthenticationProvider.WindowsAzureActiveDirectory.toString();

			final MobileServiceAuthenticationProvider mobileServiceAuthenticationProvider = MobileServiceAuthenticationProvider.valueOf(authType);
			setState(State.connecting);
			mobileServicesClient.setContext(pushEngine.getContext());
			ListenableFuture<MobileServiceUser> login = mobileServicesClient.login(mobileServiceAuthenticationProvider);
			pushEngine.setStoppable(true);
			mobileServicesClient.setCurrentUser(login.get());

			Prefs.get().edit().putString(ZUMO_USER_ID, mobileServicesClient.getCurrentUser().getUserId()).commit();
			Prefs.get().edit().putString(ZUMO_USER_TOKEN, mobileServicesClient.getCurrentUser().getAuthenticationToken()).commit();

			setState(State.connected);
			return true;
		} catch (ClassCastException cce) {
			cce.printStackTrace();
			return false;
		} catch (InterruptedException e) {
			e.printStackTrace();
			return false;
		} catch (ExecutionException e) {
			CTLog.getInstance().log("shell", Priority.WARN_INT, e.getMessage());
			e.printStackTrace();
			return false;
		}
	}

	@Override
	public void subscribeChannel(String channel) {

	}

	@Override
	public void unsubscribeChannel(String channel) {

	}

	@Override
	public void messageReceived(PushMessage message) {
		// Notify the engine
		message.setProvider(AZURE_APP_SERVICES);
		observer.messageReceived(message);
	}

	@Override
	public synchronized Future<SendResult> sendMessage(final PushMessage msg) {

		return service.submit(new Callable<SendResult>() {

			@Override
			public SendResult call() throws Exception {
				Result thisResult = Result.fail;
				do {
					thisResult = doSend(msg);

					if (thisResult != Result.retryNow)
						break;

					// Wait 5 seconds
					SystemClock.sleep(5000);

				} while (thisResult == Result.retryNow);

				setState(State.idle);
				
				if (thisResult == Result.fail)
					return SendResult.FailedDoNotRetry;
				else if (thisResult == Result.failTryLater)
					return SendResult.Failed;
				else
					return SendResult.Success;
			}
		});
	}

	public JSONObject syncSend(final String method, final String api, final JSONObject data) {

		syncSendResult = null;

		// Do we have credentials?
		String userId = Prefs.get().getString(ZUMO_USER_ID, "");
		String token = Prefs.get().getString(ZUMO_USER_TOKEN, "");

		if (userId.length() > 0 && token.length() > 0) {
			setUser(userId, token);
		}

		final CountDownLatch signal = new CountDownLatch(1);
		final Exception ex = new Exception();

		ArrayList<Pair<String, String>> params = new ArrayList<Pair<String, String>>();
		ArrayList<Pair<String, String>> headers = new ArrayList<Pair<String, String>>();

		ServiceFilterResponseCallback sfcallback = new ServiceFilterResponseCallback() {

			@Override
			public void onResponse(ServiceFilterResponse sfr, Exception exception) {
				pushEngine.setStoppable(true);
				if( sfr == null || sfr.getStatus() == null )
					zumoResponseCode = -1;
				else
					zumoResponseCode = sfr.getStatus().code;

				if (exception != null || zumoResponseCode != 200) {
					signal.countDown();
					return;
				}

				try {
					JSONObject jsa = new JSONObject(sfr.getContent());
					syncSendResult = jsa;
					signal.countDown();
				} catch (JSONException e) {
					exception = e;
					signal.countDown();
					zumoResponseCode = -1;
				}
			}
		};

		pushEngine.setStoppable(false);
		mobileServicesClient.invokeApi(api, data.toString().getBytes(), method, headers, params, sfcallback);

		try {
			signal.await();
		} catch (InterruptedException e) {
			ex.initCause(e);
			e.printStackTrace();
		}

		if( zumoResponseCode == 200 ) {
			return syncSendResult;
		}

		if ( zumoResponseCode == 401) {
			clearCredentials();
			if( login() ) {
				return syncSend(method, api, data);
			}
		}

		return null;
	}

	private synchronized Result doSend(final PushMessage msg) throws IOException {

		if (msg.expired()) {
			try {
				sendFailResponseMsg(msg, EXPIRED_TYPE,
						"Message " + msg.getId() + " expired at " + new Date(msg.getExpiry()).toString()
								+ ". Time now: " + new Date().toString());
			} catch (JSONException e) {
				e.printStackTrace();
				CTLog.getInstance().log("notify-send", Priority.ERROR_INT,
						"[zumo] Failed to send error response: " + e.getMessage());
			}

			CTLog.getInstance().log("notify-send", Priority.DEBUG_INT, "[zumo] Message has expired: " + msg.getId());
			return Result.fail;
		}

		// Do we have credentials?
		String userId = Prefs.get().getString(ZUMO_USER_ID, "");
		String token = Prefs.get().getString(ZUMO_USER_TOKEN, "");

		if (userId.length() > 0 && token.length() > 0) {
			setUser(userId, token);
		}

		CTLog.getInstance().log("shell", Priority.INFO_INT, "[zumo] Attempting to send: " + msg.getId());

		final Exception ex = new Exception();

		if (!started) {
			CTLog.getInstance().log("shell", Priority.WARN_INT, "[zumo] Zumo hasn't started yet, can't send.");
			return Result.failTryLater;
		}

		setState(State.active);

		final CountDownLatch signal = new CountDownLatch(1);

		try {
			try {
				msg.setContent(mFileRefHandler.resolveFileRefs(msg));
				history.messageSent(msg.getId());
			} catch (IOException ioe) {
				CTLog.getInstance().log("shell", Priority.ERROR_INT,
						"[zumo] Error resolving file references: " + ioe.getMessage());
				if( ioe.getCause() != null ) {
					if( ioe.getCause().getCause() != null ) {
						if( ioe.getCause().getCause().getCause() != null && ioe.getCause().getCause().getCause() instanceof AzureStorageCloudManager.GetSasTokenException) {
							return Result.failTryLater;
						}
						// This is the case we can't launch the login UI.
						if( ioe.getCause().getCause() instanceof ClassCastException ) {
							if( ioe.getCause().getCause().getMessage().equals("android.app.Application cannot be cast to android.app.Activity")) {
								CTLog.getInstance().log("shell", Priority.ERROR_INT,
										"[zumo] (no UI available to display login");
								return Result.failTryLater;
							}
						}
					}
				}

				sendFailResponseMsg(msg, OTHER_TYPE, "Error resolving file references: " + ioe.getMessage());
				return Result.fail;
			} catch (JSONException je) {
				CTLog.getInstance().log("shell", Priority.ERROR_INT,
						"[zumo] Error resolving file references: " + je.getMessage());
				sendFailResponseMsg(msg, OTHER_TYPE, "Error resolving file references: " + je.getMessage());
				return Result.fail;
			}
		} catch (JSONException je1) {
			je1.printStackTrace();
			CTLog.getInstance().log("shell", Priority.ERROR_INT,
					"[zumo] Error sending error response message: " + je1.getMessage());
		}

		String zumoType = "";
		String httpMethod = "GET";
		String zumoApi = "";

		JSONObject jsonContent = msg.getJSONContent();
		try {
			if(jsonContent.has("transport")) {
                JSONObject transport = jsonContent.getJSONObject("transport");
                zumoType = transport.getString("type");
                httpMethod = transport.getString("httpMethod");
                zumoApi = transport.getString("api");
            }
		} catch (JSONException e) {
			e.printStackTrace();
		}

//		JsonElement body = new JsonParser().parse(content);
//		if (body != null && body.isJsonObject()) {
//			JsonObject bodyObject = body.getAsJsonObject();
//			if (bodyObject.has("transport")) {
//				JsonElement transportElement = bodyObject.get("transport");
//				if (transportElement.isJsonObject()) {
//					JsonObject transport = transportElement.getAsJsonObject();
//					if (transport.has("type")) {
//						if (transport.get("type").isJsonPrimitive()) {
//							zumoType = transport.get("type").getAsString();
//						}
//					}
//					if (transport.has("httpMethod")) {
//						if (transport.get("httpMethod").isJsonPrimitive()) {
//							httpMethod = transport.get("httpMethod").getAsString();
//						}
//					}
//					if (transport.has("api")) {
//						if (transport.get("api").isJsonPrimitive()) {
//							zumoApi = transport.get("api").getAsString();
//						}
//					}
//				}
//			}
//		}

		try {
			JSONObject context = new JSONObject();
			context.put("clientId", msg.getId());

			jsonContent.put("context", context);
		} catch (JSONException e1) {
			e1.printStackTrace();
			CTLog.getInstance().log("shell", Priority.ERROR_INT,
					"[zumo] Error sending error response message: " + e1.getMessage());
		}



		// body = new JsonParser().parse(jso.toString());
		// byte[] bodyData = jso.toString().getBytes("UTF-8");

		// Check everything
		if (!zumoType.equals("zumoDirect")) {
			CTLog.getInstance().log("shell", Priority.ERROR_INT, "[zumo] Unknown zumo transport type: " + zumoType);
			setState(State.idle);
			return Result.fail;
		}

		if (zumoApi.length() < 1) {
			CTLog.getInstance().log("shell", Priority.ERROR_INT, "[zumo] No API call specified: " + zumoApi);
			setState(State.idle);
			return Result.fail;
		}

		zumoResponseCode = -1;

		ServiceFilterResponseCallback sfcallback = new ServiceFilterResponseCallback() {
			@Override
			public void onResponse(ServiceFilterResponse sfr, Exception exception) {
				pushEngine.setStoppable(true);

				if (sfr != null) {
					CTLog.getInstance().log("shell", Priority.INFO_INT,
							"[zumo] Zumo has responded (" + msg.getId() + "): " + sfr.getStatus().code);
					zumoResponseCode = sfr.getStatus().code;
				} else {
					zumoResponseCode = 0;
				}

				if (exception != null) {
					sendSuccess = false;
					CTLog.getInstance().log("shell", Priority.WARN_INT,
							"[zumo] Zumo responsed with exception: responded: " + exception.toString());
					if( exception.getCause() != null )
						CTLog.getInstance().log("shell", Priority.WARN_INT,
								"[zumo] Zumo responsed with exception: responded: " + exception.getCause().toString());
					ex.initCause(exception);

					signal.countDown();
					return;

				} else if(sfr.getContent() != null) {
					sendSuccess = true;
					try {

						JSONObject jsa = new JSONObject(sfr.getContent());
						sendSuccessResponseMsg(msg, jsa);
						signal.countDown();

						return;
						// success

					} catch (JSONException e) {
						// TODO: handle
						ex.initCause(e);
						e.printStackTrace();
					} catch (IOException e) {
						// TODO: handle
						ex.initCause(e);
						e.printStackTrace();
					} catch (AzureStorageException e) {
						// TODO Auto-generated catch block
						ex.initCause(e);
						e.printStackTrace();
					}

				} else {
					ex.initCause(new Exception("Unknown error - no data returned"));
				}

				signal.countDown();
				// fail
				// Errors?
			}
		};

		CTLog.getInstance().log("shell", Priority.INFO_INT, "[zumo] Sending request to zumo (" + msg.getId() + ")");
		if (httpMethod.equals("POST") || httpMethod.equals("PUT") || httpMethod.equals("PATCH")) {
			pushEngine.setStoppable(false);
			byte[] bodyData = jsonContent.toString().getBytes("UTF-8");
			AbstractList requestHeaders = new ArrayList();
			requestHeaders.add(new Pair("Content-Type", "application/json"));
			mobileServicesClient.invokeApi(zumoApi, bodyData, httpMethod, requestHeaders, new ArrayList<Pair<String, String>>(), sfcallback);
		} else if (httpMethod.equals("GET") || httpMethod.equals("DELETE")) {
			pushEngine.setStoppable(false);
			AbstractList requestHeaders = new ArrayList();
			requestHeaders.add(new Pair("Content-Type", "application/json"));
			ArrayList<Pair<String, String>> params = new ArrayList<Pair<String, String>>();
			params.add(new Pair<String, String>("data", msg.getContent()));
			mobileServicesClient.invokeApi(zumoApi, null, httpMethod, requestHeaders, params, sfcallback);
		} else {
			CTLog.getInstance().log("shell", Priority.ERROR_INT, "[zumo] Unknown HTTP Method: " + httpMethod);
			setState(State.idle);
			return Result.fail;
		}

		try {
			signal.await();
		} catch (InterruptedException e) {
			ex.initCause(e);
			e.printStackTrace();
		}

		setState(State.idle);

		try {
			switch (zumoResponseCode) {
			case -1:
			case 0: {
				// Need to examine the exception
				if (ex.getCause().getCause() instanceof SSLHandshakeException) {
					sendFailResponseMsg(msg, AUTH_TYPE, ex.getCause().getCause().getMessage());
					return Result.fail;
				}
				if (ex.getCause().getCause() instanceof IOException) {
					if (msg.getExpiry() == 0) {
						sendFailResponseMsg(msg, EXPIRED_TYPE, ex.getCause().getCause().getMessage());
						return Result.fail;
					}
					// Don't send a message unless it has expired.
					return Result.failTryLater;
				}
			}
			case 200: {
				// We've already sent a success message
				return Result.success;
			}
			case 401: {
				// Am I in the foreground??!
				if( login() )
					return doSend(msg);
				else
					return Result.failTryLater;
			}
			default: {
				sendFailResponseMsg(msg, OTHER_TYPE, ex.getCause().getMessage());
				return Result.fail;
			}
			}
		} catch (JSONException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		return Result.fail;

		/*
		 * if( ex.getCause() != null ) { if(ex.getCause() instanceof
		 * MobileServiceException ) { // If 401 then doLogin and return retry
		 * try { JSONObject obj = new
		 * JSONObject(ex.getCause().getCause().getMessage()); if(
		 * obj.getInt("code") == 401 ) { doALogin(); return Result.retry; } else
		 * { return Result.fail; } } catch (JSONException e) {
		 * e.printStackTrace(); return Result.fail; } } if(ex.getCause()
		 * instanceof IOException ) { return Result.retry; } return Result.fail;
		 * } else { return Result.success; }
		 */
	}

	@Override
	public void start(DBInterface db) {

		if (started)
			return;

		if( !Prefs.get().getBoolean(ZumoPlugin.ZUMO_CONFIGURED, false) ) {
			return;
		}

		synchronized (this) {

			started = true;

			CTLog.getInstance().log("shell", Priority.DEBUG_INT, "[zumo] Starting Zumo Push System");

			String appUrl = Prefs.get().getString(ZumoPlugin.ZUMO_URL, "");

			if (Prefs.get().getBoolean(ZumoPlugin.ZUMO_USE_BLOB_STORAGE, false)) {
				mFileRefHandler = new ZumoBlobFileRefHandler(this, pushEngine.getContext());
			} else {
				mFileRefHandler = new FileRefHandler(pushEngine.getContext());
			}

			setState(State.connecting);

			try {
				mobileServicesClient = new MobileServiceClient(appUrl, pushEngine.getContext());
			} catch (MalformedURLException e) {
				CTLog.getInstance().log("shell", Priority.ERROR_INT,
						"[zumo] Couldn't init Azure mobile services connection: " + e.toString());
				setState(State.idle);
				started = false;
				return;
			}

			String userId = Prefs.get().getString(ZUMO_USER_ID, "");
			String token = Prefs.get().getString(ZUMO_USER_TOKEN, "");

			if (userId.length() > 0 && token.length() > 0) {
				setUser(userId, token);
			} else {

			}

			setState(State.idle);
		}
	}

	private void clearCredentials() {
		Prefs.get().edit().putString(ZUMO_USER_ID, "").putString(ZUMO_USER_TOKEN, "").commit();
	}

	// Delete me
	private String constructCustomAuthBaseURL(boolean online) {
		String url = "";

		url += "http";

		if (Prefs.getUseSSL()) {
			url += "s";
		}

		url += "://";

		url += Prefs.get().getString("hostConnectionEdit", "0.0.0.0");
		String port = Prefs.get().getString("portConnectionEdit", "616");
		if (port.isEmpty())
			port = "616";
		if (!(port.equals("80") || port.equals("443"))) {
			url += ":";
			url += port;
		}

		url += "/mdesign/0/procs";

		return url;
	}

	// Delete me
	private String constructCustomAuthURL(boolean online) {
		String url = constructCustomAuthBaseURL(online);
		String baseParams = Utils.getParams(pushEngine.getContext(), false, false);

		url += "/authenticate.html" + baseParams;

		if (Prefs.getUsername() != null && !Prefs.getUsername().isEmpty()) {
			if (baseParams.isEmpty()) {
				url += "?username=" + Prefs.getUsername();
			} else {
				url += "&username=" + Prefs.getUsername();
			}
		}

		url += url.contains("?") ? "&" : "?";

		url += "canSavePassword=" + Prefs.get().getBoolean("canSavePassword", true);
		url += "&shouldLockPassword=" + Prefs.get().getBoolean("shouldLockPassword", false);
		url += "&shouldLockSettings=" + Prefs.get().getBoolean("shouldLockSettings", false);

		return url;
	}

	public void updateUser(MobileServiceUser user) {
		mobileServicesClient.setCurrentUser(user);

		setState(State.connected);
	}
	
	@Override
	public void configure(String config) {
		try {
			String[] configs = config.split(",");

			String zumoAppUrl = configs[1];
			String zumoAppKey = configs[2];
			String storageType = configs[3];

			Prefs.get().edit().putString("zumoAppUrl", zumoAppUrl).commit();
			Prefs.get().edit().putString("zumoAppKey", zumoAppKey).commit();
			Prefs.get().edit().putString("zumoStorageType", storageType).commit();			

			if( configs.length > 4 ) {
				String authType = configs[4];
				if( authType.equalsIgnoreCase("windowsazureactivedirectory")) {
					Prefs.setZumoAuth("ActiveDirectory");
				}

			}

		} catch (IndexOutOfBoundsException e) {
			CTLog.getInstance().log("shell", Priority.ERROR_INT,
					"[zumo] Failed to completely configure zumo push: not enough commas");
		}
	}

	public void setUser(String userId, String token) {
		MobileServiceUser user = new MobileServiceUser(userId);
		user.setAuthenticationToken(token);
		mobileServicesClient.setCurrentUser(user);
		setState(State.connected);
		started = true;
	}

	private void sendFailResponseMsg(final PushMessage msg, String errorType, String errorMessage )
			throws JSONException, IOException {
		String responseChannel = msg.getChannel();
		String responseSubchannel = msg.getSubchannel();

		if (!(responseChannel.equals("ignoreResponse") && responseSubchannel.equals("ignoreResponse"))) {
			// Create an error
			JSONObject errorContent = new JSONObject();
			JSONObject response = new JSONObject();

			response.put("result", false);
			response.put("data", "");

			errorContent.put("response", response);
			errorContent.put("config", msg.getJSONContent());
			errorContent.put("errorType", errorType);
			errorContent.put("errorMessage", errorMessage);
			errorContent.put("reqId", msg.getId());

			PushMessage responseMessage = PushMessage.createNewPushMessage(responseChannel, responseSubchannel,
					errorContent.toString());
			responseMessage.setExpiry(new Date().getTime() + (999 * 365 * 24 * 60 * 60 * 1000));
			responseMessage.setProvider(AZURE_APP_SERVICES);
			observer.messageReceived(responseMessage);
		}
	}

	private void sendSuccessResponseMsg(final PushMessage msg, JSONObject jsa) throws JSONException, IOException,
			AzureStorageException {
		String responseChannel = msg.getChannel();
		String responseSubchannel = msg.getSubchannel();

		if (!(responseChannel.equals("ignoreResponse") && responseSubchannel.equals("ignoreResponse"))) {
			// Create a success
			JSONObject newContent = new JSONObject();
			newContent.put("response", jsa);
			newContent.put("config", msg.getJSONContent());
			newContent.put("errorType", "");
			newContent.put("errorMessage", "");
			newContent.put("reqId", msg.getId());

			PushMessage responseMessage = PushMessage.createNewPushMessage(responseChannel, responseSubchannel,
					newContent.toString());
			responseMessage.setExpiry(new Date().getTime() + (999 * 365 * 24 * 60 * 60 * 1000));
			responseMessage.setContent(mFileRefHandler.createFileRefs(responseMessage.getContent()));
			responseMessage.setProvider(AZURE_APP_SERVICES);
			observer.messageReceived(responseMessage);
		}
	}

	@Override
	public void setNetworkConnected(boolean connected) {
		//CTLog.getInstance().log("notify-send", Priority.INFO_INT, "[zumo] Network connected");
		//if (connected) {
		//	pushEngine.doSendMessages();
		//}
	}

	public void logout(boolean clearCookies) {
		if( mobileServicesClient != null )
			mobileServicesClient.logout();
		Prefs.get().edit().putString(ZUMO_USER_ID, "").commit();
		Prefs.get().edit().putString(ZUMO_USER_TOKEN, "").commit();
		setUser("", "");
		if(clearCookies) {
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
				CookieManager.getInstance().removeAllCookies(new ValueCallback<Boolean>() {
                    @Override
                    public void onReceiveValue(Boolean value) {
                    }
                });
			} else {
				CookieManager.getInstance().removeAllCookie();
			}
		}
	}

	public AzureStorageUploadTable getUploadTable() {
		return history;
	}

	@Override
	public String getName() {
		return AZURE_APP_SERVICES;
	}

}
