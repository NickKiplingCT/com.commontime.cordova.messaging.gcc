package com.commontime.mdesign.plugins.notificationsbase;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.IBinder;

import com.commontime.mdesign.plugins.base.CTLog;
import com.commontime.mdesign.plugins.base.Prefs;
import com.commontime.mdesign.plugins.notificationsbase.db.NotificationsDBException;
import com.commontime.mdesign.plugins.notificationsbase.db.PushMessage;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.apache.cordova.PluginResult.Status;
import org.apache.log4j.Priority;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class Notify extends CordovaPlugin {

	public static final String NOTIFICATION_PLUGINS = "notificationPlugins";
	public static final String DEFAULT_PUSH_SYSTEM = "defaultPushSystem";

	private boolean mIsBound;
	private NotificationsService mBoundService;

	private ServiceConnection mConnection = new ServiceConnection() {
		public void onServiceConnected(ComponentName className, IBinder service) {
			mBoundService = ((NotificationsService.LocalBinder)service).getService();
			mBoundService.setAppForeground(true);
			mBoundService.setContext(cordova.getActivity());
		}

		public void onServiceDisconnected(ComponentName className) {
			mBoundService = null;
		}
	};

	@Override
	protected void pluginInitialize() {
		Prefs.create(cordova.getActivity().getApplicationContext());

		Prefs.get().edit()
				.putString("pushSystem", preferences.getString(DEFAULT_PUSH_SYSTEM, "")).commit();

		doBindService();
	}

	@Override
	public void onStart() {
		// doBindService();
		if( mBoundService != null) {
			mBoundService.setAppForeground(true);
			mBoundService.setContext(cordova.getActivity());
		}
	}

	@Override
	public void onStop() {
		// doUnbindService();
		if( mBoundService != null) {
			mBoundService.setAppForeground(false);
		}
	}

	@Override
	public void onDestroy() {
		mBoundService.setContext(null);
	}

	void doBindService() {
		cordova.getActivity().bindService(new Intent(cordova.getActivity(),
				NotificationsService.class), mConnection, Context.BIND_AUTO_CREATE);
		mIsBound = true;
	}

	void doUnbindService() {
		if (mIsBound) {
			// Detach our existing connection.
			cordova.getActivity().unbindService(mConnection);
			mIsBound = false;
		}
	}

	@Override
	public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {

		// Action dispatch
		if (action.equals("setOptions")) {
			setOptions(callbackContext, args.optJSONObject(0));
		} else if (action.equals("addChannel")) {
			addChannel(callbackContext, args.optString(0));			
		} else if (action.equals("removeChannel")) {
			removeChannel(callbackContext, args.optString(0));
		} else if (action.equals("listChannels")) {
			listChannels(callbackContext);
		} else if (action.equals("sendMessage")) {
			sendMessage(callbackContext, args.optJSONObject(0));
		} else if (action.equals("getMessages")) {
			getMessages(callbackContext, args.optString(0), args.optString(1));
		} else if (action.equals("getUnreadMessages")) {
			getUnreadMessages(callbackContext, args.optString(0), args.optString(1), args.optString(2));
		} else if (action.equals("deleteMessage")) {
			deleteMessage(callbackContext, args.optString(0));
		} else if (action.equals("receiveMessageNotification")) {
			receiveMessageNotification(callbackContext, args.optString(0), args.optString(1), args.optString(2));
		} else if (action.equals("receiveInboxChanges")) {
			receiveInboxChanges(callbackContext, args.optString(0));
		} else if (action.equals("messageReceivedAck")) {
			messageReceivedAck(callbackContext, args.optString(0), args.optString(1));
		} else if (action.equals("cancelMessageNotification")) {
			cancelMessageNotification(callbackContext, args.optString(0));
		} else if (action.equals("cancelAllMessageNotifications")) {
			cancelAllMessageNotifications(callbackContext);
		} else if (action.equals("cancelInboxChanges")) {
			cancelInboxChanges(callbackContext, args.optString(0));
		} else if (action.equals("receiveOutboxChanges")) {
			receiveOutboxChanges(callbackContext, args.optString(0));
		} else if (action.equals("cancelOutboxChanges")) {
			cancelOutboxChanges(callbackContext, args.optString(0));
		} else {		
			return false;
		}
		return true;
	}

	private void setOptions(CallbackContext callbackContext, JSONObject jsonObject) {
		String defaultPushSystem = null;
		try {
			defaultPushSystem = jsonObject.getString(DEFAULT_PUSH_SYSTEM);
			Prefs.get().edit().putString("pushSystem", defaultPushSystem).commit();
		} catch (JSONException e) {
			e.printStackTrace();
			callbackContext.error(e.getMessage());
		}
		callbackContext.success();
	}

	/**
	 * Add and subscribe to a notification channel
	 * 
	 * @param callbackContext
	 *            id to use when calling back to JavaScript
	 * @param channel
	 *            name of channel to subscribe to
	 * 
	 * @return PluginResult containing error & data to pass back to JavaScript
	 */
	private void addChannel(CallbackContext callbackContext, String channel) {
		try {
			mBoundService.getPushEngine().addChannel(channel);
			callbackContext.success();
		} catch (NotificationsDBException e) {
			e.printStackTrace();
			callbackContext.error(e.getMessage());
		}
	}

	/**
	 * Remove & unsubscribe from a notification channel
	 * 
	 * @param callbackContext
	 *            id to use when calling back to JavaScript
	 * @param channel
	 *            name of channel to unsubscribe from
	 * 
	 * @return PluginResult containing error & data to pass back to JavaScript
	 */
	private void removeChannel(CallbackContext callbackContext, String channel) {
		mBoundService.getPushEngine().removeChannel(channel);
		callbackContext.success();
	}

	/**
	 * Retrieve a list of all current channels
	 * 
	 * @param callbackContext
	 *            use when calling back to JavaScript
	 * 
	 * @return PluginResult containing error & data to pass back to JavaScript
	 */
	private void listChannels(CallbackContext callbackContext) {
		List<String> channels = mBoundService.getPushEngine().listChannels();
		callbackContext.success(new JSONArray(channels));
	}

	/**
	 * Send the supplied message using the channel specified in the message
	 * 
	 * @param callbackContext
	 *            id to use when calling back to JavaScript
	 * @param message
	 *            JSONObject message containing at least the name of the channel
	 *            which to send the message
	 * 
	 * @return PluginResult containing error & data to pass back to JavaScript
	 */
	private void sendMessage(CallbackContext callbackContext, JSONObject message) {
		try {
			PushMessage pm = PushMessage.createNewPushMessage(message);
			mBoundService.getPushEngine().setResourceApi( webView.getResourceApi() );
			mBoundService.getPushEngine().sendPushMessage(pm);
			callbackContext.success(pm.getId());
		} catch (Exception e) {
			e.printStackTrace();
			callbackContext.error(e.getMessage());
			CTLog.getInstance().log("shell", Priority.WARN_INT, "Not sending message because: " + e.getMessage());
		}
	}

	/**
	 * Retrieve all messages matching the supplied channel & subchannel
	 * 
	 * @param callbackContext
	 *            id to use when calling back to JavaScript
	 * @param channel
	 *            name of channel to get messages for
	 * @param subchannel
	 *            name of subchannel to get messages for
	 * 
	 * @return PluginResult containing error & data to pass back to JavaScript
	 */
	private void getMessages(CallbackContext callbackContext, String channel, String subchannel) {
		CTLog.getInstance().log("shell", Priority.INFO_INT, "-> plug.getMessages");

		try {
			List<PushMessage> messages = mBoundService.getPushEngine().getMessages(channel, subchannel);
			List<JSONObject> jsonMessages = new ArrayList<JSONObject>();
			for (PushMessage m : messages) {
				jsonMessages.add(m.getJSONObject());
			}
			callbackContext.success(new JSONArray(jsonMessages));
		} catch (Exception e) {
			e.printStackTrace();
			callbackContext.error(e.getMessage());
		}

		CTLog.getInstance().log("shell", Priority.INFO_INT, "<- plug.getMessages");
	}

	/**
	 * Retrieve all unread messages matching the optional supplied receiver,
	 * channel & subchannel.
	 * 
	 * @param callbackContext
	 *            id to use when calling back to JavaScript
	 * @param receiver
	 *            name of receiver to get messages for
	 * @param channel
	 *            name of channel to get messages for
	 * @param subchannel
	 *            name of subchannel to get messages for
	 * 
	 * @return PluginResult containing error & data to pass back to JavaScript
	 */
	private void getUnreadMessages(CallbackContext callbackContext, String receiver, String channel, String subchannel) {
		List<JSONObject> jsonMessages;
		try {
			List<PushMessage> messages = mBoundService.getPushEngine().getUnreadMessages(channel, subchannel, receiver);
			jsonMessages = new ArrayList<JSONObject>();
			for (PushMessage m : messages) {
                jsonMessages.add(m.getJSONObject());
            }
			callbackContext.success(new JSONArray(jsonMessages));
		} catch (Exception e){
			callbackContext.error(e.getMessage());
		}
	}

	/**
	 * Delete the message with the supplied id
	 * 
	 * @param callbackContext
	 *            id to use when calling back to JavaScript
	 * @param id
	 *            id of the message to delete
	 * 
	 * @return PluginResult containing error & data to pass back to JavaScript
	 */
	private void deleteMessage(CallbackContext callbackContext, String id) {
		try {
			mBoundService.getPushEngine().deleteMessage(id);
			callbackContext.success(id);
		} catch (NotificationsDBException e) {
			e.printStackTrace();
			callbackContext.error(e.getMessage());
		}
	}

	/**
	 * Register to receive messages as and when they arrive on the supplied
	 * channel/subchannel pair
	 * 
	 * @param callbackContext
	 *            id to use when calling back to JavaScript
	 * @param receiver
	 *            id of receiver. Used to prevent multiple delivery and during
	 *            cancelMessageNotification
	 * @param channel
	 *            name of channel to get receive messages on
	 * @param subchannel
	 *            name of subchannel to get receive messages on
	 * 
	 * @return PluginResult containing error & data to pass back to JavaScript
	 */
	private void receiveMessageNotification(final CallbackContext callbackContext, String receiver, String channel, String subchannel) {
		PluginResult result = new PluginResult(Status.NO_RESULT);
		result.setKeepCallback(true);
		mBoundService.getPushEngine().receiveMessageNotification(receiver, channel, subchannel, new MessageReceiver() {
			@Override
			public void messageReceived(PushMessage pm, String type) {
				try {
					PluginResult result = new PluginResult(Status.OK, pm.getJSONObject());
					result.setKeepCallback(true);
					callbackContext.sendPluginResult(result);
				} catch (JSONException e) {
					e.printStackTrace();
				}
			}
		});
		callbackContext.sendPluginResult(result);
	}

	/**
	 * Register to receive message store changes
	 * 
	 * @param callbackContext
	 *            id to use when calling back to JavaScript
	 * 
	 * @return PluginResult containing error & data to pass back to JavaScript
	 */
	private void receiveInboxChanges(final CallbackContext callbackContext, String receiver) {
		try {
			PluginResult result = new PluginResult(Status.NO_RESULT);
			result.setKeepCallback(true);
			mBoundService.getPushEngine().receiveStoreChangeNotification(receiver, new MessageReceiver() {
                @Override
                public void messageReceived(PushMessage msg, String type) {
                    try {
						JSONObject o = new JSONObject();
						o.put("action", type);
						o.put("message", msg.getJSONObject());
						PluginResult result = new PluginResult(Status.OK, o);
						result.setKeepCallback(true);
						callbackContext.sendPluginResult(result);
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                }
            });
			callbackContext.sendPluginResult(result);
		} catch (NotificationsDBException e) {
			e.printStackTrace();
		}
	}

	private void receiveOutboxChanges(final CallbackContext callbackContext, String receiver) {

		mBoundService.getPushEngine().receiveOutboxNotification(receiver, new MessageReceiver() {
			@Override
			public void messageReceived(PushMessage msg, String type) {
				try {
					JSONObject o = new JSONObject();
					o.put("action", type);
					o.put("message", msg.getJSONObject());
					PluginResult result = new PluginResult(Status.OK, o);
					result.setKeepCallback(true);
					callbackContext.sendPluginResult(result);
				} catch (JSONException e) {
					e.printStackTrace();
				}
			}
		});

	}

	/**
	 * Cancel receiving outbox changes
	 * 
	 * @param callbackContext
	 *            id to use when calling back to JavaScript
	 *  
	 */
	private void cancelOutboxChanges(CallbackContext callbackContext, String receiver) {
		mBoundService.getPushEngine().cancelOutboxNotification(receiver);
		callbackContext.success();
	}
	
	/**
	 * Acknowledge that the supplied messageid has been received by the supplied
	 * receiver
	 * @param callbackContext 
	 * 
	 * @param receiver
	 *            id of receiver who received the message
	 * @param messageid
	 *            id of the message received
	 * 
	 * @return PluginResult containing error & data to pass back to JavaScript
	 */
	private void messageReceivedAck(CallbackContext callbackContext, String receiver, String messageid) {
		try {
			mBoundService.getPushEngine().ackMessageReceipt(receiver, messageid);
			callbackContext.success(messageid);
		} catch (NotificationsDBException e) {
			e.printStackTrace();
			callbackContext.error(e.getMessage());
		}
	}

	/**
     * Cancel message reception matching the supplied id
     *
     * @param callbackContext
     *            id to use when calling back to JavaScript
     * @param receiver
     *            id supplied to a previous call to receiveMessageNotification
     *
     * @return PluginResult containing error & data to pass back to JavaScript
     */
	private void cancelMessageNotification(CallbackContext callbackContext, String receiver) {
		mBoundService.getPushEngine().cancelReceiveMessageNotification(receiver);
		callbackContext.success();
	}

	/**
	 * Cancel all message reception
	 * 
	 * @param callbackContext
	 *            id to use when calling back to JavaScript
	 * 
	 * @return PluginResult containing error & data to pass back to JavaScript
	 */
	private void cancelAllMessageNotifications(CallbackContext callbackContext) {
		mBoundService.getPushEngine().cancelAllReceiveMessageNotifications();
		callbackContext.success();
	}

	/**
	 * Cancel inbox change notifications
	 * 
	 * @param callbackContext
	 *            id to use when calling back to JavaScript
	 * 
	 * @return PluginResult containing error & data to pass back to JavaScript
	 */
	private void cancelInboxChanges(CallbackContext callbackContext, String receiver) {
		mBoundService.getPushEngine().cancelMessageStoreNotification(receiver);
		callbackContext.success();
	}
}
