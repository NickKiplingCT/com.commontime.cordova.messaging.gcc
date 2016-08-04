package com.commontime.mdesign.plugins.base;

import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.PackageManager.NameNotFoundException;
import android.net.Uri;
import android.os.Environment;

import org.apache.cordova.CordovaWebView;
import org.json.JSONArray;
import org.json.JSONException;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.UnsupportedEncodingException;
import java.net.HttpURLConnection;
import java.net.URLEncoder;
import java.security.InvalidKeyException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.TimeZone;

import javax.crypto.Mac;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

public class Utils {
	public static boolean isSDAvailable() {
		boolean mExternalStorageAvailable = false;
		boolean mExternalStorageWriteable = false;
		String state = Environment.getExternalStorageState();

		if (Environment.MEDIA_MOUNTED.equals(state)) {
			// We can read and write the media
			mExternalStorageAvailable = mExternalStorageWriteable = true;
		} else if (Environment.MEDIA_MOUNTED_READ_ONLY.equals(state)) {
			// We can only read the media
			mExternalStorageAvailable = true;
			mExternalStorageWriteable = false;
		} else {
			// Something else is wrong. It may be one of many other states, but
			// all we need
			// to know is we can neither read nor write
			mExternalStorageAvailable = mExternalStorageWriteable = false;
		}

		return mExternalStorageAvailable && mExternalStorageWriteable;
	}

	public static void sendFiles(Context context, String emailTo, String emailCC, String subject, String emailText, List<String> filePaths) {
		// need to "send multiple" to get more than one attachment
		final Intent emailIntent = new Intent(android.content.Intent.ACTION_SEND_MULTIPLE);
		emailIntent.setType("text/plain");
		emailIntent.putExtra(android.content.Intent.EXTRA_EMAIL, new String[] { emailTo });
		emailIntent.putExtra(android.content.Intent.EXTRA_CC, new String[] { emailCC });
		emailIntent.putExtra(android.content.Intent.EXTRA_TEXT, emailText);
		// has to be an ArrayList
		ArrayList<Uri> uris = new ArrayList<Uri>();
		// convert from paths to Android friendly Parcelable Uri's
		for (String file : filePaths) {
			File fileIn = new File(file);
			Uri u = Uri.fromFile(fileIn);
			uris.add(u);
		}
		emailIntent.putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris);
		context.startActivity(Intent.createChooser(emailIntent, "Send mail..."));
	}

	public static String constructCacheManifestURL(Context ctx) {
		String url = getServerBaseURL() + "/mdesign/0/procs/cache.manifest" + Utils.getParams(ctx, false, false);
		return url;
	}

	public static String constructProvisioningURL(boolean connectOk, Context ctx) {
		
		String url = getServerBaseURL();
		if (connectOk)
			url += "/mdesign/0/procs/index.html" + Utils.getParams(ctx, false, true);
		else
			url += "/mdesign/0/procs/loader.html";
		return url;	
	}
	
