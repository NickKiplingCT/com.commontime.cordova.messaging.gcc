package com.commontime.mdesign.plugins.base;

import android.os.Environment;

import com.commontime.mdesign.plugins.base.crypto.TripleDES;

import org.apache.log4j.Level;
import org.apache.log4j.Logger;
import org.apache.log4j.Priority;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;

public class CTLog {
	
	public final static CTLog INSTANCE = new CTLog();
	
	private CTLogConfigurator logFrameworkCfg = new CTLogConfigurator("framework");
	private final Logger logFramework = Logger.getLogger("framework");
	private CTLogConfigurator logApplicationCfg = new CTLogConfigurator("application");
	private final Logger logApplication = Logger.getLogger("application");
	private CTLogConfigurator logShellCfg = new CTLogConfigurator("shell");
	private final Logger logShell = Logger.getLogger("shell");
	private CTLogConfigurator logNotifySendCfg = new CTLogConfigurator("notify-send");
	private final Logger logNotifySend = Logger.getLogger("notify-send");
	private CTLogConfigurator logSecureCfg = new CTLogConfigurator("secure");
	private final Logger logSecure = Logger.getLogger("secure");
	private CTLogConfigurator logNotifyAuditCfg = new CTLogConfigurator("notify-audit");
	private final Logger logNotifyAudit = Logger.getLogger("notify-audit");
	
	private CTLog() {
		try {
			createLogs();
		} catch(Exception e ) {
			android.util.Log.e("Shell", "Failed to create logs!");
		}
	}
	
	public static synchronized CTLog getInstance() {
		return CTLog.INSTANCE;
	}
	
	private void createLogs() {
		if (Utils.isSDAvailable()) {
			File f = Environment.getExternalStoragePublicDirectory("logs");
			boolean b = f.mkdirs();
			File logFile = new File(f, "framework.log");
			logFrameworkCfg.setFileName(logFile.getAbsolutePath());
			logFrameworkCfg.setFilePattern("%-5p %d %m%n");
			logFrameworkCfg.setMaxBackupSize(10); // 100MB limit
			logFrameworkCfg.setMaxFileSize(10 * 1024 * 1024); // 10MB
			logFile = new File(f, "application.log");
			logApplicationCfg.setFileName(logFile.getAbsolutePath());
			logApplicationCfg.setFilePattern("%-5p %d %m%n");
			logApplicationCfg.setMaxBackupSize(10); // 100MB limit
			logApplicationCfg.setMaxFileSize(10 * 1024 * 1024); // 10MB
			logFile = new File(f, "shell.log");
			logShellCfg.setFileName(logFile.getAbsolutePath());
			logShellCfg.setFilePattern("%-5p %d %m%n");
			logShellCfg.setMaxBackupSize(10); // 100MB limit
			logShellCfg.setMaxFileSize(10 * 1024 * 1024); // 10MB
			logFile = new File(f, "notify-send.log");
			logNotifySendCfg.setFileName(logFile.getAbsolutePath());
			logNotifySendCfg.setFilePattern("%-5p %d %m%n");
			logNotifySendCfg.setMaxBackupSize(10); // 100MB limit
			logNotifySendCfg.setMaxFileSize(10 * 1024 * 1024); // 10MB
			logFile = new File(f, "secure.log");
			logSecureCfg.setFileName(logFile.getAbsolutePath());
			logSecureCfg.setFilePattern("%-5p %d %m%n");
			logSecureCfg.setMaxBackupSize(10); // 100MB limit
			logSecureCfg.setMaxFileSize(10 * 1024 * 1024); // 10MB
			logFile = new File(f, "notify-audit.log");
			logNotifyAuditCfg.setFileName(logFile.getAbsolutePath());
			logNotifyAuditCfg.setFilePattern("%-5p %d %m%n");
			logNotifyAuditCfg.setMaxBackupSize(10); // 100MB limit
			logNotifyAuditCfg.setMaxFileSize(10 * 1024 * 1024); // 10MB
		} else {
			logFrameworkCfg.setUseFileAppender(false);
			logApplicationCfg.setUseFileAppender(false);
			logShellCfg.setUseFileAppender(false);
			logNotifySendCfg.setUseFileAppender(false);
			logSecureCfg.setUseFileAppender(false);
			logNotifyAuditCfg.setUseFileAppender(false);
		}
		logFrameworkCfg.setRootLevel(Level.ALL);
		logFrameworkCfg.setResetConfiguration(true);
		logFrameworkCfg.configure();
		CTLogConfigurator.setLevel("framework", Level.ALL);	// TODO Get the framework log level from the settings
		logApplicationCfg.setRootLevel(Level.ALL);
		logApplicationCfg.setResetConfiguration(false);
		logApplicationCfg.configure();
		CTLogConfigurator.setLevel("application", Level.ALL);	// TODO Get the application log level from the settings
		logShellCfg.setRootLevel(Level.ALL);
		logShellCfg.setResetConfiguration(false);		
		logShellCfg.configure();
		CTLogConfigurator.setLevel("shell", Level.ALL);	// TODO Get the shell log level from the settings
		logNotifySendCfg.setRootLevel(Level.ALL);
		logNotifySendCfg.setResetConfiguration(false);		
		logNotifySendCfg.configure();
		CTLogConfigurator.setLevel("notify-send", Level.ALL);	// TODO Get the shell log level from the settings
		logSecureCfg.setRootLevel(Level.ALL);
		logSecureCfg.setResetConfiguration(false);		
		logSecureCfg.configure();
		CTLogConfigurator.setLevel("secure", Level.ALL);	// TODO Get the shell log level from the settings
		logNotifyAuditCfg.setRootLevel(Level.ALL);
		logNotifyAuditCfg.setResetConfiguration(false);		
		logNotifyAuditCfg.configure();
		CTLogConfigurator.setLevel("notify-audit", Level.ALL);	// TODO Get the shell log level from the settings
	}

