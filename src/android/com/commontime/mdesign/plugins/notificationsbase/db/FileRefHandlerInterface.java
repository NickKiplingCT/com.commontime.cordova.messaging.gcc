package com.commontime.mdesign.plugins.notificationsbase.db;

import org.json.JSONException;

import java.io.IOException;

public interface FileRefHandlerInterface {
	public String resolveFileRefs(PushMessage msg) throws JSONException, IOException;
	public String createFileRefs(String content) throws JSONException, IOException;
}
