package com.commontime.mdesign.plugins.notificationsbase.db;

import android.content.Context;

import com.commontime.mdesign.plugins.base.CTLog;

import org.apache.commons.io.FileUtils;
import org.apache.log4j.Priority;

import java.io.File;
import java.io.IOException;

public class ContentStore {

	private static String DIR_ROOT = "notificationsdb";
	
	private static String FILE_CHARSET = "UTF-8";
	private static String FILE_PREFIX = "content";
	private static String FILE_SUFFIX = ".json";
	
	private static String CONTENT_REF_PREFIX = "#contentref:";
	private static final int CONTENT_MIN_FILE_SIZE = 4096;

	private final File mDir;
	private final String mDirName;

	public ContentStore(Context context, String dirName) {
		File root = context.getDir(DIR_ROOT, Context.MODE_PRIVATE);
		mDir = FileUtils.getFile(root, dirName);
		mDirName = dirName;
	}
	
	public String save(String content) throws NotificationsDBException {
		if (content.length() < CONTENT_MIN_FILE_SIZE) {
			return content;
		}
		try {			
			FileUtils.forceMkdir(mDir);
			File file = File.createTempFile(FILE_PREFIX, FILE_SUFFIX, mDir);
			FileUtils.writeStringToFile(file, content, FILE_CHARSET);
			String contentRef = CONTENT_REF_PREFIX + file.getName();
			return contentRef;
		} catch (IOException e) {
			e.printStackTrace();
			throw new NotificationsDBException("Error saving message content to disk (" + mDirName + ")");
		}
	}
	
	public String load(String content) throws NotificationsDBException {
		if (!content.startsWith(CONTENT_REF_PREFIX)) {
			return content;
		}
		try {
			String fileName = content.substring(CONTENT_REF_PREFIX.length());
			File file = FileUtils.getFile(mDir, fileName);
			return FileUtils.readFileToString(file, FILE_CHARSET);		
		} catch (IOException e) {
			e.printStackTrace();
			throw new NotificationsDBException("Error loading message content from disk (" + mDirName + ")");
		}
	}

	public void deleteContent(String content) {
		if (!content.startsWith(CONTENT_REF_PREFIX)) {
			return;
		}
		String fileName = content.substring(CONTENT_REF_PREFIX.length());
		File file = FileUtils.getFile(mDir, fileName);
		file.delete();
	}
	
	public void clear()  {
		try {
			if (mDir.exists()) {
				FileUtils.cleanDirectory(mDir);
			}
		} catch (IOException e) {
			e.printStackTrace();
			CTLog.getInstance().log("shell", Priority.WARN_INT, "Error clearing all message content from disk (" + mDirName + ")");
		}
	}
	
}