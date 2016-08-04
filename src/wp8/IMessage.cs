using System;

using Newtonsoft.Json.Linq;

namespace CommonTime.Notification
{
  /// <summary>
  /// A message that is to be sent or has been received via the notification service.
  /// </summary>
  public interface IMessage
  {
    /// <summary>
    /// The channel on which the message was or is to be sent.
    /// </summary>
    string Channel
    {
      get;
    }

    /// <summary>
    /// The content of the message.
    /// </summary>
    JToken Content
    {
      get;
      set;
    }

    /// <summary>
    /// The date on which the message was created.
    /// </summary>
    DateTime CreatedDate
    {
      get;
    }

    /// <summary>
    /// The date on which the message will expire.
    /// </summary>
    DateTime ExpiryDate
    {
      get;
    }

    /// <summary>
    /// The ID of the message.
    /// </summary>
    string Id
    {
      get;
    }

    /// <summary>
    /// The notification of the message. This is expected to be displayed to a user.
    /// </summary>
    string Notification
    {
      get;
    }

    /// <summary>
    /// The provider used to send this message. If null, the default provider is used.
    /// </summary>
    string Provider
    {
      get;
      set;
    }

    /// <summary>
    /// The subchannel of which the message was or will be sent.
    /// </summary>
    string Subchannel
    {
      get;
    }
  }
}
