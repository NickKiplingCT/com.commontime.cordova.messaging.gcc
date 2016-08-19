/**
 * PhoneGap is available under *either* the terms of the modified BSD license *or* the
 * MIT License (2008). See http://opensource.org/licenses/alphabetical for full text.
 *
 * Copyright (c) Matt Kane 2010
 * Copyright (c) 2011, IBM Corporation
 */

package com.commontime.mdesign.plugins.base;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;

import com.commontime.mdesign.plugins.base.CTLog;
import com.commontime.mdesign.plugins.base.Prefs;

public class Log extends CordovaPlugin {

	public String callback;

	@Override
	protected void pluginInitialize() {
		Prefs.create(cordova.getActivity().getApplicationContext());
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
    public boolean execute(String action, final JSONArray args, final CallbackContext callbackContext) throws JSONException {

		try {

			if (action.equals("enable")) {
				CTLog.getInstance().enableLogging(true);
			} else if( action.equals("disable")) {
				CTLog.getInstance().enableLogging(false);
			} else if( action.equals("deleteLogFiles")) {
				Prefs.deleteLogs();
			} else if( action.equals("mail")) {
				Prefs.emailLogs(cordova.getActivity(), args.getString(0));
			} else if( action.equals("upload")) {
				
				new Thread(new Runnable() {
					@Override
					public void run() {
						boolean success = false;
						try {
							success = Prefs.uploadLogs(cordova.getActivity(), args.getString(0));
						} catch (JSONException e) {							
							e.printStackTrace();
						}
						if( success )
							callbackContext.success();
						else 
							callbackContext.error("");
					}					
				}).start();				
				return true;
			} else {

				String logName = args.getString(0);
				int priority = args.getInt(1);
				String msg = args.getString(2);

				CTLog.getInstance().log(logName, priority, msg);				
			}

		} catch (JSONException e) {
			e.printStackTrace();
		} catch (Exception e) {
			e.printStackTrace();
		}

		callbackContext.success();
		return true;
	}
}