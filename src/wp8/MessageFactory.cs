using System;

using Newtonsoft.Json.Linq;

namespace CommonTime.Notification
{
  /// <summary>
  /// Factory class for constructing messages.
  /// </summary>
  public sealed class MessageFactory
  {
    public static readonly DateTime Epoch = new DateTime(1970, 1, 1, 0, 0, 0);

    public static TimeSpan DefaultTimeToLive = TimeSpan.FromDays(1);

    private static readonly MessageFactory instance = new MessageFactory();

    private const string IdKey = "id";
    private const string ChannelKey = "channel";
    private const string SubchannelKey = "subchannel";
    private const string ContentKey = "content";
    private const string CreatedKey = "date";
    private const string ExpiryKey = "expiry";
    private const string NotificationKey = "notification";
    private const string ProviderKey = "provider";

    /// <summary>
    /// The single instance of this class.
    /// </summary>
    public static MessageFactory Instance
    {
      get
      {
        return instance;
      }
    }

    /// <summary>
    /// Make a message from a JSON object.
    /// </summary>
    /// <param name="source">The JSON representation of a message.</param>
    /// <param name="fillInMissingParts">Whether to fill in any missing parts.</param>
    /// <returns>The parsed message.</returns>
    public IMessage MakeMessage(JObject source, bool fillInMissingParts = false)
    {
      Message message = new Message();

      message.Id = (string) source[IdKey];
      message.Channel = (string) source[ChannelKey];
      message.Subchannel = (string) source[SubchannelKey];
      message.Content = (JObject) source[ContentKey];
      message.Notification = (string) source[NotificationKey];
      message.Provider = (string) source[ProviderKey];

      if (source[CreatedKey] != null)
      {
        message.CreatedDate = Epoch + TimeSpan.FromMilliseconds((long) source[CreatedKey]);
      }

      if (source[ExpiryKey] != null)
      {
        message.ExpiryDate = Epoch + TimeSpan.FromMilliseconds((long) source[ExpiryKey]);
      }

      if (fillInMissingParts)
      {
        if (message.Id == null)
        {
          message.Id = Guid.NewGuid().ToString();
        }

        if (message.CreatedDate == new DateTime())
        {
          message.CreatedDate = DateTime.Now;
        }

        if (message.ExpiryDate == new DateTime())
        {
          message.ExpiryDate = message.CreatedDate + TimeSpan.FromDays(1);
        }
      }

      return message;
    }

    /// <summary>
    /// Make a message from the string representation of a JSON object.
    /// </summary>
    /// <param name="source">The JSON representation of a message.</param>
    /// <param name="fillInMissingParts">Whether to fill in any missing parts.</param>
    /// <returns>The parsed message.</returns>
    public IMessage MakeMessage(string source, bool fillInMissingParts = false)
    {
      return MakeMessage(JObject.Parse(source), fillInMissingParts);
    }

    /// <summary>
    /// Makes a message.
    /// </summary>
    /// <param name="channel">The channel on which the message is to be sent.</param>
    /// <param name="subchannel">The subchannel on which the message is to be sent.</param>
    /// <param name="content">The content of the message.</param>
    /// <returns>The constructed message.</returns>
    public IMessage MakeMessage(string channel, string subchannel, string content)
    {
      return MakeMessage(channel, subchannel, content, null);
    }

    /// <summary>
    /// Makes a message.
    /// </summary>
    /// <param name="channel">The channel on which the message is to be sent.</param>
    /// <param name="subchannel">The subchannel on which the message is to be sent.</param>
    /// <param name="content">The content of the message.</param>
    /// <returns>The constructed message.</returns>
    public IMessage MakeMessage(string channel, string subchannel, JToken content)
    {
      return MakeMessage(channel, subchannel, content, null);
    }

