package com.commontime.mdesign.plugins.base;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Build;
import android.os.SystemClock;
import android.preference.PreferenceManager;
import android.text.TextUtils;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.Toast;

import com.commontime.mdesign.plugins.base.crypto.Encryptor;
import com.commontime.mdesign.plugins.base.crypto.EncryptorFactory;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.IOUtils;
import org.apache.log4j.Priority;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.net.HttpURLConnection;
import java.net.ProtocolException;
import java.nio.ByteBuffer;
import java.nio.charset.Charset;
import java.security.KeyManagementException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

public class Prefs {

	private static final int CO_TIMEOUT = 0;

	private static final int DL_TIMEOUT = 0;

	private static Prefs PREFS;
	private static Context mContext;
	private WebView mWebView;
	private static Encryptor current;
	
	// private static SecurePrefs securePrefs;
	private static PartSecurePrefs securePrefs;

	public static void create(Context context) {
		PREFS = new Prefs(context);
	}

	private Prefs(Context baseContext) {
		mContext = baseContext;
	}

	public static void setWebview(WebView webview) {
		PREFS.mWebView = webview;
	}

	public static SharedPreferences get() {		
		if( securePrefs == null ) {			
			Encryptor e = EncryptorFactory.createInstance(PREFS.mContext);
			securePrefs = new PartSecurePrefs( PREFS.mContext, e );
			CTLog.getInstance().log("shell", Priority.INFO_INT, "Using encryptor: " + e.getFilename());
		}
		return securePrefs;
	}


	public static SharedPreferences getOld() {
		return PreferenceManager.getDefaultSharedPreferences(mContext);
	}

	public static SharedPreferences getExtraPreferences() {
		SharedPreferences prefs = PREFS.mContext.getSharedPreferences("extra",
				Context.MODE_PRIVATE);
		return prefs;
	}

	public static void clearApplicationCache() {
		WebSettings settings = null;
		if (PREFS.mWebView != null) {
			settings = PREFS.mWebView.getSettings();
			settings.setAppCacheEnabled(false);
		}

		String appCachePath = PREFS.mContext.getDir("appCache",
				Context.MODE_PRIVATE).getPath();
		File dir = new File(appCachePath);
		boolean success = deleteDir(dir);

		// Re-create the app cache
		if (settings != null) {
			appCachePath = PREFS.mContext.getDir("appCache",
					Context.MODE_PRIVATE).getPath();
			settings.setAppCachePath(appCachePath);

			settings.setAppCacheEnabled(false);
			settings.setAppCacheMaxSize(52428800);
		}

		Prefs.get().edit().putBoolean("isProvisioned", false).commit();
	}

	public static void clearSqlDb() {
		WebSettings settings = null;
		if (PREFS.mWebView != null) {
			settings = PREFS.mWebView.getSettings();
			settings.setDatabaseEnabled(false);
		}
		String databasePath = PREFS.mContext.getDir("database",
				Context.MODE_PRIVATE).getPath();

		File dir = new File(databasePath);
		boolean success = deleteDir(dir);

		// re-create
		if (settings != null) {
			databasePath = PREFS.mContext.getDir("database",
					Context.MODE_PRIVATE).getPath();
			settings.setDatabasePath(databasePath);
			settings.setDatabaseEnabled(true);
		}
	}

	public static void clearAttachments(Context context) {
		File attachDir = Files.getAttachmentsDir(context);
		Utils.DeleteRecursive(attachDir);
	}

	private static boolean deleteDir(File dir) {
		if (dir.isDirectory()) {
			String[] children = dir.list();
			for (int i = 0; i < children.length; i++) {
				boolean success = deleteDir(new File(dir, children[i]));
				if (!success) {
					return false;
				}
			}
		}

		// The directory is now empty so delete it
		return dir.delete();
	}

	public static void clearWebCacheDbs() {
		boolean result1 = PREFS.mContext.deleteDatabase("webview.db");
		boolean result2 = PREFS.mContext.deleteDatabase("webviewCache.db");
	}

