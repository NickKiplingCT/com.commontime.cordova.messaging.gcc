using System;
using System.Net;

using CommonTime.Logging;

using Newtonsoft.Json.Linq;

namespace CommonTime.Notification.Rest
{
  public sealed class RestProvider : MessageProvider
  {
    internal RestProvider(Logger logger)
      : base(logger)
    {
    }

    public ICredentials Credentials
    {
      get;
      set;
    }

    public CookieContainer CookieContainer
    {
      get;
      set;
    }

    public override string Name
    {
      get
      {
        return RestName;
      }
    }

    internal void OnFinished(RestSender sender)
    {
      sender.Dispose();
    }

    protected override MessageSender MakeSender(IMessage message)
    {
      return new RestSender(this, Logger, message);
    }

    protected override MessageReceiver MakeReceiver(string channel)
    {
      throw new NotImplementedException();
    }

    public override void PrepareForInitialSending(IMessage message)
    {
      if (ContentManager.ContainsFileReferences(message.Content))
      {
        message.Content = ContentManager.ExpandFileReferences(message.Content);
      }
    }

    internal override void OnMessageExpired(MessageStore source, IMessage message)
    {
    }
  }
}
