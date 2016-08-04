using System;
using System.Threading;

using CommonTime.Logging;

namespace CommonTime.Notification
{
  public abstract class MessageReceiver : IDisposable
  {
#if DEBUG
    private readonly static TimeSpan TimeBetweenRetries = TimeSpan.FromMinutes(1);
#else
    private readonly static TimeSpan TimeBetweenRetries = TimeSpan.FromMinutes(5);
#endif

    private readonly MessageProvider provider;
    private readonly Logger logger;
    private readonly string channel;

    private bool isRunning = false;
    private Timer retryTimer;

    internal MessageReceiver(MessageProvider provider, Logger logger, string channel)
    {
      this.provider = provider;
      this.logger = logger;
      this.channel = channel;
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

    public string Channel
    {
      get
      {
        return channel;
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
          logger.TraceFormat("Started {0}", this);
        }

        isRunning = true;

        return true;
      }
    }

    internal virtual void Stop()
    {
      if (isRunning)
      {
        isRunning = false;

        if (logger != null)
        {
          logger.TraceFormat("Stopped {0}", this);
        }
      }
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

    protected void StartRetryTimer()
    {
      StartRetryTimer(TimeBetweenRetries);
    }

    protected void StartRetryTimer(TimeSpan delay)
    {
      if (logger != null)
      {
        logger.TraceFormat("Will retry {0} in {1}", this, TimeBetweenRetries);
      }

      retryTimer = new Timer(OnRetry, null, delay, TimeSpan.FromMilliseconds(-1));
    }

    private void OnRetry(object obj)
    {
      Start();
    }

    protected void OnRequestCompleted(bool shouldRestart)
    {
      OnRequestCompleted(shouldRestart, TimeSpan.Zero);
    }

    protected void OnRequestCompleted(bool shouldRestart, TimeSpan delay)
    {
      if (logger != null)
      {
        logger.TraceFormat("Request completed on {0}; {1} retry", this, shouldRestart ? "will" : "will not");
      }

      if (shouldRestart)
      {
        Stop();

        if (delay == TimeSpan.Zero)
        {
          Start();
        }
        else
        {
          StartRetryTimer();
        }
      }
      else
      {
        OnReceiverFinished();
      }
    }

    protected void OnRequestFailed(string message, bool shouldRetry)
    {
      bool willRetry = isRunning && shouldRetry;

      if (message != null && logger != null)
      {
        logger.WarnFormat("Request failed: {0} {1} retry", message, willRetry ? "Will" : "Will not");
      }

      if (willRetry)
      {
        Stop();
        StartRetryTimer();
      }
      else
      {
        OnReceiverFinished();
      }
    }

    protected void OnReceiverFinished()
    {
      if (logger != null)
      {
        logger.InfoFormat("Finished with {0}", this);
      }

      provider.OnReceiverFinished(this);
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