	public static boolean wipePrivateData() {
		return deleteDir(PREFS.mContext.getFilesDir().getParentFile());
	}

	public static void clearCache() {
		if (PREFS.mWebView != null) {
			PREFS.mWebView.clearCache(true);
		}
	}

	private static String phoneStuff() {
		StringWriter data = new StringWriter();

		PrintWriter pw = new PrintWriter(data, true);

		pw.println("Phone:");
		pw.println(Build.BRAND);
		pw.println(Build.MODEL);
		pw.println(Build.DISPLAY);
		pw.println(Build.HARDWARE);
		pw.println(Build.PRODUCT);
		pw.println(Build.VERSION.RELEASE);
		pw.println();
		pw.println();

		return data.toString();
	}

	public static void sendLogs(Activity activity) {

		if (Utils.isSDAvailable()) {

			try {
				File f = Files.getLogsDir(mContext);
				List<String> files = new ArrayList<String>();
				for (File file : f.listFiles()) {
					files.add(file.getAbsolutePath());
				}

				Utils.sendFiles(activity, "", "", "Shell Logs", phoneStuff(),
						files);
			} catch (Exception e) {
				e.printStackTrace();
				Toast.makeText(activity, e.getMessage(), Toast.LENGTH_LONG)
						.show();
			}
		}

	}

	public static void emailLogs(Activity activity, String receipient) {

		try {
			File folder = Files.getLogsDir(mContext);
			File zipFile = new File(Files.getApplicationDir(mContext), "mDesignLogs.zip");
			ZipUtility.zipDirectory(folder, zipFile);

			final Intent emailIntent = new Intent(
					android.content.Intent.ACTION_SEND);
			emailIntent.setType("text/plain");
			emailIntent.putExtra(android.content.Intent.EXTRA_EMAIL,
					new String[] { receipient });
			emailIntent.putExtra(android.content.Intent.EXTRA_SUBJECT,
					"Shell Logs");
			emailIntent.putExtra(android.content.Intent.EXTRA_TEXT,
					phoneStuff());
			emailIntent.putExtra(android.content.Intent.EXTRA_STREAM,
					Uri.fromFile(zipFile));	
			activity.startActivity(Intent.createChooser(emailIntent,
					"Send mail..."));

		} catch (IOException e) {
			e.printStackTrace();
			Toast.makeText(activity, e.getMessage(), Toast.LENGTH_LONG).show();
		}
	}
	
	public static boolean uploadLogs(Activity activity, String url) {
		
		try {

			String uploadKey = Prefs.getLogUploadKey();
			String uploadUrl = Prefs.getLogUploadURL();

			File folder = Files.getLogsDir(mContext);
			File zipFile = new File(Files.getApplicationDir(mContext),
					"mDesignLogs.zip");
			ZipUtility.zipDirectory(folder, zipFile);

			if (url == null || url.equals("null") || url.isEmpty()) {
				if (uploadUrl != null && !uploadUrl.isEmpty()) {
					url = uploadUrl;
				} else {
					url = Utils.getServerBaseURL() + "/upload-logs?user="
							+ Prefs.getUsername();
				}
			}

			CTLog.getInstance().log("shell", Priority.INFO_INT, "[logupload] URL: " + url);

			if (uploadKey != null && !uploadKey.isEmpty()) {
				final HttpURLConnection urlConnection = HttpConnection.create(url);
				urlConnection.setRequestMethod("POST");
				urlConnection.setRequestProperty("Content-Type", "application/x-zip-compressed");
				urlConnection.setConnectTimeout(CO_TIMEOUT);
				urlConnection.setDoOutput(true);
				urlConnection.setDoInput(true);
				urlConnection.setRequestProperty("Content-Length", "" + zipFile.length());
				urlConnection.setReadTimeout(DL_TIMEOUT);

				String key = Prefs.getLogUploadKey();
				if (key.isEmpty()) {
					key = Prefs.getProvisioningAppKey();
				}

				urlConnection.addRequestProperty("X-ZUMO-APPLICATION", key);

				FileInputStream fis = new FileInputStream(zipFile);
				OutputStream os = urlConnection.getOutputStream();

				IOUtils.copy(fis, os);
				os.flush();
				os.close();

				final int responseCode = urlConnection.getResponseCode();
				CTLog.getInstance().log("shell", Priority.INFO_INT, "[logupload] Response: " + responseCode);

				if (responseCode == 200) {
					return true;
				} else {
					return false;
				}

			} else {

				String val = (new StringBuffer(Prefs.getUsername()).append(":")
						.append(Prefs.getPassword())).toString();
				byte[] base = val.getBytes();
				String authorizationString = "Basic "
						+ new String(new Base64().encode(base));

				HttpURLConnection connection = null;
				try {
					connection = HttpConnection.create(url);
				} catch (KeyManagementException e) {
					e.printStackTrace();
				} catch (NoSuchAlgorithmException e) {
					e.printStackTrace();
				} catch (IOException e) {
					e.printStackTrace();
				}
				connection.addRequestProperty("Authorization", authorizationString);
				connection.setDoOutput(true);
				connection.setConnectTimeout(130000);
				connection.setReadTimeout(130000);
				try {
					connection.setRequestMethod("POST");
				} catch (ProtocolException e) {
					e.printStackTrace();
				}

				FileInputStream fis = new FileInputStream(zipFile);
				OutputStream os = connection.getOutputStream();

				IOUtils.copy(fis, os);
				os.flush();
				os.close();

				return true;
			}
		} catch (IOException e) {
			e.printStackTrace();
		} catch (KeyManagementException e) {			
			e.printStackTrace();
		} catch (NoSuchAlgorithmException e) {			
			e.printStackTrace();
		}
		return false;
	}

