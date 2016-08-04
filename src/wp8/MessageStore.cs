using System;
using System.Collections.Generic;
using System.Data.Linq;
using System.Linq;
using System.Text;
using System.Windows.Threading;

using Newtonsoft.Json.Linq;

using CommonTime.Logging;

namespace CommonTime.Notification
{
  /// <summary>
  /// A store for a set of messages.
  /// </summary>
  public sealed class MessageStore
  {
    private sealed class MessageDataContext : DataContext
    {
      public MessageDataContext(string connectionString)
        : base(connectionString)
      {
      }

      public Table<StoredMessage> Messages
      {
        get
        {
          return GetTable<StoredMessage>();
        }
      }

      public Table<Reader> Readers
      {
        get
        {
          return GetTable<Reader>();
        }
      }
    }

    private static MessageStore inbox;
    private static MessageStore outbox;

    public delegate void ChangedHandler(object sender, MessageStoreChangedEventArgs e);

    public event ChangedHandler Changed;

    private readonly string connectionString;
    private readonly string name;

    private Logger logger;
    private ContentManager contentManager;

    private DispatcherTimer timer;
    private bool canFireChangedHandler = true;

    public static MessageStore Inbox
    {
      get
      {
        if (inbox == null)
        {
          inbox = new MessageStore("Inbox", "DataSource=isostore:/Messages.sdf");
        }

        return inbox;
      }
    }

    public static MessageStore Outbox
    {
      get
      {
        if (outbox == null)
        {
          outbox = new MessageStore("Outbox", "DataSource=isostore:/Outbox.sdf");
        }

        return outbox;
      }
    }

    private MessageStore(string name, string connectionString)
    {
      this.name = name;
      this.connectionString = connectionString;
    }

    public void Initialize(Logger logger)
    {
      this.logger = logger;

      contentManager = new ContentManager(logger);

      CreateDatabase();
      PurgeExpiredMessages();

      timer = new DispatcherTimer();

      timer.Interval = TimeSpan.FromMinutes(5);
      timer.Tick += OnTick;
      timer.Start();
    }

    private void OnTick(Object sender, EventArgs args)
    {
      PurgeExpiredMessages();
    }

    private void CreateDatabase()
    {
      using (MessageDataContext context = new MessageDataContext(connectionString))
      {
        if (!context.DatabaseExists())
        {
          context.CreateDatabase();
        }
      }
    }

    private void OnChanged(MessageStoreChangedEventArgs e)
    {
      if (canFireChangedHandler)
      {
        ChangedHandler handler = Changed;

        if (handler != null)
        {
          handler(this, e);
        }
      }
    }

    private StoredMessage MakeStoredMessage(IMessage message)
    {
      StoredMessage storedMessage = new StoredMessage();

      storedMessage.Id = message.Id;
      UpdateStoredMessage(message, ref storedMessage);

      return storedMessage;
    }

    private void UpdateStoredMessage(IMessage message, ref StoredMessage storedMessage)
    {
      storedMessage.Channel = message.Channel;
      storedMessage.Subchannel = message.Subchannel;
      storedMessage.Notification = message.Notification;
      storedMessage.CreatedDate = message.CreatedDate;
      storedMessage.ExpiryDate = message.ExpiryDate;
      storedMessage.Provider = message.Provider;

      try
      {
        string json = message.Content.ToString();
        byte[] data = Encoding.UTF8.GetBytes(json);

        if (data.Length > ContentManager.MaxContentSize)
        {
          string path = contentManager.CreateUniqueFilename(".json");
          ContentReference contentReference = new ContentReference(path);

          contentManager.WriteContent(path, data);

          logger.TraceFormat("Saved content of {0} of {1} bytes to {2}", message, data.Length, contentReference);

          storedMessage.ContentString = contentReference.ToString();
        }
        else
        {
          storedMessage.ContentString = json;
        }
      }
      catch (Exception e)
      {
        logger.WarnFormat("An error occurred while storing message: {0}", e.Message);
      }
    }

