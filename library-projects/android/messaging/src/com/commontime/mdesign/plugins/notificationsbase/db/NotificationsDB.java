package com.commontime.mdesign.plugins.notificationsbase.db;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.SQLException;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import android.text.TextUtils;

import com.commontime.mdesign.plugins.base.CTLog;

import org.apache.log4j.Priority;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

public class NotificationsDB extends SQLiteOpenHelper implements DBInterface {
	
	Context context;

	private static final String DATABASE_NAME = "notifications";
	private static final int DATABASE_VERSION = 15;

	private static final String TABLE_CHANNELS = "channels";
	private static final String TABLE_INBOX = "inbox";
	private static final String TABLE_OUTBOX = "outbox";
	private static final String TABLE_DELIVERY = "delivery";

	private static final String KEY_CHANNEL_NAME = "name";

	private static final String KEY_INBOX_ID = "id";
	private static final String KEY_INBOX_DATE = "date";
	private static final String KEY_INBOX_CHANNEL = "channel";
	private static final String KEY_INBOX_SUBCHANNEL = "subchannel";
	private static final String KEY_INBOX_CONTENT = "content";
	private static final String KEY_INBOX_EXPIRY = "expiry";
	private static final String KEY_INBOX_NOTIFICATION = "notification";
	private static final String KEY_INBOX_SIGNATURE = "signature";
	private static final String KEY_INBOX_DELETED = "deleted";
	private static final String KEY_INBOX_PROVIDER = "provider";

	private static final String KEY_DELIVERY_INBOX_ID = "inboxid";
	private static final String KEY_DELIVERY_RECEIVER = "receiver";

	private static final String KEY_OUTBOX_ID = "id";
	private static final String KEY_OUTBOX_DATE = "date";
	private static final String KEY_OUTBOX_CHANNEL = "channel";
	private static final String KEY_OUTBOX_SUBCHANNEL = "subchannel";
	private static final String KEY_OUTBOX_CONTENT = "content";
	private static final String KEY_OUTBOX_EXPIRY = "expiry";
	private static final String KEY_OUTBOX_NOTIFICATION = "notification";
	private static final String KEY_OUTBOX_SIGNATURE = "signature";
	private static final String KEY_OUTBOX_PROVIDER = "provider";
	
	private static final String CONTENT_DIR_INBOX = "inbox";
	private static final String CONTENT_DIR_OUTBOX = "outbox";

	private SQLiteDatabase dbWrite;
	private SQLiteDatabase dbRead;
	
	private FileRefHandler mFileRefHandler;
	private ContentStore mInboxContentStore;
	private ContentStore mOutboxContentStore;

	public static void validateChannel(String channel) throws NotificationsDBException {
		Boolean valid = false;
		if (channel.length() > 1 && !channel.matches("[A-Z]")) {
			try {
				new URI("http://www.commontime.com/" + channel);
				valid = true;
			} catch (URISyntaxException e) {
				valid = false;
			}
		}
		if (!valid) {
			throw new NotificationsDBException("Invalid channel name: '" + channel
					+ "'. Channel names must be lower case containing only valid URI characters and at least 2 characters long.");
		}
	}

	public static void validateMessage(PushMessage message) throws NotificationsDBException {
		validateChannel(message.getChannel());
		if (message.getId().length() == 0) {
			throw new NotificationsDBException("Invalid message id");
		}
		if (message.getDate() <= 0) {
			throw new NotificationsDBException("Invalid message date");
		}
		if (message.getSubchannel().length() == 0) {
			throw new NotificationsDBException("Invalid message sub channel");
		}
		if (message.getContent().length() == 0) {
			throw new NotificationsDBException("Invalid message content");
		}
		//if (message.getExpiry() <= 0) {
		//	throw new NotificationsDBException("Invalid message expiry");
		//}
		// if (message.getNotification().length() == 0) {
		// throw new NotificationsDBException("Invalid message notification");
		// }
	}

	public NotificationsDB(Context context) {
		super(context, DATABASE_NAME, null, DATABASE_VERSION);
		this.context = context;
		dbWrite = this.getWritableDatabase();
		dbRead = this.getReadableDatabase();
		mFileRefHandler = new FileRefHandler(context);
		mInboxContentStore = new ContentStore(context, CONTENT_DIR_INBOX);
		mOutboxContentStore = new ContentStore(context, CONTENT_DIR_OUTBOX);
	}

