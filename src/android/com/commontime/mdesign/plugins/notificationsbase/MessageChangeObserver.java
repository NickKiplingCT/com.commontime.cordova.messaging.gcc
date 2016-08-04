package com.commontime.mdesign.plugins.notificationsbase;

import com.commontime.mdesign.plugins.notificationsbase.db.PushMessage;

public interface MessageChangeObserver {

	public static String CREATE_TYPE = "create";
	public static String UPDATE_TYPE = "update";
	public static String DELETE_TYPE = "delete";
	
	public void messageChanged(PushMessage message, String changeType);
	
}