//	public static String constructURL(boolean connectOk, Context ctx) {
//
//		if (Prefs.getIsPPA()) {						
//			return "file:///android_asset/www/" + Prefs.getStartPage() + Utils.getParams(ctx, false, false);
//		} else {
//			String url = getServerBaseURL();
//			if (connectOk || Prefs.usesBootstrapPackage() )
//				url += "/mdesign/0/procs/index.html" + Utils.getParams(ctx, false, false);
//			else
//				url += "/mdesign/0/procs/loader.html";
//
//			return url;
//		}		
//	}

	public static String constructDataUploadURL(Context context) {
		String url = getServerBaseURL();
		url += "/data-request" + Utils.getParams(context, false, true);
		return url;
	}

	public static String constructClearDownURL(boolean online, Context ctx) {
		if (Prefs.getIsPPA()) {
			return "file:///android_asset/www/mdesign/0/procs/clear.html" + Utils.getParams(ctx, false, false);
		} else {
			String url = getServerBaseURL();
			url += "/mdesign/0/procs/clear.html" + Utils.getParams(ctx, false, false);
			return url;
		}
	}

	public static String constructZipURL(String stamp) {
		String url = getServerBaseURL();
		url += Prefs.getProvisioningURL();

		if(stamp !=null && !stamp.isEmpty() )
			url += "?stamp=" + stamp;

		return url;
	}
	
	public static String constructIndexURL() {
		return getServerBaseURL() + "/mdesign/0/procs/index.html";
	}
	
	public static String constructManifestRootURL(Context ctx) {
		String url = getServerBaseURL() + "/mdesign/0/procs/";
		return url;
	}

	public static String getServerBaseURL() {
		String url = "http";

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
		return url;
	}
	
	public static String constructAuthenticateURL() {
		return getServerBaseURL() + "/mdesign/0/procs/authenticate.html";
	}

	public static String getParams(Context context, boolean withTime, boolean always) {
		
		String params = "";
		
		if (!Prefs.getIsPPA() || always) {
			
			params += "?X-mDesign-Client=AndroidPhoneGap";

			try {
				PackageManager manager = context.getApplicationContext().getPackageManager();
				PackageInfo info;
				info = manager.getPackageInfo(context.getPackageName(), 0);
				params += "&X-mDesign-Client-Version=" + info.versionName;

				String cordovaVersion = CordovaWebView.CORDOVA_VERSION;
				if (cordovaVersion.equals("dev")) {
					cordovaVersion = "3.5.1";
				}
				params += "&cordova=" + cordovaVersion;
			} catch (NameNotFoundException e) {
			}

			String usedProcessVersions = Prefs.get().getString("usedProcessVersions", null);

			if (usedProcessVersions != null) {
				params = params.concat("&usedProcessVersions=").concat(URLEncoder.encode(usedProcessVersions));
			}

			if (withTime) {
				params = params + "&client-time=" + getCurrent8601TimeString();
			}					
		}

		return params;
	}

	public static String md5ForStream(InputStream is) {
		try {
			MessageDigest md = MessageDigest.getInstance("MD5");

			byte[] dataBytes = new byte[1024];

			int nread = 0;
			while ((nread = is.read(dataBytes)) != -1) {
				md.update(dataBytes, 0, nread);
			}
			;
			byte[] mdbytes = md.digest();
			StringBuffer sb = new StringBuffer();
			for (int i = 0; i < mdbytes.length; i++) {
				sb.append(Integer.toString((mdbytes[i] & 0xff) + 0x100, 16).substring(1));
			}
			return sb.toString();
		} catch (NoSuchAlgorithmException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}

		return "";
	}

	public static byte[] hmacSHA256(String key, String data) {
		try {
			Mac alg = Mac.getInstance("HmacSHA256");
			SecretKey secretKey = new SecretKeySpec(key.getBytes("UTF-8"), "HmacSHA256");
			alg.init(secretKey);
			byte[] result = alg.doFinal(data.getBytes("UTF-8"));			
			return result;
		} catch (NoSuchAlgorithmException e) {
			e.printStackTrace();
		} catch (UnsupportedEncodingException e) {
			e.printStackTrace();
		} catch (InvalidKeyException e) {
			e.printStackTrace();
		}

		return new byte[0];
	}

	final protected static char[] hexArray = "0123456789ABCDEF".toCharArray();

	public static String bytesToHex(byte[] bytes) {
		char[] hexChars = new char[bytes.length * 2];
		for (int j = 0; j < bytes.length; j++) {
			int v = bytes[j] & 0xFF;
			hexChars[j * 2] = hexArray[v >>> 4];
			hexChars[j * 2 + 1] = hexArray[v & 0x0F];
		}
		return new String(hexChars);
	}

	public static String urlEncode(String data) {
		try {
			return URLEncoder.encode(data, "UTF-8");
		} catch (UnsupportedEncodingException e) {
			e.printStackTrace();
		}
		return "";
	}

	public static String urlEncodeLower(String data) {
		String upperCased;
		try {
			upperCased = URLEncoder.encode(data, "UTF-8");
		} catch (UnsupportedEncodingException e) {
			e.printStackTrace();
			return "";
		}
		char[] temp = upperCased.toCharArray();

		for (int i = 0; i < temp.length - 2; i++) {
			if (temp[i] == '%') {
				temp[i + 1] = Character.toLowerCase(temp[i + 1]);
				temp[i + 2] = Character.toLowerCase(temp[i + 2]);
			}
		}
		return new String(temp);

	}

	public static void DeleteRecursive(File fileOrDirectory) {
		if (fileOrDirectory.isDirectory())
			for (File child : fileOrDirectory.listFiles())
				DeleteRecursive(child);

		fileOrDirectory.delete();
	}

	public static void testCrash() {
		throw new TestCrashException("Test Crash at:" + (new Date()).toString());
	}

	public static String getCurrent8601TimeString() {
		TimeZone tz = TimeZone.getTimeZone("UTC");
		DateFormat df = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm'Z'");
		df.setTimeZone(tz);
		String nowAsISO = df.format(new Date());
		return nowAsISO;
	}	
	
	public static void addCookies(HttpURLConnection urlConnection, String... overrides) {
		String cookies = Prefs.get().getString("cookies", "");
		List<String> cookieStrings = new ArrayList<String>();
		if( !cookies.isEmpty() ) {
			try {
				JSONArray jsa = new JSONArray(cookies);
				for( int i = 0; i < jsa.length(); i++ ) {
					String s = jsa.getString(i);
					String key = s.substring(0, s.indexOf("="));
					for (String override: overrides) {
						if (override.startsWith(key)) {
							s = override;
						}
					}
					cookieStrings.add(s);
				}
			} catch (JSONException e) {
				e.printStackTrace();
			}
		}
		
		for( String s : cookieStrings ) {					
			urlConnection.addRequestProperty("Cookie", s);
		}
	}

	
}
