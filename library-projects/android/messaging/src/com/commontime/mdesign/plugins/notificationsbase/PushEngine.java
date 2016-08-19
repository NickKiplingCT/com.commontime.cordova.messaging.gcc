package com.commontime.mdesign.plugins.notificationsbase;

import android.content.Context;
import android.content.pm.PackageManager.NameNotFoundException;
import android.database.sqlite.SQLiteException;
import android.os.CountDownTimer;
import android.os.Messenger;

import com.commontime.mdesign.plugins.appservices.ZumoPushSystem;
import com.commontime.mdesign.plugins.base.CTLog;
import com.commontime.mdesign.plugins.base.Prefs;
import com.commontime.mdesign.plugins.notificationsbase.db.NotificationsDB;
import com.commontime.mdesign.plugins.notificationsbase.db.NotificationsDBException;
import com.commontime.mdesign.plugins.notificationsbase.db.PushMessage;

import org.apache.cordova.CordovaResourceApi;
import org.apache.log4j.Priority;
import org.json.JSONException;

import java.io.IOException;
import java.lang.reflect.InvocationTargetException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;


public class PushEngine implements PushSystemObserver {

	private ExecutorService singleExecutor = Executors.newSingleThreadExecutor();

	private boolean avoidUnbind;

	private static HashMap<String, PushSystemInterface> systemsByName = new HashMap<String, PushSystemInterface>();

	private Map<String, Map<String, List<String>>> channelCallbackidMap = new ConcurrentHashMap<String, Map<String, List<String>>>();
	private Map<String, MessageReceiveObserver> callbackIdCallbackMap = new ConcurrentHashMap<String, MessageReceiveObserver>();
	private Map<String, MessageChangeObserver> storeCallbackIdCallbackMap = new ConcurrentHashMap<String, MessageChangeObserver>();
	private Map<String, OutboxChangeObserver> outboxCallbackIdCallbackMap = new ConcurrentHashMap<String, OutboxChangeObserver>();

	private CountDownTimer scheduleTimer = null;
	private Map<String, Messenger> replyMessageMap = new HashMap<String, Messenger>();
	private boolean done = true;
	private boolean uiAvailable = false;

	Map<String, PushSystem> systems = new HashMap<String, PushSystem>();

	private PopupManager popupManager;
	private NotificationsDB notificationsDB;
	private CordovaResourceApi cordovaResourceApi;

	private Context context;

	public PushEngine(Context context) {
		this.context = context;
		popupManager = new PopupManager(context);
		notificationsDB = new NotificationsDB(context);
	}

	private synchronized void registerStoreCallback(String callbackid, MessageChangeObserver messageChangeObserver) {
		storeCallbackIdCallbackMap.put(callbackid, messageChangeObserver);
	}

	private synchronized void unregisterStoreCallback(String callbackid) {
		storeCallbackIdCallbackMap.remove(callbackid);
	}

	private synchronized void registerOutboxCallback(String callbackid, OutboxChangeObserver outboxChangeObserver) {
		outboxCallbackIdCallbackMap.put(callbackid, outboxChangeObserver);
	}

	private synchronized void unregisterOutboxCallback(String callbackid) {
		outboxCallbackIdCallbackMap.remove(callbackid);
	}

	private synchronized void registerCallback(String callbackid, String channel, String subchannel, MessageReceiveObserver messageReceiveObserver) {

		if (!channelCallbackidMap.containsKey(channel))
			channelCallbackidMap.put(channel, new ConcurrentHashMap<String, List<String>>());

		if (!channelCallbackidMap.get(channel).containsKey(subchannel))
			channelCallbackidMap.get(channel).put(subchannel, new ArrayList<String>());

		if (callbackIdCallbackMap.containsKey(callbackid)) {
			CTLog.getInstance().log("shell", Priority.WARN_INT, "There is already a recevier registered on: " + callbackid);
			unregisterCallback(callbackid);
		}

		channelCallbackidMap.get(channel).get(subchannel).add(callbackid);
		callbackIdCallbackMap.put(callbackid, messageReceiveObserver);
	}