    private IMessage MakeMessage(StoredMessage storedMessage)
    {
      Message message = new Message();

      message.Id = storedMessage.Id;
      message.Channel = storedMessage.Channel;
      message.Subchannel = storedMessage.Subchannel;
      message.Notification = storedMessage.Notification;
      message.CreatedDate = storedMessage.CreatedDate;
      message.ExpiryDate = storedMessage.ExpiryDate;
      message.Provider = storedMessage.Provider;

      if (storedMessage.ContentString != null)
      {
        try
        {
          ContentReference contentReference = ContentReference.Parse(storedMessage.ContentString);

          if (contentReference == null)
          {
            message.Content = JToken.Parse(storedMessage.ContentString);
          }
          else
          {
            byte[] buffer = contentManager.ReadContent(contentReference.Path);

            logger.TraceFormat("Read content of {0} from {1} and got {2} bytes", message, contentReference, buffer.Length);

            string json = Encoding.UTF8.GetString(buffer, 0, buffer.Length);

            message.Content = JToken.Parse(json);
          }
        }
        catch (Exception e)
        {
          logger.WarnFormat("An error occurred while loading message: {0}", e.Message);
        }
      }

      return message;
    }

    private IList<IMessage> MakeMessages(IList<StoredMessage> storedMessages)
    {
      List<IMessage> messages = new List<IMessage>(storedMessages.Count);

      foreach (StoredMessage storedMessage in storedMessages)
      {
        messages.Add(MakeMessage(storedMessage));
      }

      return messages;
    }

    /// <summary>
    /// Adds a message to this store.
    /// </summary>
    /// <param name="message">The message to add.</param>
    /// <returns>true, if the message was added; false, if the message is already in this store.</returns>
    public bool Add(IMessage message)
    {
      if (message.ExpiryDate >= DateTime.Now)
      {
        using (MessageDataContext context = new MessageDataContext(connectionString))
        {
          IQueryable<StoredMessage> query = from msg in context.Messages
                                            where msg.Id == message.Id
                                            select msg;

          if (query.Count() == 0)
          {
            StoredMessage storedMessage = MakeStoredMessage(message);

            context.Messages.InsertOnSubmit(storedMessage);
            context.SubmitChanges();

            OnChanged(new MessageStoreChangedEventArgs(message, MessageAction.Created));

            return true;
          }
          else
          {
            return false;
          }
        }
      }
      else
      {
        return AddAsDeleted(message);
      }
    }

    /// <summary>
    /// Adds a message to this store and marks it as deleted. Changed events will <i>not</i> be fired.
    /// </summary>
    /// <param name="message">The message to add.</param>
    /// <returns>true, if the message was added; false, if the message is already in this store.</returns>
    private bool AddAsDeleted(IMessage message)
    {
      using (MessageDataContext context = new MessageDataContext(connectionString))
      {
        IQueryable<StoredMessage> query = from msg in context.Messages
                                          where msg.Id == message.Id
                                          select msg;

        if (query.Count() == 0)
        {
          StoredMessage storedMessage = MakeStoredMessage(message);

          storedMessage.IsDeleted = true;
          context.Messages.InsertOnSubmit(storedMessage);
          context.SubmitChanges();

          return true;
        }
        else
        {
          return false;
        }
      }
    }

    /// <summary>
    /// Updates a message, provided it exists in the store.
    /// </summary>
    /// <param name="message">The message to update.</param>
    /// <returns>Wther the message was updated.</returns>
    public bool Update(IMessage message)
    {
      using (MessageDataContext context = new MessageDataContext(connectionString))
      {
        IQueryable<StoredMessage> query = from msg in context.Messages
                                          where msg.Id == message.Id
                                          select msg;

        if (query.Count() == 1)
        {
          StoredMessage storedMessage = query.First<StoredMessage>();

          UpdateStoredMessage(message, ref storedMessage);
          context.SubmitChanges();

          return true;
        }
        else
        {
          return false;
        }
      }
    }

    /// <summary>
    /// Returns all non-deleted messages in this store.
    /// </summary>
    /// <returns>All messages in this store.</returns>
    public IList<IMessage> GetMessages()
    {
      using (MessageDataContext context = new MessageDataContext(connectionString))
      {
        IQueryable<StoredMessage> query = from msg in context.Messages
                                          where !msg.IsDeleted
                                          select msg;

        return MakeMessages(query.ToList<StoredMessage>());
      }
    }

    /// <summary>
    /// Logs all messages in this store.
    /// </summary>
    public void LogAllMessages()
    {
      logger.InfoFormat("{0}:", name);

      using (MessageDataContext context = new MessageDataContext(connectionString))
      {
        IQueryable<StoredMessage> query = from msg in context.Messages
                                          where !msg.IsDeleted
                                          select msg;

        foreach (StoredMessage message in query.ToList<StoredMessage>())
        {
          logger.InfoFormat("  {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7}",
                            message.Id,
                            message.Channel,
                            message.Subchannel,
                            CollapseNewLines(message.ContentString),
                            CollapseNewLines(message.Notification),
                            message.CreatedDate,
                            message.ExpiryDate,
                            message.IsDeleted ? "<Deleted" : "");
        }
      }
    }

