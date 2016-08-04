using System;

using Newtonsoft.Json.Linq;

namespace CommonTime.Notification
{
  internal sealed class Message : IMessage
  {
    public Message()
    {
    }

    public override bool Equals(object obj)
    {
      Message other = obj as Message;

      return other != null && Id == other.Id;
    }

    public override int GetHashCode()
    {
      return Id.GetHashCode();
    }

    public override string ToString()
    {
      return string.Format("Message {0}", Id);
    }

    #region IMessage Members

    public string Id
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

    public JToken Content
    {
      get;
      set;
    }

    public string Notification
    {
      get;
      set;
    }

    public DateTime CreatedDate
    {
      get;
      set;
    }

    public DateTime ExpiryDate
    {
      get;
      set;
    }

    public string Provider
    {
      get;
      set;
    }

    #endregion
  }
}