	public static void deleteLogs() {
		if (Utils.isSDAvailable()) {
			File f = Files.getLogsDir(mContext);
			for (File file : f.listFiles()) {
				file.delete();
			}
		}
	}

	public static void clearNotificationsDb() {
		// boolean result = PREFS.mContext.deleteDatabase("notifications");
		// result = PREFS.mContext.deleteDatabase("notifications");
		// NotificationsDB.get().clear();
		// getExtraPreferences().edit().putLong("DBWipedAt", new Date().getTime())
		// .commit();
	}

	public static void clearForNewUser() {
		Prefs.get().edit().putBoolean("restartApp", true).commit();
		Prefs.get().edit().putBoolean("deleteCookies", true).commit();
		Prefs.get().edit().putBoolean("isProvisioned", true).commit();
		CTLog.getInstance().log("shell", Priority.INFO_INT,
				"Will cleardown on next start up");
		Prefs.get().edit().putBoolean("clearDown", true).commit();
		Prefs.clearSqlDb();
		Prefs.clearNotificationsDb();
		Prefs.clearApplicationCache();
		Prefs.clearCache();
		SystemClock.sleep(500);
		Prefs.clearWebCacheDbs();
		Prefs.get().edit().putString("zumoUserToken", "").commit();
		Prefs.get().edit().putString("zumoUserId", "").commit();
		mContext.deleteFile("coooooookies.ser");		
	}

	public static void clearForAppRestart() {
		Prefs.clearSqlDb();
		Prefs.clearNotificationsDb();
		Prefs.clearApplicationCache();
		Prefs.clearCache();
		SystemClock.sleep(500);
		Prefs.clearWebCacheDbs();
		Prefs.get().edit().putString("zumoUserToken", "").commit();
		Prefs.get().edit().putString("zumoUserId", "").commit();
		Prefs.setHasBootstrapped(false);
		Prefs.setHasRealApplication(false);
		mContext.deleteFile("coooooookies.ser");
	}

	public static void eraseAllSettings() {
		Prefs.get().edit().clear().commit();
	}

	public static String getUsername() {
		return get().getString("usernameCredentialEdit", "");
	}

	public static void setUsername(String username) {
		get().edit().putString("usernameCredentialEdit", username).commit();
	}

	public static String getPassword() {
		return get().getString("passwordCredentialEdit", "");
	}

