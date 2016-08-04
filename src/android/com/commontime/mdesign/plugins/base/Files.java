package com.commontime.mdesign.plugins.base;

import android.content.Context;
import android.os.Environment;

import java.io.File;

public final class Files {

	private static File getDir(Context context, String path) {
		return new File(getRootDir(context), path);
	}
	
	public static File getRootDir(Context context) {
		return Environment.getExternalStorageDirectory();
	}
	
	public static File getApplicationDir(Context context) {
		String root = "mDesign" + File.separatorChar + context.getPackageName() + File.separatorChar;
		return getDir(context, root);
	}
	
	public static File getLogsDir(Context context) {
		String root = "mDesign" + File.separatorChar + context.getPackageName() + File.separatorChar;
		String logs = root + "logs" + File.separatorChar;
		return getDir(context, logs);
	}
	
	public static File getAttachmentsDir(Context context) {
		String root = "mDesign" + File.separatorChar + context.getPackageName() + File.separatorChar;
		String att = root + "attachments" + File.separatorChar;
		return getDir(context, att);
	}

	public static File getSendingFileDir(Context context) {
		String root = "mDesign" + File.separatorChar + context.getPackageName() + File.separatorChar;
		String snd = root + "sending" +  File.separatorChar;
		return getDir(context, snd);
	}
	
	public static File getReceivedFileDir(Context context) {
		String root = "mDesign" + File.separatorChar + context.getPackageName() + File.separatorChar;
		String rcv = root + "received" +  File.separatorChar;
		return getDir(context, rcv);
	}
}
