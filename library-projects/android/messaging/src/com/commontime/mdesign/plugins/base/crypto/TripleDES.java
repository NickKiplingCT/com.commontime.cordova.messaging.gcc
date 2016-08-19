package com.commontime.mdesign.plugins.base.crypto;

import android.util.Base64;

import java.io.UnsupportedEncodingException;
import java.security.InvalidKeyException;
import java.security.NoSuchAlgorithmException;
import java.security.spec.InvalidKeySpecException;
import java.security.spec.KeySpec;

import javax.crypto.BadPaddingException;
import javax.crypto.Cipher;
import javax.crypto.IllegalBlockSizeException;
import javax.crypto.NoSuchPaddingException;
import javax.crypto.SecretKey;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.DESedeKeySpec;

public class TripleDES {

	private static final String UNICODE_FORMAT = "UTF8";
	public static final String DESEDE_ENCRYPTION_SCHEME = "DESede";
	private KeySpec ks;
	private SecretKeyFactory skf;
	private Cipher cipher;
	byte[] arrayBytes;
	private String myEncryptionKey;
	private String myEncryptionScheme;
	SecretKey key;

	public TripleDES(String xKey) {
	
		try {
			if( xKey == null || xKey.isEmpty() )
				myEncryptionKey = xKey;
			else
				myEncryptionKey = "GrahamGrahamGrahamGraham";
			myEncryptionScheme = DESEDE_ENCRYPTION_SCHEME;
			arrayBytes = myEncryptionKey.getBytes(UNICODE_FORMAT);
			ks = new DESedeKeySpec(arrayBytes);
			skf = SecretKeyFactory.getInstance(myEncryptionScheme);
			cipher = Cipher.getInstance(myEncryptionScheme);			
			key = skf.generateSecret(ks);
		} catch (InvalidKeyException e) {			
			e.printStackTrace();
		} catch (UnsupportedEncodingException e) {			
			e.printStackTrace();
		} catch (NoSuchAlgorithmException e) {			
			e.printStackTrace();
		} catch (NoSuchPaddingException e) {			
			e.printStackTrace();
		} catch (InvalidKeySpecException e) {			
			e.printStackTrace();
		} catch (Exception e) {			
			e.printStackTrace();
		}		
	}
	
	public String encrypt(String unencryptedString) {
		try {
			String encryptedString = null;
			cipher.init(Cipher.ENCRYPT_MODE, key);
			byte[] plainText = unencryptedString.getBytes(UNICODE_FORMAT);
			byte[] encryptedText = cipher.doFinal(plainText);
			encryptedString = new String(Base64.encode(encryptedText, Base64.NO_WRAP));
			return encryptedString;
		} catch (InvalidKeyException e) {			
			e.printStackTrace();
			return "UnableToEncrypt";
		} catch (UnsupportedEncodingException e) {			
			e.printStackTrace();
			return "UnableToEncrypt";
		} catch (IllegalBlockSizeException e) {			
			e.printStackTrace();
			return "UnableToEncrypt";
		} catch (BadPaddingException e) {			
			e.printStackTrace();
			return "UnableToEncrypt";
		} catch (Exception e) {			
			e.printStackTrace();
			return "UnableToEncrypt";
		}
	}

	public String decrypt(String encryptedString) {
		String decryptedText=null;
		try {
			cipher.init(Cipher.DECRYPT_MODE, key);
			byte[] encryptedText = Base64.decode(encryptedString, Base64.NO_WRAP);
			byte[] plainText = cipher.doFinal(encryptedText);
			decryptedText= new String(plainText);
		} catch (Exception e) {
			e.printStackTrace();
			return "UnableToDecrypt";
		}
		return decryptedText;
	}

}
