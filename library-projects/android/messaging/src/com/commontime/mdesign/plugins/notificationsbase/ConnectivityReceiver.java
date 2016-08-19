package com.commontime.mdesign.plugins.notificationsbase;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;

import com.commontime.mdesign.plugins.base.CTLog;
import com.commontime.mdesign.plugins.base.Prefs;

import org.apache.log4j.Priority;

/**
 * Created by graham on 27/06/16.
 */
public class ConnectivityReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        Bundle extras = intent.getExtras();
        String action = "connected";
        if (extras != null) {
            action = !extras.getBoolean("noConnectivity") ? "connected" : "disconnected";
        }
        Prefs.create(context.getApplicationContext());
        Intent serviceIntent = new Intent(context, NotificationsService.class);
        serviceIntent.setAction(action);

        CTLog.getInstance().log("shell", Priority.INFO_INT, "ConnectivityReceiver:onReceive: " + action);

        context.startService(serviceIntent);
    }
}