	@Override
	public synchronized void onCreate(SQLiteDatabase db) {
		String CREATE_CHANNELS_TABLE = "CREATE TABLE " + TABLE_CHANNELS + "(" + KEY_CHANNEL_NAME + " TEXT" + ")";
		db.execSQL(CREATE_CHANNELS_TABLE);

		String CREATE_INBOX_TABLE = "CREATE TABLE " + TABLE_INBOX + "(" + KEY_INBOX_ID + " TEXT PRIMARY KEY," + KEY_INBOX_DATE + " INTEGER,"
				+ KEY_INBOX_CHANNEL + " TEXT," + KEY_INBOX_SUBCHANNEL + " TEXT," + KEY_INBOX_CONTENT + " TEXT," + KEY_INBOX_EXPIRY + " INTEGER,"
				+ KEY_INBOX_NOTIFICATION + " TEXT," + KEY_INBOX_SIGNATURE + " TEXT, " + KEY_INBOX_DELETED + " BOOLEAN, " + KEY_INBOX_PROVIDER + " TEXT )";
		db.execSQL(CREATE_INBOX_TABLE);

		String CREATE_DELIVERY_TABLE = "CREATE TABLE " + TABLE_DELIVERY + "(" + KEY_DELIVERY_INBOX_ID + " TEXT," + KEY_DELIVERY_RECEIVER + " TEXT" + ")";
		db.execSQL(CREATE_DELIVERY_TABLE);

		String CREATE_OUTBOX_TABLE = "CREATE TABLE " + TABLE_OUTBOX + "(" + KEY_OUTBOX_ID + " TEXT PRIMARY KEY," + KEY_OUTBOX_DATE + " INTEGER,"
				+ KEY_OUTBOX_CHANNEL + " TEXT," + KEY_OUTBOX_SUBCHANNEL + " TEXT," + KEY_OUTBOX_CONTENT + " TEXT," + KEY_OUTBOX_EXPIRY + " INTEGER,"
				+ KEY_OUTBOX_NOTIFICATION + " TEXT," + KEY_OUTBOX_SIGNATURE + " TEXT," + KEY_OUTBOX_PROVIDER + " TEXT" + ")";
		db.execSQL(CREATE_OUTBOX_TABLE);
	}

	@Override
	public synchronized void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
		
