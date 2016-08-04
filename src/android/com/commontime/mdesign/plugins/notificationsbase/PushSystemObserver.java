package com.commontime.mdesign.plugins.notificationsbase;

import com.commontime.mdesign.plugins.notificationsbase.db.PushMessage;

public interface PushSystemObserver {
	public void messageReceived(PushMessage message);
	public void connectionStateChange(PushSystem.State state);
}
