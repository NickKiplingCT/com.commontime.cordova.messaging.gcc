package com.commontime.mdesign.plugins.appservices;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.IBinder;

import com.commontime.mdesign.plugins.base.Prefs;
import com.commontime.mdesign.plugins.notificationsbase.NotificationsService;
import com.commontime.mdesign.plugins.notificationsbase.Notify;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashSet;
import java.util.Set;

/**
 * Created by gjm on 26/02/2016.
 */
public class ZumoPlugin extends CordovaPlugin {

    static final String ZUMO_USE_BLOB_STORAGE = "zumoUseBlobStorage";
    static final String ZUMO_URL = "zumoUrl";
    static final String ZUMO_AUTHENTICATION_METHOD = "zumoAuthenticationMethod";

    static private final String USE_BLOB_STORAGE = "useBlobStorage";
    static private final String AUTHENTICATION_METHOD = "authenticationMethod";
    static private final String URL = "url";
    static final String ZUMO_CONFIGURED = "zumoConfigured";

    private NotificationsService mBoundService;

    private ServiceConnection mConnection = new ServiceConnection() {
        public void onServiceConnected(ComponentName className, IBinder service) {
            mBoundService = ((NotificationsService.LocalBinder)service).getService();
            mBoundService.getPushEngine().startPushSystem(ZumoPushSystem.AZURE_APP_SERVICES);
            cordova.getActivity().unbindService(mConnection);
        }

        public void onServiceDisconnected(ComponentName className) {
            mBoundService = null;
        }
    };

    @Override
    protected void pluginInitialize() {

        Prefs.create(cordova.getActivity().getApplicationContext());

        synchronized (cordova) {
            Set<String> plugins = Prefs.get().getStringSet(Notify.NOTIFICATION_PLUGINS, new HashSet<String>());
            plugins.add(com.commontime.mdesign.plugins.appservices.ZumoPushSystem.class.getName());
            Prefs.get().edit().putStringSet(Notify.NOTIFICATION_PLUGINS, plugins).commit();
        }

        if( !Prefs.get().getBoolean(ZUMO_CONFIGURED, false)) {
            if( preferences.contains(ZUMO_URL) ) {
                Prefs.get().edit()
                        .putString(ZUMO_URL, preferences.getString(ZUMO_URL, ""))
                        .putBoolean(ZUMO_USE_BLOB_STORAGE, preferences.getBoolean(ZUMO_USE_BLOB_STORAGE, false))
                        .putString(ZUMO_AUTHENTICATION_METHOD, preferences.getString(ZUMO_AUTHENTICATION_METHOD, ""))
                        .putBoolean(ZUMO_CONFIGURED, true)
                        .commit();
            }
        }

    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {

        // Action dispatch
        if (action.equals("start")) {
            JSONObject options = args.optJSONObject(0);

            if( options != null ) {
                Prefs.get().edit()
                        .putString(ZUMO_URL, options.getString(URL))
                        .putBoolean(ZUMO_USE_BLOB_STORAGE, options.getBoolean(USE_BLOB_STORAGE))
                        .putString(ZUMO_AUTHENTICATION_METHOD, options.getString(AUTHENTICATION_METHOD))
                        .commit();
            }

            if( Prefs.get().getString(Notify.DEFAULT_PUSH_SYSTEM, "").isEmpty() ) {
                Prefs.get().edit().putString(Notify.DEFAULT_PUSH_SYSTEM, ZumoPushSystem.AZURE_APP_SERVICES).commit();
            }

            cordova.getActivity().bindService(new Intent(cordova.getActivity(),
                    NotificationsService.class), mConnection, Context.BIND_AUTO_CREATE);

            Prefs.get().edit().putBoolean(ZUMO_CONFIGURED, true).commit();

            callbackContext.success();
            return true;
        }

        return false;
    }
}
