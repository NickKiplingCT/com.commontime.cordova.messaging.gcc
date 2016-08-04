using System;
using System.Collections.Generic;
using System.IO.IsolatedStorage;

using CommonTime.Logging;

using Microsoft.WindowsAzure.MobileServices;

namespace CommonTime.Notification.Zumo
{
  public sealed class ZumoProvider : MessageProvider
  {
    private static MobileServiceAuthenticationProvider ParseAuthenticationMethod(string method)
    {
      switch (method)
      {
        case "facebook":
        {
          return MobileServiceAuthenticationProvider.Facebook;
        }
        case "google":
        {
          return MobileServiceAuthenticationProvider.Google;
        }
        case "microsoftaccount":
        {
          return MobileServiceAuthenticationProvider.MicrosoftAccount;
        }
        case "twitter":
        {
          return MobileServiceAuthenticationProvider.Twitter;
        }
        case "windowsazureactivedirectory":
        {
          return MobileServiceAuthenticationProvider.WindowsAzureActiveDirectory;
        }
        default:
        {
          throw new ArgumentException("Unsupported authentication method: " + method);
        }
      }
    }

    private const string UserIdKey = "ZumoUserId";
    private const string TokenKey = "ZumoToken";

    private readonly bool useStorage;

    private string userId;
    private string token;

    private MobileServiceClient mobileServiceClient;

    internal ZumoProvider(Logger logger, Uri applicationUrl, bool useStorage)
      : base(logger)
    {
      this.useStorage = useStorage;

      LoadSettings();

      mobileServiceClient = new MobileServiceClient(applicationUrl);

      mobileServiceClient.CurrentUser = new MobileServiceUser(userId);
      mobileServiceClient.CurrentUser.MobileServiceAuthenticationToken = token;
    }

    public override string Name
    {
      get
      {
        return ZumoName;
      }
    }

    public bool UseStorage
    {
      get
      {
        return useStorage;
      }
    }

    public MobileServiceClient MobileServiceClient
    {
      get
      {
        return mobileServiceClient;
      }
    }

    public void ClearAuthenticationToken()
    {
      try
      {
        mobileServiceClient.LogoutAsync();

        userId = null;
        token = null;
        SaveSettings();
      }
      catch (Exception)
      {
      }
    }

    protected override MessageReceiver MakeReceiver(string channel)
    {
      throw new NotImplementedException();
    }

    protected override MessageSender MakeSender(IMessage message)
    {
      return new ZumoSender(this, Logger, mobileServiceClient, message);
    }

    internal bool ShouldPostResponse(IMessage message)
    {
      return message.Subchannel != "ignoreresponse";
    }

    internal override void OnMessageExpired(MessageStore source, IMessage message)
    {
      if (ShouldPostResponse(message) && source == MessageStore.Outbox)
      {
        PostResponse(message, null, "expired", "The message has expired", TimeSpan.FromDays(999 * 365));
      }
    }

    public override void PrepareForInitialSending(IMessage message)
    {
      if (useStorage)
      {
        message.Content = ContentManager.CopyAllFileReferences(message.Content);
      }
      else
      {
        if (ContentManager.ContainsFileReferences(message.Content))
        {
          message.Content = ContentManager.ExpandFileReferences(message.Content);
        }
      }
    }

    public async void Authenticate(string method)
    {
      try
      {
        Logger.InfoFormat("Will try to authenticate with Azure App Services using {0}", method);

        MobileServiceUser user = await mobileServiceClient.LoginAsync(ParseAuthenticationMethod(method));

        Logger.InfoFormat("Authenticated with Azure App Services and obtained the user ID {0}", user.UserId);

        userId = user.UserId;
        token = user.MobileServiceAuthenticationToken;
        SaveSettings();

        OnAuthenticationSucceeded();
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot authenticate using {0}: {1}", method, e.Message);
      }
    }

    private void SaveSettings()
    {
      IsolatedStorageSettings storage = IsolatedStorageSettings.ApplicationSettings;

      SaveSettings(storage);
      storage.Save();
    }

    private void SaveSettings(IDictionary<string, object> storage)
    {
      storage[UserIdKey] = userId == null ? null : userId;
      storage[TokenKey] = token == null ? null : token;
    }

    private void LoadSettings()
    {
      IsolatedStorageSettings storage = IsolatedStorageSettings.ApplicationSettings;

      LoadSettings(storage);
    }

    private void LoadSettings(IDictionary<string, object> storage)
    {
      object userIdObject;

      if (storage.TryGetValue(UserIdKey, out userIdObject))
      {
        userId = userIdObject as string;
      }

      object tokenObject;

      if (storage.TryGetValue(TokenKey, out tokenObject))
      {
        token = tokenObject as string;
      }
    }
  }
}
