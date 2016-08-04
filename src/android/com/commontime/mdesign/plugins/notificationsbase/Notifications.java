//package com.commontime.mdesign.plugins.notificationsbase;
//
//import android.content.Context;
//
//import com.commontime.mdesign.plugins.base.Prefs;
//
//import java.util.HashSet;
//import java.util.Set;
//
///**
// * Created by gjm on 26/02/2016.
// */
//public class Notifications {
//    private Context context;
//    private PushEngine pushEngine;
//
//    public Notifications(NotificationsService notificationsService) {
//        context = notificationsService;
//        pushEngine = new PushEngine(context);
//    }
//
//    public void init() {
//        Set<String> plugins = Prefs.get().getStringSet(NotificationsPlugin.NOTIFICATION_PLUGINS, new HashSet<String>());
//    }
//
//    public void check() {
//
//    }
//
//    public void setAlarm() {
//
//    }
//
//    public PushEngine getPushEngine() {
//        return pushEngine;
//    }
//
//    public void goForegroundService() {
//
//    }
//
//    public void changeNotificationState(PushSystem.State state) {
//
//    }
//
//    public void startIfNotRunning() {
//        pushEngine.start();
//    }
//
//    public void stopWhenIdle() {
//        pushEngine.stop();
//    }
//}
