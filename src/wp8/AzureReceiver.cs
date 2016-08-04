using System;
using System.Net;
using System.IO;

using Newtonsoft.Json.Linq;

using CommonTime.Logging;

namespace CommonTime.Notification.Azure
{
  internal sealed class AzureReceiver : MessageReceiver, IAzureConnectionHandler
  {
    private readonly AzureConnection connection;

    public AzureReceiver(AzureProvider provider, Logger logger, string channel)
      : base(provider, logger, channel)
    {
      connection = new AzureConnection(provider, logger, this, channel);
    }

    internal override bool Start()
    {
      if (base.Start())
      {
        connection.Start();

        return true;
      }
      else
      {
        return false;
      }
    }

    public override string ToString()
    {
      return string.Format("Azure receiver on {0}", Channel);
    }

    #region IAzureConnectionHandler Members

    void IAzureConnectionHandler.OnRequestFailed(string details, bool shouldRetry)
    {
      base.OnRequestFailed(details, shouldRetry);
    }

    void IAzureConnectionHandler.OnConnectionFinished()
    {
      base.OnReceiverFinished();
    }

    void IAzureConnectionHandler.OnConnectionInitialized()
    {
      connection.BeginReceive();
    }

    #endregion
  }
}
