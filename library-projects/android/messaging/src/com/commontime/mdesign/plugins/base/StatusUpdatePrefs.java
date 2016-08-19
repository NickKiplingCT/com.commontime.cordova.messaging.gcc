package com.commontime.mdesign.plugins.base;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.Resources;

import java.util.Map;

public final class StatusUpdatePrefs {

	public static final String STATUS_UPDATE_CHANNEL = "statusUpdateChannel";
	public static final String STATUS_UPDATE_SUBCHANNEL = "statusUpdateSubchannel";
	public static final String STATUS_UPDATE_PROVIDER = "statusUpdateProvider";
	public static final String STATUS_UPDATE_INTERVAL = "statusUpdateInterval";
	public static final String STATUS_UPDATE_DISTANCE = "statusUpdateDistance";
	public static final String STATUS_UPDATE_CONTENT = "statusUpdateContent";
	public static final String STATUS_UPDATE_ENABLE_HIGH_ACCURACY = "statusUpdateEnableHighAccuracy";
	public static final String STATUS_UPDATE_INCLUDE_LOCATION = "statusUpdateIncludeLocation";
	public static final String STATUS_UPDATE_INCLUDE_DEVICE_STATUS = "statusUpdateIncludeDeviceStatus";
	public static final String STATUS_UPDATE_START_AUTOMATICALLY = "statusUpdateStartAutomatically";


	private final Context mContext;
	private final SharedPreferences mPrefs;

	private Resources resources;
	private String packageName;

	public StatusUpdatePrefs(Context context, SharedPreferences prefs) {
		this.mContext = context;
		this.mPrefs = prefs;

		packageName = context.getPackageName();
		resources = context.getResources();
	}

	public String getChannel() {
		return mPrefs.getString(STATUS_UPDATE_CHANNEL, "");
	}

	public void setChannel(String value) {
		mPrefs.edit().putString(STATUS_UPDATE_CHANNEL, value).commit();
	}

	public String getSubchannel() {
		return mPrefs.getString(STATUS_UPDATE_SUBCHANNEL, "");
	}

	public void setSubchannel(String value) {
		mPrefs.edit().putString(STATUS_UPDATE_SUBCHANNEL, value).commit();
	}

	public String getProvider() {
		return mPrefs.getString(STATUS_UPDATE_PROVIDER, "");
	}

	public void setProvider(String value) {
		mPrefs.edit().putString(STATUS_UPDATE_PROVIDER, value).commit();
	}

	public long getInterval() {
		return mPrefs.getLong(STATUS_UPDATE_INTERVAL, 0);
	}

	public void setInterval(long value) {
		mPrefs.edit().putLong(STATUS_UPDATE_INTERVAL, value).commit();
	}

	public long getDistance() {
		return mPrefs.getLong(STATUS_UPDATE_DISTANCE, 0);
	}

	public void setDistance(long value) {
		mPrefs.edit().putLong(STATUS_UPDATE_DISTANCE, value).commit();
	}

	public String getContent() {
		return mPrefs.getString(STATUS_UPDATE_CONTENT, "");
	}

	public void setContent(String value) {
		mPrefs.edit().putString(STATUS_UPDATE_CONTENT, value).commit();
	}

	public boolean getHighAccuracy() {
		return mPrefs.getBoolean(STATUS_UPDATE_ENABLE_HIGH_ACCURACY, false);
	}

	public void setHighAccuracy(boolean value) {
		mPrefs.edit().putBoolean(STATUS_UPDATE_ENABLE_HIGH_ACCURACY, value).commit();
	}

	public boolean getIncludeLocation() {
		return mPrefs.getBoolean(STATUS_UPDATE_INCLUDE_LOCATION, false);
	}

	public void setIncludeLocation(boolean value) {
		mPrefs.edit().putBoolean(STATUS_UPDATE_INCLUDE_LOCATION, value).commit();
	}

	public boolean getIncludeDeviceStatus() {
		return mPrefs.getBoolean(STATUS_UPDATE_INCLUDE_DEVICE_STATUS, false);
	}

	public void setIncludeDeviceStatus(boolean value) {
		mPrefs.edit().putBoolean(STATUS_UPDATE_INCLUDE_DEVICE_STATUS, value).commit();
	}

	public boolean getStartAutomatically() {
		return mPrefs.getBoolean(STATUS_UPDATE_START_AUTOMATICALLY, false);
	}

	public void setStartAutomatically(boolean value) {
		mPrefs.edit().putBoolean(STATUS_UPDATE_START_AUTOMATICALLY, value).commit();
	}

	public void set(Map<String, Object> config) {
		for (Map.Entry<String, Object> entry : config.entrySet()) {
			if (entry.getKey().equalsIgnoreCase(STATUS_UPDATE_CHANNEL)) {
				setChannel((String) entry.getValue());
			} else if (entry.getKey().equalsIgnoreCase(STATUS_UPDATE_SUBCHANNEL)) {
				setSubchannel((String) entry.getValue());
			} else if (entry.getKey().equalsIgnoreCase(STATUS_UPDATE_PROVIDER)) {
				setProvider((String) entry.getValue());
			} else if (entry.getKey().equalsIgnoreCase(STATUS_UPDATE_INTERVAL)) {
				setInterval(getLong(entry.getValue()));
			} else if (entry.getKey().equalsIgnoreCase(STATUS_UPDATE_DISTANCE)) {
				setDistance(getLong(entry.getValue()));
			} else if (entry.getKey().equalsIgnoreCase(STATUS_UPDATE_ENABLE_HIGH_ACCURACY)) {
				setHighAccuracy((Boolean) entry.getValue());
			} else if (entry.getKey().equalsIgnoreCase(STATUS_UPDATE_INCLUDE_LOCATION)) {
				setIncludeLocation((Boolean) entry.getValue());
			} else if (entry.getKey().equalsIgnoreCase(STATUS_UPDATE_INCLUDE_DEVICE_STATUS)) {
				setIncludeDeviceStatus((Boolean) entry.getValue());
			} else if (entry.getKey().equalsIgnoreCase(STATUS_UPDATE_START_AUTOMATICALLY)) {
				setStartAutomatically((Boolean) entry.getValue());
			}
		}
	}

	private static long getLong(Object maybeLong) {
		if (maybeLong instanceof Long) {
			return (Long) maybeLong;
		} else if (maybeLong instanceof Integer) {
			return ((Integer) maybeLong).longValue();
		} else {
			return 0;
		}
	}
}
