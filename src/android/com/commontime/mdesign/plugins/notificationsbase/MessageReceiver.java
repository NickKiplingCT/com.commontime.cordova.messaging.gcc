package com.commontime.mdesign.plugins.notificationsbase;

import com.commontime.mdesign.plugins.notificationsbase.db.PushMessage;

/**
 * Created by graham on 20/10/2015.
 */
public interface MessageReceiver {
    void messageReceived(PushMessage pm, String type);
}
