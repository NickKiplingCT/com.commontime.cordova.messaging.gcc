using System;
using System.Collections.Generic;
using System.Text;

using CommonTime.Logging;

using Newtonsoft.Json.Linq;

namespace CommonTime.Notification
{
  public abstract class MessageProvider
  {
    public const string AzureName = "azure.servicebus";
    public const string RestName = "rest";
    public const string ZumoName = "azure.appservices";

    public event EventHandler AuthenticationRequired;

    private readonly Logger logger;
    private readonly ContentManager contentManager;

    private readonly IDictionary<string, MessageReceiver> receivers = new Dictionary<string, MessageReceiver>();
    private readonly ISet<MessageSender> senders = new HashSet<MessageSender>();
    private readonly object synchronizationObject = new object();

    protected MessageProvider(Logger logger)
    {
      this.logger = logger;

      contentManager = new ContentManager(logger);
    }

    protected Logger Logger
    {
      get
      {
        return logger;
      }
    }

    internal ContentManager ContentManager
    {
      get
      {
        return contentManager;
      }
    }

    public abstract string Name
    {
      get;
    }

    internal virtual bool NeedsDeletionStubs
    {
      get
      {
        return false;
      }
    }

    public virtual ICollection<string> GetAllSubscribedChannels()
    {
      lock (synchronizationObject)
      {
        return receivers.Keys;
      }
    }

    internal virtual void OnMessageExpired(MessageStore source, IMessage message)
    {
    }

    public virtual void PrepareForInitialSending(IMessage message)
    {
    }

    public virtual void Send(IMessage message)
    {
      MessageStore.Outbox.Add(message);

      MessageSender sender = MakeSender(message);

      lock (synchronizationObject)
      {
        senders.Add(sender);
      }

      sender.Start();
    }

    public void SendAllPendingMessages()
    {
      IList<IMessage> pendingMessages = MessageStore.Outbox.GetMessages(Name);

      logger.InfoFormat("Have {0} pending message(s) to send", pendingMessages.Count);

      foreach (IMessage message in pendingMessages)
      {
        Send(message);
      }
    }

    public virtual void Subscribe(string channel)
    {
      channel = channel.ToLowerInvariant();

      lock (synchronizationObject)
      {
        MessageReceiver receiver = null;

        if (!receivers.TryGetValue(channel, out receiver))
        {
          receiver = MakeReceiver(channel);
          receivers[channel] = receiver;
          receiver.Start();
        }
      }
    }

    public virtual void Unsubscribe(string channel)
    {
      channel = channel.ToLowerInvariant();

      lock (synchronizationObject)
      {
        MessageReceiver receiver = null;

        if (receivers.TryGetValue(channel, out receiver))
        {
          receiver.Stop();
          receivers.Remove(channel);
        }
      }
    }

    protected abstract MessageSender MakeSender(IMessage message);

    protected abstract MessageReceiver MakeReceiver(string channel);

    internal void OnAuthenticationRequired()
    {
      EventHandler handler = AuthenticationRequired;

      if (handler != null)
      {
        handler(this, EventArgs.Empty);
      }
    }

    internal void OnReceiverFinished(MessageReceiver receiver)
    {
      lock (synchronizationObject)
      {
        if (logger != null)
        {
          logger.TraceFormat("{0} has finished", receiver);
        }

        receivers.Remove(receiver.Channel);
        receiver.Dispose();
      }
    }

    internal void OnSenderFinished(MessageSender sender)
    {
      lock (synchronizationObject)
      {
        senders.Remove(sender);
      }

      sender.Dispose();
    }

    internal void OnHistoryFinished(MessageHistoryReceiver history)
    {
      history.Dispose();
    }

    public void OnAuthenticationSucceeded()
    {
      lock (synchronizationObject)
      {
        foreach (MessageSender sender in senders)
        {
          sender.ResendNow();
        }
      }
    }

    #region Posting a response to direct-data/Zumo requests

    internal void PostResponse(IMessage message, JToken result, string errorType, string errorMessage, TimeSpan timeToLive)
    {
      ContentManager contentManager = new ContentManager(Logger);
      JObject obj = new JObject();

      if (result == null)
      {
        JObject errorResult = new JObject();

        errorResult["result"] = false;
        errorResult["data"] = "";

        obj["response"] = errorResult;
      }
      else
      {
        obj["response"] = result;
      }

      obj["errorType"] = errorType == null ? "" : errorType;
      obj["errorMessage"] = errorMessage == null ? "" : errorMessage;
      obj["config"] = message.Content;

      JToken content = contentManager.ContainsFileData(obj) ? contentManager.ExtractFileData(obj) : obj;
      IMessage responseMessage = MessageFactory.Instance.MakeMessage(message.Channel, message.Subchannel, content, null, timeToLive, Name);

      MessageStore.Inbox.Add(responseMessage);
    }

    #endregion

    #region IDisposable Members

    public void Dispose()
    {
      Dispose(true);
      GC.SuppressFinalize(this);
    }

    protected virtual void Dispose(bool disposing)
    {
      if (disposing)
      {
        lock (synchronizationObject)
        {
          foreach (MessageReceiver receiver in receivers.Values)
          {
            receiver.Stop();
          }

          receivers.Clear();
        }
      }
    }

    #endregion
  }
}