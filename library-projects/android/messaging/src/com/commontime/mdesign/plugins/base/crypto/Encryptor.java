package com.commontime.mdesign.plugins.base.crypto;

import android.content.Context;

public interface Encryptor {
	public void init(Context ctx);	
	public String encrypt(String source);
	public String decrypt(String source);
	public String getFilename();	
}
