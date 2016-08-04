using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CommonTime.Notification
{
  /// <summary>
  /// Event data for a MessageSend event
  /// </summary>
  public sealed class MessageSendEventArgs : EventArgs
  {
    internal MessageSendEventArgs(IMessage message)
    {
      this.Message = message;
    }

    internal MessageSendEventArgs(IMessage message, string details)
    {
      this.Message = message;
      this.Details = details;
    }

    /// <summary>
    /// The message that was attempted to be sent.
    /// </summary>
    public IMessage Message
    {
      get;
      private set;
    }

    /// <summary>
    /// The details for the event.
    /// </summary>
    public string Details
    {
      get;
      private set;
    }
  }
}
