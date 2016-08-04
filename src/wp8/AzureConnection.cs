using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Text;
using System.Threading;
using System.Security.Cryptography;

using CommonTime.Logging;

using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace CommonTime.Notification.Azure
{
  internal sealed class AzureConnection : IDisposable
  {
    private delegate void BeginRequest();

    private static string EncodeForm(IDictionary<string, string> form)
    {
      StringBuilder builder = new StringBuilder();
      bool addAmpersand = false;

      foreach (KeyValuePair<string, string> pair in form)
      {
        if (addAmpersand)
        {
          builder.Append('&');
        }
        else
        {
          addAmpersand = true;
        }

        builder.Append(Uri.EscapeDataString(pair.Key));
        builder.Append('=');
        builder.Append(Uri.EscapeDataString(pair.Value));
      }

      return builder.ToString();
    }

    private static IDictionary<string, string> DecodeForm(string str)
    {
      IDictionary<string, string> form = new Dictionary<string, string>();
      string[] components = str.Split('&');

      foreach (string component in components)
      {
        string[] parts = component.Split('=');

        if (parts.Length == 2)
        {
          string key = Uri.UnescapeDataString(parts[0]);
          string value = Uri.UnescapeDataString(parts[1]);

          form.Add(key, value);
        }
      }

      return form;
    }

    private static readonly TimeSpan RequestTimeout = TimeSpan.FromMinutes(5);
    private static readonly TimeSpan RetryTimeout = TimeSpan.FromMinutes(1);

    private readonly AzureProvider provider;
    private readonly Logger logger;
    private readonly IAzureConnectionHandler handler;
    private readonly string channel;
    private readonly string baseUrl;
    private readonly IMessage messageToSend;
    private readonly string topicName;
    private readonly string subscriptionName;
    private readonly string subscriptionPath;
    private readonly IDictionary<string, string> sharedAccessSignatures = new Dictionary<string, string>();

    private string token;
    private bool isRunning = false;
    private string wrapToken;

    private HttpWebRequest request;
    private byte[] content;
    private Timer timer;

    private string azureMessageId;
    private string lockToken;

    internal AzureConnection(AzureProvider provider, Logger logger, IAzureConnectionHandler handler, string channel)
      : this(provider, logger, handler, channel, null)
    {
    }

    internal AzureConnection(AzureProvider provider, Logger logger, IAzureConnectionHandler handler, IMessage messageToSend)
      : this(provider, logger, handler, messageToSend.Channel, messageToSend)
    {
    }

    internal AzureConnection(AzureProvider provider, Logger logger, IAzureConnectionHandler handler, string channel, IMessage messageToSend)
    {
      this.provider = provider;
      this.channel = channel;
      this.handler = handler;
      this.logger = logger;
      this.messageToSend = messageToSend;

      baseUrl = string.Format("https://{0}.{1}/", provider.ServiceNamespace, provider.ServiceBusHostname);

      if (provider.UseTopics)
      {
        string[] parts = channel.Split('/');

        if (parts.Length < 2)
        {
          topicName = channel;
          subscriptionName = channel;
        }
        else
        {
          topicName = parts[0];
          subscriptionName = parts[1];
        }

        subscriptionPath = string.Format("{0}/subscriptions/{1}", topicName, subscriptionName);
      }
    }

    public override string ToString()
    {
      return string.Format("Azure connection on channel {0}", channel);
    }

    public void Start()
    {
      if (!isRunning)
      {
        if (logger != null)
        {
          logger.InfoFormat("Starting {0}", this);
        }

        isRunning = true;

        if (provider.SharedAccess == null)
        {
          BeginGetTokenRequest();
        }
        else
        {
           if (provider.AutoCreate)
          {
            if (provider.UseQueues)
            {
              BeginCreateQueueRequest();
            }
            else
            {
              BeginCreateTopicRequest();
            }
          }
          else
          {
            OnConnectionInitialized();
          }
        }
      }
    }

    internal void Stop()
    {
      if (isRunning)
      {
        if (logger != null)
        {
          logger.InfoFormat("Stopping {0}", this);
        }

        isRunning = false;
        CancelTimer();

        if (request != null)
        {
          request.Abort();
          request = null;
        }
      }
    }

    internal void BeginSend()
    {
      BeginSendMessageRequest();
    }

    internal void BeginReceive()
    {
      if (azureMessageId == null)
      {
        BeginReceiveMessageRequest();
      }
      else
      {
        BeginDeleteMessageRequest();
      }
    }

    private void OnConnectionFinished()
    {
      isRunning = false;
      handler.OnConnectionFinished();
    }

    private void OnRequestCompleted(BeginRequest nextRequest)
    {
      request = null;
      content = null;

      if (nextRequest == null)
      {
        OnConnectionFinished();
      }
      else
      {
        nextRequest();
      }
    }

    private void OnRequestTimeout(object state)
    {
      if (timer != null)
      {
        timer.Dispose();
        timer = null;
      }

      BeginRequest requestToRetry = (BeginRequest) state;

      request = null;
      content = null;

      if (requestToRetry == null)
      {
        OnConnectionFinished();
      }
      else
      {
        requestToRetry();
      }
    }

    private void OnRequestFailed(string description)
    {
      if (description != null && logger != null)
      {
        logger.WarnFormat("{0} Will not retry", description);
      }

      request = null;
      content = null;

      OnConnectionFinished();
    }

    private void OnRequestFailed(string description, RetryStrategy retryStrategy, BeginRequest requestToRetry)
    {
      CancelTimer();

      request = null;
      content = null;

      if (!isRunning)
      {
        return;
      }

      switch (retryStrategy)
      {
        case RetryStrategy.Immediately:
        {
          if (description != null && logger != null)
          {
            logger.WarnFormat("{0} Will retry immediately", description);
          }

          requestToRetry();

          break;
        }
        case RetryStrategy.AfterDefaultPeriod:
        {
          if (description != null && logger != null)
          {
            logger.WarnFormat("{0} Will retry in {1}", description, RetryTimeout);
          }

          StartTimer(RetryTimeout, requestToRetry);

          break;
        }
        case RetryStrategy.WhenAuthenticated:
        {
          if (description != null && logger != null)
          {
            logger.WarnFormat("{0} Will retry when authenticated", description);
          }

          break;
        }
        case RetryStrategy.Never:
        {
          if (description != null && logger != null)
          {
            logger.WarnFormat("Failed to send {0}; will not retry", description);
          }

          OnConnectionFinished();

          break;
        }
      }
    }

    private void StartTimer(TimeSpan timeout, BeginRequest requestToRetry)
    {
      if (timer != null)
      {
        System.Diagnostics.Debug.Assert(timer == null);
      }

      if (logger != null)
      {
        logger.TraceFormat("{0} will time out in {1}", this, timeout);
      }

      timer = new Timer(OnRequestTimeout, requestToRetry, timeout, TimeSpan.FromMilliseconds(-1));
    }

    private void CancelTimer()
    {
      if (timer != null)
      {
        if (logger != null)
        {
          logger.TraceFormat("Cancelling time-out on {0}", this);
        }

        timer.Change(TimeSpan.FromMilliseconds(-1), TimeSpan.FromMilliseconds(-1));
        timer.Dispose();
        timer = null;
      }
    }

    private void OnConnectionInitialized()
    {
      handler.OnConnectionInitialized();
    }

    private string GetAuthorization(string path)
    {
      if (provider.SharedAccess == null)
      {
        return wrapToken;
      }
      else
      {
        return GetSharedAccessSignature(path);
      }
    }

    private string GetSharedAccessSignature(string path)
    {
      string authorization = null;

      if (!sharedAccessSignatures.TryGetValue(path, out authorization))
      {
        authorization = GenerateSharedAccessSignature(path);
        sharedAccessSignatures[path] = authorization;
      }

      return authorization;
    }

    private void ClearSharedAccessSignatures()
    {
      sharedAccessSignatures.Clear();
    }

    private string GenerateSharedAccessSignature(string path)
    {
      string uri = string.Format("{0}{1}", baseUrl, path);
      string encodedUri = HttpUtility.UrlEncode(uri);
      DateTime epoch = new DateTime(1970, 1, 1, 0, 0, 0);
      TimeSpan timeToLive = TimeSpan.FromHours(1);
      long expiry = (long) (DateTime.Now + timeToLive - epoch).TotalSeconds;
      string stringToSign = string.Format("{0}\n{1}", encodedUri, expiry);
      HMACSHA256 hmac = new HMACSHA256(Encoding.UTF8.GetBytes(provider.SharedAccess.Key));
      string signature = Convert.ToBase64String(hmac.ComputeHash(Encoding.UTF8.GetBytes(stringToSign)));

      return string.Format("SharedAccessSignature sig={0}&se={1}&skn={2}&sr={3}", HttpUtility.UrlEncode(signature), expiry, provider.SharedAccess.KeyName, encodedUri);
    }

    #region Get Token

    private void BeginGetTokenRequest()
    {
      try
      {
        if (logger != null)
        {
          logger.TraceFormat("Getting token for {0}", this);
        }

        string url = string.Format("https://{0}-sb.{1}/WRAPv0.9/", provider.ServiceNamespace, provider.AccessControl.Hostname);
        IDictionary<string, string> form = new Dictionary<string, string>();

        form["wrap_name"] = provider.AccessControl.NamespaceOwner;
        form["wrap_password"] = provider.AccessControl.NamespaceKey;
        form["wrap_scope"] = string.Format("http://{0}.{1}/", provider.ServiceNamespace, provider.ServiceBusHostname);

        content = Encoding.UTF8.GetBytes(EncodeForm(form));
        request = (HttpWebRequest) WebRequest.CreateHttp(url);

        request.Method = "POST";
        request.ContentType = "application/x-www-form-urlencoded";
        request.ContentLength = content.Length;

        logger.TraceFormat("Sending {0} request for {1}", request.Method, request.RequestUri);

        request.BeginGetRequestStream(EndGetTokenRequest, request);
      }
      catch (Exception e)
      {
        OnRequestFailed("Cannot get token: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginGetTokenRequest);
      }
    }

    private void EndGetTokenRequest(IAsyncResult result)
    {
      try
      {
        using (Stream stream = request.EndGetRequestStream(result))
        {
          stream.Write(content, 0, content.Length);
        }

        StartTimer(RequestTimeout, BeginGetTokenRequest);
        request.BeginGetResponse(EndGetTokenResponse, result.AsyncState);
      }
      catch (Exception e)
      {
        OnRequestFailed("Cannot get token: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginGetTokenRequest);
      }
    }

    private void EndGetTokenResponse(IAsyncResult result)
    {
      HttpWebResponse response = null;

      try
      {
        // Make sure we're processing the current request and not an old one (which 
        // we can safely ignore
        if (result.AsyncState == request)
        {
          response = (HttpWebResponse) request.EndGetResponse(result);
        }
        else
        {
          return;
        }
      }
      catch (WebException e)
      {
        response = (HttpWebResponse) e.Response;

        if (response == null || e.Status == WebExceptionStatus.RequestCanceled)
        {
          CancelTimer();
          OnRequestFailed("Cannot get token: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginGetTokenRequest);

          return;
        }
      }
      catch (Exception e)
      {
        CancelTimer();
        OnRequestFailed("Cannot get token: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginGetTokenRequest);

        return;
      }

      CancelTimer();

      switch (response.StatusCode)
      {
        case HttpStatusCode.OK:
        {
          if (response.ContentLength > 0)
          {
            byte[] content = new byte[response.ContentLength];
            Stream stream = null;

            try
            {
              stream = response.GetResponseStream();

              using (StreamReader reader = new StreamReader(stream))
              {
                stream = null;

                string data = reader.ReadToEnd();
                IDictionary<string, string> form = DecodeForm(data);

                if (form.TryGetValue("wrap_access_token", out token))
                {
                  if (logger != null)
                  {
                    logger.TraceFormat("Got token for {0}", this);
                  }

                  wrapToken = string.Format("WRAP access_token=\"{0}\"", token);

                  if (provider.UseQueues)
                  {
                    OnRequestCompleted(BeginCreateQueueRequest);
                  }
                  else
                  {
                    OnRequestCompleted(BeginCreateTopicRequest);
                  }
                }
                else
                {
                  OnRequestFailed("Cannot get token: no token returned");
                }
              }
            }
            catch (Exception e)
            {
              OnRequestFailed("Cannot get token: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginGetTokenRequest);
            }
            finally
            {
              if (stream != null)
              {
                stream.Dispose();
              }
            }
          }
          else
          {
            OnRequestFailed("Cannot get token: no content returned");
          }

          break;
        }
        default:
        {
          OnRequestFailed("Cannot get token: " + response.StatusDescription);

          break;
        }
      }
    }

    #endregion Get Token

    #region Create Queue

    private void BeginCreateQueueRequest()
    {
      try
      {
        if (logger != null)
        {
          logger.TraceFormat("Creating queue for {0}", this);
        }

        string url = string.Format("{0}{1}", baseUrl, channel);

        const string contentFormat =
          "<entry xmlns=\"http://www.w3.org/2005/Atom\">" +
          "<title type=\"text\">{0}</title>" +
          "<content type=\"application/xml\">" +
          "<QueueDescription xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\" " +
          "xmlns=\"http://schemas.microsoft.com/netservices/2010/10/servicebus/connect\" />" +
          "</content>" +
          "</entry>";

        content = Encoding.UTF8.GetBytes(string.Format(contentFormat, channel));
        request = (HttpWebRequest) WebRequest.CreateHttp(url);

        request.Method = "PUT";
        request.ContentType = "application/atom+xml; type=entry; charset=utf-8";
        request.ContentLength = content.Length;
        request.Headers[HttpRequestHeader.Authorization] = GetAuthorization(channel);

        logger.TraceFormat("Sending {0} request for {1}", request.Method, request.RequestUri);

        request.BeginGetRequestStream(EndCreateQueueRequest, request);
      }
      catch (Exception e)
      {
        OnRequestFailed("Cannot create queue: " + e, RetryStrategy.AfterDefaultPeriod, BeginCreateQueueRequest);
      }
    }

    private void EndCreateQueueRequest(IAsyncResult result)
    {
      try
      {
        using (Stream stream = request.EndGetRequestStream(result))
        {
          stream.Write(content, 0, content.Length);
        }

        StartTimer(RequestTimeout, BeginCreateQueueRequest);
        request.BeginGetResponse(EndCreateQueueResponse, result.AsyncState);
      }
      catch (Exception e)
      {
        OnRequestFailed("Cannot create queue: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginCreateQueueRequest);
      }
    }

    private void EndCreateQueueResponse(IAsyncResult result)
    {
      HttpWebResponse response = null;

      try
      {
        // Make sure we're processing the current request and not an old one (which 
        // we can safely ignore
        if (result.AsyncState == request)
        {
          response = (HttpWebResponse) request.EndGetResponse(result);
        }
        else
        {
          return;
        }
      }
      catch (WebException e)
      {
        response = (HttpWebResponse) e.Response;

        if (response == null || e.Status == WebExceptionStatus.RequestCanceled)
        {
          CancelTimer();
          OnRequestFailed("Cannot create queue: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginCreateQueueRequest);

          return;
        }
      }
      catch (Exception e)
      {
        CancelTimer();
        OnRequestFailed("Cannot create queue: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginCreateQueueRequest);

        return;
      }

      CancelTimer();

      switch (response.StatusCode)
      {
        case HttpStatusCode.Conflict:
        {
          if (logger != null)
          {
            logger.TraceFormat("Queue already exists for {0}", this);
          }

          OnRequestCompleted(OnConnectionInitialized);

          break;
        }
        case HttpStatusCode.Created:
        {
          if (logger != null)
          {
            logger.TraceFormat("Created queue for {0}", this);
          }

          OnRequestCompleted(OnConnectionInitialized);

          break;
        }
        case HttpStatusCode.Unauthorized:
        {
          if (logger != null)
          {
            logger.TraceFormat("Need to reauthenticate {0}", this);
          }

          if (provider.SharedAccess != null)
          {
            ClearSharedAccessSignatures();
            OnRequestCompleted(BeginCreateQueueRequest);
          }
          else
          {
            OnRequestCompleted(BeginGetTokenRequest);
          }

          break;
        }
        default:
        {
          OnRequestFailed("Cannot create queue: " + response.StatusDescription, RetryStrategy.AfterDefaultPeriod, BeginCreateQueueRequest);

          break;
        }
      }
    }

    #endregion Create Queue

    #region Create Topic

    private void BeginCreateTopicRequest()
    {
      try
      {
        if (logger != null)
        {
          logger.TraceFormat("Creating topic for {0}", this);
        }

        string url = string.Format("{0}{1}", baseUrl, topicName);

        const string contentFormat =
          "<entry xmlns=\"http://www.w3.org/2005/Atom\">" +
          "<title type=\"text\">{0}</title>" +
          "<content type=\"application/xml\">" +
          "<TopicDescription xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns=\"http://schemas.microsoft.com/netservices/2010/10/servicebus/connect\" />" +
          "</content>" +
          "</entry>";

        content = Encoding.UTF8.GetBytes(string.Format(contentFormat, topicName));
        request = (HttpWebRequest) WebRequest.CreateHttp(url);

        request.Method = "PUT";
        request.ContentType = "application/xml; charset=utf-8";
        request.ContentLength = content.Length;
        request.Headers[HttpRequestHeader.Authorization] = GetAuthorization(topicName);

        logger.TraceFormat("Sending {0} request for {1}", request.Method, request.RequestUri);

        request.BeginGetRequestStream(EndCreateTopicRequest, request);
      }
      catch (Exception e)
      {
        OnRequestFailed("Cannot create topic: " + e, RetryStrategy.AfterDefaultPeriod, BeginCreateTopicRequest);
      }
    }

    private void EndCreateTopicRequest(IAsyncResult result)
    {
      try
      {
        using (Stream stream = request.EndGetRequestStream(result))
        {
          stream.Write(content, 0, content.Length);
        }

        StartTimer(RequestTimeout, BeginCreateTopicRequest);
        request.BeginGetResponse(EndCreateTopicResponse, result.AsyncState);
      }
      catch (Exception e)
      {
        OnRequestFailed("Cannot create topic: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginCreateTopicRequest);
      }
    }

    private void EndCreateTopicResponse(IAsyncResult result)
    {
      HttpWebResponse response = null;

      try
      {
        // Make sure we're processing the current request and not an old one (which 
        // we can safely ignore
        if (result.AsyncState == request)
        {
          response = (HttpWebResponse) request.EndGetResponse(result);
        }
        else
        {
          return;
        }
      }
      catch (WebException e)
      {
        response = (HttpWebResponse) e.Response;

        if (response == null || e.Status == WebExceptionStatus.RequestCanceled)
        {
          CancelTimer();
          OnRequestFailed("Cannot create topic: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginCreateTopicRequest);

          return;
        }
      }
      catch (Exception e)
      {
        CancelTimer();
        OnRequestFailed("Cannot create topic: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginCreateTopicRequest);

        return;
      }

      CancelTimer();

      switch (response.StatusCode)
      {
        case HttpStatusCode.Conflict:
        {
          if (logger != null)
          {
            logger.TraceFormat("Topic already exists for {0}", this);
          }

          OnRequestCompleted(BeginCreateSubscriptionRequest);

          break;
        }
        case HttpStatusCode.Created:
        {
          if (logger != null)
          {
            logger.TraceFormat("Created topic for {0}", this);
          }

          OnRequestCompleted(BeginCreateSubscriptionRequest);

          break;
        }
        case HttpStatusCode.Unauthorized:
        {
          if (logger != null)
          {
            logger.TraceFormat("Need to reauthenticate {0}", this);
          }

          if (provider.SharedAccess != null)
          {
            ClearSharedAccessSignatures();
            OnRequestCompleted(BeginCreateSubscriptionRequest);
          }
          else
          {
            OnRequestCompleted(BeginGetTokenRequest);
          }

          break;
        }
        default:
        {
          OnRequestFailed("Cannot create topic: " + response.StatusDescription);

          break;
        }
      }
    }

    #endregion

    #region Create Subscription

    private void BeginCreateSubscriptionRequest()
    {
      try
      {
        if (logger != null)
        {
          logger.TraceFormat("Creating subscription for {0}", this);
        }

        string url = string.Format("{0}{1}", baseUrl, subscriptionPath);

        const string contentFormat =
          "<entry xmlns=\"http://www.w3.org/2005/Atom\">" +
          "<title type=\"text\">{0}</title>" +
          "<content type=\"application/xml\">" +
          "<SubscriptionDescription xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns=\"http://schemas.microsoft.com/netservices/2010/10/servicebus/connect\" />" +
          "<LockDuration>PT5M</LockDuration>" +
          "<RequiresSession>false</RequiresSession>" +
          "</content>" +
          "</entry>";

        string body = string.Format(contentFormat, subscriptionName);

        content = Encoding.UTF8.GetBytes(body);
        request = (HttpWebRequest) WebRequest.CreateHttp(url);

        request.Method = "PUT";
        request.ContentType = "application/xml; charset=utf-8";
        request.ContentLength = content.Length;
        request.Headers[HttpRequestHeader.Authorization] = GetAuthorization(subscriptionPath);

        logger.TraceFormat("Sending {0} request for {1}", request.Method, request.RequestUri);

        request.BeginGetRequestStream(EndCreateSubscriptionRequest, request);
      }
      catch (Exception e)
      {
        OnRequestFailed("Cannot create subscription: " + e, RetryStrategy.AfterDefaultPeriod, BeginCreateSubscriptionRequest);
      }
    }

    private void EndCreateSubscriptionRequest(IAsyncResult result)
    {
      try
      {
        using (Stream stream = request.EndGetRequestStream(result))
        {
          stream.Write(content, 0, content.Length);
        }

        StartTimer(RequestTimeout, BeginCreateSubscriptionRequest);
        request.BeginGetResponse(EndCreateSubscriptionResponse, result.AsyncState);
      }
      catch (Exception e)
      {
        OnRequestFailed("Cannot create subscription: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginCreateSubscriptionRequest);
      }
    }

    private void EndCreateSubscriptionResponse(IAsyncResult result)
    {
      HttpWebResponse response = null;

      try
      {
        // Make sure we're processing the current request and not an old one (which 
        // we can safely ignore
        if (result.AsyncState == request)
        {
          response = (HttpWebResponse) request.EndGetResponse(result);
        }
        else
        {
          return;
        }
      }
      catch (WebException e)
      {
        response = (HttpWebResponse) e.Response;

        if (response == null || e.Status == WebExceptionStatus.RequestCanceled)
        {
          CancelTimer();
          OnRequestFailed("Cannot create subscription: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginCreateSubscriptionRequest);

          return;
        }
      }
      catch (Exception e)
      {
        CancelTimer();
        OnRequestFailed("Cannot create subscription: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginCreateSubscriptionRequest);

        return;
      }

      CancelTimer();

      switch (response.StatusCode)
      {
        case HttpStatusCode.Conflict:
        {
          if (logger != null)
          {
            logger.TraceFormat("Subscription already exists for {0}", this);
          }

          OnRequestCompleted(OnConnectionInitialized);

          break;
        }
        case HttpStatusCode.Created:
        {
          if (logger != null)
          {
            logger.TraceFormat("Created subscription for {0}", this);
          }

          OnRequestCompleted(OnConnectionInitialized);

          break;
        }
        case HttpStatusCode.Unauthorized:
        {
          if (logger != null)
          {
            logger.TraceFormat("Need to reauthenticate {0}", this);
          }

          if (provider.SharedAccess != null)
          {
            ClearSharedAccessSignatures();
            OnRequestCompleted(BeginCreateSubscriptionRequest);
          }
          else
          {
            OnRequestCompleted(BeginGetTokenRequest);
          }

          break;
        }
        default:
        {
          OnRequestFailed("Cannot create subscription: " + response.StatusDescription);

          break;
        }
      }
    }

    #endregion

    #region Send Message

    private void BeginSendMessageRequest()
    {
      try
      {
        if (logger != null)
        {
          logger.InfoFormat("Sending {0} on {1}", messageToSend, this);
        }

        TimeSpan timeToLive = messageToSend.ExpiryDate - messageToSend.CreatedDate;

        if (timeToLive < TimeSpan.Zero)
        {
          handler.OnRequestFailed("Message has expired", false);

          return;
        }

        string path = provider.UseQueues ? channel : topicName;

        // Note, we want the server to time us out (naturally) before we 
        // abort the request ourselves. Also, sending always uses the channel/topic
        // not the topic + subscription, i.e., subscription path. 
        TimeSpan timeout = RequestTimeout - TimeSpan.FromSeconds(5);
        string url = string.Format("{0}{1}/messages?timeout={2}", baseUrl, path, (int) timeout.TotalSeconds);
        string json = MessageFactory.Instance.MakeJObject(messageToSend).ToString();

        content = Encoding.UTF8.GetBytes(json);
        request = (HttpWebRequest) WebRequest.CreateHttp(url);

        request.Method = "POST";
        request.ContentType = "application/json; type=entry; charset=utf-8";
        request.ContentLength = content.Length;
        request.Headers[HttpRequestHeader.Authorization] = GetAuthorization(path);

        JObject brokerProperties = new JObject();

        brokerProperties["TimeToLive"] = (int) timeToLive.TotalSeconds;

        TextWriter textWriter = null;
        JsonTextWriter jsonWriter = null;

        try
        {
          textWriter = new StringWriter();
          jsonWriter = new JsonTextWriter(textWriter);
          jsonWriter.Formatting = Formatting.None;
          brokerProperties.WriteTo(jsonWriter);
          request.Headers["BrokerProperties"] = textWriter.ToString();
        }
        finally
        {
          if (jsonWriter != null)
          {
            ((IDisposable) jsonWriter).Dispose();
            textWriter = null;
          }

          if (textWriter != null)
          {
            textWriter.Dispose();
          }
        }

        logger.TraceFormat("Sending {0} request for {1}", request.Method, request.RequestUri);

        request.BeginGetRequestStream(EndSendMessageRequest, request);
      }
      catch (Exception e)
      {
        handler.OnRequestFailed("Cannot send message: " + e.Message, false);
      }
    }

    private void EndSendMessageRequest(IAsyncResult result)
    {
      try
      {
        using (Stream stream = request.EndGetRequestStream(result))
        {
          stream.Write(content, 0, content.Length);
        }

        StartTimer(RequestTimeout, BeginSendMessageRequest);
        request.BeginGetResponse(EndSendMessageResponse, result.AsyncState);
      }
      catch (Exception e)
      {
        handler.OnRequestFailed("Cannot send message: " + e.Message, false);
      }
    }

    private void EndSendMessageResponse(IAsyncResult result)
    {
      HttpWebResponse response = null;

      try
      {
        // Make sure we're processing the current request and not an old one (which 
        // we can safely ignore
        if (result.AsyncState == request)
        {
          response = (HttpWebResponse) request.EndGetResponse(result);
        }
        else
        {
          return;
        }
      }
      catch (WebException e)
      {
        response = (HttpWebResponse) e.Response;

        if (response == null || e.Status == WebExceptionStatus.RequestCanceled)
        {
          CancelTimer();
          handler.OnRequestFailed("Cannot send message: " + e.Message, true);

          return;
        }
      }
      catch (Exception e)
      {
        CancelTimer();
        handler.OnRequestFailed("Cannot send message: " + e.Message, true);

        return;
      }

      CancelTimer();

      switch (response.StatusCode)
      {
        case HttpStatusCode.Created:
        {
          if (logger != null)
          {
            logger.InfoFormat("Sent {0} on {1}", messageToSend, this);
          }

          MessageStore.Outbox.OnSentMessage(messageToSend);
          OnRequestCompleted(null);

          break;
        }
        case HttpStatusCode.Unauthorized:
        {
          if (logger != null)
          {
            logger.TraceFormat("Need to reauthenticate {0}", this);
          }

          OnRequestCompleted(BeginGetTokenRequest);

          break;
        }
        case HttpStatusCode.BadRequest:
        {
          handler.OnRequestFailed("Cannot send message: " + response.StatusDescription, false);

          break;
        }
        default:
        {
          handler.OnRequestFailed("Cannot send message: " + response.StatusDescription, false);

          break;
        }
      }
    }

    #endregion

    #region Receive Message

    private void BeginReceiveMessageRequest()
    {
      try
      {
        if (logger != null)
        {
          logger.TraceFormat("Receiving next message on {0}", this);
        }

        // Note, we want the server to time us out (naturally) before we 
        // abort the request ourselves
        TimeSpan timeout = RequestTimeout - TimeSpan.FromSeconds(5);
        string url = string.Format("{0}{1}/messages/head?timeout={2}", baseUrl, provider.UseQueues ? channel : subscriptionPath, (int) timeout.TotalSeconds);

        request = (HttpWebRequest) WebRequest.CreateHttp(url);

        request.Method = "POST";
        request.Headers[HttpRequestHeader.Authorization] = GetAuthorization(provider.UseQueues ? channel : subscriptionPath);

        logger.TraceFormat("Sending {0} request for {1}", request.Method, request.RequestUri);

        StartTimer(RequestTimeout, BeginReceiveMessageRequest);
        request.BeginGetResponse(EndReceiveMessageResponse, request);
      }
      catch (Exception e)
      {
        OnRequestFailed("Cannot receive message: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginReceiveMessageRequest);
      }
    }

    private void EndReceiveMessageResponse(IAsyncResult result)
    {
      HttpWebResponse response = null;

      try
      {
        // Make sure we're processing the current request and not an old one (which 
        // we can safely ignore
        if (result.AsyncState == request)
        {
          response = (HttpWebResponse) request.EndGetResponse(result);
        }
        else
        {
          return;
        }
      }
      catch (WebException e)
      {
        response = (HttpWebResponse) e.Response;

        if (response == null || e.Status == WebExceptionStatus.RequestCanceled)
        {
          CancelTimer();
          OnRequestFailed("Cannot receive message: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginReceiveMessageRequest);

          return;
        }
      }
      catch (Exception e)
      {
        CancelTimer();
        OnRequestFailed("Cannot receive message: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginReceiveMessageRequest);

        return;
      }

      CancelTimer();

      switch (response.StatusCode)
      {
        case HttpStatusCode.Created:
        {
          if (logger != null)
          {
            logger.InfoFormat("Received message on {0}", this);
          }

          try
          {
            string brokerProperties = response.Headers["BrokerProperties"];
            JObject responses = JObject.Parse(brokerProperties);

            azureMessageId = (string) responses["MessageId"];
            lockToken = (string) responses["LockToken"];

            if (azureMessageId == null)
            {
              OnRequestFailed("Cannot receive message: no message ID received", RetryStrategy.AfterDefaultPeriod, BeginReceiveMessageRequest);
            }
            else if (lockToken == null)
            {
              OnRequestFailed("Cannot receive message: no lock token received", RetryStrategy.AfterDefaultPeriod, BeginReceiveMessageRequest);
            }
            else
            {
              long contentLength = response.ContentLength;
              bool isChunked = response.Headers[HttpRequestHeader.TransferEncoding] == "chunked";

              if (contentLength > 0 || isChunked)
              {
                string json;
                Stream stream = null;

                try
                {
                  stream = response.GetResponseStream();

                  using (TextReader textReader = new StreamReader(stream))
                  {
                    stream = null;
                    json = textReader.ReadToEnd();
                  }
                }
                finally
                {
                  if (stream != null)
                  {
                    stream.Dispose();
                  }
                }

                try
                {
                  IMessage message = MessageFactory.Instance.MakeMessage(JObject.Parse(json));

                  message.Provider = provider.Name;
                  MessageStore.Inbox.Add(message);
                }
                catch (Exception e)
                {
                  if (logger != null)
                  {
                    logger.WarnFormat("An exception occurred while dispatching message to subscriber: {0}", e.Message);
                  }
                }

                OnRequestCompleted(BeginDeleteMessageRequest);
              }
            }
          }
          catch (Exception e)
          {
            OnRequestFailed("Cannot receive message: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginReceiveMessageRequest);
          }

          break;
        }
        case HttpStatusCode.NoContent:
        {
          if (logger != null)
          {
            logger.TraceFormat("No message to receive on on {0}", this);
          }

          OnRequestCompleted(BeginReceiveMessageRequest);

          break;
        }
        case HttpStatusCode.Unauthorized:
        {
          if (logger != null)
          {
            logger.TraceFormat("Need to reauthenticate {0}", this);
          }

          OnRequestCompleted(BeginGetTokenRequest);

          break;
        }
        default:
        {
          OnRequestFailed("Cannot receive message: " + response.StatusDescription, RetryStrategy.AfterDefaultPeriod, BeginReceiveMessageRequest);

          break;
        }
      }
    }

    #endregion

    #region Delete Message

    private void BeginDeleteMessageRequest()
    {
      try
      {
        if (logger != null)
        {
          logger.TraceFormat("Deleting message on {0}", this);
        }

        string url = string.Format("{0}{1}/messages/{2}/{3}", baseUrl, provider.UseQueues ? channel : subscriptionPath, azureMessageId, lockToken);

        request = (HttpWebRequest) WebRequest.CreateHttp(url);

        request.Method = "DELETE";
        request.Headers[HttpRequestHeader.Authorization] = GetAuthorization(provider.UseQueues ? channel : subscriptionPath);

        logger.TraceFormat("Sending {0} request for {1}", request.Method, request.RequestUri);

        StartTimer(RequestTimeout, BeginDeleteMessageRequest);
        request.BeginGetResponse(EndDeleteMessageResponse, request);
      }
      catch (Exception e)
      {
        OnRequestFailed("Cannot delete message: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginDeleteMessageRequest);
      }
    }

    private void EndDeleteMessageResponse(IAsyncResult result)
    {
      HttpWebResponse response = null;

      try
      {
        // Make sure we're processing the current request and not an old one (which 
        // we can safely ignore
        if (result.AsyncState == request)
        {
          response = (HttpWebResponse) request.EndGetResponse(result);
        }
        else
        {
          return;
        }
      }
      catch (WebException e)
      {
        response = (HttpWebResponse) e.Response;

        if (response == null || e.Status == WebExceptionStatus.RequestCanceled)
        {
          CancelTimer();
          OnRequestFailed("Cannot delete message: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginDeleteMessageRequest);

          return;
        }
      }
      catch (Exception e)
      {
        CancelTimer();
        OnRequestFailed("Cannot delete message: " + e.Message, RetryStrategy.AfterDefaultPeriod, BeginDeleteMessageRequest);

        return;
      }

      CancelTimer();

      switch (response.StatusCode)
      {
        case HttpStatusCode.OK:
        case HttpStatusCode.NoContent:
        case HttpStatusCode.NotFound:
        {
          if (logger != null)
          {
            logger.TraceFormat("Deleted message on {0}", this);
          }

          azureMessageId = null;
          lockToken = null;

          OnRequestCompleted(BeginReceiveMessageRequest);

          break;
        }
        case HttpStatusCode.Unauthorized:
        {
          if (logger != null)
          {
            logger.TraceFormat("Need to reauthenticate {0}", this);
          }

          OnRequestCompleted(BeginGetTokenRequest);

          break;
        }
        default:
        {
          OnRequestFailed("Cannot delete message: " + response.StatusDescription);

          break;
        }
      }
    }

    #endregion

    #region IDisposable Members

    public void Dispose()
    {
      if (timer != null)
      {
        timer.Dispose();
        timer = null;
      }
    }

    #endregion
  }
}
