namespace CommonTime.Notification
{
  public abstract class Attachment
  {
    private readonly string id;
    private readonly IMessage message;

    protected Attachment(string id, IMessage message)
    {
      this.id = id;
      this.message = message;
    }

    public IMessage Message
    {
      get
      {
        return message;
      }
    }

    public string Id
    {
      get
      {
        return id;
      }
    }

    public abstract string LocalReference
    {
      get;
    }

    public abstract string RemoteReference
    {
      get;
    }
  }
}
