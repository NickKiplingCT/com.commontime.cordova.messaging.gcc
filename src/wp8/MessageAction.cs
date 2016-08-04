namespace CommonTime.Notification
{
  public enum MessageAction
  {
    Created,
    Updated,
    Deleted,

    Sending,
    Sent,
    SendFailed,
    SendFailedWillRetry
  }
}