    private string CollapseNewLines(string source)
    {
      if (string.IsNullOrEmpty(source))
      {
        return "";
      }

      StringBuilder dest = new StringBuilder(source.Length);

      for (int i = 0; i != source.Length; ++i)
      {
        char c = source[i];

        if (c == '\r')
        {
        }
        else if (c == '\n')
        {
          dest.Append(' ');
        }
        else
        {
          dest.Append(c);
        }
      }

      return dest.ToString();
    }

    /// <summary>
    /// Clears the store.
    /// </summary>
    public void Clear()
    {
      canFireChangedHandler = false;

      try
      {
        ContentManager contentManager = new ContentManager(logger);

        using (MessageDataContext context = new MessageDataContext(connectionString))
        {
          IQueryable<StoredMessage> query = from msg in context.Messages
                                            where !msg.IsDeleted
                                            select msg;

          IList<IMessage> messages = MakeMessages(query.ToList<StoredMessage>());

          foreach (IMessage message in messages)
          {
            contentManager.DeleteFiles(message.Content);
          }
        }

        using (MessageDataContext context = new MessageDataContext(connectionString))
        {
          IQueryable<Reader> expiredReadersQuery = from rdr in context.Readers
                                                   select rdr;

          context.Readers.DeleteAllOnSubmit(expiredReadersQuery.ToList());

          IQueryable<StoredMessage> expiredMessagesQuery = from msg in context.Messages
                                                           select msg;

          context.Messages.DeleteAllOnSubmit(expiredMessagesQuery.ToList());
          context.SubmitChanges();
        }
      }
      catch (Exception e)
      {
        if (logger != null)
        {
          logger.WarnFormat("Cannot clear {0}: {1}", this, e.Message);
        }
      }

      canFireChangedHandler = true;
    }

    /// <summary>
    /// Returns all non-deleted messages in this store for the given channel and subchannel.
    /// </summary>
    /// <param name="channel">The channel for which messages are required.</param>
    /// <param name="subchannel">The subchannel for which messages are required.
    /// If null, messages for all subchannels are returned.</param>
    /// <returns>All messages for the given channel and subchannel.</returns>
    public IList<IMessage> GetMessages(string channel, string subchannel)
    {
      channel = channel.ToLowerInvariant();

      if (string.IsNullOrEmpty(subchannel))
      {
        using (MessageDataContext context = new MessageDataContext(connectionString))
        {
          IQueryable<StoredMessage> query = from msg in context.Messages
                                            where !msg.IsDeleted && msg.Channel == channel
                                            select msg;

          return MakeMessages(query.ToList<StoredMessage>());
        }
      }
      else
      {
        subchannel = subchannel.ToLowerInvariant();

        using (MessageDataContext context = new MessageDataContext(connectionString))
        {
          IQueryable<StoredMessage> query = from msg in context.Messages
                                            where !msg.IsDeleted && msg.Channel == channel && msg.Subchannel == subchannel
                                            select msg;

          return MakeMessages(query.ToList<StoredMessage>());
        }
      }
    }

    /// <summary>
    /// Returns all non-deleted messages in this store for the given channel and subchannel that
    /// have not been read by the given reader.
    /// </summary>
    /// <param name="channel">The channel for which messages are required.</param>
    /// <param name="subchannel">The subchannel for which messages are required.
    /// If null, messages for all subchannels are returned.</param>
    /// <param name="reader">The reader who wants the unread messages.</param>
    /// <returns>All messages for the given channel and subchannel.</returns>
    public IList<IMessage> GetAllUnreadMessages(string channel, string subchannel, string reader)
    {
      channel = channel.ToLowerInvariant();

      using (MessageDataContext context = new MessageDataContext(connectionString))
      {
        IQueryable<string> readersQuery = from rdr in context.Readers
                                          where rdr.Name == reader
                                          select rdr.MessageId;

        List<string> readIds = readersQuery.ToList();

        if (string.IsNullOrEmpty(subchannel))
        {
          IQueryable<StoredMessage> query = from msg in context.Messages
                                            where !msg.IsDeleted && msg.Channel == channel && !readIds.Contains(msg.Id)
                                            select msg;

          return MakeMessages(query.ToList<StoredMessage>());
        }
        else
        {
          subchannel = subchannel.ToLowerInvariant();

          IQueryable<StoredMessage> query = from msg in context.Messages
                                            where !msg.IsDeleted && msg.Channel == channel && msg.Subchannel == subchannel && !readIds.Contains(msg.Id)
                                            select msg;

          return MakeMessages(query.ToList<StoredMessage>());
        }
      }
    }

