package com.commontime.mdesign.plugins.appservices;

import java.util.HashMap;
import java.util.Map;

public class AzureStorageUploadTable {

	private Map<String, Map<String, String>> table = new HashMap<String, Map<String,String>>();
		
	public void uploadComplete( String msgId, String path, String uploadFileId) {
		if( ! table.containsKey(msgId)) {
			table.put(msgId, new HashMap<String, String>());
		}
		table.get(msgId).put(path, uploadFileId);
	}

	public String findUpload(String msgId, String path) {
		if( table.containsKey(msgId) ) {
			return table.get(msgId).get(path);
		}		
		return null;
	}

	public void messageSent(String msgId) {
		if(table.containsKey(msgId)) {
			table.remove(msgId);
		}
	}
	
	
	
}
