using System;
using System.Data.Linq.Mapping;

using Newtonsoft.Json.Linq;

namespace CommonTime.Notification
{
  [Table (Name="Message")]
  internal sealed class StoredMessage
  {
    public StoredMessage()
    {
    }

    [Column]
    public bool IsDeleted
    {
      get;
      set;
    }

    [Column(IsPrimaryKey = true, CanBeNull = false)]
    public string Id
    {
      get;
      set;
    }

    [Column]
    public string Channel
    {
      get;
      set;
    }

    [Column]
    public string Subchannel
    {
      get;
      set;
    }

    [Column]
    public string ContentString
    {
      get;
      set;
    }

    [Column]
    public string Notification
    {
      get;
      set;
    }

    [Column]
    public DateTime CreatedDate
    {
      get;
      set;
    }

    [Column]
    public DateTime ExpiryDate
    {
      get;
      set;
    }

    [Column]
    public string Provider
    {
      get;
      set;
    }

    public override string ToString()
    {
      return string.Format("Message {0}", Id);
    }
  }
}
