package com.commontime.mdesign.plugins.notificationsbase;

import com.commontime.mdesign.plugins.notificationsbase.db.PushMessage;

public interface MessageReceiveObserver {
	public void messageReceived(PushMessage message);
}
