//package com.commontime.mdesign.plugins.notificationsbase;
//
//import android.app.AlarmManager;
//import android.app.PendingIntent;
//import android.content.Context;
//import android.content.Intent;
//import android.os.Handler;
//import android.os.Looper;
//import android.os.Message;
//import android.support.annotation.NonNull;
//
//import com.commontime.mdesign.plugins.base.CTLog;
//import com.commontime.mdesign.plugins.base.Prefs;
//
//import org.apache.log4j.Priority;
//
//import java.lang.reflect.InvocationTargetException;
//import java.util.ArrayList;
//import java.util.Calendar;
//import java.util.HashSet;
//import java.util.List;
//import java.util.Set;
//
//public class NotificationsHandler extends Handler {
//    private final NotificationsService service;
//
//    public NotificationsHandler(Looper looper, NotificationsService service) {
//        super(looper);
//        this.service = service;
//        createAlarm();
//    }
//
//    @Override
//    public void handleMessage(Message msg) {
//        super.handleMessage(msg);
//        int startId = msg.arg1;
//        String action = (String) msg.obj;
//
//        if( action.equals("shutdown") ) {
//            service.getPushEngine().stop();
//        } else if( action.equals("check2") ) {
//            List<PushSystem> systems = getPushSystems();
//            for( PushSystem pushSystem : systems ) {
//                pushSystem.setObserver(service.getPushEngine());
//            }
//
//            service.getPushEngine().doSingleCheck(new SingleCheckObserver() {
//                @Override
//                public void checkComplete() {
//                    CTLog.getInstance().log("shell", Priority.INFO_INT, "Single Check complete");
//                    clearAlarm();
//                    createAlarm();
//                }
//            }, systems);
//        } else if( action.equals("check") ) {
//
//            if( service.getIsUsingPush() ) {
//                createAlarm();
//                return;
//            }
//
//            List<PushSystem> systems = getPushSystems();
//            for( PushSystem pushSystem : systems ) {
//                pushSystem.setObserver(service.getPushEngine());
//            }
//
//            service.getPushEngine().doSingleCheck(new SingleCheckObserver() {
//                @Override
//                public void checkComplete() {
//                    CTLog.getInstance().log("shell", Priority.INFO_INT, "Single Check complete");
//                    clearAlarm();
//                    createAlarm();
//                }
//            }, systems);
//        } else if( action.equals("start") ) {
//            start();
//        }
//
//        service.stopSelfResult(startId);
//    }
//
//    private void createAlarm() {
//        clearAlarm();
//        Intent i = new Intent(service, SingleCheckReceiver.class );
//        PendingIntent pi = PendingIntent.getBroadcast(service, 0, i, 0);
//        AlarmManager am = (AlarmManager)service.getSystemService(Context.ALARM_SERVICE);
//        Calendar c = Calendar.getInstance();
//        Calendar cal = Calendar.getInstance();
//        cal.add(Calendar.MINUTE, 1);
//        am.set(AlarmManager.RTC_WAKEUP, cal.getTimeInMillis(), pi);
//        CTLog.getInstance().log("shell", Priority.INFO_INT, "Next check scheduled for: " + cal.getTime().toString());
//    }
//
//    private void clearAlarm() {
//        AlarmManager am = (AlarmManager)service.getSystemService(Context.ALARM_SERVICE);
//        Intent i = new Intent(service, SingleCheckReceiver.class );
//        PendingIntent pendingUpdateIntent = PendingIntent.getBroadcast(service, 0, i, 0);
//        am.cancel(pendingUpdateIntent);
//        pendingUpdateIntent.cancel();
//    }
//
//    private void start() {
//        Prefs.create(service.getApplicationContext());
//
//        List<PushSystem> systems = getPushSystems();
//        service.getPushEngine().start(systems);
//    }
//
//    @NonNull
//    private List<PushSystem> getPushSystems() {
//
//        Prefs.create(service.getApplicationContext());
//
//        List<PushSystem> systems = new ArrayList<PushSystem>();
//        Set<String> plugins = Prefs.get().getStringSet(Notify.NOTIFICATION_PLUGINS, new HashSet<String>());
//        for( String plugin : plugins ) {
//            try {
//                Class c = Class.forName(plugin);
//                PushSystem ps = (PushSystem) c.getDeclaredConstructor(new Class[]{PushEngine.class}).newInstance(service.getPushEngine());
//                systems.add(ps);
//            } catch (ClassNotFoundException e) {
//                e.printStackTrace();
//            } catch (InvocationTargetException e) {
//                e.printStackTrace();
//            } catch (NoSuchMethodException e) {
//                e.printStackTrace();
//            } catch (InstantiationException e) {
//                e.printStackTrace();
//            } catch (IllegalAccessException e) {
//                e.printStackTrace();
//            }
//        }
//        return systems;
//    }
//}