package com.commontime.mdesign.plugins.base.crypto;

import android.content.Context;

public class NoEncryptor implements Encryptor {
	
	@Override
	public void init(Context ctx) {
	}

	@Override
	public synchronized String encrypt(String source) {
		return source;
	}

	@Override
	public synchronized String decrypt(String source) {
		return source;
	}

	@Override
	public String getFilename() {
		return "no";
	}

}
