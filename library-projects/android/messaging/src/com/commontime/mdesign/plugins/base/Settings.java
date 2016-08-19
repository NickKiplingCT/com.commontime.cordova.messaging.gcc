
package com.commontime.mdesign.plugins.base;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.log4j.Priority;

import com.commontime.mdesign.plugins.base.CTLog;
import com.commontime.mdesign.plugins.base.Prefs;
import com.commontime.mdesign.plugins.base.Utils;

public class Settings extends CordovaPlugin {

	public String callback;

	/**
	 * Constructor.
	 */
	public Settings() {
	}

	@Override
	protected void pluginInitialize() {

		Prefs.create(cordova.getActivity().getApplicationContext());

		if( Prefs.isPreconfigured() )
			return;

		Prefs.setHost(preferences.getString("host", ""));
		Prefs.setPort(preferences.getString("port", "616"));
		Prefs.setUsername(preferences.getString("username", ""));
		Prefs.setPassword(preferences.getString("password", ""));
		Prefs.setUseSSL(preferences.getBoolean("ssl", false));

		Prefs.setPreconfigured(true);
	}

	/**
	 * Executes the request and returns PluginResult.
	 * 
	 * @param action
	 *            The action to execute.
	 * @param args
	 *            JSONArray of arguments for the plugin.
	 * @param callbackId
	 *            The callback id used when calling back into JavaScript.
	 * @return A PluginResult object with a status and message.
	 */
	@Override
    public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {

		if( action.equals("getHost") ) {
			callbackContext.success(Prefs.getHost());
			return true;
		} else if( action.equals("getPort") ) {
			callbackContext.success(Prefs.getPort());
			return true;			
		} else if( action.equals("getSSL") ) {
			callbackContext.success( new JSONArray().put( Prefs.getUseSSL() ));
			return true;						
		} else if( action.equals("getURL") ) {
			String url = "http";

			if (Prefs.getUseSSL()) {
				url += "s";
			}

			url += "://";
				
			url += Prefs.getHost();
			String port = Prefs.getPort();
			if (!(port.equals("80") || port.equals("443"))) {
				url += ":";
				url += port;
			}			
			callbackContext.success(url);
			return true;
		} else if( action.equals("setVersions") ) {
			try {
				JSONObject versionObject = args.getJSONObject(0); 
				String fw = versionObject.getString("framework");
				Prefs.get().edit().putString("javascriptVersions", versionObject.toString()).commit();				
				callbackContext.success();
				return true;
			} catch (JSONException e) {			
				e.printStackTrace();
				callbackContext.error(e.getMessage());				
				return true;
			}
//		} else if( action.equals("getProvisioningURL") ) {
//			String url = Utils.constructURL(true, cordova.getActivity());
//			callbackContext.success(url);
//			return true;			
		} else if( action.equals("getClearURL") ) {
			String url = Utils.constructClearDownURL(true, cordova.getActivity());
			callbackContext.success(url);
			return true;			
		} else if( action.equals("getApplicationID") ) {
			callbackContext.success(Prefs.getPackageName(cordova.getActivity()));
			return true;				
		} else if( action.equals("getUsername") ) {
			String username = Prefs.getUsername();
			callbackContext.success(username);
			return true;
		} else if( action.equals("getServiceUsername")) {
			String service = args.getString(0);
			String pref = service + "UserId";
			String serviceUserName = Prefs.get().getString(pref, "");
			callbackContext.success(serviceUserName);
			return true;
		} else if( action.equals("setPreference") ) {			
			try {
				Prefs.get().edit().putString(args.getString(0), args.getString(1)).commit();
				callbackContext.success();
			} catch (JSONException e) {
				CTLog.getInstance().log("shell", Priority.ERROR_INT, "Failed to save Pref");
				e.printStackTrace();
				callbackContext.error(e.toString());
				return true;
			}
		} else if( action.equals("setUserPreference") ) {			
			try {
				Prefs.get().edit().putString("UserPref:"+args.getString(0), args.getString(1)).commit();
				callbackContext.success();
			} catch (JSONException e) {
				CTLog.getInstance().log("shell", Priority.ERROR_INT, "Failed to save Pref");
				e.printStackTrace();
				callbackContext.error(e.toString());
				return true;
			}
		} else if( action.equals("getUserPreference") ) {			
			try {
				String s = Prefs.get().getString("UserPref:"+args.getString(0), null);
				if( s != null) {
					callbackContext.success(s);
				} else {
					CTLog.getInstance().log("shell", Priority.ERROR_INT, "Failed to find Pref: " + args.getString(0));
					callbackContext.error("Preference: " + args.getString(0) + " not found.");
				}
			} catch (JSONException e) {
				CTLog.getInstance().log("shell", Priority.ERROR_INT, "Failed to get Pref");
				e.printStackTrace();
				callbackContext.error(e.toString());
				return true;
			}
		} else if( action.equals("openShellSettings") ) {			
			// ((MainActivity)cordova.getActivity()).launchSettings();
			return true;
		} else if( action.equals("openAbout") ) {			
			// ((MainActivity)cordova.getActivity()).launchAbout();
			return true;
		}			

		return false;
	}
}