	public static String getPasswordForNotificationsPList() {
		return get().getString("passwordCredentialEditForNotifications", "");
	}

	public static void setPassword(String password) {
		get().edit().putString("passwordCredentialEdit", password).commit();
		get().edit()
				.putString("passwordCredentialEditForNotifications", password)
				.commit();
	}

	public static void setPasswordForNotificationsPList(String password) {
		get().edit()
				.putString("passwordCredentialEditForNotifications", password)
				.commit();
	}

	public static boolean getPasswordLocked() {
		return get().getBoolean("passwordLocked", false);
	}

	public static boolean getUseSSL() {
		return get().getBoolean("secureConnectionCheck", false);
	}

	public static void setUseSSL(boolean b) {
		get().edit().putBoolean("secureConnectionCheck", b).commit();
	}

	public static String getHost() {
		return get().getString("hostConnectionEdit", "");
	}

	public static void setHost(String host) {
		get().edit().putString("hostConnectionEdit", host).commit();
	}

	public static String getPort() {
		return get().getString("portConnectionEdit", "");
	}

	public static void setPort(String port) {
		get().edit().putString("portConnectionEdit", port).commit();
	}

	public static String getStartPage() {
		return get().getString("startPage", "");
	}

	public static void setStartPage(String startPage) {
		get().edit().putString("startPage", startPage)
				.putBoolean("isProvisioned", true).commit();
	}

	public static boolean getIsPPA() {
		return !TextUtils.isEmpty(getStartPage());
	}

	public static void GenerateUsername(String application, String tenant, String serverId) {
		byte[] sharedSecret = new byte[] { 0x74, 0x70, 0x27, 0x00, 0x7f, 0x5d,
				0x11, (byte) 0xe3, (byte) 0xba, (byte) 0xa7, 0x08, 0x00, 0x20,
				0x0c, (byte) 0x9a, 0x66 };

		UUID usernameGuid = UUID.randomUUID();
		if( Prefs.getUseTestGeneratedUsername() ) {
			usernameGuid = UUID.fromString("00000000-0000-0000-0000-000000000000");
		}
		
		String username = application + "+" + tenant + "+" + serverId + "+" + formatUUID(usernameGuid);

		byte[] usernameData = username.getBytes(Charset.forName("UTF-8"));
		byte[] passwordData = new byte[usernameData.length
				+ sharedSecret.length];

		System.arraycopy(usernameData, 0, passwordData, 0, usernameData.length);
		System.arraycopy(sharedSecret, 0, passwordData, usernameData.length,
				sharedSecret.length);

		String password = "";
		try {
			byte[] hash = MessageDigest.getInstance("MD5").digest(passwordData);
			password = formatUUIDBytes(hash);
		} catch (NoSuchAlgorithmException e) {
			e.printStackTrace();
			CTLog.getInstance().log("shell", Priority.ERROR_INT,
					"MD5 Algorithm doesn't exist");
		}
		
		setUsername(username);
		setPassword(password);		
	}

	private static byte[] getUUIDBytes(UUID uuid) {
		ByteBuffer bb = ByteBuffer.wrap(new byte[16]);
		bb.putLong(uuid.getMostSignificantBits());
		bb.putLong(uuid.getLeastSignificantBits());
		byte[] bytes = bb.array();
		return bytes;
	}

	private static String formatUUIDBytes(byte[] bytes) {
		return String
				.format("%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
						bytes[3], bytes[2], bytes[1], bytes[0], bytes[5],
						bytes[4], bytes[7], bytes[6], bytes[8], bytes[9],
						bytes[10], bytes[11], bytes[12], bytes[13], bytes[14],
						bytes[15]);
	}

	private static String formatUUID(UUID uuid) {
		byte[] bytes = getUUIDBytes(uuid);
		return formatUUIDBytes(bytes);
	}

	public static void setApplication(String right) {
		get().edit().putString("application", right).commit();
		updateGeneratedUsername();
	}
	
	public static void setTenant(String right) {
		get().edit().putString("tenant", right).commit();
		updateGeneratedUsername();
	}
	
