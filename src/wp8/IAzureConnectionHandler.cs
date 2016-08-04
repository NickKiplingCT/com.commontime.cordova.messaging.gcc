
namespace CommonTime.Notification.Azure
{
  internal interface IAzureConnectionHandler
  {
    void OnRequestFailed(string details, bool shouldRetry);

    void OnConnectionFinished();

    void OnConnectionInitialized();
  }
}