		if( oldVersion == 14 && newVersion == 15 ) {
			String ALTER_INBOX_TABLE = "ALTER TABLE " + TABLE_INBOX + " ADD COLUMN " + KEY_INBOX_PROVIDER + " TEXT";
			db.execSQL(ALTER_INBOX_TABLE);
		} else {		
			db.execSQL("DROP TABLE IF EXISTS " + TABLE_OUTBOX);
			db.execSQL("DROP TABLE IF EXISTS " + TABLE_DELIVERY);
			db.execSQL("DROP TABLE IF EXISTS " + TABLE_INBOX);
			db.execSQL("DROP TABLE IF EXISTS " + TABLE_CHANNELS);
			onCreate(db);
		}
	}

	public void addChannel(String channel) throws NotificationsDBException, SQLException {
		validateChannel(channel);
		ContentValues values = new ContentValues();
		values.put(KEY_CHANNEL_NAME, channel);		
		synchronized (this) {			
			dbWrite.insertOrThrow(TABLE_CHANNELS, null, values);
		}
	}

	public synchronized void removeChannel(String channel) {	
		
		dbWrite.beginTransaction();
		try {
			dbWrite.delete(TABLE_CHANNELS, KEY_CHANNEL_NAME + " = ?", new String[] { channel });
			dbWrite.delete(TABLE_INBOX, KEY_INBOX_CHANNEL + " = ?", new String[] { channel });
			dbWrite.setTransactionSuccessful();
		} finally {
			dbWrite.endTransaction();
		}
	}

	public List<String> getChannels() {
		List<String> channels = new ArrayList<String>();
		String sql = "SELECT " + KEY_CHANNEL_NAME + " FROM " + TABLE_CHANNELS;
		
		synchronized (this) {		
			Cursor cursor = null;		
			try {
				cursor = dbRead.rawQuery(sql, null);
				if (cursor.moveToFirst()) {
					do {
						channels.add(cursor.getString(0));
					} while (cursor.moveToNext());
				}
				return channels;
			} finally {
				if( cursor != null ) {
					cursor.close();
				}
			}				
		}
	}

	public void addInboxMessage(PushMessage message) throws NotificationsDBException, SQLException {
		validateMessage(message);
		ContentValues values = new ContentValues();
		values.put(KEY_INBOX_ID, message.getId());
		values.put(KEY_INBOX_DATE, message.getDate());
		values.put(KEY_INBOX_CHANNEL, message.getChannel());
		values.put(KEY_INBOX_SUBCHANNEL, message.getSubchannel());
		values.put(KEY_INBOX_CONTENT, mInboxContentStore.save(message.getContent()));
		values.put(KEY_INBOX_EXPIRY, message.getExpiry());
		values.put(KEY_INBOX_NOTIFICATION, message.getNotification());
		values.put(KEY_INBOX_DELETED, false);
		values.put(KEY_INBOX_PROVIDER, message.getProvider());
		// values.put(KEY_INBOX_SIGNATURE, message.getSignature());		
		
		CTLog.getInstance().log("shell", Priority.DEBUG_INT, "Adding to inbox: " + message.getId());
		synchronized (this) {
			dbWrite.insertOrThrow(TABLE_INBOX, null, values);
		}		
		CTLog.getInstance().log("shell", Priority.DEBUG_INT, "Added to inbox: " + message.getId());
		
		CTLog.getInstance().log("notify-audit", Priority.INFO_INT, "Receive in Inbox: " + message.toString());
	}

	public void removeInboxMessage(String messageid, boolean removeAltogether) throws NotificationsDBException {

		if (messageid.length() == 0) {
			throw new NotificationsDBException("Invalid message id");
		}
		
		PushMessage pm = getMessage(messageid);
		CTLog.getInstance().log("shell", Priority.DEBUG_INT, "removeInboxMessage: " + messageid + ", " + pm.getChannel() + ", " + pm.getSubchannel());		
		
		String content = pm.getContent();
		mFileRefHandler.deleteFiles(content);
		mInboxContentStore.deleteContent(content);
		
		synchronized (this) {		
			dbWrite.beginTransaction();
			try {
				if (removeAltogether) {			
					dbWrite.delete(TABLE_INBOX, KEY_INBOX_ID + " = ?", new String[] { messageid });
					dbWrite.delete(TABLE_DELIVERY, KEY_DELIVERY_INBOX_ID + " = ?", new String[] { messageid });

				} else {
					ContentValues args = new ContentValues();
					args.put(KEY_INBOX_DELETED, true);
					args.put(KEY_INBOX_CONTENT, "");
					dbWrite.update(TABLE_INBOX, args, KEY_INBOX_ID + " = ?", new String[] { messageid });
				}
				dbWrite.setTransactionSuccessful();
			} finally {
				dbWrite.endTransaction();
			}
		}
		
		CTLog.getInstance().log("notify-audit", Priority.INFO_INT, "Remove: " + pm.getId());
	}

	public List<PushMessage> getInboxMessages() {
		String sql = "SELECT " + KEY_INBOX_ID + " id1," + KEY_INBOX_DATE + "," + KEY_INBOX_CHANNEL + "," + KEY_INBOX_SUBCHANNEL + "," + KEY_INBOX_CONTENT + ","
				+ KEY_INBOX_EXPIRY + "," + KEY_INBOX_NOTIFICATION + "," + KEY_INBOX_SIGNATURE + "," + KEY_INBOX_PROVIDER + " FROM " + TABLE_INBOX;
		
		List<PushMessage> messages = new ArrayList<PushMessage>();
		
		synchronized (this) {
			Cursor cursor = null;
			try {
				cursor = dbRead.rawQuery(sql, new String[0]);	
				if (cursor.moveToFirst()) {
					do {
						PushMessage m = new PushMessage(cursor.getString(0), cursor.getString(2), cursor.getString(3), cursor.getString(4));
						m.setDate(cursor.getLong(1));
						m.setExpiry(cursor.getLong(5));
						m.setNotification(cursor.getString(6));
						m.setProvider(cursor.getString(8));
						messages.add(m);
					} while (cursor.moveToNext());
				}
			} finally {
				if( cursor != null ) {
					cursor.close();
				}				
			}
		}
		return messages;
	}
	
	public List<PushMessage> getInboxMessages(String channel, String subchannel, boolean includeDeleted) throws NotificationsDBException {
		validateChannel(channel);
		if (subchannel.length() == 0) {
			throw new NotificationsDBException("Invalid sub channel");
		}

		List<String> args = new ArrayList<String>();
		args.add(channel);
		args.add(subchannel);

		String sql = "SELECT " + KEY_INBOX_ID + " id1," + KEY_INBOX_DATE + "," + KEY_INBOX_CHANNEL + "," + KEY_INBOX_SUBCHANNEL + "," + KEY_INBOX_CONTENT + ","
				+ KEY_INBOX_EXPIRY + "," + KEY_INBOX_NOTIFICATION + "," + KEY_INBOX_SIGNATURE + "," + KEY_INBOX_PROVIDER + " FROM " + TABLE_INBOX + " WHERE " + KEY_INBOX_CHANNEL
				+ " = ? AND " + KEY_INBOX_SUBCHANNEL + " = ?";
		if (!includeDeleted) {
			sql += " AND " + KEY_INBOX_DELETED + " = ?";
			args.add("0");
		}
		
		List<PushMessage> messages = new ArrayList<PushMessage>();
		
		synchronized (this) {
			Cursor cursor = null;
			try {
				cursor = dbRead.rawQuery(sql, args.toArray(new String[3]));			
				if (cursor.moveToFirst()) {
					do {
						PushMessage m = new PushMessage(cursor.getString(0), cursor.getString(2), cursor.getString(3), mInboxContentStore.load(cursor.getString(4)));
						m.setDate(cursor.getLong(1));
						m.setExpiry(cursor.getLong(5));
						m.setNotification(cursor.getString(6));
						m.setProvider(cursor.getString(8));
						messages.add(m);
					} while (cursor.moveToNext());
				}
			} finally {
				if( cursor != null ) {
					cursor.close();
				}				
			}
		}
		return messages;		
	}

	public PushMessage getMessage(String messageId) throws NotificationsDBException {
		PushMessage m = null;
		String sql = "SELECT " + KEY_INBOX_ID + " id1," + KEY_INBOX_DATE + "," + KEY_INBOX_CHANNEL + "," + KEY_INBOX_SUBCHANNEL + "," + KEY_INBOX_CONTENT + ","
				+ KEY_INBOX_EXPIRY + "," + KEY_INBOX_NOTIFICATION + "," + KEY_INBOX_SIGNATURE + "," + KEY_INBOX_PROVIDER + "," + KEY_INBOX_DELETED + " FROM " + TABLE_INBOX + " WHERE "
				+ KEY_INBOX_ID + " = ?";		
		Cursor cursor = null;
		
		synchronized (this) {
			try {
				cursor = dbRead.rawQuery(sql, new String[] { messageId });			
				if (cursor.moveToFirst()) {
					CTLog.getInstance().log("shell", 0, "Msg: " + cursor.getString(0) + ", deleted: " + cursor.getString(8));
					m = new PushMessage(cursor.getString(0), cursor.getString(2), cursor.getString(3), mInboxContentStore.load(cursor.getString(4)));
					m.setDate(cursor.getLong(1));
					m.setExpiry(cursor.getLong(5));
					m.setNotification(cursor.getString(6));
					m.setProvider(cursor.getString(8));
				}
			} finally {
				if( cursor != null ) {
					cursor.close();
				}
			}
		}
		return m;
		
	}
	
	private synchronized boolean inboxMessageExists(String messageid) {
		if (TextUtils.isEmpty(messageid)) {
			return false;
		}
		String sql = "SELECT 1 FROM " + TABLE_INBOX + " WHERE " + KEY_INBOX_ID + " = ?";
		Cursor cursor = null;
		try {
			cursor = dbRead.rawQuery(sql, new String[] {messageid});
			return (cursor.getCount() > 0);
		} 
		finally {
			if (cursor != null) {
				cursor.close();
			}
		}

	}

	public boolean inboxMessageDelivered(String messageid, String receiver) throws NotificationsDBException, SQLException {
		
		CTLog.getInstance().log("shell", Priority.DEBUG_INT, "inboxMessageDelivered: " + messageid );
		
		if (messageid.length() == 0) {
			throw new NotificationsDBException("Invalid message id");
		}
		if (receiver.length() == 0) {
			throw new NotificationsDBException("Invalid receiver");
		}
		ContentValues values = new ContentValues();
		values.put(KEY_DELIVERY_INBOX_ID, messageid);
		values.put(KEY_DELIVERY_RECEIVER, receiver);
		synchronized (this) {
			if (inboxMessageExists(messageid)) {
				dbWrite.insertOrThrow(TABLE_DELIVERY, null, values);
				return true;
			}
		}
		return false;
	}

	// TODO: I think this is broken, but its not used anywhere
	public Boolean isInboxMessageDelivered(String messageid, String receiver) throws NotificationsDBException {
		if (messageid.length() == 0) {
			throw new NotificationsDBException("Invalid message id");
		}
		if (receiver.length() == 0) {
			throw new NotificationsDBException("Invalid receiver");
		}
		String sql = "SELECT " + KEY_DELIVERY_INBOX_ID + " FROM " + TABLE_DELIVERY + " WHERE " + KEY_DELIVERY_INBOX_ID + " = ? AND " + KEY_DELIVERY_RECEIVER
				+ " = ?";
		Boolean delivered = false;
		Cursor cursor = null;
		synchronized (this) {	
			try {
				cursor = dbRead.rawQuery(sql, null);
				delivered = cursor.moveToFirst();
			} finally {
				if( cursor != null ) {
					cursor.close();
				}
			}
		}
		return delivered;		
	}

	public List<PushMessage> getUndeliveredInboxMessages(String callbackid) throws NotificationsDBException {

		// SELECT id
		// id1,date,channel,subchannel,content,expiry,notification,signature
		// FROM inbox JOIN (SELECT id id2 FROM inbox EXCEPT SELECT inboxid FROM
		// delivery WHERE receiver = 'receiver') on id2 = id1 WHERE deleted = 0
		String sql = "SELECT " + KEY_INBOX_ID + " id1," + KEY_INBOX_DATE + "," + KEY_INBOX_CHANNEL + "," + KEY_INBOX_SUBCHANNEL + "," + KEY_INBOX_CONTENT + ","
				+ KEY_INBOX_EXPIRY + "," + KEY_INBOX_NOTIFICATION + "," + KEY_INBOX_SIGNATURE + "," + KEY_INBOX_PROVIDER + "," + KEY_INBOX_DELETED + " FROM " + TABLE_INBOX
				+ " JOIN (SELECT " + KEY_INBOX_ID + " id2 FROM " + TABLE_INBOX + " EXCEPT SELECT " + KEY_DELIVERY_INBOX_ID + " FROM " + TABLE_DELIVERY
				+ " WHERE " + KEY_DELIVERY_RECEIVER + " = ?) ON id2 = id1" + " WHERE " + KEY_INBOX_DELETED + " = 0 ";		
		List<PushMessage> messages = new ArrayList<PushMessage>();
		Cursor cursor = null;
		synchronized (this) {
			try {
				cursor = dbRead.rawQuery(sql, new String[] { callbackid });			
				if (cursor.moveToFirst()) {
					CTLog.getInstance().log("shell", 0, "Msg: " + cursor.getString(0) + ", deleted: " + cursor.getInt(8));
					do {
						PushMessage m = new PushMessage(cursor.getString(0), cursor.getString(2), cursor.getString(3), mInboxContentStore.load(cursor.getString(4)));
						m.setDate(cursor.getLong(1));
						m.setExpiry(cursor.getLong(5));
						m.setNotification(cursor.getString(6));
						m.setProvider(cursor.getString(8));
						messages.add(m);
					} while (cursor.moveToNext());
				}
			} finally {
				if( cursor != null ) {
					cursor.close();
				}
			}
		}		
		return messages;		
	}

	public List<PushMessage> getUndeliveredInboxMessages(String channel, String subchannel, String receiver) throws NotificationsDBException {

		// SELECT id
		// id1,date,channel,subchannel,content,expiry,notification,signature
		// FROM inbox JOIN (SELECT id id2 FROM inbox EXCEPT SELECT inboxid FROM
		// delivery WHERE receiver = 'receiver') on id2 = id1 WHERE channel =
		// 'channel' AND subchannel = 'subchannel'

		List<String> args = new ArrayList<String>();

		String sql = "SELECT " + KEY_INBOX_ID + " id1," + KEY_INBOX_DATE + "," + KEY_INBOX_CHANNEL + "," + KEY_INBOX_SUBCHANNEL + "," + KEY_INBOX_CONTENT + ","
				+ KEY_INBOX_EXPIRY + "," + KEY_INBOX_NOTIFICATION + "," + KEY_INBOX_SIGNATURE + "," + KEY_INBOX_PROVIDER + "," + KEY_INBOX_DELETED + " FROM " + TABLE_INBOX
				+ " JOIN (SELECT " + KEY_INBOX_ID + " id2 FROM " + TABLE_INBOX + " EXCEPT SELECT " + KEY_DELIVERY_INBOX_ID + " FROM " + TABLE_DELIVERY;

		if (!receiver.isEmpty()) {
			sql += " WHERE " + KEY_DELIVERY_RECEIVER + " = ?";
			args.add(receiver);
		}
		sql += ") ON id2 = id1 ";

		if (!channel.isEmpty()) {
			sql += "WHERE " + KEY_INBOX_CHANNEL + " = ? ";
			args.add(channel);
		}

		if (!subchannel.isEmpty()) {
			sql += channel.isEmpty() ? "WHERE " : "AND ";
			sql += KEY_INBOX_SUBCHANNEL + " = ? ";
			args.add(subchannel);
		}

		sql += (channel.isEmpty() && subchannel.isEmpty()) ? "WHERE " : "AND ";
		sql += " " + KEY_INBOX_DELETED + " = 0 ";
		
		String[] stringArray = null;
		if (!args.isEmpty()) {
			stringArray = new String[args.size()];
			stringArray = args.toArray(stringArray);
		}
		List<PushMessage> messages = new ArrayList<PushMessage>();
		Cursor cursor = null;
		synchronized (this) {					
			try {
				cursor = dbRead.rawQuery(sql, stringArray);			
				if (cursor.moveToFirst()) {
					CTLog.getInstance().log("shell", 0, "Msg: " + cursor.getString(0) + ", deleted: " + cursor.getInt(8));
					do {
						PushMessage m = new PushMessage(cursor.getString(0), cursor.getString(2), cursor.getString(3), mInboxContentStore.load(cursor.getString(4)));
						m.setDate(cursor.getLong(1));
						m.setExpiry(cursor.getLong(5));
						m.setNotification(cursor.getString(6));
						m.setProvider(cursor.getString(8));
						messages.add(m);
					} while (cursor.moveToNext());
				}
			} finally {
				if( cursor != null ) {
					cursor.close();
				}
			}
		}
		return messages;
	}

	public void addOutboxMessage(PushMessage message) throws NotificationsDBException, SQLException {
		validateMessage(message);
		
		String content = message.getContent();
		try {
			content = mFileRefHandler.convertSendingFileRefs(content);
		} catch (Exception e) {
			throw new NotificationsDBException("mFileRefHandler.convertSendingFileRefs: " + e.getMessage());
		} 
		content = mOutboxContentStore.save(content);
		
		ContentValues values = new ContentValues();
		values.put(KEY_OUTBOX_ID, message.getId());
		values.put(KEY_OUTBOX_DATE, message.getDate());
		values.put(KEY_OUTBOX_CHANNEL, message.getChannel());
		values.put(KEY_OUTBOX_SUBCHANNEL, message.getSubchannel());
		values.put(KEY_OUTBOX_CONTENT, content);
		values.put(KEY_OUTBOX_EXPIRY, message.getExpiry());
		values.put(KEY_OUTBOX_NOTIFICATION, message.getNotification());
		// values.put(KEY_OUTBOX_SIGNATURE, message.getSignature());	
		values.put(KEY_OUTBOX_PROVIDER, message.getProvider());
		synchronized (this) {				
			dbWrite.insertOrThrow(TABLE_OUTBOX, null, values);
		}
		
		CTLog.getInstance().log("notify-audit", Priority.INFO_INT, "Queued to send: " + message.toString());
	}

	public void removeOutboxMessage(String messageid) throws NotificationsDBException {
		if (messageid.length() == 0) {
			throw new NotificationsDBException("Invalid message id");
		}
		
		PushMessage pm = getOutboxMessage(messageid);
		
		if( pm != null ) {		
			String content = pm.getContent();
			mFileRefHandler.deleteFiles(content);
			mOutboxContentStore.deleteContent(content);
			
			synchronized (this) {
				dbWrite.delete(TABLE_OUTBOX, KEY_OUTBOX_ID + " = ?", new String[] { messageid });
			}
			
			CTLog.getInstance().log("notify-audit", Priority.INFO_INT, "Removed from outbox: " + messageid);
		} else {
			CTLog.getInstance().log("shell", Priority.WARN_INT, "Failed to remove from outbox - message not found: " + messageid);
		}
	}

	public List<PushMessage> getOutboxMessages() throws NotificationsDBException {
		String sql = "SELECT " + KEY_OUTBOX_ID + "," + KEY_OUTBOX_DATE + "," + KEY_OUTBOX_CHANNEL + "," + KEY_OUTBOX_SUBCHANNEL + "," + KEY_OUTBOX_CONTENT
				+ "," + KEY_OUTBOX_EXPIRY + "," + KEY_OUTBOX_NOTIFICATION + "," + KEY_OUTBOX_SIGNATURE + "," + KEY_OUTBOX_PROVIDER + " FROM " + TABLE_OUTBOX;		
		List<PushMessage> messages = new ArrayList<PushMessage>();
		synchronized (this) {
			Cursor cursor = null;
			try {
				cursor = dbRead.rawQuery(sql, null);		
				if (cursor.moveToFirst()) {
					do {
						PushMessage m = new PushMessage(cursor.getString(0), cursor.getString(2), cursor.getString(3), mOutboxContentStore.load(cursor.getString(4)));
						m.setDate(cursor.getLong(1));
						m.setExpiry(cursor.getLong(5));
						m.setNotification(cursor.getString(6));
						m.setProvider(cursor.getString(8));
						messages.add(m);
					} while (cursor.moveToNext());
				}
			} finally {
				if( cursor != null ) {
					cursor.close();
					SQLiteDatabase.releaseMemory();
				}
			}
		}
		return messages;
	}

	public PushMessage getOutboxMessage(String messageId) throws NotificationsDBException {
		PushMessage m = null;
		String sql = "SELECT " + KEY_OUTBOX_ID + "," + KEY_OUTBOX_DATE + "," + KEY_OUTBOX_CHANNEL + "," + KEY_OUTBOX_SUBCHANNEL + "," + KEY_OUTBOX_CONTENT
				+ "," + KEY_OUTBOX_EXPIRY + "," + KEY_OUTBOX_NOTIFICATION + "," + KEY_OUTBOX_SIGNATURE + "," + KEY_OUTBOX_PROVIDER + " FROM " + TABLE_OUTBOX  + " WHERE "
				+ KEY_OUTBOX_ID + " = ?";		
		Cursor cursor = null;
		
		synchronized (this) {
			try {
				cursor = dbRead.rawQuery(sql, new String[] { messageId });			
				if (cursor.moveToFirst()) {
					CTLog.getInstance().log("shell", 0, "Msg: " + cursor.getString(0));
					m = new PushMessage(cursor.getString(0), cursor.getString(2), cursor.getString(3), mOutboxContentStore.load(cursor.getString(4)));
					m.setDate(cursor.getLong(1));
					m.setExpiry(cursor.getLong(5));
					m.setNotification(cursor.getString(6));
					m.setProvider(cursor.getString(8));
				}
			} finally {
				if( cursor != null ) {
					cursor.close();
				}
			}
		}
		return m;
		
	}
	
	public void clearExpiredMessages() {

		// TODO: This should probably remove the content and filerefs and all that when it's called.
		
		long t = (new Date()).getTime();
		String where = KEY_INBOX_EXPIRY + " < ?";	
		synchronized (where) {				
			dbWrite.delete(TABLE_INBOX, where, new String[] { String.valueOf(t) });
		}
	}

	public void clearInbox() {
		clearTable(TABLE_INBOX);
		mInboxContentStore.clear();
		mFileRefHandler.clearReceivedFiles();
		CTLog.getInstance().log("notify-audit", Priority.INFO_INT, "Clearing inbox");
	}

	public void clearOutbox() {
		clearTable(TABLE_OUTBOX);
		mOutboxContentStore.clear();
		mFileRefHandler.clearSendingFiles();		
		CTLog.getInstance().log("notify-audit", Priority.INFO_INT, "Clearing outbox");
	}
	
	public void clearDelivery() {
		clearTable(TABLE_DELIVERY);
	}

	public void clearChannels() {
		clearTable(TABLE_CHANNELS);
	}

	public synchronized void clear() {			
		dbWrite.beginTransaction();
		try {
			clearInbox();
			clearOutbox();
			clearDelivery();
			clearChannels();
			dbWrite.setTransactionSuccessful();
		} finally {
			dbWrite.endTransaction();
		}	
	}

	private synchronized void clearTable(String table) {		
		dbWrite.delete(table, null, null);		
	}
}