	public static void setServerId(String right) {
		get().edit().putString("serverid", right).commit();
		updateGeneratedUsername();
	}
	
	private static void updateGeneratedUsername() {
		if(getApplication().length() > 0 && getTenant().length() > 0 && getUseGeneratedUsername()) {
			GenerateUsername(getApplication(), getTenant(), getServerId());
		}					
	}
	
	public static void setUseGeneratedUsername(boolean right) {
		get().edit().putBoolean("generateUsername", right).commit();
		updateGeneratedUsername();
	}

	private static boolean getUseGeneratedUsername() {
		return get().getBoolean("generateUsername", false);
	}
	
	private static String getApplication() {
		return get().getString("application", "");
	}
	
	private static String getTenant() {
		return get().getString("tenant", "");
	}
	
	private static String getServerId() {
		return get().getString("serverid", "");
	}

	public static void setUseTestGeneratedUsername(boolean right) {
		get().edit().putBoolean("generateTestUsername", right).commit();
	}
	
	private static boolean getUseTestGeneratedUsername() {
		return get().getBoolean("generateTestUsername", false);
	}

	public static boolean getUseBugsense() {
		return get().getBoolean("useBugsense", false);
	}

	public static boolean getUseSoftwareLayer() {
		return get().getBoolean("useSoftwareLayer", false);		
	}

	public static void setSecretMenu(boolean b) {
		get().edit().putBoolean("secretMenu", b).commit();
	}
	
	public static boolean getSecretMenu() {
		return get().getBoolean("secretMenu", false);
	}

	public static boolean getWebDebuggable() {
		return get().getBoolean("webDebuggable", false);		
	}

	public static void setZumoAuth(String right) {
		get().edit().putString("zumoAuth", right).commit();
	}
	
	public static String getZumoAuth() {
		return get().getString("zumoAuth", "");
	}
	
	public static boolean getIsProvisioned() {
		return get().getBoolean("isProvisioned", false);
	}

	public static void setIsProvisioned(boolean isProv) {
		get().edit().putBoolean("isProvisioned", isProv).commit();
	}
	
	public static String getProvisioningAppKey() {
		return get().getString("provisioningappkey", "BOB");
	}

	public static String getProvisioningURL() {
		return get().getString("provisioningurl", "/mdesign/0/procs/app.zip");
	}

	public static String getDeviceId() {
		return "unknown";
	}

	public static boolean usesBootstrapPackage() {
		return get().getBoolean("useBootstrapPackage", false);
	}
	
	public static void setUsesBootstrapPackage(boolean b) {
		get().edit().putBoolean("useBootstrapPackage", b ).commit();
	}

	public static boolean hasBootstrapped() {
		return get().getBoolean("hasBootstrapped", false);
	}

	public static void setHasBootstrapped(boolean b) {
		get().edit().putBoolean("hasBootstrapped", b).commit();
	}

	public static void setIsZumoProvisioned(boolean b) {
		get().edit().putBoolean("zumoprovisioned", b).commit();
	}
	
	public static boolean isZumoProvisioned() {		
		return get().getBoolean("zumoprovisioned", false);
	}

	private static String getLogUploadURL() {
		return get().getString("loguploadurl", "");		
	}

	private static String getLogUploadKey() {
		return get().getString("loguploadappkey", "");
	}

	public static boolean getNoAutoSwap() {
		return get().getBoolean("autoSwapDisabled", false);
	}
	
	public static void setNoAutoSwap(boolean b) {
		get().edit().putBoolean("autoSwapDisabled", b).commit();
	}

	public static void setHasRealApplication(boolean b) {
		get().edit().putBoolean("hasRealApplication", b).commit();
	}
	
	public static boolean getHasRealApplication() {
		return get().getBoolean("hasRealApplication", false);
	}

	public static void setPreconfigured(boolean b) {
		get().edit().putBoolean("isPreconfigured", b).commit();
	}

	public static boolean isPreconfigured() {
		return get().getBoolean("isPreconfigured", false);
	}

	public static String getPackageName(Context c) {
		return c.getPackageName();
	}
}
