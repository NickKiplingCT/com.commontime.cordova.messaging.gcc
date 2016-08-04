package com.commontime.mdesign.plugins.notificationsbase.db;

import com.commontime.mdesign.plugins.base.CTLog;

import org.apache.log4j.Priority;

public class NotificationsDBException extends Exception {

	private static final long serialVersionUID = 1494176463268251814L;

	public NotificationsDBException(String message) {
		super(message);
		CTLog.getInstance().log("shell", Priority.ERROR_INT, message);
	}
}
