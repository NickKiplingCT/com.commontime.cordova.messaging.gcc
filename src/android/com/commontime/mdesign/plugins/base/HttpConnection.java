package com.commontime.mdesign.plugins.base;

import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.MalformedURLException;
import java.net.Socket;
import java.net.URL;
import java.net.UnknownHostException;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;

import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

public class HttpConnection {

	private final static HttpConnection INSTANCE = new HttpConnection();
	private static SSLContext sslContext;
	
	private HttpConnection() {}
	
	public HttpURLConnection get(String url) throws KeyManagementException, MalformedURLException, NoSuchAlgorithmException, IOException {
		return INSTANCE.getConnection(url);
	}
	
	public static HttpURLConnection create(String url) throws KeyManagementException, MalformedURLException, NoSuchAlgorithmException, IOException {
		return new HttpConnection().getConnection(url);
	}
	
	private HttpURLConnection getConnection(final String url)
			throws MalformedURLException, NoSuchAlgorithmException,
			KeyManagementException, IOException {
		HttpURLConnection urlConnection = null;
		URL urlObj = new URL(url);

		if (Prefs.getUseSSL()) {
			if( sslContext == null ) {
				try {
					sslContext = SSLContext.getInstance("TLSv1.2");
				} catch (NoSuchAlgorithmException e) {
					sslContext = SSLContext.getInstance("TLS");
				}
				
				sslContext.init(null, null, null);
			}
			HttpsURLConnection sslConnection = (HttpsURLConnection) urlObj.openConnection();
			
			if( android.os.Build.VERSION.SDK_INT >= 19) {
				sslConnection.setSSLSocketFactory(new SSLSocketFactory() {
					
					@Override
					public Socket createSocket(InetAddress address, int port,
							InetAddress localAddress, int localPort) throws IOException {
						SSLSocket socket = (SSLSocket) sslContext.getSocketFactory().createSocket(address, port, localAddress, localPort);
						socket.setEnabledProtocols(new String[] {"TLSv1.2"});
						return socket;
					}
					
					@Override
					public Socket createSocket(String host, int port, InetAddress localHost,
							int localPort) throws IOException, UnknownHostException {
						SSLSocket socket = (SSLSocket) sslContext.getSocketFactory().createSocket(host, port, localHost, localPort);
						socket.setEnabledProtocols(new String[] {"TLSv1.2"});
						return socket;
					}
					
					@Override
					public Socket createSocket(InetAddress host, int port) throws IOException {
						SSLSocket socket = (SSLSocket) sslContext.getSocketFactory().createSocket(host, port);
						socket.setEnabledProtocols(new String[] {"TLSv1.2"});
						return socket;
					}
					
					@Override
					public Socket createSocket(String host, int port) throws IOException,
							UnknownHostException {
						SSLSocket socket = (SSLSocket) sslContext.getSocketFactory().createSocket(host, port);
						socket.setEnabledProtocols(new String[] {"TLSv1.2"});
						return socket;
					}
					
					@Override
					public String[] getSupportedCipherSuites() {
						return sslContext.getSocketFactory().getSupportedCipherSuites();
					}
					
					@Override
					public String[] getDefaultCipherSuites() {
						return sslContext.getSocketFactory().getDefaultCipherSuites();
					}
					
					@Override
					public Socket createSocket(Socket s, String host, int port,
							boolean autoClose) throws IOException {
						SSLSocket socket = (SSLSocket) sslContext.getSocketFactory().createSocket(s, host, port, autoClose);
						socket.setEnabledProtocols(new String[] {"TLSv1.2"});
						return socket;
					}
				});
			}			
						
			urlConnection = sslConnection;
		} else {
			urlConnection = (HttpURLConnection) urlObj.openConnection();
		}
		return urlConnection;
	}

	
	
}
