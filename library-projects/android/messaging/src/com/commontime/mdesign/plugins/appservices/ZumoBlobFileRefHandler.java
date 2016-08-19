package com.commontime.mdesign.plugins.appservices;

import android.content.Context;

import com.commontime.mdesign.plugins.base.CTLog;
import com.commontime.mdesign.plugins.notificationsbase.db.FileRefHandlerInterface;
import com.commontime.mdesign.plugins.notificationsbase.db.PushMessage;

import org.apache.log4j.Priority;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.util.Iterator;

public class ZumoBlobFileRefHandler implements FileRefHandlerInterface {

	private interface Converter {
		boolean shouldConvert(String value);
		String convert(String value) throws IOException, AzureStorageException;
	}
	
	private AzureStorageCloudManager storage;
	
	private static final String PREFIX_FILE_REF = "#fileref:";
	private static final String PREFIX_FILE_DATA = "#azureStorageBlobRef:";
	
	protected String url;

	public ZumoBlobFileRefHandler(ZumoPushSystem zumoPushSystem, Context context) {
		storage = new AzureStorageCloudManager(zumoPushSystem, context);
	}

	@Override
	public String resolveFileRefs(final PushMessage msg) throws JSONException, IOException {
		JSONObject jsonObject = new JSONObject(msg.getContent());

		try {
			ConvertJSONObject(jsonObject, new Converter() {
                @Override
                public boolean shouldConvert(String value) {
                    return value.startsWith(PREFIX_FILE_REF);
                }
                @Override
                public String convert(String value) throws IOException, AzureStorageException {
                    String path = value.substring(PREFIX_FILE_REF.length());

                    // Upload the data
                    CTLog.getInstance().log("shell", Priority.INFO_INT, "FileRef found in content, uploading: " + path);
                    String uploadId = storage.uploadFileToCloud(msg, path);
                    if(uploadId == null) {
                        throw new AzureStorageException("Failed to upload");
                    }
                    String result = PREFIX_FILE_DATA + uploadId;
                    CTLog.getInstance().log("shell", Priority.INFO_INT, "Upload complete. Result: " + result);

                    // Return URL
                    return result;
                }
            });
		} catch (AzureStorageException e) {
			e.printStackTrace();
			throw new IOException(e);
		}

		return jsonObject.toString();
	}
	
	@Override
	public String createFileRefs(String content) throws JSONException, IOException {
		JSONObject jsonObject = new JSONObject(content);

		try {
			ConvertJSONObject(jsonObject, new Converter() {
                @Override
                public boolean shouldConvert(String value) {
                    return value.startsWith(PREFIX_FILE_DATA);
                }
                @Override
                public String convert(String value) throws IOException, AzureStorageException {
                    String uri = value.substring(PREFIX_FILE_DATA.length());
                    CTLog.getInstance().log("shell", Priority.INFO_INT, "FileRef found in content, downloading: " + uri.toString());
                    String result = storage.downloadFileFromCloud(uri);
                    CTLog.getInstance().log("shell", Priority.INFO_INT, "Download complete.  Result: " + result);
                    return PREFIX_FILE_REF + result;
                }

            });
		} catch (AzureStorageException e) {
			e.printStackTrace();
			throw new IOException(e);
		}

		return jsonObject.toString();
	}

	public void deleteFiles(String content) {
		try {
			JSONObject jsonObject = new JSONObject(content);
			ConvertJSONObject(jsonObject, new Converter() {
				@Override
				public boolean shouldConvert(String value) {
					return value.startsWith(PREFIX_FILE_REF);
				}
				@Override
				public String convert(String value) throws IOException {
					String path = value.substring(PREFIX_FILE_REF.length());
					deleteFileData(path);
					return value;
				}				
			});
	
		} catch (Exception e) {
			e.printStackTrace();
			CTLog.getInstance().log("shell", Priority.WARN_INT, "FileRef content files may not have been deleted.");
		}
	}
	
	private void ConvertJSONObject(JSONObject jsonObject, Converter converter) throws JSONException, IOException, AzureStorageException {
		Iterator<?> iter = jsonObject.keys();
		while (iter.hasNext()) {
			String key = (String) iter.next();
			Object value = jsonObject.get(key);
			if (value instanceof JSONObject) {
				ConvertJSONObject((JSONObject)value, converter);
			} else if (value instanceof JSONArray) {
				ConvertJSONArray((JSONArray)value, converter);
			} else if (value instanceof String) {
				String s = (String)value;
				if (converter.shouldConvert(s)) {
					jsonObject.put(key, converter.convert(s));
				}
			}
		}		
	}

	private void ConvertJSONArray(JSONArray arr, Converter converter) throws JSONException, IOException, AzureStorageException {
		for (int i = 0; i < arr.length(); i++) {
			Object value = arr.get(i);
			if (value instanceof JSONObject) {
				ConvertJSONObject((JSONObject)value, converter);
			} else if (value instanceof JSONArray) {
				ConvertJSONArray((JSONArray)value, converter);
			} else if (value instanceof String) {
				String s = (String)value;
				if (converter.shouldConvert(s)) {
					arr.put(i, converter.convert(s));
				}
			}
		}
	}	
	
	private void deleteFileData(String path) throws IOException {
		storage.deleteLocalFile(path);		
	}
}
