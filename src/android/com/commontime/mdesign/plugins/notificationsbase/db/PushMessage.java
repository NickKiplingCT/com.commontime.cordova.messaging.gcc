package com.commontime.mdesign.plugins.notificationsbase.db;

import android.os.Parcel;
import android.os.Parcelable;

import org.json.JSONException;
import org.json.JSONObject;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.Date;
import java.util.UUID;

public class PushMessage implements Parcelable {

	private String id;
	private String channel;
	private String subchannel;
	private String content;
	private long date;
	private long expiry;
	private String notification;
	private String provider;

	public static PushMessage createNewPushMessage(String channel, String subchannel, String content) {
		PushMessage pm = new PushMessage(UUID.randomUUID().toString(), channel, subchannel, content);
		pm.setDate(new Date().getTime());
		pm.setExpiry(0);
		return pm;
	}
	
	public static PushMessage createNewPushMessage(JSONObject obj) throws JSONException {
		
		PushMessage pm = new PushMessage();
		pm.id = UUID.randomUUID().toString();
		pm.channel = obj.getString("channel");
		pm.subchannel = obj.getString("subchannel");
		
		if( obj.has("content") ) {		
			JSONObject jso = obj.getJSONObject("content");
			pm.content = jso.toString();
		} else {
			pm.content = "{}";
		}
		
		pm.date = new Date().getTime();
		pm.expiry = obj.getLong("expiry");
		
		if( obj.has("notification") ) {
			pm.notification = obj.getString("notification");
		} else {
			pm.notification = "";
		}	
		
		if( obj.has("provider") ) {
			pm.provider = obj.getString("provider");
		} else {
			pm.provider = "";
		}
					
		return pm;
	}
	
	private PushMessage() {	}
	
	public PushMessage(String id, String channel, String subchannel, String content) {
		this.id = id;
		this.channel = channel;
		this.subchannel = subchannel;
		this.content = content;		
	}

	public PushMessage(Parcel source) {
		this.id = source.readString();
		this.channel = source.readString();
		this.subchannel = source.readString();
		this.content = source.readString();
		this.date = source.readLong();
		this.expiry = source.readLong();
		this.notification = source.readString();
		this.provider = source.readString();
	}

	public PushMessage(JSONObject obj) throws JSONException {
		this.id = obj.getString("id");
		this.channel = obj.getString("channel");
		this.subchannel = obj.getString("subchannel");
		
		if( obj.has("content") ) {			
			if( obj.optJSONObject("content") != null ) {			
				JSONObject jso = obj.getJSONObject("content");
				this.content = jso.toString();
			} else {
				this.content = obj.getString("content");
			}
		} else {
			this.content = "{}";
		}
			
		this.date = obj.getLong("date");
		this.expiry = obj.getLong("expiry");
		
		if( obj.has("notification") ) {
			this.notification = obj.getString("notification");
		} else {
			this.notification = "";
		}
		
		if( obj.has("provider") ) {
			this.provider = obj.getString("provider");
		} else {
			this.provider = "";
		}
	}
	
	public JSONObject getJSONObject() throws JSONException {
		JSONObject jso = new JSONObject();
		jso.put("id", this.id);
		jso.put("channel", this.channel);
		jso.put("subchannel", this.subchannel);
		jso.put("content", new JSONObject(this.content) );
		jso.put("date", this.date);		
		jso.put("expiry", this.expiry);		
		jso.put("notification", this.notification);
		jso.put("provider", this.provider);
		
		return jso;
	}
	
	@Override
	public void writeToParcel(Parcel parcel, int arg1) {
		parcel.writeString(id);
		parcel.writeString(channel);
		parcel.writeString(subchannel);
		parcel.writeString(content);
		parcel.writeLong(date);
		parcel.writeLong(expiry);
		parcel.writeString(notification);
		parcel.writeString(provider);
	}

	public String getId() { return this.id; }
	public void setId(String id) { this.id = id; }
	public String getChannel() { return this.channel; }
	public void setChannel(String channel) { this.channel = channel; }
	public String getSubchannel() { return this.subchannel; }
	public void setSubchannel(String subchannel) { this.subchannel = subchannel; }
	public String getContent() { return this.content; }
	public void setContent(String content) { this.content = content; }
	public long getDate() { return this.date; }
	public void setDate(long date) { this.date = date; }
	public long getExpiry() { return this.expiry; }
	public void setExpiry(long expiry) { this.expiry = expiry; }	
	public String getNotification() { return notification; }
	public void setNotification(String notification) { this.notification = notification; }
	public String getProvider() { return provider; }
	public void setProvider(String provider) { this.provider = provider; }

	@Override
	public int describeContents() {
		return 0;
	}
	
	public static final Creator<PushMessage> CREATOR = new Creator<PushMessage>() {

		@Override
		public PushMessage createFromParcel(Parcel source) {
			return new PushMessage(source);
		}

		@Override
		public PushMessage[] newArray(int size) {
			return new PushMessage[size];
		}
		
	};

	public boolean expired() {		

		if( expiry == 0 )
			return false;
		
		if( new Date().getTime() < expiry )
			return false;
				
		return true;
	}
	
	public boolean validate(String message) {		
	
		if (!channel.matches("^[\\w]+$")){
			message = "Channel name contains invalid characters";
			return false;
		}
		
		try {
			new URI( "http://www.commontime.com/" + getChannel() );
		} catch (URISyntaxException e) {
			message = e.getMessage();
			return false;
		}
						
		return true;
	}

	public boolean handle() {
		return false;
		// return new PushMessageHandler(this).handle();
	}
	
	@Override
	public String toString() {
		try {
			return this.getJSONObject().toString(3);
		} catch (JSONException e) {		
			e.printStackTrace();
		}		
		return "Error converting PushMessage: " + id + " to JSON";
	}

	public JSONObject getJSONContent() {
		try {
			return new JSONObject(content);
		} catch (JSONException e) {
			e.printStackTrace();
			return null;
		}
	}
}
