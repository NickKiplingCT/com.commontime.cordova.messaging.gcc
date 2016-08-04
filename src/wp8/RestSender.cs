using System;
using System.Collections.Generic;
using System.IO;
using System.IO.IsolatedStorage;
using System.Net;
using System.Text;
using System.Threading;

using CommonTime.Logging;
using CommonTime.Notification;

using WPCordovaClassLib.Cordova.Commands;

using Newtonsoft.Json.Linq;

namespace CommonTime.Notification.Rest
{
  public sealed class RestSender : MessageSender
  {
    private const string Base64EncodeRequestContentKey = "base64encode";
    private const string ConfigKey = "config";
    private const string DataKey = "data";
    private const string DownloadAsFileKey = "downloadAsFile";
    private const string FormPartNameKey = "formPartName";
    private const string FormPartFilenameKey = "formPartFilename";
    private const string HeadersKey = "headers";
    private const string InternalFileReferenceKey = "internalFileReference";
    private const string MethodKey = "method";
    private const string QueryParametersKey = "params";
    private const string StatusKey = "status";
    private const string StatusTextKey = "statusText";
    private const string UploadAsFileKey = "uploadAsFile";
    private const string UploadAsMultipartFormKey = "uploadAsMultipartForm";
    private const string UriKey = "url";

    #if DEBUG
    private readonly static TimeSpan RequestTimeout = TimeSpan.FromMinutes(1);
#else
    private readonly static TimeSpan RequestTimeout = TimeSpan.FromMinutes(5);
#endif

    private readonly ContentManager contentManager;

    private Uri uri;
    private string method;
    private JObject headers;
    private bool downloadAsFile;
    private bool uploadAsFile;
    private bool base64EncodeRequestContent;
    private bool uploadAsMultipartForm;
    private string formPartName;
    private string formPartFilename;
    private string formPartContentType;

    private byte[] requestData;
    private string requestPath;
    private string boundary;

    private HttpWebRequest request;
    private Timer timeoutTimer;

    public RestSender(RestProvider provider, Logger logger, IMessage message)
      : base(provider, logger, message)
    {
      contentManager = new ContentManager(logger);

      ParseContent();
    }

    private RestProvider RestProvider
    {
      get
      {
        return (RestProvider) base.Provider;
      }
    }

    public override string ToString()
    {
      return string.Format("REST sender for {0}", Message);
    }

    private void ParseContent()
    {
      JObject content = (JObject) Message.Content;

      method = (string) content[MethodKey];
      headers = (JObject) content[HeadersKey];

      JToken downloadAsFileToken = content[DownloadAsFileKey];

      if (downloadAsFileToken != null)
      {
        downloadAsFile = (bool) downloadAsFileToken;
      }

      JToken uploadAsFileToken = content[UploadAsFileKey];

      if (uploadAsFileToken != null)
      {
        uploadAsFile = (bool) uploadAsFileToken;
      }

      JToken base64EncodeRequestContentToken = content[Base64EncodeRequestContentKey];

      if (base64EncodeRequestContentToken != null)
      {
        base64EncodeRequestContent = (bool) base64EncodeRequestContentToken;
      }

      JToken uploadAsMultipartFormToken = content[UploadAsMultipartFormKey];

      if (uploadAsMultipartFormToken != null)
      {
        uploadAsMultipartForm = (bool) uploadAsMultipartFormToken;
        boundary = Guid.NewGuid().ToString();
      }

      JToken formPartNameToken = content[FormPartNameKey];

      if (formPartNameToken != null)
      {
        formPartName = (string) formPartNameToken;
      }

      JToken formPartFilenameToken = content[FormPartFilenameKey];

      if (formPartFilenameToken != null)
      {
        formPartFilename = (string) formPartFilenameToken;
      }

      SetData();
      SetUri();

      if (method == null)
      {
        method = requestData == null && requestPath == null ? "GET" : "POST";
      }
    }