	private synchronized void unregisterCallback(String callbackid) {
		callbackIdCallbackMap.remove(callbackid);

		// remove the callbackid from the list
		for (Map<String, List<String>> innermap : channelCallbackidMap.values()) {
			for (List<String> list : innermap.values()) {
				if (list.contains(callbackid)) {
					list.remove(callbackid);
				}
			}
		}
	}

	@Override
	public synchronized void messageReceived(PushMessage message) {

		CTLog.getInstance().log("shell", Priority.INFO_INT, "Message received: " + message.getId());

		if( ! isMessageValid(message) ) {
			return;
		}

		// Have we already received this message
		try {
			if( notificationsDB.getMessage(message.getId()) != null ) {
				CTLog.getInstance().log("shell", Priority.INFO_INT, "Message: " + message.getId() + " already received." );
				return;
			}
		} catch (NotificationsDBException ex) {
			CTLog.getInstance().log("shell", Priority.INFO_INT, "Message: " + message.getId() + " could not be retrieved from db." );
			return;
		}

		if (!message.expired()) {

			// Add new message to the DB
			try {

				notificationsDB.addInboxMessage(message);

				if (message.handle()) {
					if (!message.getNotification().isEmpty()) {
						popupManager.addNotification(UUID.randomUUID().toString(), message.getNotification());
					}
					deleteMessage(message.getId());
					return;
				} else {

					// Are there any 'store monitoring' notifications to fire
					for (String key : storeCallbackIdCallbackMap.keySet()) {
						MessageChangeObserver mco = storeCallbackIdCallbackMap.get(key);
						CTLog.getInstance().log("shell", Priority.INFO_INT, "StoreChangeNotifying (rcv): " + message.getId() + " to: " + key);

						mco.messageChanged(message, MessageChangeObserver.CREATE_TYPE);
					}

					// Notify the user if needed
					if (!(message.getNotification() == null || message.getNotification().isEmpty()) ) {
						CTLog.getInstance().log("shell", Priority.INFO_INT, "Message contains notification: " + message.getNotification());
						if( uiAvailable && Prefs.get().getBoolean("AllowForegroundNotifications", false) ) {
							// Do broadcast
							popupManager.addLocalNotification(message.getId(), message.getNotification());
						} else {
							// Display an unlinked popup
							popupManager.addNotification(message.getId(), message.getNotification());
						}
					}

					// Is anyone listening on this channel
					if (channelCallbackidMap.containsKey(message.getChannel())) {
						// Are they also listening on the right subchannel
						Map<String, List<String>> subChannelMap = channelCallbackidMap.get(message.getChannel());
						if (subChannelMap.containsKey(message.getSubchannel()) ||
								subChannelMap.containsKey("")) {

							// So this is the list of callbackIds we need to address - real subchannels
							List<String> callbacks = channelCallbackidMap.get(message.getChannel()).get(message.getSubchannel());

							// And this is the list of people listening on all subchannels
							List<String> wildCallbacks = channelCallbackidMap.get(message.getChannel()).get("");

							if( callbacks == null )
								callbacks = new ArrayList<String>();

							if( wildCallbacks == null )
								wildCallbacks = new ArrayList<String>();

							callbacks.addAll(wildCallbacks);

							CTLog.getInstance().log("shell", Priority.INFO_INT, "There are : " + callbacks.size() + " listeners for this message");

							for (String callbackid : callbacks) {
								// Send the message to the service, where a client
								// is waiting.
								if (callbackIdCallbackMap.containsKey(callbackid)) {

									CTLog.getInstance().log("shell", Priority.INFO_INT, "Delivering: " + message.getId() + " to: " + callbackid);
									callbackIdCallbackMap.get(callbackid).messageReceived(message);
								}
							}
						}
					}
				}

			} catch (NotificationsDBException e) {
				CTLog.getInstance().log("shell", Priority.ERROR_INT, "Failed receiving message: " + e.getMessage());
			} catch (SQLiteException e ) {
				CTLog.getInstance().log("shell", Priority.ERROR_INT, "Failed receiving message: " + e.getMessage());
			}

		} else {
			CTLog.getInstance().log("shell", Priority.WARN_INT, "Message id: " + message.getId() + " has expired.");
		}
	}

