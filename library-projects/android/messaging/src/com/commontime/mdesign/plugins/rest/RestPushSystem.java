package com.commontime.mdesign.plugins.rest;

import android.net.Uri;
import android.util.Base64;
import android.util.Base64InputStream;

import com.commontime.mdesign.plugins.base.Files;
import com.commontime.mdesign.plugins.base.Utils;
import com.commontime.mdesign.plugins.notificationsbase.PushEngine;
import com.commontime.mdesign.plugins.notificationsbase.PushSystem;
import com.commontime.mdesign.plugins.notificationsbase.SingleCheckObserver;
import com.commontime.mdesign.plugins.notificationsbase.db.DBInterface;
import com.commontime.mdesign.plugins.notificationsbase.db.PushMessage;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.cordova.CordovaResourceApi;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.Calendar;
import java.util.Date;
import java.util.Iterator;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import okhttp3.Headers;
import okhttp3.HttpUrl;
import okhttp3.MediaType;
import okhttp3.MultipartBody;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import okio.BufferedSink;
import okio.Okio;

/**
 * Created by graham on 21/06/16.
 */
public class RestPushSystem extends PushSystem {

    static final String REST_PROVIDER = "rest";
    private static final String URL = "url";
    private static final String METHOD = "method";
    private static final String DATA = "data";
    private static final String PARAMS = "params";
    private static final String HEADERS = "headers";
    private static final String UPLOAD_AS_FILE = "uploadAsFile";
    private static final String BASE64_ENCODE = "base64encode";
    private static final String DOWNLOAD_AS_FILE = "downloadAsFile";
    private static final String UPLOAD_AS_MULTIPART_FORM = "uploadAsMultipartForm";
    private static final String FORM_PART_NAME = "formPartName";
    private static final String FORM_PART_FILENAME = "formPartFilename";

    private static final String GET_METHOD = "GET";
    private static final String POST_METHOD = "POST";
    private static final String PUT_METHOD = "PUT";
    private static final String PATCH_METHOD = "PATCH";
    private static final String CONFIG = "config";
    private static final String STATUS = "status";
    private static final String STATUS_TEXT = "statusText";
    private static final String CONTENT_TYPE = "Content-Type";
    private static final String APPLICATION_JSON = "application/json";
    private static final String FILEREF = "fileref";
    private static final String FILEREF1 = "#fileref:";


    public RestPushSystem(PushEngine engine) {
        super(engine);
    }

    @Override
    public void stop() {

    }

    @Override
    public void subscribeChannel(String channel) {

    }

    @Override
    public void unsubscribeChannel(String channel) {

    }

