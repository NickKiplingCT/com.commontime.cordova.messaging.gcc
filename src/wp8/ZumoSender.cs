using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Text;
using System.IO;

using Microsoft.WindowsAzure.MobileServices;

using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

using CommonTime.Logging;
using CommonTime.Notification;

namespace CommonTime.Notification.Zumo
{
  internal sealed class ZumoSender : MessageSender
  {
    private readonly MobileServiceClient mobileServiceClient;

    internal ZumoSender(ZumoProvider provider, Logger logger, MobileServiceClient mobileServiceClient, IMessage message)
      : base(provider, logger, message)
    {
      this.mobileServiceClient = mobileServiceClient;
    }

    private ZumoProvider ZumoProvider
    {
      get
      {
        return (ZumoProvider) base.Provider;
      }
    }

    internal override bool Start()
    {
      if (base.Start())
      {
        UploadNextAttachment();

        return true;
      }
      else
      {
        return false;
      }
    }

    public override string ToString()
    {
      return string.Format("Azure App Services sender for {0}", Message);
    }

    private void UploadNextAttachment()
    {
      try
      {
        FileReference fileReference = Provider.ContentManager.FindFirstFileReference(Message.Content);

        if (fileReference == null)
        {
          Send();
        }
        else
        {
          string identifier = Path.GetFileNameWithoutExtension(fileReference.Path);
          AzureStorageBlobAttachment attachment = new AzureStorageBlobAttachment(identifier, Message, fileReference);
          ZumoAttachmentUploader uploader = new ZumoAttachmentUploader(ZumoProvider, Logger, ZumoProvider.MobileServiceClient, attachment);

          uploader.Succeeded += OnUploaderSucceeded;
          uploader.Failed += OnUploaderFailed;

          uploader.Start();
        }
      }
      catch (Exception e)
      {
        OnRequestFailed(string.Format("Cannot send message: {0}.", e.Message), RetryStrategy.Never);
      }
    }

    private void OnUploaderFailed(object o, ZumoAttachmentUploadFailedEventArgs e)
    {
      OnRequestFailed(e.Exception.Message, e.RetryStrategy);
    }

    private void OnUploaderSucceeded(object o, EventArgs e)
    {
      AzureStorageBlobAttachment attachment = ((ZumoAttachmentUploader) o).Attachment;

      Message.Content = Provider.ContentManager.ReplaceReference(Message.Content, attachment.FileReference, attachment.BlobReference);

      MessageStore.Outbox.Update(Message);
      UploadNextAttachment();
    }

    private async void Send()
    {
      try
      {
        Logger.InfoFormat("{0} will start sending message", this);

        JObject transport = (JObject) Message.Content["transport"];

        if (transport == null)
        {
          throw new ApplicationException("missing transport");
        }

        string transportType = (string) transport["type"];
        string httpMethod = (string) transport["httpMethod"];
        string api = (string) transport["api"];

        if (transportType != "zumoDirect")
        {
          throw new ApplicationException("unknown transport type");
        }

        IDictionary<string, string> parameters = null;
        JToken body = null;

        switch (httpMethod)
        {
          case "POST":
          case "PUT":
          case "PATCH":
          {
            body = Message.Content;

            break;
          }
          case "DELETE":
          case "GET":
          {
            parameters = new Dictionary<string, string>();
            parameters["data"] = Message.Content.ToString();

            break;
          }
          default:
          {
            throw new ApplicationException("unsupported HTTP method");
          }
        }

        try
        {
          JToken result = await mobileServiceClient.InvokeApiAsync(api, body, new HttpMethod(httpMethod), parameters);

          Logger.InfoFormat("{0} did finish sending message", this);

          ZumoProvider.PostResponse(Message, result, null, null, TimeSpan.FromDays(1));
        }
        catch (MobileServiceInvalidOperationException e)
        {
          HttpResponseMessage response = e.Response;
          RetryStrategy retryStrategy = RetryStrategy.Never;

          if (response.StatusCode == HttpStatusCode.Unauthorized)
          {
            Provider.OnAuthenticationRequired();
            retryStrategy = RetryStrategy.WhenAuthenticated;
          }

          OnRequestFailed(string.Format("Cannot send message: {0}.", e.Message), retryStrategy);
        }
        catch (Exception e)
        {
          OnRequestFailed(string.Format("Cannot send message: {0}.", e.Message), RetryStrategy.AfterDefaultPeriod);
        }
      }
      catch (Exception e)
      {
        OnRequestFailed(string.Format("Cannot send message: {0}.", e.Message), RetryStrategy.Never);
      }
    }

    protected override bool OnRequestFailed(string details, RetryStrategy retryStrategy)
    {
      bool willRetry = base.OnRequestFailed(details, retryStrategy);

      if (!willRetry)
      {
        bool hasExpired = Message.ExpiryDate > DateTime.Now;

        ZumoProvider.PostResponse(Message, null, hasExpired ? "expired" : "other", details, TimeSpan.FromDays(1));
      }

      return willRetry;
    }
  }
}