	private boolean isMessageValid(PushMessage message) {

		long wiped = Prefs.getExtraPreferences().getLong("DBWipedAt", 0);
		if( wiped > message.getDate()) {
			CTLog.getInstance().log("shell", Priority.INFO_INT, "Message: " + message.getId() + " sent before last wipe time." );
			return false;
		}

		// Were we installed after this message's date?
		try {
			long installed = context.getPackageManager().getPackageInfo(context.getPackageName(), 0).firstInstallTime;

			if( installed > message.getDate() ) {
				CTLog.getInstance().log("shell", Priority.INFO_INT, "Message: " + message.getId() + " sent before installation." );
				return false;
			}
		} catch (NameNotFoundException e1) {
			CTLog.getInstance().log("shell", Priority.INFO_INT, "Message: " + message.getId() + " error: " + e1.getMessage() );
			e1.printStackTrace();
			return false;
		}

		// Were we configured after this message's date?
		long configTime = Prefs.get().getLong("configTime", 0);
		if( configTime > message.getDate() ) {
			CTLog.getInstance().log("shell", Priority.INFO_INT, "Message: " + message.getId() + " sent before pre-configuration.");
			return false;
		}

		return true;
	}

	public void addChannel(String channel) throws NotificationsDBException {

		CTLog.getInstance().log("secure", Priority.INFO_INT, "Adding channel: " + channel);

		try {

			if (!notificationsDB.getChannels().contains(channel)) {
				// Add the channel to the database
				notificationsDB.addChannel(channel);
			} else {
				CTLog.getInstance().log("secure", Priority.WARN_INT, "Channel already in DB: " + channel);
			}

			// Start listening on the default provider to this channel
			getSystem().subscribeChannel(channel);

		} catch (NotificationsDBException e) {
			CTLog.getInstance().log("shell", Priority.ERROR_INT, "Failed adding channel: " + e.getMessage());
			throw e;
		}
	}

	public void removeChannel(String channel) {

		CTLog.getInstance().log("secure", Priority.INFO_INT, "Removing channel: " + channel);

		notificationsDB.removeChannel(channel);

		// Stop listening on the default provider to this channel
		getSystem().unsubscribeChannel(channel);
	}

	public List<String> listChannels() {
		return notificationsDB.getChannels();
	}

	/*
	 *
	 * Fetch all messages that match channel/subchannel that have NOT been
	 * received by receiver
	 */
	public List<PushMessage> checkPendingMessages(String channel, String subchannel, String receiver) {
		try {
			return notificationsDB.getUndeliveredInboxMessages(channel, subchannel, receiver);
		} catch (NotificationsDBException e) {
			CTLog.getInstance().log("shell", Priority.ERROR_INT, "Failed getting pending messages: " + e.getMessage());
		}

		return new ArrayList<PushMessage>();
	}

	public Context getContext() {
		if( context == null ) {
			System.out.println("Null Context!" + context);
		}
		return context;
	}

	public void sendPushMessage(PushMessage pm) throws NotificationsDBException, JSONException {
		if( pm.getNotification() == null)
			pm.setNotification("");
		notificationsDB.addOutboxMessage(pm);
		getSystem(pm).prepareMessage(pm, cordovaResourceApi);
		startSendSchedule();
	}

