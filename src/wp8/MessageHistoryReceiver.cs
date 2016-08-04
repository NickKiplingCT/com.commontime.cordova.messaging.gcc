using System;
using System.Threading;

using CommonTime.Logging;

namespace CommonTime.Notification
{
  public abstract class MessageHistoryReceiver : IDisposable
  {
#if DEBUG
    private readonly static TimeSpan TimeBetweenRetries = TimeSpan.FromMinutes(1);
#else
    private readonly static TimeSpan TimeBetweenRetries = TimeSpan.FromMinutes(5);
#endif

    private readonly MessageProvider provider;
    private readonly Logger logger;

    private bool isRunning = false;
    private Timer retryTimer;

    internal MessageHistoryReceiver(MessageProvider provider, Logger logger)
    {
      this.provider = provider;
      this.logger = logger;
    }

    protected bool IsRunning
    {
      get
      {
        return isRunning;
      }
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

    internal virtual void Start()
    {
      if (!isRunning)
      {
        isRunning = true;
        BeginSend();
      }
    }

    protected abstract void BeginSend();

    internal virtual void Stop()
    {
      if (isRunning)
      {
        CancelRetryTimer();

        if (logger != null)
        {
          logger.InfoFormat("Stopped {0}", this);
        }

        isRunning = false;
      }
    }

    protected void OnGotHistory()
    {
      OnFinished();
    }

    protected void OnRequestCompleted(bool shouldRestart)
    {
      if (logger != null)
      {
        logger.TraceFormat("Request completed on {0}; {1} retry", this, shouldRestart ? "will" : "will not");
      }

      if (shouldRestart)
      {
        Stop();
        Start();
      }
      else
      {
        OnFinished();
      }
    }

    protected void OnFailed(string details, bool shouldRetry)
    {
      bool willRetry = isRunning && shouldRetry;

      if (details != null && logger != null)
      {
        logger.WarnFormat("{0} failed: {1} {2} retry", this, details, willRetry ? "Will" : "Will not");
      }

      if (willRetry)
      {
        StartRetryTimer();
      }
      else
      {
        OnFinished();
      }
    }

    private void OnFinished()
    {
      if (logger != null)
      {
        logger.InfoFormat("Finished with {0}", this);
      }

      provider.OnHistoryFinished(this);
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
      if (logger != null)
      {
        logger.TraceFormat("Will retry {0} in {1}", this, TimeBetweenRetries);
      }

      retryTimer = new Timer(OnRetry, null, TimeBetweenRetries, TimeSpan.FromMilliseconds(-1));
    }

    private void OnRetry(object obj)
    {
      Start();
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