	private Logger resolveLogger(String logName) {
		Logger logger = null;
		if (logName.equalsIgnoreCase("shell")) {
			logger = logShell;
		} else if (logName.equalsIgnoreCase("framework")) {
			logger = logFramework;
		} else if (logName.equalsIgnoreCase("application")) {
			logger = logApplication;
		} else if (logName.equalsIgnoreCase("notify-send")) {
			logger = logNotifySend;
		} else if (logName.equalsIgnoreCase("secure")) {
			logger = logSecure;
		} else if (logName.equalsIgnoreCase("notify-audit")) {
			logger = logNotifyAudit;
		}
		
		return logger;
	}
	
	private CTLogConfigurator resolveLoggerCfg(String logName) {
		CTLogConfigurator cfg = null;
		if (logName.equalsIgnoreCase("shell")) {
			cfg = logShellCfg;
		} else if (logName.equalsIgnoreCase("framework")) {
			cfg = logFrameworkCfg;
		} else if (logName.equalsIgnoreCase("application")) {
			cfg = logApplicationCfg;
		} else if (logName.equalsIgnoreCase("notify-send")) {
			cfg = logNotifySendCfg;	
		} else if (logName.equalsIgnoreCase("secure")) {
			cfg = logSecureCfg;
		} else if (logName.equalsIgnoreCase("notify-audit")) {
			cfg = logNotifyAuditCfg;
		}
		return cfg;
	}
	
	@SuppressWarnings("deprecation")
	public void log(String logName, int priority, String msg) {
		Logger logger = resolveLogger(logName);
		if (logger != null) {
			
			logger.log(Level.toLevel(priority), msg);
			
			// We don't support trace logging here, so ignore thems
			//if( priority == 5000 )
			//	return;
			
//			if( priority == SECURITY_INT )
//				logEnc(logName, priority, msg);
//			else
//				logger.log(Priority.toPriority(priority), msg);
		}
	}
	
	private void logEnc(String logName, int priority, String msg) {
		TripleDES td = new TripleDES(null);
		String encMsg = td.encrypt(msg);
		log(logName, Priority.INFO_INT, "secure: " + encMsg);		
	}

	public void removeAllAppenders(String logName) {	// Only valid for shell log - other logs dealt with in JS
		Logger logger = resolveLogger(logName);
		logger.removeAllAppenders();	
	}

	public void removeAppender(String logName, String appender) {	// Only valid for shell log - other logs dealt with in JS
		Logger logger = resolveLogger(logName);
		logger.removeAppender(appender);	// Doesn't seem to work, is this because the derived log class doesn't have an override for it?
	}

	public void addAppender(String logName, String appender, JSONObject jso) {	// Only valid for shell log - other logs dealt with in JS
		
		CTLogConfigurator cfg =  resolveLoggerCfg(logName);
		
		if (appender.equals("FileAppender")) {
			cfg.configureFileAppender();
		} else if (appender.equals("LogCatAppender")) {				
			cfg.configureLogCatAppender();
		} else if (appender.equals("NotifyLogAppender")) {
			// cfg.configureNotifyLogAppender(jso);
		}	
	}
	
	public JSONArray getAppenders(String logName) throws JSONException {
		JSONArray appenders = null;
		
		CTLogConfigurator cfg =  resolveLoggerCfg(logName);		
		appenders = cfg.getAppenders();		
		return appenders;
	}
	
	public void setLevel(String logName, String level) {
		CTLogConfigurator.setLevel(logName, Level.toLevel(level));
	}

	public String getLevel(String logName) {
		return CTLogConfigurator.getLevel(logName);
	}

	public void enableLogging(boolean enabled) {
		
		CTLog.getInstance().log("shell", Priority.INFO_INT, "Logging enabled: " + enabled);
		
		Prefs.get().edit().putBoolean("enableClientLogging", enabled).commit();
		
		logFrameworkCfg.setUseLogCatAppender(enabled);
		logFrameworkCfg.setUseFileAppender(enabled);
		
		logApplicationCfg.setUseLogCatAppender(enabled);
		logApplicationCfg.setUseFileAppender(enabled);
		
		logShellCfg.setUseLogCatAppender(enabled);
		logShellCfg.setUseFileAppender(enabled);
		
		logNotifySendCfg.setUseLogCatAppender(enabled);
		logNotifySendCfg.setUseFileAppender(enabled);
		
		logSecureCfg.setEncrypt(true);
		logSecureCfg.setUseLogCatAppender(enabled);
		logSecureCfg.setUseFileAppender(enabled);
		
		logNotifyAuditCfg.setUseLogCatAppender(true);
		logNotifyAuditCfg.setUseFileAppender(true);
		
		logFrameworkCfg.configure();
		logApplicationCfg.configure();
		logShellCfg.configure();
		logNotifySendCfg.configure();
		logSecureCfg.configure();
		logNotifyAuditCfg.configure();
		
		CTLog.getInstance().log("shell", Priority.INFO_INT, "Logging enabled: " + enabled);
	}
}