	public void doSendMessages() {

		Runnable sender = new Runnable() {

			@Override
			public void run() {

				List<PushMessage> messagesToSend;

				try {
					messagesToSend = notificationsDB.getOutboxMessages();
				} catch (NotificationsDBException e) {
					CTLog.getInstance().log("notify-send", Priority.ERROR_INT, "Failed to retrieve messages from outbox. No messages will be sent.");
					done = true;
					return;
				}

				done = true;

				if( messagesToSend.size() == 0) {
					// Nothing to send, stop the schedule
					stopSendSchedule();
					stopLimitedSendSchedule();
					return;
				}

				CTLog.getInstance().log("notify-send", Priority.INFO_INT, "Starting sendMessages.  There are " + messagesToSend.size() + " messages to send");

				for (PushMessage msg : messagesToSend) {

					CTLog.getInstance().log("notify-send", Priority.DEBUG_INT, "Sending message: " + msg.getId());
					notifyMessageSending(msg);

					try {
						PushSystemInterface.SendResult sendResult = null;
						try {
							sendResult = getSystem(msg).sendMessage(msg).get();
						} catch (InterruptedException e) {
							e.printStackTrace();
							CTLog.getInstance().log("shell", Priority.ERROR_INT, "Interrupted while sending message: " + e.getMessage());
							notificationsDB.removeOutboxMessage(msg.getId());
							notifyMessageNotSent(msg, false);
							continue;
						} catch (ExecutionException e) {
							e.printStackTrace();
							CTLog.getInstance().log("shell", Priority.ERROR_INT, "ExecutionException while sending message: " + e.getMessage());
							if( e.getCause() instanceof IOException ) {
								notifyMessageNotSent(msg, true);
							} else {
								notificationsDB.removeOutboxMessage(msg.getId());
								notifyMessageNotSent(msg, false);
							}
							continue;
						}
						if (sendResult == PushSystemInterface.SendResult.Success) {
							notifyMessageSent(msg);
							CTLog.getInstance().log("notify-send", Priority.DEBUG_INT, "Sent OK, removing from outbox: " + msg.getId());
							notificationsDB.removeOutboxMessage(msg.getId());
						} else if(sendResult == PushSystemInterface.SendResult.Failed) {
							handleSendFailure(msg);
							break;	// Don't try any more messages if one has failed
						} else {	// FailedDoNotRetry
							notifyMessageNotSent(msg, false);
							CTLog.getInstance().log("notify-send", Priority.DEBUG_INT, "Failed to send, removing from outbox: " + msg.getId());
							notificationsDB.removeOutboxMessage(msg.getId());
						}
					} catch (NotificationsDBException e) {
						CTLog.getInstance().log("shell", Priority.ERROR_INT, "Failed to remove message from outbox." + e.getMessage());
					}
				}

			}

			private void handleSendFailure(PushMessage msg) throws NotificationsDBException {
				if( msg.getExpiry() == 0 ) {
					CTLog.getInstance().log("notify-send", Priority.DEBUG_INT, "Failed to send, and that was the only try: " + msg.getId());
					notifyMessageNotSent(msg, false);
					notificationsDB.removeOutboxMessage(msg.getId());
				} else {
					CTLog.getInstance().log("notify-send", Priority.DEBUG_INT, "Failed to send, will retry: " + msg.getId());
					notifyMessageNotSent(msg, true);
				}
			}
		};

		if(done) {
			done = false;
			singleExecutor.execute(sender);
		}
	}

	protected void notifyMessageSending(PushMessage msg) {
		notifyOutbox(msg, OutboxChangeObserver.SENDING_TYPE);
	}

	protected void notifyMessageNotSent(PushMessage msg, boolean willRetry) {
		notifyOutbox(msg, willRetry ? OutboxChangeObserver.FAILED_WILL_RETRY_TYPE : OutboxChangeObserver.FAILED_TYPE);
	}

	protected void notifyMessageSent(PushMessage msg) {
		notifyOutbox(msg, OutboxChangeObserver.SENT_TYPE);
	}