    private void SetData()
    {
      JObject content = (JObject) Message.Content;
      string internalFileReference = (string) content[InternalFileReferenceKey];

      if (internalFileReference != null)
      {
        requestPath = FileReference.Parse(internalFileReference).Path;

        return;
      }

      JToken data = content[DataKey];

      if (data == null || data.Type == JTokenType.Null)
      {
        return;
      }

      if (uploadAsFile)
      {
        string sourcePath = (string) data;

        if (sourcePath.StartsWith("file://"))
        {
          sourcePath = (new Uri(sourcePath)).AbsolutePath;        
        }

        requestPath = contentManager.CreateUniqueFilename(Path.GetExtension(sourcePath));

        using (IsolatedStorageFile userStore = IsolatedStorageFile.GetUserStoreForApplication())
        {
          userStore.CopyFile(sourcePath, requestPath);        
        }

        Message.Content[InternalFileReferenceKey] = (new FileReference(requestPath, null)).ToString();
        MessageStore.Outbox.Update(Message);
      }
      else
      {
        string contentType = GetHeader("content-type");

        if (contentType != null && contentType == "application/json")
        {
          requestData = Encoding.UTF8.GetBytes((string) data.ToString());
        }
        else if (contentType != null && contentType.StartsWith("text/"))
        {
          requestData = Encoding.UTF8.GetBytes((string) data);
        }
        else
        {
          requestData = Convert.FromBase64String((string) data);
        }
      }    
    }

    private void SetUri()
    {
      JObject content = (JObject) Message.Content;
      string uriString = (string) Message.Content[UriKey];
      JObject queryParameters = (JObject) Message.Content[QueryParametersKey];

      if (queryParameters == null)
      {
        uri = new Uri(uriString);
      }
      else
      {
        char separator = '?';
        StringBuilder builder = new StringBuilder(uriString);

        foreach (KeyValuePair<string, JToken> pair in queryParameters)
        {
          builder.Append(separator);
          builder.Append(HttpUtility.UrlEncode(pair.Key));
          builder.Append('=');
          builder.Append(HttpUtility.UrlEncode((string) pair.Value));

          separator = '&';
        }

        uri = new Uri(builder.ToString());
      }
    }

    private string GetHeader(string key)
    {
      if (headers != null)
      {
        foreach (KeyValuePair<string, JToken> pair in headers)
        {
          if (pair.Key.Equals(key, StringComparison.InvariantCultureIgnoreCase))
          {
            return (string) pair.Value;
          }
        }
      }

      return null;
    }

    internal override bool Stop()
    {
      if (IsRunning)
      {
        CancelTimeoutTimer();

        if (request != null)
        {
          request.Abort();
          request = null;
        }

        return base.Stop();
      }
      else
      {
        return false;
      }
    }

    private void StartTimeoutTimer()
    {
      if (Logger != null)
      {
        Logger.TraceFormat("{0} will timeout in {1}", this, RequestTimeout);
      }

      timeoutTimer = new Timer(OnRequestTimeout, null, RequestTimeout, TimeSpan.FromMilliseconds(-1));
    }

    private void CancelTimeoutTimer()
    {
      if (timeoutTimer != null)
      {
        if (Logger != null)
        {
          Logger.DebugFormat("Cancelling timer on {0}", this);
        }

        timeoutTimer.Change(TimeSpan.FromMilliseconds(-1), TimeSpan.FromMilliseconds(-1));
        timeoutTimer.Dispose();
        timeoutTimer = null;
      }
    }

    private void OnRequestTimeout(object obj)
    {
      if (request != null)
      {
        request.Abort();
        request = null;
      }

      StartRetryTimer(RequestTimeout);
    }

    internal override bool Start()
    {
      if (base.Start())
      {
        BeginSend();

        return true;
      }
      else
      {
        return false;
      }
    }

    private void BeginSend()
    {
      try
      {
        request = (HttpWebRequest) WebRequest.Create(uri);

        request.Method = method;
        request.CookieContainer = RestProvider.CookieContainer;
        request.Credentials = RestProvider.Credentials;
        request.Headers["Accept-Charset"] = "utf-8";

        if (headers != null)
        {
          foreach (KeyValuePair<string, JToken> pair in headers)
          {
            if (pair.Key.Equals("Content-Type", StringComparison.InvariantCultureIgnoreCase))
            {
              if (uploadAsMultipartForm)
              {
                formPartContentType = (string) pair.Value;
              }
              else
              {
                request.ContentType = (string) pair.Value;
              }
            }
            else if (pair.Key.Equals("Accept", StringComparison.InvariantCultureIgnoreCase))
            {
              request.Accept = (string) pair.Value;
            }
            else
            {
              request.Headers[pair.Key] = (string) pair.Value;
            }
          }
        }

        if (uploadAsMultipartForm)
        {
          request.ContentType = string.Format("multipart/form-data; boundary={0}", boundary);
        }

        Logger.DebugFormat("Will send {0} request to {1}", method, uri);

        if (requestPath == null && requestData == null)
        {
          request.BeginGetResponse(OnGetResponse, request);
          StartTimeoutTimer();
        }
        else
        {
          request.BeginGetRequestStream(EndCreateRequest, request);
        }
      }
      catch (Exception e)
      {
        PostResponse(0, e.Message, null, null, null, null);

        OnRequestFailed(e.Message, RetryStrategy.Never);
      }
    }

