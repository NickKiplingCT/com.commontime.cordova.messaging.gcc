package com.commontime.mdesign.plugins.base;

import org.apache.log4j.Layout;
import org.apache.log4j.PatternLayout;
import org.apache.log4j.spi.LoggingEvent;

import com.commontime.mdesign.plugins.base.crypto.GaryEncryptor;
import de.mindpipe.android.logging.log4j.LogCatAppender;

public class LogCatEncryptedAppender extends LogCatAppender {
		
	public LogCatEncryptedAppender(final Layout messageLayout) {
		super(messageLayout, new PatternLayout("%c"));		
	}

	@Override
	protected void append(final LoggingEvent le) {	
		String encrypted = "sec: " + GaryEncryptor.get().encrypt(le.getMessage().toString());
		LoggingEvent copy = new LoggingEvent(le.getFQNOfLoggerClass(), le.getLogger(), le.getTimeStamp(),
				le.getLevel(), encrypted, le.getThreadName(), le.getThrowableInformation(), le.getNDC(),
				le.getLocationInformation(), le.getProperties());
		super.append(copy);
	}
}
