using CommonTime.Logging;

namespace CommonTime.Notification.Azure
{
  internal sealed class AzureSender : MessageSender, IAzureConnectionHandler
  {
    private readonly AzureConnection connection;

    public AzureSender(AzureProvider provider, Logger logger, string channel, IMessage message) :
      base(provider, logger, message)
    {
      connection = new AzureConnection(provider, logger, this, channel, message);
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
      return string.Format("Azure sender for {0}", Message);
    }

    #region IAzureConnectionHandler Members

    void IAzureConnectionHandler.OnRequestFailed(string details, bool shouldRetry)
    {
      base.OnRequestFailed(details, shouldRetry ? RetryStrategy.AfterDefaultPeriod : RetryStrategy.Never);
    }

    void IAzureConnectionHandler.OnConnectionFinished()
    {
      base.OnSenderFinished();
    }

    void IAzureConnectionHandler.OnConnectionInitialized()
    {
      connection.BeginSend();
    }

    #endregion
  }
}