    private void EndCreateRequest(IAsyncResult result)
    {
      try
      {
        using (Stream outputStream = request.EndGetRequestStream(result))
        {
          if (requestPath == null)
          {
            if (uploadAsMultipartForm)
            {
              WriteMultipartForm(outputStream);
            }
            else
            {
              WriteContent(outputStream);
            }
          }
          else
          {
            using (IsolatedStorageFile userStore = IsolatedStorageFile.GetUserStoreForApplication())
            {
              using (Stream inputStream = userStore.OpenFile(requestPath, FileMode.Open, FileAccess.Read))
              {
                if (uploadAsMultipartForm)
                {
                  WriteMultipartForm(inputStream, outputStream);
                }
                else
                {
                  WriteContent(inputStream, outputStream);
                }
              }
            }
          }
        }

        request.BeginGetResponse(OnGetResponse, result.AsyncState);
        StartTimeoutTimer();
      }
      catch (Exception e)
      {
        CancelTimeoutTimer();

        OnRequestFailed(e.Message, RetryStrategy.Never);
      }
    }

    private void WriteContent(Stream outputStream)
    {
      if (base64EncodeRequestContent)
      {
        byte[] base64Data = Encoding.UTF8.GetBytes(Convert.ToBase64String(requestData));

        outputStream.Write(base64Data, 0, base64Data.Length);
      }
      else
      {
        outputStream.Write(requestData, 0, requestData.Length);
      }
    }

    private void WriteContent(Stream inputStream, Stream outputStream)
    {
      if (base64EncodeRequestContent)
      {
        // TODO: find a way of doing this that doesn't eat up so much memory
        using (MemoryStream memoryStream = new MemoryStream())
        {
          inputStream.CopyTo(memoryStream);

          byte[] base64Data = Encoding.UTF8.GetBytes(Convert.ToBase64String(memoryStream.ToArray()));

          outputStream.Write(base64Data, 0, base64Data.Length);
        }
      }
      else
      {
        inputStream.CopyTo(outputStream);
      }
    }

    private string GetContentDisposition()
    {
      StringBuilder builder = new StringBuilder("Content-Disposition: form-data");

      if (!string.IsNullOrEmpty(formPartName))
      {
        builder.AppendFormat("; name=\"{0}\"", formPartName);
      }

      if (!string.IsNullOrEmpty(formPartFilename))
      {
        builder.AppendFormat("; filename=\"{0}\"", formPartFilename);
      }

      return builder.ToString();
    }

    private string GetMultipartHeader()
    {
      StringBuilder builder = new StringBuilder();

      builder.AppendFormat("--{0}\r\n", boundary);
      builder.AppendFormat("{0}\r\n", GetContentDisposition());

      if (string.IsNullOrEmpty(formPartContentType))
      {
        if (!string.IsNullOrEmpty(formPartFilename))
        {
          builder.AppendFormat("Content-Type: {0}\r\n", MimeTypeMapper.GetMimeType(formPartFilename));
        }
      }
      else
      {
        builder.AppendFormat("Content-Type: {0}\r\n", formPartContentType);
      }

      builder.AppendFormat("\r\n");

      return builder.ToString();
    }

    private string GetMultipartFooter()
    {
      return string.Format("\r\n--{0}--\r\n", boundary);
    }

    private void WriteMultipartForm(Stream outputStream)
    {
      {
        byte[] header = Encoding.UTF8.GetBytes(GetMultipartHeader());

        outputStream.Write(header, 0, header.Length);
      }

      {
        if (base64EncodeRequestContent)
        {
          string base64String = Convert.ToBase64String(requestData);
          byte[] base64Data = Encoding.UTF8.GetBytes(base64String);

          outputStream.Write(base64Data, 0, base64Data.Length);
        }
        else
        {
          outputStream.Write(requestData, 0, requestData.Length);
        }
      }

      {
        byte[] footer = Encoding.UTF8.GetBytes(GetMultipartFooter());

        outputStream.Write(footer, 0, footer.Length);
      }
    }

