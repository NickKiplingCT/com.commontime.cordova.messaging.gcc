package com.commontime.mdesign.plugins.base.crypto;

import android.content.Context;
import android.os.Build;

import com.commontime.mdesign.plugins.base.Prefs;

public class EncryptorFactory {
		
	public static Encryptor createInstance(Context ctx) {
		return new TDESEncryptor();
		
//		String enc = Prefs.getOld().getString("encryptor", "");		
//		boolean sec = Prefs.getOld().getBoolean("secure", false);
//		boolean aes = Prefs.getOld().getBoolean("AES", false);
//				
//		// This is a completely fresh start
//		if( enc.isEmpty() && (!sec) ) {
//			Encryptor e = new NoEncryptor();
//			Prefs.getOld().edit().putString("encryptor", e.getFilename()).commit();
//			return e;
//		}
//		
//		// We need to upgrade from RSA or Gary
//		if( enc.isEmpty() && sec ) {
//			if( aes ) {
//				EncryptionSwitcher.create(ctx).switchEncryptor(new GaryEncryptor(), new NoEncryptor());
//				return createInstance(ctx);
//			} else {
//				EncryptionSwitcher.create(ctx).switchEncryptor(new RSAKeyEncryptor(), new Salted());
//				return createInstance(ctx);
//			}
//		}
//		
//		if( enc.equals("saltedAES") ) {
//			return new NoEncryptor();
//		}
//		
//		throw new RuntimeException("Encryptor not found");
	}
	
	private static boolean useAES() {
		boolean oldDevice = !deviceSupportsRSA();
		boolean forceAES = Prefs.getOld().getBoolean("AES", false);
		return oldDevice || forceAES;
	}
	
	public static boolean deviceSupportsRSA() {
		return Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2;
	}
}