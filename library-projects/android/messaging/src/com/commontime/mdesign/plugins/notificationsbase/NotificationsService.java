package com.commontime.mdesign.plugins.notificationsbase;

import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Binder;
import android.os.Handler;
import android.os.IBinder;
import android.util.Log;

import com.commontime.mdesign.plugins.base.CTLog;
import com.commontime.mdesign.plugins.base.Prefs;

import org.apache.log4j.Priority;

public class NotificationsService extends Service {

	private PushEngine engine;
	private boolean bound;

	private Handler serviceKiller = new Handler();
	private boolean foreground;

	public PushEngine getPushEngine() {
		return engine;
	}

	public boolean getBound() {
		return bound;
	}

	public void setAppForeground(boolean foreground) {
		this.foreground = foreground;

		if( !foreground ) {
			serviceKiller.postDelayed(new Runnable() {
				@Override
				public void run() {
					CTLog.getInstance().log("shell", Priority.INFO_INT, "Stopping Service");
					engine.stopLimitedSendSchedule();
					engine.stopSendSchedule();

					stopSelf();
				}
			}, 60000);
		} else {
			serviceKiller.removeCallbacksAndMessages(null);
		}
	}

	public void setContext(Context context) {
		getPushEngine().setContext(context != null ? context : this);
	}

	public void zumoLogOut(boolean clearCookies) {
		engine.zumoLogOut(clearCookies);
	}

	public class LocalBinder extends Binder {
		public NotificationsService getService() {
			return NotificationsService.this;
		}
	}

	@Override
	public void onCreate() {
		// Toast.makeText(this, "Notifications Start", Toast.LENGTH_SHORT).show();
		engine = new PushEngine(this.getApplicationContext());
	}

	@Override
	public int onStartCommand(Intent intent, int flags, int startId) {
		Prefs.create(this.getApplicationContext());
		Log.d("shell", Prefs.get().getString("sbHostName", "") );
		getPushEngine().setNetworkConnected(intent.getAction().equals("connected"));
		if( intent.getAction().equals("connected") ) {
			getPushEngine().startLimitedSendSchedule(5);
		} else {
			getPushEngine().stopLimitedSendSchedule();
			getPushEngine().stopSendSchedule();
		}
		return START_NOT_STICKY;
	}

	@Override
	public IBinder onBind(Intent intent) {
		bound = true;
		return mBinder;
	}

	@Override
	public boolean onUnbind (Intent intent) {
		bound = false;
		return true;
	}

	// This is the object that receives interactions from clients.  See
	// RemoteService for a more complete example.
	private final IBinder mBinder = new LocalBinder();
}