    /// <summary>
    /// Returns the message with the given ID.
    /// </summary>
    /// <param name="id">The ID of the message.</param>
    /// <returns>The message with the given ID, null if no such message.</returns>
    public IMessage GetMessage(string id)
    {
      using (MessageDataContext context = new MessageDataContext(connectionString))
      {
        IQueryable<StoredMessage> query = from msg in context.Messages
                                          where msg.Id == id && !msg.IsDeleted
                                          select msg;

        return query.Count() == 0 ? null : MakeMessage(query.First());
      }
    }

    /// <summary>
    /// Mark all unread messages as newly created, firing the Changed event.
    /// </summary>
    public void MarkAllUnreadMessagesAsCreated()
    {
      using (MessageDataContext context = new MessageDataContext(connectionString))
      {
        IQueryable<string> readersQuery = from rdr in context.Readers
                                          select rdr.MessageId;

        List<string> readIds = readersQuery.ToList();

        IQueryable<StoredMessage> query = from msg in context.Messages
                                          where !msg.IsDeleted && !readIds.Contains(msg.Id)
                                          select msg;

        foreach (IMessage message in MakeMessages(query.ToList<StoredMessage>()))
        {
          OnChanged(new MessageStoreChangedEventArgs(message, MessageAction.Created));
        }
      }
    }

    /// <summary>
    /// Removes the given message from the store.
    /// </summary>
    /// <param name="message">The message to remove.</param>
    /// <returns>true, if the message was removed; false, if the message was not in this store.</returns>
    public bool Remove(IMessage message)
    {
      return Remove(message.Id);
    }

    /// <summary>
    /// Removes the message with the given ID from the store.
    /// </summary>
    /// <param name="id">The ID of the message to remove.</param>
    /// <returns>true, if the message with the given ID was removed; 
    /// false, if no message with the given ID was in this store.</returns>
    public bool Remove(string id)
    {
      using (MessageDataContext context = new MessageDataContext(connectionString))
      {
        IQueryable<StoredMessage> query = from msg in context.Messages
                                          where msg.Id == id
                                          select msg;

        if (query.Count() > 0)
        {
          StoredMessage storedMessage = query.First();
          IMessage message = MakeMessage(storedMessage);
          MessageProvider provider = MessageProviderFactory.Instance.GetProvider(message.Provider);
          bool deleteImmediately = false;

          contentManager.DeleteFiles(message.Content);

          if (provider != null)
          {
            deleteImmediately = !provider.NeedsDeletionStubs;
          }

          if (deleteImmediately)
          {
            IQueryable<Reader> deletedReadersQuery = from rdr in context.Readers
                                                     where rdr.MessageId == id
                                                     select rdr;

            context.Readers.DeleteAllOnSubmit(deletedReadersQuery.ToList());
            context.Messages.DeleteOnSubmit(storedMessage);
            context.SubmitChanges();
          }
          else
          {
            storedMessage.IsDeleted = true;
            storedMessage.ContentString = null;
            storedMessage.Notification = null;
            storedMessage.ExpiryDate = DateTime.Now + TimeSpan.FromDays(2);
            context.SubmitChanges();
          }

          OnChanged(new MessageStoreChangedEventArgs(message, MessageAction.Deleted));

          return true;
        }
        else
        {
          return false;
        }
      }
    }

    private void OnMessagesExpired(IList<string> expiredIds)
    {
      MessageProviderFactory factory = MessageProviderFactory.Instance;

      foreach (string expiredId in expiredIds)
      {
        IMessage message = GetMessage(expiredId);

        if (message != null)
        {
          MessageProvider provider = factory.GetProvider(message.Provider);

          if (provider != null)
          {
            provider.OnMessageExpired(this, message);
          }
        }
      }
    }

