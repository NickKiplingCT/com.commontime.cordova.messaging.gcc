package com.commontime.mdesign.plugins.notificationsbase;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class SingleCheckReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {

        Intent i = new Intent(context, NotificationsService.class);
        i.setAction("check");
        context.startService(i);
    }
}
