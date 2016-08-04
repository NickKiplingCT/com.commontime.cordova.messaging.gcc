package com.commontime.mdesign.plugins.rest;

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
 * Created by graham on 21/06/16.
 */
public class RestPlugin extends CordovaPlugin {

    private NotificationsService mBoundService;

    private ServiceConnection mConnection = new ServiceConnection() {
        public void onServiceConnected(ComponentName className, IBinder service) {
            mBoundService = ((NotificationsService.LocalBinder)service).getService();
            mBoundService.getPushEngine().startPushSystem(RestPushSystem.REST_PROVIDER);
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
            plugins.add(RestPushSystem.class.getName());
            Prefs.get().edit().putStringSet(Notify.NOTIFICATION_PLUGINS, plugins).commit();
        }
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {

        // Action dispatch
        if (action.equals("start")) {
            JSONObject options = args.optJSONObject(0);

            if( options != null ) {

            }

            if( Prefs.get().getString(Notify.DEFAULT_PUSH_SYSTEM, "").isEmpty() ) {
                Prefs.get().edit().putString(Notify.DEFAULT_PUSH_SYSTEM, "rest").commit();
            }

            cordova.getActivity().bindService(new Intent(cordova.getActivity(),
                    NotificationsService.class), mConnection, Context.BIND_AUTO_CREATE);

            callbackContext.success();
            return true;
        }

        return false;
    }

}
