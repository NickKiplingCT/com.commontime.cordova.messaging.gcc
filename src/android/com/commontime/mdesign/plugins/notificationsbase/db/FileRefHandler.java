package com.commontime.mdesign.plugins.notificationsbase.db;

import android.content.Context;
import android.util.Base64;

import com.commontime.mdesign.plugins.base.CTLog;
import com.commontime.mdesign.plugins.base.Files;

import org.apache.commons.io.FileUtils;
import org.apache.log4j.Priority;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.IOException;
import java.util.Iterator;
import java.util.UUID;

public class FileRefHandler implements FileRefHandlerInterface {
	
	private interface Converter {
		boolean shouldConvert(String value);
		String convert(String value) throws IOException;
	}
	
	private static final String PREFIX_FILE_REF = "#fileref:";
	private static final String PREFIX_FILE_DATA = "#file:";

	private static final String FILE_SUFFIX= ".bin";
	
	private final File mRootDir;
	private final File mSendingDir;
	private final File mReceivedDir;
	
	public FileRefHandler(Context c) {
		mRootDir = Files.getRootDir(c);
		mSendingDir = Files.getSendingFileDir(c);
		mReceivedDir = Files.getReceivedFileDir(c);
	}

	public String convertSendingFileRefs(String content) throws JSONException, IOException {
		JSONObject jsonObject = new JSONObject(content);
		ConvertJSONObject(jsonObject, new Converter() {
			@Override
			public boolean shouldConvert(String value) {
				return value.startsWith(PREFIX_FILE_REF);
			}
			@Override
			public String convert(String value) throws IOException{
				String path = value.substring(PREFIX_FILE_REF.length());
				int hashIndex = path.indexOf("#");
				if( hashIndex != -1 ) {
					String hashPart = path.substring(hashIndex);
					String pathPart = path.substring(0, hashIndex);
					return PREFIX_FILE_REF + copySendingFile(pathPart) + hashPart;
				}
				
				return PREFIX_FILE_REF + copySendingFile(path);
			}
			
		});
		return jsonObject.toString();
	}
	
	@Override
	public String resolveFileRefs(PushMessage msg) throws JSONException, IOException {
		JSONObject jsonObject = new JSONObject(msg.getContent());
		ConvertJSONObject(jsonObject, new Converter() {
			@Override
			public boolean shouldConvert(String value) {
				return value.startsWith(PREFIX_FILE_REF);
			}
			@Override
			public String convert(String value) throws IOException{
				String path = value.substring(PREFIX_FILE_REF.length());
				return PREFIX_FILE_DATA + readFileData(path);
			}
			
		});
		return jsonObject.toString();
	}
	
	@Override
	public String createFileRefs(String content) throws JSONException, IOException {
		JSONObject jsonObject = new JSONObject(content);
		ConvertJSONObject(jsonObject, new Converter() {
			@Override
			public boolean shouldConvert(String value) {
				return value.startsWith(PREFIX_FILE_DATA);
			}
			@Override
			public String convert(String value) throws IOException {
				String fileData = value.substring(PREFIX_FILE_DATA.length());
				return PREFIX_FILE_REF + writeFileData(fileData);
			}
			
		});
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
				public String convert(String value) throws IOException{
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
	

	public void clearSendingFiles() {
		try {
			FileUtils.cleanDirectory(mSendingDir);
		} catch (Exception e) {
			e.printStackTrace();
			CTLog.getInstance().log("shell", Priority.WARN_INT, "FileRef content files may not have been cleared.");
		}
	}

	public void clearReceivedFiles() {
		try {
			FileUtils.cleanDirectory(mReceivedDir);
		} catch (Exception e) {
			e.printStackTrace();
			CTLog.getInstance().log("shell", Priority.WARN_INT, "FileRef content files may not have been cleared.");
		}
	}
	
	private void ConvertJSONObject(JSONObject jsonObject, Converter converter) throws JSONException, IOException {
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

	private void ConvertJSONArray(JSONArray arr, Converter converter) throws JSONException, IOException {
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

	private String copySendingFile(String path) throws IOException {
		if( path.startsWith("file://")) {
			path = path.substring("file://".length());
		}
		mSendingDir.mkdirs();
		File srcFile = new File(path);
		File destFile = File.createTempFile(UUID.randomUUID().toString(), FILE_SUFFIX, mSendingDir);
		FileUtils.copyFile(srcFile, destFile);
		
		String rootPath = mRootDir.getAbsolutePath();
		String filePath = destFile.getAbsolutePath();
		return filePath.substring(rootPath.length());
	}
	
	private String readFileData(String path) throws IOException {
		File file = new File(mRootDir, path);
		byte[] bytes = FileUtils.readFileToByteArray(file);
		return Base64.encodeToString(bytes, Base64.DEFAULT);
	}

	private String writeFileData(String fileData) throws IOException {
		mReceivedDir.mkdirs();
		File file = File.createTempFile(UUID.randomUUID().toString(), FILE_SUFFIX, mReceivedDir);
		byte[] bytes = Base64.decode(fileData, Base64.DEFAULT);
		FileUtils.writeByteArrayToFile(file, bytes);
		
		String rootPath = mRootDir.getAbsolutePath();
		String filePath = file.getAbsolutePath();
		return filePath.substring(rootPath.length());
	}
	
	private void deleteFileData(String path) throws IOException {
		File file = new File(mRootDir, path);
		file.delete();
	}
}
