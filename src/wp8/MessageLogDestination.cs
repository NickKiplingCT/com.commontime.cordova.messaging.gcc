using System;

using CommonTime.Logging;

using Newtonsoft.Json.Linq;

namespace CommonTime.Notification
{
  public sealed class MessageLogDestination : ILogDestination
  {
    private static readonly DateTime Epoch = new DateTime(1970, 1, 1, 0, 0, 0);

    public MessageProvider Provider
    {
      get;
      set;
    }

    public string Channel
    {
      get;
      set;
    }

    public string Subchannel
    {
      get;
      set;
    }

    public string Notification
    {
      get;
      set;
    }

    public TimeSpan TimeToLive
    {
      get;
      set;
    }

    #region ILogDestination Members

    public int MaximumSize
    {
      get
      {
        return 0;
      }
      set
      {
      }
    }

    public void Write(DateTime time, LogLevel level, string source, string message)
    {
      if (Provider == null)
      {
        return;
      }

      JObject content = new JObject();

      content["level"] = LogUtility.GetDescriptionFromLevel(level);
      content["name"] = source;
      content["detail"] = message;
      content["timestamp"] = (long) (time - Epoch).TotalMilliseconds; 

      Provider.Send(MessageFactory.Instance.MakeMessage(Channel, Subchannel, content.ToString(), Notification, TimeToLive));
    }

    public byte[] GetContent()
    {
      return null;
    }

    #endregion

    #region IDisposable Members

    public void Dispose()
    {
    }

    #endregion
  }
}
