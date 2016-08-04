using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Resources;
using System.Xml.Linq;

using CommonTime.Logging;
using CommonTime.Notification;

using Newtonsoft.Json.Linq;

namespace WPCordovaClassLib.Cordova.Commands
{
  public sealed class NotificationPlugin : BaseCommand
  {
    private static JArray ToJArray(IList<IMessage> messages)
    {
      MessageFactory factory = MessageFactory.Instance;
      JArray array = new JArray();

      foreach (IMessage message in messages)
      {
        array.Add(factory.MakeJObject(message));
      }

      return array;
    }

    private class ReceiveCallback
    {
      public ReceiveCallback(string receiver, string channel, string subchannel, string callbackId)
      {
        Receiver = receiver;
        Channel = channel.ToLower();
        Subchannel = subchannel.ToLower();
        CallbackId = callbackId;
      }

      public string Receiver
      {
        get;
        private set;
      }

      public string Channel
      {
        get;
        private set;
      }

      public string Subchannel
      {
        get;
        private set;
      }

      public string CallbackId
      {
        get;
        private set;
      }
    }

    private readonly IDictionary<string, string> inboxChangeCallbacks = new Dictionary<string, string>();
    private readonly IDictionary<string, string> outboxChangeCallbacks = new Dictionary<string, string>();
    private IList<ReceiveCallback> receiveCallbacks = new List<ReceiveCallback>();
    private bool isAttachedToStores = false;

    public NotificationPlugin()
    {
      MessageProviderFactory.Instance.StartLogging();

      MessageStore.Inbox.Initialize(Logger);
      MessageStore.Outbox.Initialize(Logger);

      ParsePreferences(); 
    }

    public Logger Logger
    {
      get
      {
        return MessageProviderFactory.Instance.Logger;
      }
    }

    private void ParsePreferences()
    {
      try
      {
        StreamResourceInfo streamInfo = Application.GetResourceStream(new Uri("config.xml", UriKind.Relative));

        if (streamInfo != null)
        {
          StreamReader reader = new StreamReader(streamInfo.Stream);
          XDocument document = XDocument.Parse(reader.ReadToEnd());

          var preferences = from results in document.Descendants()
                            where results.Name.LocalName == "preference"
                            select new
                            {
                              name = (string) results.Attribute("name"),
                              value = (string) results.Attribute("value")
                            };

          foreach (var preference in preferences)
          {
            if (preference.name == "defaultPushSystem")
            {
              MessageProviderFactory.Instance.DefaultProviderName = preference.value;

              Logger.InfoFormat("Set default push system to {0}", preference.value);
            }
          }
        }

        AttachHandlersToStores();
      }
      catch (Exception e)
      {
        Debug.WriteLine("Cannot parse preferences: {0}", e.Message);
      }
    }

    public override void OnReset()
    {
      DetachHandlersFromStores();

      base.OnReset();
    }

    public override void OnResume(object sender, Microsoft.Phone.Shell.ActivatedEventArgs e)
    {
      AttachHandlersToStores();

      base.OnResume(sender, e);
    }

    public override void OnPause(object sender, Microsoft.Phone.Shell.DeactivatedEventArgs e)
    {
      DetachHandlersFromStores();

      base.OnReset();
    }

    private void AttachHandlersToStores()
    {
      if (!isAttachedToStores)
      {
        MessageStore.Inbox.Changed += OnInboxChanged;
        MessageStore.Outbox.Changed += OnOutboxChanged;

        isAttachedToStores = false;
      }
    }

    private void DetachHandlersFromStores()
    {
      if (isAttachedToStores)
      {
        MessageStore.Inbox.Changed -= OnInboxChanged;
        MessageStore.Outbox.Changed -= OnOutboxChanged;
        
        isAttachedToStores = false;
      }
    }

    #region Plugin Methods

