package com.commontime.mdesign.plugins.base;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.SharedPreferences;

import com.commontime.mdesign.plugins.base.crypto.Encryptor;

import java.util.HashMap;
import java.util.Map;
import java.util.Set;

public class PartSecurePrefs implements SharedPreferences {

	class PartSecurePrefsEditor implements Editor {

		Editor editor;

		private PartSecurePrefsEditor() {
			editor = prefs.edit();
		}

		@Override
		public void apply() {
			editor.apply();
		}

		@Override
		public Editor clear() {
			editor.clear();
			return this;
		}

		@Override
		public boolean commit() {
			editor.commit();
			return true;
		}

		@Override
		public Editor putBoolean(String key, boolean value) {
			boolean secure = checkSecure(key);
			if( secure ) {
				editor.putString(key, encry.encrypt("" + value));
			} else {
				editor.putBoolean(key, value);
			}
			return this;
		}

		@Override
		public Editor putFloat(String key, float value) {
			boolean secure = checkSecure(key);
			if( secure ) {
				editor.putString(key, encry.encrypt("" + value));
			} else {
				editor.putFloat(key, value);
			}
			return this;
		}

		@Override
		public Editor putInt(String key, int value) {
			boolean secure = checkSecure(key);
			if( secure ) {
				editor.putString(key, encry.encrypt("" + value));
			} else {
				editor.putInt(key, value);
			}
			return this;
		}

		@Override
		public Editor putLong(String key, long value) {
			boolean secure = checkSecure(key);
			if( secure ) {
				editor.putString(key, encry.encrypt(""+value));
			} else {
				editor.putLong(key, value);
			}
			return this;
		}

		@Override
		public Editor putString(String key, String value) {
			boolean secure = checkSecure(key);
			if( secure ) {
				editor.putString(key, encry.encrypt(value));
			} else {
				editor.putString(key, value);
			}
			return this;
		}

		@SuppressLint("NewApi")
		@Override
		public Editor putStringSet(String key, Set<String> values) {
			return editor.putStringSet(key, values);
//			boolean secure = checkSecure(key);
//			if( secure ) {
//				editor.putStringSet(key, values);
//			} else {
//				Set<String> set = new HashSet<String>();
//				for (String s : values) {
//					set.add(encry.encrypt(s));
//				}
//				editor.putStringSet(key, set);
//			}
//			return this;
		}

		@Override
		public Editor remove(String key) {
			editor.remove(key);
			return this;
		}

	}

	private boolean checkSecure(String key) {
		if(
				key.equals("passwordCredentialEditForNotifications") ||
				key.equals("passwordCredentialEdit") ||
				key.equals("zumoAppKey") ||
				key.equals("provisioningappkey") ||
				key.equals("loguploadappkey") ||
				key.equals("cookies") ||
				key.equals("sasKey") ||
				key.equals("key") ||
				key.equals("pubnubSecretKey") ||
				key.equals("pubnubSubscribeKey") ||
				key.equals("pubnubPublishKey") ||
				key.equals("zumoUserToken") ||
				key.equals("notificationConfigString")) {
			return true;
		}
		return false;
	}

	private SharedPreferences prefs;
	private Context context;
	protected Encryptor encry;

	public PartSecurePrefs(Context ctx, Encryptor e) {
		this.context = ctx;
		this.encry = e;
		prefs = context.getSharedPreferences(e.getFilename(), Context.MODE_PRIVATE);
		encry.init(ctx);
	}	
	
	@Override
	public boolean contains(String key) {
		return prefs.contains(key);
	}

	@Override
	public Editor edit() {
		Editor editor = new PartSecurePrefsEditor();
		return editor;
	}

	@Override
	public Map<String, ?> getAll() {
		throw new RuntimeException("Not implemented");
	}		

	@Override
	public boolean getBoolean(String key, boolean defValue) {
		if( ! prefs.contains(key)) {
			return defValue;
		}

		boolean secure = checkSecure(key);
		if( secure ) {
			String booleanPref = prefs.getString(key, null);
			return Boolean.parseBoolean(encry.decrypt(booleanPref));
		} else {
			return prefs.getBoolean(key, defValue);
		}
	}

	@Override
	public float getFloat(String key, float defValue) {
		if( ! prefs.contains(key)) {
			return defValue;
		}

		boolean secure = checkSecure(key);
		if( secure ) {
			String floatPref = prefs.getString(key, null);
			return Float.parseFloat(encry.decrypt(floatPref));
		} else {
			return prefs.getFloat(key, defValue);
		}
	}

	@Override
	public int getInt(String key, int defValue) {
		if( ! prefs.contains(key)) {
			return defValue;
		}

		boolean secure = checkSecure(key);
		if( secure ) {
			String intPref = prefs.getString(key, null);
			return Integer.parseInt(encry.decrypt(intPref));
		} else {
			return prefs.getInt(key, defValue);
		}
	}

	@Override
	public long getLong(String key, long defValue) {
		if( ! prefs.contains(key)) {
			return defValue;
		}

		boolean secure = checkSecure(key);
		if( secure ) {
			String longPref = prefs.getString(key, null);
			return Long.parseLong(encry.decrypt(longPref));
		} else {
			return prefs.getLong(key, defValue);
		}
	}

	@Override
	public String getString(String key, String defValue) {
		if( ! prefs.contains(key)) {
			return defValue;
		}

		boolean secure = checkSecure(key);
		if( secure ) {
			String stringPref = prefs.getString(key, null);
			return encry.decrypt(stringPref);
		} else {
			return prefs.getString(key, defValue);
		}
	}

	@SuppressLint("NewApi")
	@Override
	public Set<String> getStringSet(String key, Set<String> defValue) {
		return prefs.getStringSet(key, defValue);
//		if( ! prefs.contains(key)) {
//			return defValue;
//		}
//
//		boolean secure = checkSecure(key);
//		if( secure ) {
//			Set<String> stringSetPref = prefs.getStringSet(key, null );
//			Set<String> set = new HashSet<String>();
//			for(String s : stringSetPref ) {
//				set.add(encry.decrypt(s));
//			}
//			return set;
//		} else {
//			return prefs.getStringSet(key, defValue);
//		}
	}

	@Override
	public void registerOnSharedPreferenceChangeListener(OnSharedPreferenceChangeListener listener) {
		prefs.registerOnSharedPreferenceChangeListener(listener);
	}

	@Override
	public void unregisterOnSharedPreferenceChangeListener(OnSharedPreferenceChangeListener listener) {
		prefs.unregisterOnSharedPreferenceChangeListener(listener);
	}

	public Map<String, String> getAllEncrypted() {
		Map<String, String> newMap = new HashMap<String, String>();
		for( String key : prefs.getAll().keySet() ) {
			newMap.put(key, prefs.getString(key, null));
		}
		return newMap;
	}
	
	public void setAlreadyEncrypted(String key, String newEncrypted) {
		prefs.edit().putString(key, newEncrypted).commit();
	}
}