    @Override
    public void prepareMessage(final PushMessage msg, CordovaResourceApi cordovaResourceApi) throws JSONException {
        JSONObject content = msg.getJSONContent();
        boolean uploadAsFile = content.optBoolean(UPLOAD_AS_FILE, false);

        if( uploadAsFile ) {
            File original = null;
            if( content.getString(DATA).toLowerCase().startsWith("file") ) {
                original = new File(content.getString(DATA).substring(7));
            } else if( content.getString(DATA).toLowerCase().startsWith("cdvfile") ) {
                original = new File( cordovaResourceApi.remapUri(Uri.parse(content.getString(DATA))).toString().substring(5) );
            } else if( content.getString(DATA).toLowerCase().startsWith("/") ) {
                original = new File(content.getString(DATA));
            }

            if( original != null ) {
                File cacheDir = pushEngine.getContext().getCacheDir();
                File restDir = new File(cacheDir, REST_PROVIDER);
                File msgDir = new File(restDir, msg.getId());
                msgDir.mkdirs();

                try {
                    FileUtils.copyFileToDirectory(original, msgDir);
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
    }

    @Override
    public Future<SendResult> sendMessage(final PushMessage msg) {

        final ExecutorService service = Executors.newSingleThreadScheduledExecutor();

        return service.submit(new Callable<SendResult>() {

            @Override
            public SendResult call() throws Exception {

                try {
                    OkHttpClient client = new OkHttpClient();
                    Request.Builder requestBuilder = new Request.Builder();

                    JSONObject content = msg.getJSONContent();
                    HttpUrl.Builder urlBuilder = HttpUrl.parse(content.getString(URL)).newBuilder();

                    JSONObject params = content.optJSONObject(PARAMS) != null ? content.optJSONObject(PARAMS) : new JSONObject();
                    Iterator<String> paramsIter = params.keys();
                    while (paramsIter.hasNext()) {
                        String key = paramsIter.next();
                        String value = params.getString(key);
                        urlBuilder.addQueryParameter(key, value);
                    }
                    requestBuilder.url(urlBuilder.build());

                    JSONObject headers = content.optJSONObject(HEADERS) != null ? content.getJSONObject(HEADERS) : new JSONObject();
                    Iterator<String> headersIter = headers.keys();
                    while (headersIter.hasNext()) {
                        String key = headersIter.next();
                        String value = headers.getString(key);
                        requestBuilder.addHeader(key, value);
                    }

                    boolean uploadAsFile = content.optBoolean(UPLOAD_AS_FILE, false);
                    boolean base64encode = content.optBoolean(BASE64_ENCODE, false);
                    boolean downloadAsFile = content.optBoolean(DOWNLOAD_AS_FILE, false);
                    boolean uploadAsMultipartForm = content.optBoolean(UPLOAD_AS_MULTIPART_FORM, false);

                    String formPartName = content.optString(FORM_PART_NAME);
                    String formPartFilename = content.optString(FORM_PART_FILENAME);

                    String method = content.optString(METHOD, GET_METHOD);

                    if (method.equals(POST_METHOD) || method.equals(PUT_METHOD) || method.equals(PATCH_METHOD)) {
                        String contentType = headers.getString(CONTENT_TYPE);
                        RequestBody rBody = null;
                        if (contentType.toLowerCase().equals(APPLICATION_JSON)) {
                            rBody = RequestBody.create(MediaType.parse(contentType), content.getString(DATA).toString());
                        } else if (contentType.toLowerCase().startsWith("text/")) {
                            rBody = RequestBody.create(MediaType.parse(contentType), content.getString(DATA).toString());
                        } else {
                            if( uploadAsFile ) {
                                if( uploadAsMultipartForm ) {
                                    rBody = new MultipartBody.Builder()
                                            .setType(MultipartBody.FORM)
                                            .addPart(
                                                    Headers.of("Content-Disposition", "form-data; name=\""+ formPartName +"\"; filename=\""+formPartFilename+"\""),
                                                    RequestBody.create(MediaType.parse(contentType),
                                                            new File(pushEngine.getContext().getCacheDir(), REST_PROVIDER + "/" + msg.getId() + "/" + content.getString(DATA).substring(content.getString(DATA).lastIndexOf("/")))))
                                            .build();
                                } else {
                                    rBody = RequestBody.create(MediaType.parse(contentType), new File(pushEngine.getContext().getCacheDir(), msg.getId() + "/" + content.getString(DATA).substring(content.getString(DATA).lastIndexOf("/"))));
                                }
                            } else {
                                String data = content.getString(DATA);
                                File outputFile = File.createTempFile("temp", "file", pushEngine.getContext().getCacheDir());
                                FileOutputStream fos = new FileOutputStream(outputFile);
                                Base64InputStream is = new Base64InputStream(IOUtils.toInputStream(content.getString(DATA)), Base64.DEFAULT);
                                IOUtils.copy(is, fos);
                                fos.flush();
                                fos.close();
                                rBody = RequestBody.create(MediaType.parse(contentType), outputFile);
                            }
                        }

                        requestBuilder.method(method, rBody);
                    } else {
                        requestBuilder.method(method, null);
                    }

                    Request request = requestBuilder.build();
                    Response response = client.newCall(request).execute();
                    JSONObject responseContent = new JSONObject();

                    responseContent.put(STATUS, response.code());
                    responseContent.put(CONFIG, msg.getJSONContent());
                    responseContent.put(STATUS_TEXT, response.message());
                    JSONObject responseHeaders = new JSONObject();
                    for (String headerName : response.headers().names()) {
                        responseHeaders.put(headerName, response.headers().get(headerName));
                    }
                    responseContent.put(HEADERS, responseHeaders);

                    String responseType = response.header("Content-Type");
                    if( downloadAsFile ) {
                        File rootFiles = Files.getRootDir(pushEngine.getContext());
                        File rcvFiles = Files.getReceivedFileDir(pushEngine.getContext());
                        rcvFiles.mkdirs();
                        File outputFile = new File( rcvFiles, UUID.randomUUID().toString() );
                        BufferedSink sink = Okio.buffer(Okio.sink(outputFile));
                        sink.writeAll(response.body().source());
                        sink.close();
                        responseContent.put(DATA, outputFile.getAbsolutePath());

                        String file = rcvFiles.getAbsolutePath().substring(rootFiles.getAbsolutePath().length()) + "/" + outputFile.getName();
                        responseContent.put(FILEREF, FILEREF1 + file);
                    } else if( responseType.toLowerCase().contains("application/json")) {
                        responseContent.put(DATA, new JSONObject(response.body().string()));
                    } else {
                        responseContent.put(DATA, response.body().string());
                    }
                    PushMessage responseMessage = PushMessage.createNewPushMessage(msg.getChannel(), msg.getSubchannel(), "");
                    responseMessage.setProvider(REST_PROVIDER);

                    Calendar c = Calendar.getInstance();
                    c.setTime(new Date());
                    c.add(Calendar.YEAR, 100);
                    responseMessage.setExpiry(c.getTimeInMillis());

                    responseMessage.setContent(responseContent.toString());
                    responseMessage.setProvider(REST_PROVIDER);

                    observer.messageReceived(responseMessage);

                    // Clean up
                    File cacheDir = pushEngine.getContext().getCacheDir();
                    File restDir = new File(cacheDir, REST_PROVIDER);
                    File msgDir = new File(restDir, msg.getId());
                    Utils.DeleteRecursive(msgDir);

                    return SendResult.Success;

                } catch (JSONException e) {
                    e.printStackTrace();
                    return SendResult.FailedDoNotRetry;
                } catch (IOException e) {
                    e.printStackTrace();
                    return SendResult.Failed;
                } catch (Exception e) {
                    return SendResult.FailedDoNotRetry;
                }
            }
        });
    }

    @Override
    public void start(DBInterface db) {

    }

    @Override
    public void setNetworkConnected(boolean connected) {

    }

    @Override
    public String getName() {
        return REST_PROVIDER;
    }

    @Override
    public void configure(String config) {

    }

    @Override
    public void checkOnce(DBInterface notificationsDB, SingleCheckObserver singleCheckObserver) {
        // Not needed
    }
}