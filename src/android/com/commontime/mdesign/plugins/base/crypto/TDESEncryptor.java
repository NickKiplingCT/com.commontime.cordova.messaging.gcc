package com.commontime.mdesign.plugins.base.crypto;

import android.content.Context;

public class TDESEncryptor implements Encryptor {

	final static private String key = "2KeUWwUzkV5PtogQoIv2";

	private TripleDES tdes;

	public TDESEncryptor() {
		tdes = new TripleDES(key);
	}

	@Override
	public void init(Context ctx) {
	}

	@Override
	public synchronized String encrypt(String source) {				
		return tdes.encrypt(source);
	}

	@Override
	public synchronized String decrypt(String source) {
		return tdes.decrypt(source);
	}

	@Override
	public String getFilename() {
		return "tdes";
	}

}