	private void notifyOutbox(PushMessage msg, String type) {
		for (String key : outboxCallbackIdCallbackMap.keySet()) {
			OutboxChangeObserver oco = outboxCallbackIdCallbackMap.get(key);

			if( oco != null ) {
				CTLog.getInstance().log("shell", Priority.INFO_INT,
						"OutboxChange ("+type+"): " + msg.getId() + " by: " + key);
				oco.messageStatusChanged(msg, type);
			}
		}
	}

	public void doExpiryHousekeeping() {
		notificationsDB.clearExpiredMessages();
	}

	public void cancelReceiveOutboxNotification(String callbackToCancel) {
		unregisterOutboxCallback(callbackToCancel);
	}

	public void cancelReceiveMessageNotification(String callbackid) {
		CTLog.getInstance().log("shell", Priority.INFO_INT, "Unregistering receiver: " + callbackid);
		unregisterCallback(callbackid);
		replyMessageMap.remove(callbackid);
	}

	public void cancelAllReceiveMessageNotifications() {
		for (String callbackid : callbackIdCallbackMap.keySet()) {
			unregisterCallback(callbackid);
		}
	}

	public void ackMessageReceipt(String receiver, String messageid) throws NotificationsDBException {
		CTLog.getInstance().log("shell", Priority.INFO_INT, "Marking message: " + messageid + " was read by: " + receiver);
		try {
			boolean success = notificationsDB.inboxMessageDelivered(messageid, receiver);
			if( success ) {
				PushMessage m = notificationsDB.getMessage(messageid);
				// There must be a multithreaded scenario that allows us to get here, but still have a null message
				if (m != null) {
					// Are there any 'store monitoring' notifications to fire
					for (String key : storeCallbackIdCallbackMap.keySet()) {
						MessageChangeObserver mco = storeCallbackIdCallbackMap.get(key);
						CTLog.getInstance().log("shell", Priority.INFO_INT, "StoreChangeNotifying (ack): " + messageid + " to: " + key);

						mco.messageChanged(m, MessageChangeObserver.UPDATE_TYPE);
					}
				}
			}
		} catch (NotificationsDBException e) {
			CTLog.getInstance().log("shell", Priority.ERROR_INT, "Failed to mark message as delivered." + e.getMessage());
		}
	}

	@Override
	public void connectionStateChange(PushSystem.State state) {
		CTLog.getInstance().log("shell", Priority.INFO_INT, "State: " + state.toString());

		//if( service != null )
		//service.getNotifications().changeNotificationState(state);
	}

//	public void setService(NotificationsService notificationsService) {
//		this.service = notificationsService;
//	}

	public void setNetworkConnected(boolean connected) {
		for (PushSystem system : getPushSystems()){
			if( connected )
				system.start(notificationsDB);
			else
				system.stop();

			system.setNetworkConnected(connected);
		}
	}

	public void deleteMessage(String messageId) throws NotificationsDBException {

		PushMessage m = notificationsDB.getMessage(messageId);

		if( m != null ) {

			CTLog.getInstance().log("shell", Priority.INFO_INT, "Attempting to delete msg: " + messageId);

			boolean deleteFully = m.getProvider() == null || (!m.getProvider().equalsIgnoreCase("pubnub"));
			notificationsDB.removeInboxMessage(messageId, deleteFully);

			// Any icons to remove
			popupManager.clearNotification(messageId);

			// Are there any 'store monitoring' notifications to fire
			for (String key : storeCallbackIdCallbackMap.keySet()) {
				MessageChangeObserver mco = storeCallbackIdCallbackMap.get(key);
				CTLog.getInstance().log("shell", Priority.INFO_INT, "StoreChangeNotifying (del): " + messageId + " by: " + key);

				mco.messageChanged(m, MessageChangeObserver.DELETE_TYPE);
			}

		}
	}

	public void cancelMessageStoreNotification(String callbackToCancel) {
		unregisterStoreCallback(callbackToCancel);
	}

	public void cancelOutboxNotification(String callbackToCancel) {
		unregisterOutboxCallback(callbackToCancel);
	}

