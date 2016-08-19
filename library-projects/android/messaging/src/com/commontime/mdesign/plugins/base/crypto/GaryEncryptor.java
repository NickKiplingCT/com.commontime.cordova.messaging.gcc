package com.commontime.mdesign.plugins.base.crypto;

import java.io.UnsupportedEncodingException;

import javax.crypto.BadPaddingException;
import javax.crypto.Cipher;
import javax.crypto.IllegalBlockSizeException;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;

import org.apache.commons.codec.binary.Base64;
import org.apache.log4j.Priority;

import com.commontime.mdesign.plugins.base.CTLog;
import android.content.Context;

public class GaryEncryptor implements Encryptor {

	static final byte[] CTSecretKey = { (byte) 0xb4, 0x2a, 0x73, 0x73,
			(byte) 0xc7, (byte) 0xf1, 0x4c, (byte) 0xa3, (byte) 0x99, 0x09,
			0x5b, 0x06, (byte) 0xbe, (byte) 0xc9, (byte) 0xc6, 0x78 };
	static final byte[] CTInitVector = { (byte) 0xd0, 0x7b, 0x6b, (byte) 0xaf,
			(byte) 0x86, 0x5d, 0x47, 0x19, (byte) 0xaa, (byte) 0x80,
			(byte) 0xef, (byte) 0x87, (byte) 0xc7, 0x24, 0x19, 0xb };

	private Cipher encryptCipher;
	private Cipher decryptCipher;

	private static GaryEncryptor INSTANCE = null;
	
	public static GaryEncryptor get() {
		if( INSTANCE != null ) {
			return INSTANCE;
		} else {
			INSTANCE = new GaryEncryptor();
			INSTANCE.init();
			return INSTANCE;
		}
	}
	
	@Override
	public void init(Context ctx) {
		init();
	}
	
	public void init() {
		try {
			encryptCipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
			decryptCipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
			SecretKeySpec secretKey = new SecretKeySpec(CTSecretKey, "AES");
			IvParameterSpec ivSpec = new IvParameterSpec(CTInitVector);
			encryptCipher.init(Cipher.ENCRYPT_MODE, secretKey, ivSpec);
			decryptCipher.init(Cipher.DECRYPT_MODE, secretKey, ivSpec);
			return;
		} catch (Exception e) {
			e.printStackTrace();
			CTLog.getInstance().log("shell", Priority.WARN_INT,
					"Encrypt Preferences fail: " + e.getMessage());
		}
	}

	@Override
	public String encrypt(String strToEncrypt) {
		try {						
			byte[] data = strToEncrypt.getBytes("UTF-8");
			byte[] encData = encryptCipher.doFinal(data);
			String encString = new String(Base64.encodeBase64(encData), "UTF-8");
			return encString;
		} catch (UnsupportedEncodingException e) {			
			e.printStackTrace();
		} catch (IllegalBlockSizeException e) {			
			e.printStackTrace();
		} catch (BadPaddingException e) {			
			e.printStackTrace();
		}
		
		return strToEncrypt;
	}

	@Override
	public String decrypt(String strToDecrypt) {
		try {				
			String decryptedString = new String(decryptCipher.doFinal(Base64.decodeBase64(strToDecrypt.getBytes("UTF-8"))));			
			return decryptedString;
		} catch (IllegalBlockSizeException e) {
			e.printStackTrace();
		} catch (BadPaddingException e) {
			e.printStackTrace();
		} catch (UnsupportedEncodingException e) {
			e.printStackTrace();
		}

		return strToDecrypt;
	}

	@Override
	public String getFilename() {
		return "encrypted";
	}

	

}
