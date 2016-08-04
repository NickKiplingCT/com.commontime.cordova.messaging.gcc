using System;
using System.IO;
using System.IO.IsolatedStorage;
using System.Net;
using System.Net.Http;
using System.Threading;

using WPCordovaClassLib.Cordova.Commands;

using CommonTime.Logging;

using Microsoft.WindowsAzure.MobileServices;

using Newtonsoft.Json.Linq;

namespace CommonTime.Notification.Zumo
{
  public class ZumoAttachmentUploader
  {
    public delegate void SucceededEventHandler(object o, EventArgs e);
    public delegate void FailedEventHandler(object o, ZumoAttachmentUploadFailedEventArgs e);

    public event SucceededEventHandler Succeeded;
    public event FailedEventHandler Failed;

    private readonly TimeSpan timeout = TimeSpan.FromMinutes(5);

    private readonly ZumoProvider provider;
    private readonly Logger logger;
    private readonly MobileServiceClient mobileServiceClient;
    private readonly AzureStorageBlobAttachment attachment;

    private Uri uri;
    private HttpWebRequest request;
    private Timer timer;

    public ZumoAttachmentUploader(ZumoProvider provider, Logger logger, MobileServiceClient mobileServiceClient, AzureStorageBlobAttachment attachment)
    {
      this.provider = provider;
      this.logger = logger;
      this.mobileServiceClient = mobileServiceClient;
      this.attachment = attachment;
    }

    public AzureStorageBlobAttachment Attachment
    {
      get
      {
        return attachment;
      }
    }

    public void Start()
    {
      GetToken();
    }

    public override string ToString()
    {
      return string.Format("Uploader for {0}", attachment);
    }

    private async void GetToken()
    {
      try
      {
        JObject body = new JObject();

        body["permission"] = "write";
        body["gstId"] = attachment.Id;
        body["reqId"] = attachment.Message.Id;

        if (attachment.FileReference.Context != null)
        {
          body["context"] = attachment.FileReference.Context;
        }

        logger.InfoFormat("Requesting SAS token for {0}", this);

        JToken response = await mobileServiceClient.InvokeApiAsync("getsastoken", body, HttpMethod.Post, null);
        JObject result = response as JObject;

        if (result == null)
        {
          OnFailed(new ApplicationException("bad result from server"), RetryStrategy.Never);
        }
        else
        {
          string blobUriString = (string) result["blobUri"];
          string token = (string) result["sasToken"];

          attachment.BlobReference = new AzureStorageBlobReference(new Uri(blobUriString), attachment.FileReference.Context);
          uri = new Uri(string.Format("{0}?{1}", blobUriString, token));

          logger.InfoFormat("Received SAS token for {0}; will upload {1} to {2}", this, attachment, attachment.BlobReference);

          BeginUpload();
        }
      }
      catch (MobileServiceInvalidOperationException e)
      {
        HttpResponseMessage response = e.Response;
        RetryStrategy retryStrategy;

        if (response.StatusCode == HttpStatusCode.Unauthorized)
        {
          provider.OnAuthenticationRequired();
          retryStrategy = RetryStrategy.WhenAuthenticated;
        }
        else
        {
          retryStrategy = RetryStrategy.Never;
        }

        OnFailed(e, retryStrategy);
      }
      catch (Exception e)
      {
        OnFailed(e, RetryStrategy.AfterDefaultPeriod);
      }
    }

    private void OnFailed(Exception e, RetryStrategy retryStrategy)
    {
      FailedEventHandler handler = Failed;

      if (handler != null)
      {
        handler(this, new ZumoAttachmentUploadFailedEventArgs(e, retryStrategy));
      }
    }

    private void OnSucceeded()
    {
      logger.InfoFormat("{0} did succeed", this);

      SucceededEventHandler handler = Succeeded;

      if (handler != null)
      {
        handler(this, EventArgs.Empty);
      }
    }

    private void UploadAttachment()
    {
    }

    private void StartTimer()
    {
      timer = new Timer(OnTimeout, null, timeout, TimeSpan.FromMilliseconds(-1));
    }

    private void CancelTimer()
    {
      if (timer != null)
      {
        timer.Change(TimeSpan.FromMilliseconds(-1), TimeSpan.FromMilliseconds(-1));
        timer.Dispose();
        timer = null;
      }
    }

    private void OnTimeout(object state)
    {
      logger.WarnFormat("Timeout occurred while uploading {0} to {1}", attachment, uri);

      try
      {
        request.Abort();
      }
      catch (Exception e)
      {
        logger.WarnFormat("An error occurred while timing out: {0}", e.Message);
      }

      OnFailed(new ApplicationException("timeout occurred while uploading attachment"), RetryStrategy.AfterDefaultPeriod);
    }

    public void BeginUpload()
    {
      try
      {
        request = (HttpWebRequest) WebRequest.Create(uri);
        
        request.Method = "PUT";
        request.Headers["x-ms-blob-type"] = "BlockBlob";
        request.ContentType = MimeTypeMapper.GetMimeType(attachment.FileReference.Path);

        StartTimer();

        request.BeginGetRequestStream(new AsyncCallback(AddRequestData), null);
      }
      catch (Exception e)
      {
        OnFailed(e, RetryStrategy.Never);
      }
    }

    private void AddRequestData(IAsyncResult result)
    {
      try
      {
        using (IsolatedStorageFile userStore = IsolatedStorageFile.GetUserStoreForApplication())
        {
          using (IsolatedStorageFileStream inputStream = new IsolatedStorageFileStream(attachment.FileReference.Path, FileMode.Open, userStore))
          {
            using (Stream outputStream = request.EndGetRequestStream(result))
            {
              inputStream.CopyTo(outputStream);
            }
          }
        }

        request.BeginGetResponse(EndUpload, result.AsyncState);
      }
      catch (Exception e)
      {
        OnFailed(e, RetryStrategy.Never);
      }
    }

    private void EndUpload(IAsyncResult result)
    {
      CancelTimer();

      try
      {
        using (HttpWebResponse response = (HttpWebResponse) request.EndGetResponse(result))
        {
          OnSucceeded();
        }
      }
      catch (WebException e)
      {
        OnFailed(e, RetryStrategy.Never);
      }
    }
  }
}
