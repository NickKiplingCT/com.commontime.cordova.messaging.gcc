using System;
using System.Threading;

using CommonTime.Logging;

namespace CommonTime.Notification
{
  public abstract class MessageSender : IDisposable
  {
#if DEBUG
    private readonly static TimeSpan TimeBetweenRetries = TimeSpan.FromSeconds(30);
#else
    private readonly static TimeSpan TimeBetweenRetries = TimeSpan.FromMinutes(5);
#endif

    private readonly MessageProvider provider;
    private readonly Logger logger;
    private readonly IMessage message;

    private bool isRunning = false;
    private Timer retryTimer;

    internal MessageSender(MessageProvider provider, Logger logger, IMessage message)
    {
      this.provider = provider;
      this.logger = logger;
      this.message = message;
    }

    protected MessageProvider Provider
    {
      get
      {
        return provider;
      }
    }

    protected Logger Logger
    {
      get
      {
        return logger;
      }
    }

    protected IMessage Message
    {
      get
      {
        return message;
      }
    }

    protected bool IsRunning
    {
      get
      {
        return isRunning;
      }
    }
 
    internal virtual bool Start()
    {
      if (isRunning)
      {
        return false;
      }
      else
      {
        if (logger != null)
        {
          logger.TraceFormat("Starting {0}", this);
        }

        isRunning = true;

        return true;
      }
    }

    internal virtual bool Stop()
    {
      if (isRunning)
      {
        CancelRetryTimer();

        if (logger != null)
        {
          logger.InfoFormat("Stopped {0}", this);
        }

        isRunning = false;

        return true;
      }
      else
      {
        return false;
      }
    }

    protected void OnSent()
    {
      if (Logger != null)
      {
        logger.TraceFormat("Sent {0}", message);
      }

      MessageStore.Outbox.OnSentMessage(message);
      OnSenderFinished();
    }

    protected virtual bool OnRequestFailed(string details, RetryStrategy retryStrategy)
    {
      bool willRetry = isRunning && (retryStrategy == RetryStrategy.WhenAuthenticated || (retryStrategy != RetryStrategy.Never && message.ExpiryDate > DateTime.Now));

      MessageStore.Outbox.OnFailedToSendMessage(message, willRetry);

      switch (retryStrategy)
      {
        case RetryStrategy.AfterDefaultPeriod:
        {
          Stop();

          if (details != null && logger != null)
          {
            logger.WarnFormat("{0} failed: {1}; will retry in {2}", this, details, TimeBetweenRetries);
          }

          StartRetryTimer(TimeBetweenRetries);

          break;
        }
        case RetryStrategy.Immediately:
        {
          Stop();

          if (details != null && logger != null)
          {
            logger.WarnFormat("{0} failed: {1}; will retry immediately", this, details);
          }

          Start();

          break;
        }
        case RetryStrategy.WhenAuthenticated:
        {
          Stop();

          if (details != null && logger != null)
          {
            logger.WarnFormat("{0} failed: {1}; will retry when authenticated", this, details);
          }

          StartRetryTimer(TimeSpan.FromDays(30));

          break;
        }
        case RetryStrategy.Never:
        {
          if (details != null && logger != null)
          {
            logger.WarnFormat("{0} failed: {1}; will not retry", this, details);
          }

          OnSenderFinished();

          break;
        }
      }

      return willRetry;
    }

    protected void OnSenderFinished()
    {
      if (logger != null)
      {
        logger.InfoFormat("Finished with {0}", this);
      }

      provider.OnSenderFinished(this);
    }

    private void CancelRetryTimer()
    {
      if (retryTimer != null)
      {
        retryTimer.Change(TimeSpan.FromMilliseconds(-1), TimeSpan.FromMilliseconds(-1));
        retryTimer.Dispose();
        retryTimer = null;
      }
    }

    protected void StartRetryTimer(TimeSpan delay)
    {
      retryTimer = new Timer(OnRetry, null, delay, TimeSpan.FromMilliseconds(-1));
    }

    private void OnRetry(object obj)
    {
      Start();
    }

    public void ResendNow()
    {
      if (retryTimer != null)
      {
        retryTimer.Change(0, 0);
      }
    }

    #region IDisposable Members

    public void Dispose()
    {
      Dispose(true);
      GC.SuppressFinalize(this);           
    }

    protected virtual void Dispose(bool disposing)
    {
      if (disposing)
      {
        CancelRetryTimer();
      }
    }

    #endregion
  }
}
