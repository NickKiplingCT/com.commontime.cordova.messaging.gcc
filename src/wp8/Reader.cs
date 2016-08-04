using System.Data.Linq.Mapping;

namespace CommonTime.Notification
{
  [Table]
  internal sealed class Reader
  {
    public Reader()
    {
    }

    [Column(IsPrimaryKey = true, CanBeNull = false, IsDbGenerated = true)]
    public int Id
    {
      get;
      set;
    }

    [Column(CanBeNull = false)]
    public string MessageId
    {
      get;
      set;
    }

    [Column(CanBeNull = false)]
    public string Name
    {
      get;
      set;
    }
  }
}
