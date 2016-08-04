namespace CommonTime.Notification
{
  public enum RetryStrategy
  {
    Never,
    WhenAuthenticated,
    Immediately,
    AfterDefaultPeriod
  }
}