    private void PurgeExpiredMessages()
    {
      using (MessageDataContext context = new MessageDataContext(connectionString))
      {
        IQueryable<string> expiredIdsQuery = from msg in context.Messages
                                             where msg.ExpiryDate < DateTime.Now
                                             select msg.Id;

        List<string> expiredIds = expiredIdsQuery.ToList();

        OnMessagesExpired(expiredIds);

        IQueryable<Reader> expiredReadersQuery = from rdr in context.Readers
                                                 where expiredIds.Contains(rdr.MessageId)
                                                 select rdr;

        context.Readers.DeleteAllOnSubmit(expiredReadersQuery.ToList());

        IQueryable<StoredMessage> expiredMessagesQuery = from msg in context.Messages
                                                         where msg.ExpiryDate < DateTime.Now
                                                         select msg;

        context.Messages.DeleteAllOnSubmit(expiredMessagesQuery.ToList());
        context.SubmitChanges();
      }
    }

    /// <summary>
    /// Add a reader for a message.
    /// </summary>
    /// <param name="message">The message to be marked as read by a reader.</param>
    /// <param name="name">The name of the reader.</param>
    /// <returns>true, if the reader was added;
    /// false, if the message was already marked as read by the reader or is not in this store.</returns>
    public bool AddReader(IMessage message, string name)
    {
      using (MessageDataContext context = new MessageDataContext(connectionString))
      {
        IQueryable<Reader> readerQuery = from rdr in context.Readers
                                         where rdr.MessageId == message.Id && rdr.Name == name
                                         select rdr;

        if (readerQuery.Count() == 0)
        {
          IQueryable<StoredMessage> messageQuery = from msg in context.Messages
                                                   where msg.Id == message.Id
                                                   select msg;

          if (messageQuery.Count() != 0)
          {
            Reader reader = new Reader();

            reader.MessageId = message.Id;
            reader.Name = name;

            context.Readers.InsertOnSubmit(reader);
            context.SubmitChanges();

            return true;
          }
        }

        return false;
      }
    }

    /// <summary>
    /// Returns all readers for the given message.
    /// </summary>
    /// <param name="message">The message for which we want the readers.</param>
    /// <returns>The list of readers of the message.</returns>
    public IList<string> GetAllReaders(IMessage message)
    {
      using (MessageDataContext context = new MessageDataContext(connectionString))
      {
        IQueryable<string> query = from rdr in context.Readers
                                   where rdr.MessageId == message.Id
                                   select rdr.Name;

        return query.ToList<string>();
      }
    }

    /// <summary>
    /// Send all pending messages.
    /// </summary>
    public void SendAllMessages()
    {
      MessageProviderFactory factory = MessageProviderFactory.Instance;

      using (MessageDataContext context = new MessageDataContext(connectionString))
      {
        IQueryable<StoredMessage> query = from msg in context.Messages
                                          where !msg.IsDeleted
                                          select msg;

        IList<IMessage> messages = MakeMessages(query.ToList<StoredMessage>());

        foreach (IMessage message in messages)
        {
          MessageProvider provider = factory.GetProvider(message.Provider);

          if (provider != null)
          {
            provider.Send(message);
          }
        }
      }
    }

    /// <summary>
    /// Get all messages for the provider with the given name.
    /// </summary>
    /// <param name="providerName">The name of the provider</param>
    /// <returns>All messages in this store for the given provdider</returns>
    public IList<IMessage> GetMessages(string providerName)
    {
      MessageProviderFactory factory = MessageProviderFactory.Instance;

      using (MessageDataContext context = new MessageDataContext(connectionString))
      {
        IQueryable<StoredMessage> query = from msg in context.Messages
                                          where !msg.IsDeleted
                                          select msg;

       return MakeMessages(query.ToList<StoredMessage>());
      }
    }

    internal void OnSendingMessage(IMessage message)
    {
      ChangedHandler handler = Changed;

      if (handler != null)
      {
        handler(this, new MessageStoreChangedEventArgs(message, MessageAction.Sending));
      }
    }

    internal void OnSentMessage(IMessage message)
    {
      ChangedHandler handler = Changed;

      if (handler != null)
      {
        handler(this, new MessageStoreChangedEventArgs(message, MessageAction.Sent));
      }

      Remove(message);
    }

    internal void OnFailedToSendMessage(IMessage message, bool willRetry)
    {
      ChangedHandler handler = Changed;

      if (handler != null)
      {
        handler(this, new MessageStoreChangedEventArgs(message, willRetry ? MessageAction.SendFailedWillRetry : MessageAction.SendFailed));
      }

      if (!willRetry)
      {
        Remove(message);
      }
    }

    public override string ToString()
    {
      return name;
    }
  }
}