    public void addChannel(string args)
    {
      string callbackId = "";

      try
      {
        JArray parameters = JArray.Parse(args);
        string channel = (string) parameters[0];
       
        callbackId = (string) parameters[1];

        Logger.TraceFormat("Adding channel {0} with callback {1}", channel, callbackId);

        MessageProviderFactory.Instance.DefaultProvider.Subscribe(channel);

        DispatchCommandResult(new PluginResult(PluginResult.Status.OK, channel), callbackId);
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot add channel: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    public void removeChannel(string args)
    {
      string callbackId = "";

      try
      {
        JArray parameters = JArray.Parse(args);
        string channel = (string) parameters[0];
       
        callbackId = (string) parameters[1];

        Logger.TraceFormat("Removing channel {0} with callback {1}", channel, callbackId);

        MessageProviderFactory.Instance.DefaultProvider.Unsubscribe(channel);
        
        DispatchCommandResult(new PluginResult(PluginResult.Status.OK, channel), callbackId);
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot remove channel: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    public void listChannels(string args)
    {
      string callbackId = "";

      try
      {
        JArray parameters = JArray.Parse(args);
      
        callbackId = (string) parameters[0];

        Logger.TraceFormat("Listing channels with callback {0}", callbackId);

        ICollection<string> channels = MessageProviderFactory.Instance.DefaultProvider.GetAllSubscribedChannels();
        JArray result = new JArray();

        foreach (string channel in channels)
        {
          result.Add(channel);
        }

        DispatchCommandResult(new PluginResult(PluginResult.Status.OK, result.ToString()), callbackId);
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot list channels: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    public void sendMessage(string args)
    {
      string callbackId = "";

      try
      {
        JArray parameters = JArray.Parse(args);
        JObject json = JObject.Parse((string) parameters[0]);
        
        callbackId = (string) parameters[1];
        
        Logger.TraceFormat("Sending message with callback {0}", callbackId);

        IMessage message = MessageFactory.Instance.MakeMessage(json, true);
        MessageProvider provider = MessageProviderFactory.Instance.GetProvider(message.Provider);

        if (provider == null)
        {
          throw new ApplicationException("no notification provider specified in message and/or no default provider");
        }

        provider.PrepareForInitialSending(message);
        provider.Send(message);
        DispatchCommandResult(new PluginResult(PluginResult.Status.OK, message.Id), callbackId);
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot send message: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    public void getMessages(string args)
    {
      string callbackId = "";

      try
      {
        JArray parameters = JArray.Parse(args);
        string channel = (string) parameters[0];
        string subchannel = (string) parameters[1];
        
        callbackId = (string) parameters[2];

        if (string.IsNullOrEmpty(subchannel))
        {
          Logger.TraceFormat("Getting all messages on channel {0} and all subchannels with callback {1}", channel, callbackId);
        }
        else
        {
          Logger.TraceFormat("Getting all messages on channel {0} and subchannel {1} with callback {2}", channel, subchannel, callbackId);
        }

        IList<IMessage> messages = MessageStore.Inbox.GetMessages(channel, subchannel);
        JArray result = ToJArray(messages);

        DispatchCommandResult(new PluginResult(PluginResult.Status.OK, result.ToString()), callbackId);
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot get messages: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    public void getUnreadMessages(string args)
    {
      string callbackId = "";

      try
      {
        JArray parameters = JArray.Parse(args);
        string receiver = (string) parameters[0];
        string channel = (string) parameters[1];
        string subchannel = (string) parameters[2];

        callbackId = (string) parameters[3];

        if (string.IsNullOrEmpty(subchannel))
        {
          Logger.TraceFormat("Getting all unread messages on channel {0} and all subchannels for {1} with callback {2}", channel, receiver, callbackId);
        }
        else
        {
          Logger.TraceFormat("Getting all unread messages on channel {0} and subchannel {1} for {2} wit callback {3}", channel, subchannel, receiver, callbackId);
        }

        IList<IMessage> messages = MessageStore.Inbox.GetAllUnreadMessages(channel, subchannel, receiver);
        JArray result = ToJArray(messages);

        DispatchCommandResult(new PluginResult(PluginResult.Status.OK, result.ToString()), callbackId);
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot get unread messages: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    public void deleteMessage(string args)
    {
      string callbackId = "";

      try
      {
        JArray parameters = JArray.Parse(args);
        string id = (string) parameters[0];

        callbackId = (string) parameters[1];

        Logger.TraceFormat("Deleting message {0} with callback {1}", id, callbackId);

        MessageStore.Inbox.Remove(id);

        DispatchCommandResult(new PluginResult(PluginResult.Status.OK, id), callbackId);
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot delete message: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    public void receiveMessageNotification(string args)
    {
      string callbackId = "";

      try
      {
        JArray parameters = JArray.Parse(args);
        string receiver = (string) parameters[0];
        string channel = (string) parameters[1];
        string subchannel = (string) parameters[2];

        callbackId = (string) parameters[3];

        if (string.IsNullOrEmpty(subchannel))
        {
          Logger.TraceFormat("Will receive messages for {1} on channel {0} and all subchannels with callback {2}", channel, receiver, callbackId);
        }
        else
        {
          Logger.TraceFormat("Will receive messages for {2} on channel {0} and subchannel {1} with callback {3}", channel, subchannel, receiver, callbackId);
        }

        MessageFactory factory = MessageFactory.Instance;

        foreach (IMessage message in MessageStore.Inbox.GetAllUnreadMessages(channel, subchannel, receiver))
        {
          PluginResult result = new PluginResult(PluginResult.Status.OK, factory.MakeJObject(message).ToString());

          result.KeepCallback = true;

          DispatchCommandResult(result, callbackId);
        }

        receiveCallbacks.Add(new ReceiveCallback(receiver, channel, subchannel, callbackId));
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot receive message notification: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    public void cancelMessageNotification(string args)
    {
      string callbackId = "";

      try
      {
        JArray parameters = JArray.Parse(args);
        string receiver = (string) parameters[0];

        callbackId = (string) parameters[1];

        Logger.TraceFormat("Will cancel receiving messages for {0} with callback {1}", receiver, callbackId);

        IList<ReceiveCallback> toKeep = new List<ReceiveCallback>();

        foreach (ReceiveCallback callback in receiveCallbacks)
        {
          if (callback.Receiver != receiver)
          {
            toKeep.Add(callback);
          }
        }

        receiveCallbacks = toKeep;

        DispatchCommandResult(new PluginResult(PluginResult.Status.OK), callbackId);
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot cancel message notification: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    public void cancelAllMessageNotifications(string args)
    {
      string callbackId = "";

      try
      {
        JArray parameters = JArray.Parse(args);

        callbackId = (string) parameters[0];

        Logger.TraceFormat("Will cancel receiving messages for all receivers with callback", callbackId);

        receiveCallbacks.Clear();

        DispatchCommandResult(new PluginResult(PluginResult.Status.OK), callbackId);
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot cancel all message notification: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    public void receiveInboxChanges(string args)
    {
      string callbackId = "";

      try
      {
        JArray parameters =  JArray.Parse(args);
        string receiver = (string) parameters[0];
        
        callbackId = (string) parameters[1];

        Logger.TraceFormat("Will receive inbox changes for {0} on callback {1}", receiver, callbackId);

        inboxChangeCallbacks[receiver] = callbackId;
        MessageStore.Inbox.MarkAllUnreadMessagesAsCreated();
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot receive inbox changes: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    public void receiveOutboxChanges(string args)
    {
      string callbackId = "";

      try
      {
        JArray parameters = JArray.Parse(args);
        string receiver = (string) parameters[0];
        
        callbackId = (string) parameters[1];

        Logger.TraceFormat("Will receive outbox changes for {0} on callback {1}", receiver, callbackId);

        outboxChangeCallbacks[receiver] = callbackId;
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot receive outbox changes: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    public void messageReceivedAck(string args)
    {
      string callbackId = "";

      try
      {
        JArray parameters = JArray.Parse(args);
        string receiver = (string) parameters[0];
        string id = (string) parameters[1];

        callbackId = (string) parameters[2];

        Logger.TraceFormat("Acknowledging receipt of {0} by {1} with callback {2}", id, receiver, callbackId);

        IMessage message = MessageStore.Inbox.GetMessage(id);

        if (message == null)
        {
          throw new ApplicationException(string.Format("No message with ID {0}", id));
        }

        MessageStore.Inbox.AddReader(message, receiver);

        DispatchCommandResult(new PluginResult(PluginResult.Status.OK), callbackId);
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot process message-received ack: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    public void cancelInboxChanges(string args)
    {
      string callbackId = "";
      
      try
      {
        JArray parameters = JArray.Parse(args);
        string receiver = (string) parameters[0];

        callbackId = (string) parameters[1];

        Logger.TraceFormat("Will stop receiving inbox changes for {0} with callback {1}", receiver, callbackId);

        inboxChangeCallbacks.Remove(receiver);

        DispatchCommandResult(new PluginResult(PluginResult.Status.OK), callbackId);
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot cancel receiving inbox changes: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    public void cancelOutboxChanges(string args)
    {
      string callbackId = "";

      try
      {
        JArray parameters = JArray.Parse(args);
        string receiver = (string) parameters[0];

        callbackId = (string) parameters[1];

        Logger.TraceFormat("Will stop receiving outbox changes for {0} with callback {1}", receiver, callbackId);
         
        outboxChangeCallbacks.Remove(receiver);

        DispatchCommandResult(new PluginResult(PluginResult.Status.OK), callbackId);
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot cancel receiving outbox changes: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    public void setOptions(string args)
    {
      string callbackId = "";

      try
      {
        JArray parameters = JArray.Parse(args);

        callbackId = (string) parameters[1];

        if (parameters[0] != null && parameters[0].Type != JTokenType.Null)
        {
          JObject options = JObject.Parse((string) parameters[0]);

          Logger.TraceFormat("Will set options with callback {0}", callbackId);

          JToken defaultPushSystem = null;

          if (options.TryGetValue("defaultPushSystem", out defaultPushSystem))
          {
            MessageProviderFactory.Instance.DefaultProviderName = (string) defaultPushSystem;

            Logger.InfoFormat("Set default push system to {0}", defaultPushSystem);
          }
        }

        DispatchCommandResult(new PluginResult(PluginResult.Status.OK), callbackId);
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot set options: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    #endregion

    private void OnInboxChanged(object sender, MessageStoreChangedEventArgs e)
    {
      if (inboxChangeCallbacks.Count == 0 & receiveCallbacks.Count == 0)
      {
        return;
      }

      try
      {
        JObject json = new JObject();

        switch (e.Action)
        {
          case CommonTime.Notification.MessageAction.Created:
          {
            json["action"] = "create";

            break;
          }
          case CommonTime.Notification.MessageAction.Updated:
          {
            json["action"] = "update";

            break;
          }
          case CommonTime.Notification.MessageAction.Deleted:
          {
            json["action"] = "delete";

            break;
          }
          default:
          {
            return;
          }
        }

        json["message"] = MessageFactory.Instance.MakeJObject(e.Message);

        PluginResult result = new PluginResult(PluginResult.Status.OK);

        result.Message = json.ToString();
        result.KeepCallback = true;

        foreach (string callbackId in inboxChangeCallbacks.Values)
        {
          DispatchCommandResult(result, callbackId);
        }

        CallReceiveCallbacks(MessageStore.Inbox, e.Message);
      }
      catch (Exception ex)
      {
        Logger.WarnFormat("An error occurred while processing inbox change: {0}", ex.Message);
      }
    }

    private void CallReceiveCallbacks(MessageStore store, IMessage message)
    {
      PluginResult result = new PluginResult(PluginResult.Status.OK);

      result.Message = MessageFactory.Instance.MakeJObject(message).ToString();
      result.KeepCallback = true;

      foreach (ReceiveCallback receiveCallback in receiveCallbacks)
      {
        if (!store.GetAllReaders(message).Contains(receiveCallback.Receiver))
        {
          if (receiveCallback.Channel == message.Channel &&
              (string.IsNullOrEmpty(receiveCallback.Subchannel) || receiveCallback.Subchannel == message.Subchannel))
          {
            DispatchCommandResult(result, receiveCallback.CallbackId);
          }
        }
      }
    }

    private void OnOutboxChanged(object sender, MessageStoreChangedEventArgs e)
    {
      if (outboxChangeCallbacks.Count == 0)
      {
        return;
      }

      try
      {
        JObject json = new JObject();

        switch (e.Action)
        {
          case CommonTime.Notification.MessageAction.Sending:
          {
            json["action"] = "SENDING";

            break;
          }
          case CommonTime.Notification.MessageAction.Sent:
          {
            json["action"] = "SENT";

            break;
          }
          case CommonTime.Notification.MessageAction.SendFailed:
          {
            json["action"] = "FAILED";

            break;
          }
          case CommonTime.Notification.MessageAction.SendFailedWillRetry:
          {
            json["action"] = "FAILED_WILL_RETRY";

            break;
          }
          default:
          {
            return;
          }
        }

        json["message"] = MessageFactory.Instance.MakeJObject(e.Message);

        PluginResult result = new PluginResult(PluginResult.Status.OK);

        result.Message = json.ToString();
        result.KeepCallback = true;

        foreach (string callbackId in outboxChangeCallbacks.Values)
        {
          DispatchCommandResult(result, callbackId);
        }
      }
      catch (Exception ex)
      {
        Logger.WarnFormat("An error occurred while processing outbox change: {0}", ex.Message);
      }
    }
  }
}
