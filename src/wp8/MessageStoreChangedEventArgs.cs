using System;

namespace CommonTime.Notification
{
  /// <summary>
  /// Event data for a MessageStoreChanged event
  /// </summary>
  public sealed class MessageStoreChangedEventArgs : EventArgs
  {
    private readonly IMessage message;
    private readonly MessageAction action;

    internal MessageStoreChangedEventArgs(IMessage message, MessageAction action)
    {
      this.message = message;
      this.action = action;
    }

    /// <summary>
    /// The message in the store that was affected.
    /// </summary>
    public IMessage Message
    {
      get
      {
        return message;
      }
    }

    /// <summary>
    /// The action that was performed on the message.
    /// </summary>
    public MessageAction Action
    {
      get
      {
        return action;
      }
    }
  }
}
