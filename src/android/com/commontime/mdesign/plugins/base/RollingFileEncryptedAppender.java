package com.commontime.mdesign.plugins.base;

import java.io.IOException;

import org.apache.log4j.Layout;
import org.apache.log4j.RollingFileAppender;
import org.apache.log4j.spi.LoggingEvent;

import com.commontime.mdesign.plugins.base.crypto.GaryEncryptor;

public class RollingFileEncryptedAppender extends RollingFileAppender {
	
	public RollingFileEncryptedAppender(final Layout messageLayout, final String filename) throws IOException {
		super(messageLayout, filename);
	}

	@Override
	public void append(final LoggingEvent le) {	
		String encrypted = "sec: " + GaryEncryptor.get().encrypt(le.getMessage().toString());
		LoggingEvent copy = new LoggingEvent(le.getFQNOfLoggerClass(), le.getLogger(), le.getTimeStamp(),
				le.getLevel(), encrypted, le.getThreadName(), le.getThrowableInformation(), le.getNDC(),
				le.getLocationInformation(), le.getProperties());
		super.append(copy);
	}
	
}

