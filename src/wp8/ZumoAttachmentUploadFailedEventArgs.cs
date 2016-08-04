using System;

namespace CommonTime.Notification.Zumo
{
  public class ZumoAttachmentUploadFailedEventArgs : EventArgs
  {
    public ZumoAttachmentUploadFailedEventArgs(Exception e, RetryStrategy retryStrategy)
    {
      Exception = e;
      RetryStrategy = retryStrategy;
    }

    public Exception Exception
    {
      get;
      private set;
    }

    public RetryStrategy RetryStrategy
    {
      get;
      private set;
    }
  }
}