    /// <summary>
    /// Makes a message.
    /// </summary>
    /// <param name="channel">The channel on which the message is to be sent.</param>
    /// <param name="subchannel">The subchannel on which the message is to be sent.</param>
    /// <param name="content">The content of the message.</param>
    /// <param name="notification">The notification of the message.</param>
    /// <returns>The constructed message.</returns>
    public IMessage MakeMessage(string channel, string subchannel, string content, string notification)
    {
      return MakeMessage(channel, subchannel, content, notification, DefaultTimeToLive);
    }

    /// <summary>
    /// Makes a message.
    /// </summary>
    /// <param name="channel">The channel on which the message is to be sent.</param>
    /// <param name="subchannel">The subchannel on which the message is to be sent.</param>
    /// <param name="content">The content of the message.</param>
    /// <param name="notification">The notification of the message.</param>
    /// <returns>The constructed message.</returns>
    public IMessage MakeMessage(string channel, string subchannel, JToken content, string notification)
    {
      return MakeMessage(channel, subchannel, content, notification, DefaultTimeToLive);
    }

    /// <summary>
    /// Makes a message.
    /// </summary>
    /// <param name="channel">The channel on which the message is to be sent.</param>
    /// <param name="subchannel">The subchannel on which the message is to be sent.</param>
    /// <param name="content">The content of the message.</param>
    /// <param name="notification">The notification of the message.</param>
    /// <param name="timeToLive">The time the message has to live. The expiry date is this plus the created date (now).</param>
    /// <returns>The constructed message.</returns>
    public IMessage MakeMessage(string channel, string subchannel, string content, string notification, TimeSpan timeToLive)
    {
      return MakeMessage(channel, subchannel, content == null ? null : JObject.Parse(content), notification, timeToLive);
    }

    /// <summary>
    /// Makes a message.
    /// </summary>
    /// <param name="channel">The channel on which the message is to be sent.</param>
    /// <param name="subchannel">The subchannel on which the message is to be sent.</param>
    /// <param name="content">The content of the message.</param>
    /// <param name="notification">The notification of the message.</param>
    /// <param name="timeToLive">The time the message has to live. The expiry date is this plus the created date (now).</param>
    /// <returns>The constructed message.</returns>
    public IMessage MakeMessage(string channel, string subchannel, JToken content, string notification, TimeSpan timeToLive)
    {
      return MakeMessage(channel, subchannel, content, notification, timeToLive, null);
    }

    /// <summary>
    /// Makes a message.
    /// </summary>
    /// <param name="channel">The channel on which the message is to be sent.</param>
    /// <param name="subchannel">The subchannel on which the message is to be sent.</param>
    /// <param name="content">The content of the message.</param>
    /// <param name="notification">The notification of the message.</param>
    /// <param name="timeToLive">The time the message has to live. The expiry date is this plus the created date (now).</param>
    /// <param name="provider">The provider used to send the message.</param>
    /// <returns>The constructed message.</returns>
    public IMessage MakeMessage(string channel, string subchannel, JToken content, string notification, TimeSpan timeToLive, string provider)
    {
      Message message = new Message();

      message.Id = Guid.NewGuid().ToString();
      message.Channel = channel.ToLowerInvariant();
      message.Subchannel = subchannel.ToLowerInvariant();
      message.Content = content;
      message.Notification = notification;
      message.CreatedDate = DateTime.Now;
      message.ExpiryDate = DateTime.Now + timeToLive;
      message.Provider = provider;

      return message;
    }

    /// <summary>
    /// Returns the JSON representation of this message.
    /// </summary>
    /// <param name="message">The message to format.</param>
    /// <returns>The JSON representation of the message.</returns>
    public JObject MakeJObject(IMessage message)
    {
      JObject dest = new JObject();

      dest[IdKey] = message.Id;
      dest[ChannelKey] = message.Channel;
      dest[SubchannelKey] = message.Subchannel;
      dest[ContentKey] = message.Content;
      dest[NotificationKey] = message.Notification;
      dest[CreatedKey] = (long) (message.CreatedDate - Epoch).TotalMilliseconds;
      dest[ExpiryKey] = (long) (message.ExpiryDate - Epoch).TotalMilliseconds;
      dest[ProviderKey] = message.Provider;

      return dest;
    }
  }
}
