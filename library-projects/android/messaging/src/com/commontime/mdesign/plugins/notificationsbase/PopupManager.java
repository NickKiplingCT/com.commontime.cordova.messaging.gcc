package com.commontime.mdesign.plugins.notificationsbase;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Build;
import android.support.v4.app.NotificationCompat;

import com.commontime.mdesign.plugins.base.CTLog;
import com.commontime.mdesign.plugins.base.Prefs;

import org.apache.log4j.Priority;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;


public class PopupManager {

    public final static int ONGOING_NOTIFICATION_ID = 477364273;
    public final static String LOCAL_NOTIFICATION_POPUP = "LOCAL_NOTIFICATION_POPUP";
    public final static String NOTIFICATION_TEXT = "NOTIFICATION_TEXT";

    private Context context;
    Map<String, Integer> notificationIds = new HashMap<String, Integer>();
    int idCounter = 0;
    ConcurrentHashMap<String, String> notifications = new ConcurrentHashMap<String, String>();

    private Resources resources;
    private String packageName;

    public PopupManager(Context context) {
        this.context = context;
        packageName = context.getPackageName();
        resources = context.getResources();
    }

    public void addLocalNotification(String messageId, String notification) {
        CTLog.getInstance().log("shell", Priority.INFO_INT, "Adding local notification");
        Intent i = new Intent();
        i.setAction(LOCAL_NOTIFICATION_POPUP);
        i.putExtra(NOTIFICATION_TEXT, notification);
        context.sendBroadcast(i, "c6WERCaV.K7gaDmDV.zb4kcRLd.permission.POPUP_NOTIFICATION");
    }

    public void addNotification(String messageId, String notification) {
        // 4.1 Supports big inbox style
        if( Build.VERSION.SDK_INT >= 16 ) {
            addInboxStyleNotification(messageId, notification);
        } else {
            addOldNotification(messageId, notification);
        }
    }

    private void addOldNotification(String messageId, String notification) {
        String packageName = context.getPackageName();
        Intent launchIntent = context.getPackageManager().getLaunchIntentForPackage(packageName);

        Intent intent = new Intent(context, launchIntent.getComponent().getClass());
        intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);

        PendingIntent pendIntent = PendingIntent.getActivity(context, 0, intent, 0);

        int iconId = resources.getIdentifier("envelope36", "drawable", packageName);
        int stringId = resources.getIdentifier("mdesign", "string", packageName);

        Bitmap largeIconBitmap = BitmapFactory.decodeResource(context.getResources(), iconId);

        Notification notice = (new NotificationCompat.Builder(context)
                .setContentTitle(context.getString(stringId)).setContentText(notification))
                .setContentIntent(pendIntent)
                .setSmallIcon(iconId)
                .setLargeIcon(largeIconBitmap)
                .setDefaults(Notification.DEFAULT_ALL)
                .setAutoCancel(true).getNotification();

        NotificationManager notifManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);

        notificationIds.put(messageId, idCounter);
        notifManager.notify(idCounter++, notice);
    }

    private synchronized void addInboxStyleNotification(String messageId, String notification) {
        notifications.put(messageId, notification);

        updateInboxStyleNotifications();
    }

    private synchronized void updateInboxStyleNotifications() {

        NotificationManager notifManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);

        if( notifications.size() <= 0 ) {
            notifManager.cancel(7546737);
            return;
        }

        String packageName = context.getPackageName();
        Intent launchIntent = context.getPackageManager().getLaunchIntentForPackage(packageName);

        Intent intent = new Intent(context, launchIntent.getComponent().getClass());
        intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);

        PendingIntent pendIntent = PendingIntent.getActivity(context, 0, intent, 0);

        int iconId = resources.getIdentifier("envelope36", "drawable", packageName);
        int stringId = resources.getIdentifier("app_name", "string", packageName);

        Bitmap largeIconBitmap = BitmapFactory.decodeResource(context.getResources(), iconId);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context)
                .setContentTitle(context.getString(stringId))
                .setContentText("There are " + notifications.size() + " notifications waiting.")
                .setSmallIcon(iconId).setContentIntent(pendIntent)
                .setLargeIcon(largeIconBitmap)
                .setDefaults(Notification.DEFAULT_ALL)
                .setAutoCancel(true);

        NotificationCompat.InboxStyle inboxStyle =
                new NotificationCompat.InboxStyle(builder);

        String msgCount = notifications.size() + " new message";
        if( notifications.size() > 1 )
            msgCount += "s";
        inboxStyle.setBigContentTitle(msgCount);

        final String username = Prefs.getUsername();
        final String host = Prefs.get().getString("hostConnectionEdit", "?");

        // inboxStyle.setSummaryText("mDesign (" + username + "@" + host + ")");

        for( String key : notifications.keySet() ) {
            inboxStyle.addLine(notifications.get(key));
        }

        Notification ibNotice = inboxStyle.build();

        // notificationIds.put(messageId, idCounter);
        notifManager.notify(7546737, ibNotice);
    }

    public synchronized void clearInboxStyleNotification(String messageId) {
        notifications.remove(messageId);
        updateInboxStyleNotifications();
    }

    public void clearOldNotification(String messageId) {
        NotificationManager notifManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if( notificationIds.containsKey(messageId)) {
            notifManager.cancel(notificationIds.get(messageId));
            notificationIds.remove(messageId);
        }

    }

    public void clearNotification(String messageId) {
        if( Build.VERSION.SDK_INT >= 16 ) {
            clearInboxStyleNotification(messageId);
        } else {
            clearOldNotification(messageId);
        }
    }
}
