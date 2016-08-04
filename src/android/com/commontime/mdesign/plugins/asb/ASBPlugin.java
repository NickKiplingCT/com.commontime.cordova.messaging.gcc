package com.commontime.mdesign.plugins.asb;

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
public class ASBPlugin extends CordovaPlugin {

    public static final String SB_HOST_NAME = "sbHostName";
    public static final String SERVICE_NAMESPACE = "serviceNamespace";
    public static final String SAS_KEY_NAME = "sasKeyName";
    public static final String SAS_KEY = "sasKey";
    public static final String BROKER_TYPE = "brokerType";
    public static final String BROKER_AUTO_CREATE = "brokerAutoCreate";
    static final String ASB_CONFIGURED = "AsbConfigured";

    private NotificationsService mBoundService;

    private ServiceConnection mConnection = new ServiceConnection() {
        public void onServiceConnected(ComponentName className, IBinder service) {
            mBoundService = ((NotificationsService.LocalBinder)service).getService();
            mBoundService.getPushEngine().startPushSystem(AzurePushSystem.AZURE_SERVICEBUS);
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
            plugins.add(AzurePushSystem.class.getName());
            Prefs.get().edit().putStringSet(Notify.NOTIFICATION_PLUGINS, plugins).commit();
        }

        if( !Prefs.get().getBoolean(ASB_CONFIGURED, false)) {
            if( preferences.contains(SB_HOST_NAME) ) {
                Prefs.get().edit()
                        .putString(SB_HOST_NAME, preferences.getString(SB_HOST_NAME, ""))
                        .putString(SERVICE_NAMESPACE, preferences.getString(SERVICE_NAMESPACE, ""))
                        .putString(SAS_KEY_NAME, preferences.getString(SAS_KEY_NAME, ""))
                        .putString(SAS_KEY, preferences.getString(SAS_KEY, ""))
                        .putString(BROKER_TYPE, preferences.getString(BROKER_TYPE, ""))
                        .putBoolean(BROKER_AUTO_CREATE, preferences.getBoolean(BROKER_AUTO_CREATE, true))
                        .putBoolean(ASB_CONFIGURED, true)
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
                        .putString(SB_HOST_NAME, options.getString(SB_HOST_NAME))
                        .putString(SERVICE_NAMESPACE, options.getString(SERVICE_NAMESPACE))
                        .putString(SAS_KEY_NAME, options.getString(SAS_KEY_NAME))
                        .putString(SAS_KEY, options.getString(SAS_KEY))
                        .putString(BROKER_TYPE, options.getString(BROKER_TYPE))
                        .putBoolean(BROKER_AUTO_CREATE, options.getBoolean(BROKER_AUTO_CREATE))
                        .commit();
            }

            if( Prefs.get().getString(Notify.DEFAULT_PUSH_SYSTEM, "").isEmpty() ) {
                Prefs.get().edit().putString(Notify.DEFAULT_PUSH_SYSTEM, AzurePushSystem.AZURE_SERVICEBUS).commit();
            }

            cordova.getActivity().bindService(new Intent(cordova.getActivity(),
                    NotificationsService.class), mConnection, Context.BIND_AUTO_CREATE);

            Prefs.get().edit().putBoolean(ASB_CONFIGURED, true).commit();

            callbackContext.success();
            return true;
        }

        return false;
    }
}
