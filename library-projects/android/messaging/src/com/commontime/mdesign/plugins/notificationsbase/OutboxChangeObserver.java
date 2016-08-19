package com.commontime.mdesign.plugins.notificationsbase;

import com.commontime.mdesign.plugins.notificationsbase.db.PushMessage;

public interface OutboxChangeObserver {
	public static final String NOT_TRIED_TYPE = "NOT_TRIED";
	public static final String SENDING_TYPE = "SENDING";
	public static final String SENT_TYPE = "SENT";
	public static final String FAILED_TYPE = "FAILED";
	public static final String FAILED_WILL_RETRY_TYPE = "FAILED_WILL_RETRY";

	public void messageStatusChanged(PushMessage message, String changeType);
}
