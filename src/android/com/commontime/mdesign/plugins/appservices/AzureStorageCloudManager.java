package com.commontime.mdesign.plugins.appservices;

import android.content.Context;
import android.os.SystemClock;

import com.commontime.mdesign.plugins.base.CTLog;
import com.commontime.mdesign.plugins.base.Files;
import com.commontime.mdesign.plugins.notificationsbase.db.PushMessage;
import com.microsoft.azure.storage.RetryNoRetry;
import com.microsoft.azure.storage.StorageException;
import com.microsoft.azure.storage.blob.BlobRequestOptions;
import com.microsoft.azure.storage.blob.CloudBlockBlob;

import org.apache.commons.io.IOUtils;
import org.apache.commons.io.input.CountingInputStream;
import org.apache.log4j.Priority;
import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONTokener;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.net.URI;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class AzureStorageCloudManager {
	private static final String GET_SAS_TOKEN = "getsastoken";

	private static String storageConnectionString =
	        "DefaultEndpointsProtocol=http;"
	        + "AccountName=graham;"
	        + "AccountKey=tX0S6XyGjZf5uyvvJhcgSom4mISonDJpWJqA5CXD8TszLihp8T9x3rELoALQ/E+SDo3z/6EDthc6EL9O8idZWw==;";
	
	private final File receivedDir;
	private final File sendingDir;

	private File downloadFile;
	private String uploadFileId;

	private ZumoPushSystem system;

	public AzureStorageCloudManager(ZumoPushSystem zumoPushSystem, Context context) {
		receivedDir = Files.getReceivedFileDir(context);
		sendingDir = Files.getSendingFileDir(context);
		this.system = zumoPushSystem;
	}

	public synchronized String downloadFileFromCloud(final String id) throws AzureStorageException {
			
//		final AzureStorageException exception = new AzureStorageException();
//
//		ExecutorService es = Executors.newSingleThreadExecutor();
//
//		es.execute( new Runnable() {
//			@Override
//			public void run() {
//				try {
////					 Pair<CloudBlobContainer, String> pair = initAzureCloudStorage();
////					 CloudBlobContainer container = initAzureCloudStorage();
//
//					 downloadFile = File.createTempFile(FILE_PREFIX, FILE_SUFFIX, receivedDir);
//					 receivedDir.mkdirs();
//					 CloudBlockBlob blob = container.getBlockBlobReference(id);
//
//					 blob.downloadToFile(downloadFile.getAbsolutePath());
//
//				} catch (InvalidKeyException e) {
//					e.printStackTrace();
//					exception.initCause(e);
//				} catch (IOException e) {
//					e.printStackTrace();
//					exception.initCause(e);
//				} catch (URISyntaxException e) {
//					e.printStackTrace();
//					exception.initCause(e);
//				} catch (StorageException e) {
//					e.printStackTrace();
//					exception.initCause(e);
//				} catch (JSONException e) {
//					e.printStackTrace();
//					exception.initCause(e);
//				}
//			}
//		});
//
//		boolean success = false;
//		try {
//			es.shutdown();
//			success = es.awaitTermination(5, TimeUnit.MINUTES);
//		} catch (InterruptedException e) {
//			e.printStackTrace();
//			exception.initCause(e);
//		}
//
//		if( !success ) {
//			exception.initCause(new IOException("Azure cloud timed out downloading blob"));
//		}
//
//		if( exception.getCause() != null ) {
//			throw exception;
//		}
//
//		return receivedPath + downloadFile.getName();
		return null;
	}
	
	public synchronized String uploadFileToCloud(final PushMessage msg, final String path) throws AzureStorageException {
		
		// Check: 
		uploadFileId = system.getUploadTable().findUpload(msg.getId(), path);
		
		if( uploadFileId != null ) {
			CTLog.getInstance().log("shell", Priority.INFO_INT, "Upload of "+path+" aleady done.");
			return uploadFileId;
		}		
		
		final AzureStorageException exception = new AzureStorageException();		
		
		ExecutorService es = Executors.newSingleThreadExecutor();
		
		es.execute( new Runnable() {
			private boolean uploadingBlob;
			private int blobUploadPercentage;

			@Override
			public void run() {				
				try {								
					
					String ctx = null;
					String filePath = path;
					Object ctxObject = null;
					String gstId = UUID.randomUUID().toString();
					
					// pull apart the path if it contains #
					if( path.contains("#") ) {
						String[] parts = path.split("#");
						filePath = parts[0];
						ctx = parts[1];
						
						ctxObject = new JSONTokener(ctx).nextValue();
					}					
					
					CTLog.getInstance().log("shell", Priority.INFO_INT, "Requesting SAS token...");
					JSONObject body = new JSONObject();
					body.put("permission", "write");	
					body.put("reqId", msg.getId());
					body.put("gstId", gstId);
					body.putOpt("context", ctxObject);
					JSONObject response = system.syncSend("POST", GET_SAS_TOKEN, body);
					
					if( response == null ) {
						Exception e = new Exception();
						e.initCause(new GetSasTokenException());
						throw e;
					}
					
					String sasToken = response.getString("sasToken");
					String blobUri = response.getString("blobUri");

					final File file = new File(sendingDir, new File(filePath).getName());

					CTLog.getInstance().log("shell", Priority.INFO_INT, "Uploading...");
					final CountingInputStream cis = new CountingInputStream(new FileInputStream(file));
					
					uploadingBlob = true;
					blobUploadPercentage = 0;
					
					new Thread(new Runnable() {

						@Override
						public void run() {						
							while(uploadingBlob) {
								int newBlobUploadPercentage = (int) (100 * ((double) cis.getByteCount() / (double) file.length()));
								if( newBlobUploadPercentage > blobUploadPercentage ) {
									blobUploadPercentage = newBlobUploadPercentage;
									CTLog.getInstance().log("shell", Priority.INFO_INT, "Uploading blob: " + cis.getByteCount() + " (" + blobUploadPercentage + "%)");
								}
								SystemClock.sleep(200);
							}
						}
					}).start();
					
					CloudBlockBlob sasBlob = new CloudBlockBlob(URI.create(blobUri + "?" + sasToken));
					
					sasBlob.setStreamWriteSizeInBytes(256 * 1024);					
					BlobRequestOptions bro = new BlobRequestOptions();
					bro.setConcurrentRequestCount(1);
					bro.setRetryPolicyFactory(new RetryNoRetry());
					sasBlob.getServiceClient().setDefaultRequestOptions(bro);
					
					OutputStream os = sasBlob.openOutputStream();
					IOUtils.copy(cis, os);
					os.flush();
					os.close();
					
					// sasBlob.upload(cis, file.length());	
					String uri = sasBlob.getUri().toString();
					uploadingBlob = false;
					uploadFileId = uri;
					CTLog.getInstance().log("shell", Priority.INFO_INT, "Upload complete.");
					
					system.getUploadTable().uploadComplete( msg.getId(), path, uploadFileId );
					
				} catch (StorageException e) {
					e.printStackTrace();
					exception.initCause(e);
				} catch (IOException e) {
					e.printStackTrace();
					exception.initCause(e);
				} catch (JSONException e) {
					e.printStackTrace();
					exception.initCause(e);
				} catch (Exception e) {
					e.printStackTrace();
					if( exception.getCause() == null )
						exception.initCause(e);
				}
			}			
		});
		
		boolean success = false;
		try {
			es.shutdown();
			success = es.awaitTermination(5, TimeUnit.MINUTES);
		} catch (InterruptedException e) {
			exception.initCause(e);
		}
				
		if( !success ) {
			exception.initCause(new IOException("Azure cloud timed out uploading blob"));
		}
		
		if( exception.getCause() != null ) {
			throw exception;
		}
		
		return uploadFileId;
	}

	public void deleteLocalFile(String path) {
		File file = new File(path);
		file.delete();
	}

	public class GetSasTokenException extends Throwable {
	}
}