	public void setUiAvailability(boolean available) {
		uiAvailable = available;
	}

//	public void configure(String notificationsString) throws MDesignServiceException {
//		reconfigure(notificationsString);
//	}
//
//	public void configureMany(String notificationsString) throws MDesignServiceException {
//		reconfigureMany(notificationsString);
//	}

	public List<PushMessage> getMessages(String channel, String subchannel) throws NotificationsDBException {
		ArrayList<PushMessage> messages = null;
		messages = new ArrayList<PushMessage>(notificationsDB.getInboxMessages(channel, subchannel, false));
		return messages;
	}

	public List<PushMessage> getUnreadMessages(String channel, String subchannel, String receiver) throws NotificationsDBException {
		ArrayList<PushMessage> messages = null;
		messages = new ArrayList<PushMessage>(notificationsDB.getUndeliveredInboxMessages(channel, subchannel, receiver));
		return messages;
	}

	public void receiveMessageNotification(String receiver, String channel, String subchannel, final MessageReceiver callback ) {
		List<PushMessage> messages = checkPendingMessages(channel, subchannel, receiver);

		// Send message(s) to clients
		for (PushMessage message : messages) {

			if (!message.expired()) {
				// Need to be parcelled

				CTLog.getInstance().log("shell", Priority.INFO_INT, "Delivering: " + message.getId() + " to: " + receiver);
				callback.messageReceived(message, MessageChangeObserver.CREATE_TYPE);
			}
		}

		// Register with Engine
		registerCallback(receiver, channel, subchannel, new MessageReceiveObserver() {
			@Override
			public void messageReceived(PushMessage message) {

				// Need to be parcelled
				callback.messageReceived(message, MessageChangeObserver.CREATE_TYPE);
			}
		});
	}

	public void receiveOutboxNotification(String receiver, final MessageReceiver callback ) {

		registerOutboxCallback(receiver, new OutboxChangeObserver() {
			@Override
			public void messageStatusChanged(PushMessage message, String changeType) {
				callback.messageReceived(message, changeType);
			}
		});
	}

	public void receiveStoreChangeNotification(String receiver, final MessageReceiver messageReceiver) throws NotificationsDBException {
		List<PushMessage> messages = notificationsDB.getUndeliveredInboxMessages(receiver);

		// Send message(s) to clients
		for (PushMessage message : messages) {

			if (!message.expired()) {
				// Need to be parcelled

				CTLog.getInstance().log("shell", Priority.INFO_INT, "StoreChangeNotifying (rcv): " + message.getId() + " to: " + receiver);
				messageReceiver.messageReceived(message, MessageChangeObserver.CREATE_TYPE);
			}
		}

		// Register with Engine
		CTLog.getInstance().log("secure", Priority.INFO_INT, "Registering to receive store notifications for: " + receiver);
		registerStoreCallback(receiver, new MessageChangeObserver() {
			@Override
			public void messageChanged(PushMessage message, String changeType) {

				// Need to be parcelled
				messageReceiver.messageReceived(message, changeType);
			}
		});
	}

	public List<PushMessage> getAllMessages() {
		return new ArrayList<PushMessage>(notificationsDB.getInboxMessages());
	}

	int singleCheckRemaining;
	public synchronized void doSingleCheck(final SingleCheckObserver singleCheckObserver, List<PushSystem> allSystems) {

		doSendMessages();
		String defaultSystemName = getDefaultSystemName();
		singleCheckRemaining = allSystems.size();
		for (PushSystem system : allSystems) {
			boolean isDefault = system.getName().equals(defaultSystemName);
			system.checkOnce(notificationsDB, new SingleCheckObserver() {
				@Override
				public void checkComplete() {
					singleCheckRemaining--;
					CTLog.getInstance().log("shell", 0, "[Service] Waiting for checks");
					if( singleCheckRemaining == 0 ) {
						singleCheckObserver.checkComplete();
					}
				}
			});
		}
	}

	public boolean getUiAvailable() {
		return uiAvailable;
	}

	public void setAvoidUnbind(boolean avoid) {
		avoidUnbind = avoid;
	}