    private void WriteMultipartForm(Stream inputStream, Stream outputStream)
    {
      {
        byte[] header = Encoding.UTF8.GetBytes(GetMultipartHeader());

        outputStream.Write(header, 0, header.Length);
      }

      if (base64EncodeRequestContent)
      {
        using (MemoryStream memoryStream = new MemoryStream())
        {
          inputStream.CopyTo(memoryStream);

          byte[] base64Data = Encoding.UTF8.GetBytes(Convert.ToBase64String(memoryStream.ToArray()));

          outputStream.Write(base64Data, 0, base64Data.Length);
        }
      }
      else
      {
        inputStream.CopyTo(outputStream);
      }

      {
        byte[] footer = Encoding.UTF8.GetBytes(GetMultipartFooter());

        outputStream.Write(footer, 0, footer.Length);
      }
    }

    private void OnGetResponse(IAsyncResult result)
    {
      HttpWebResponse response = null;

      try
      {
        CancelTimeoutTimer();

        response = (HttpWebResponse) request.EndGetResponse(result);

        if (response == null)
        {
          OnRequestFailed("Cannot send message: no response.", RetryStrategy.AfterDefaultPeriod);
        }
        else
        {
          byte[] data = null;
          string path = null;

          if (response.ContentLength > 0 || response.Headers[HttpRequestHeader.TransferEncoding] == "chunked")
          {
            Stream inputStream = response.GetResponseStream();

            if (downloadAsFile)
            {
              path = contentManager.CreateUniqueFilename(".bin");

              using (IsolatedStorageFile userStore = IsolatedStorageFile.GetUserStoreForApplication())
              {
                using (IsolatedStorageFileStream outputStream = userStore.OpenFile(path, FileMode.Create, FileAccess.Write))
                {
                  inputStream.CopyTo(outputStream);
                }
              }
            }
            else
            {
              using (MemoryStream outputStream = new MemoryStream())
              {
                inputStream.CopyTo(outputStream);
                data = outputStream.ToArray();
              }
            }
          }

          if (200 <= (int) response.StatusCode && (int) response.StatusCode < 300)
          {
            PostResponse(response.StatusCode, response.StatusDescription, response.Headers, response.ContentType, data, path);

            OnSent();
          }
          else
          {
            PostResponse(response.StatusCode, response.StatusDescription, response.Headers, response.ContentType, data, path);

            if (string.IsNullOrEmpty(response.StatusDescription))
            {
              OnRequestFailed(string.Format("Cannot send message: {0}.", response.StatusCode), RetryStrategy.Never);
            }
            else
            {
              OnRequestFailed(string.Format("Cannot send message: {0}.", response.StatusDescription), RetryStrategy.Never);
            }
          }
        }
      }
      catch (Exception e)
      {
        CancelTimeoutTimer();

        OnRequestFailed(string.Format("Cannot send message: {0}.", e.Message), RetryStrategy.AfterDefaultPeriod);
      }
    }

    private void PostResponse(HttpStatusCode statusCode, string statusText, WebHeaderCollection responseHeaders, string contentType, byte[] responseData, string responsePath)
    {
      JObject content = new JObject();

      content[StatusKey] = (int) statusCode;

      Message.Content[InternalFileReferenceKey] = null;
      content[ConfigKey] = Message.Content;

      if (statusText != null)
      {
        content[StatusTextKey] = statusText;
      }

      if (responseHeaders != null)
      {
        JObject headers = new JObject();

        foreach (string key in responseHeaders)
        {
          headers[key] = responseHeaders[key];
        }

        content[HeadersKey] = headers;

        // TODO: do we need to add the content type or is it included in the headers?
      }

      if (responseData != null)
      {
        if (contentType != null && contentType.Contains("application/json"))
        {
          content[DataKey] = JToken.Parse(Encoding.UTF8.GetString(responseData, 0, responseData.Length));
        }
        else if (contentType != null && contentType.StartsWith("text/"))
        {
          content[DataKey] = Encoding.UTF8.GetString(responseData, 0, responseData.Length);
        }
        else
        {
          content[DataKey] = Convert.ToBase64String(responseData);
        }
      }
      else if (responsePath != null)
      {
        content[DataKey] = responsePath;
        content[InternalFileReferenceKey] = (new FileReference(responsePath, null)).ToString();
      }

      IMessage responseMessage = MessageFactory.Instance.MakeMessage(Message.Channel, Message.Subchannel, content, null, TimeSpan.FromDays(1), RestProvider.Name);

      MessageStore.Inbox.Add(responseMessage);
    }

    #region IDisposable Members

    protected override void Dispose(bool disposing)
    {
      if (disposing)
      {
        if (timeoutTimer != null)
        {
          timeoutTimer.Dispose();
          timeoutTimer = null;
        }
      }

      base.Dispose(disposing);
    }

    #endregion
  }
}