	public boolean getAvoidUnbind() {
		return avoidUnbind;
	}

	private PushSystem getSystem(String providerName) {
		PushSystem defaultSystem = getSystem();
		for( PushSystem pushSystem : getPushSystems() ) {
			pushSystem.setObserver(this);
			if( pushSystem.getName().equals(providerName))
				defaultSystem = pushSystem;
		}
		return defaultSystem;
	}

	private PushSystem getSystem(PushMessage m) {
		PushSystem defaultSystem = getSystem();
		for( PushSystem pushSystem : getPushSystems() ) {
			pushSystem.setObserver(this);
			if( pushSystem.getName().equals(m.getProvider()))
				defaultSystem = pushSystem;
		}
		return defaultSystem;
	}

	private PushSystem getSystem() {
		PushSystem defaultSystem = new NullPushSystem(this);
		for( PushSystem pushSystem : getPushSystems() ) {
			pushSystem.setObserver(this);
			if( pushSystem.getName().equals(getDefaultSystemName()))
				defaultSystem = pushSystem;
		}
		return defaultSystem;
	}

	private List<PushSystem> getPushSystems() {

		Prefs.create(context.getApplicationContext());

		Set<String> plugins = Prefs.get().getStringSet(Notify.NOTIFICATION_PLUGINS, new HashSet<String>());
		for (String plugin : plugins) {
			try {
				if( systems.get(plugin) == null ) {
					Class c = Class.forName(plugin);
					PushSystem ps = (PushSystem) c.getDeclaredConstructor(new Class[]{PushEngine.class}).newInstance(this);
					systems.put(plugin, ps);
				}
			} catch (ClassNotFoundException e) {
				e.printStackTrace();
			} catch (InvocationTargetException e) {
				e.printStackTrace();
			} catch (NoSuchMethodException e) {
				e.printStackTrace();
			} catch (InstantiationException e) {
				e.printStackTrace();
			} catch (IllegalAccessException e) {
				e.printStackTrace();
			}
		}
		return new ArrayList<PushSystem>(systems.values());
	}

	public String getDefaultSystemName() {
		return Prefs.get().getString("pushSystem", "null");
	}

	public void setStoppable(boolean b) {
	}

	private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
	private ScheduledFuture<?> limitedSenderHandle;
	private ScheduledFuture<?> senderHandle;

	public void startSendSchedule() {
		final Runnable sender = new Runnable() {

			@Override
			public void run() {
				doSendMessages();
			}
		};

		if( senderHandle != null)
			senderHandle.cancel(false);
		senderHandle = scheduler.scheduleAtFixedRate(sender, 0, 60, TimeUnit.SECONDS);
	}

	public void startLimitedSendSchedule(final int attempts) {
		final Runnable sender = new Runnable() {

			int tries = attempts;

			@Override
			public void run() {

				if( tries > 0 ) {
					doSendMessages();
				} else {
					limitedSenderHandle.cancel(false);
				}
				tries--;
			}
		};

		if( limitedSenderHandle != null)
			limitedSenderHandle.cancel(false);
		limitedSenderHandle = scheduler.scheduleAtFixedRate(sender, 0, 60, TimeUnit.SECONDS);
	}

	public void stopSendSchedule() {
		if( senderHandle != null )
			senderHandle.cancel(false);
	}

	public void stopLimitedSendSchedule() {
		if( limitedSenderHandle != null )
			limitedSenderHandle.cancel(false);
	}

	public void setResourceApi(CordovaResourceApi resourceApi) {
		cordovaResourceApi = resourceApi;
	}

	public void startPushSystem(String providerName) {
		getSystem(providerName).start(notificationsDB);
	}

	public void setContext(Context context) {
		this.context = context;
	}

	public void zumoLogOut(boolean clearCookies) {
		((ZumoPushSystem)getSystem(ZumoPushSystem.AZURE_APP_SERVICES)).logout(clearCookies);
	}
}
