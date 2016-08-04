using System;
using System.Collections.Generic;

using CommonTime.Logging;
using CommonTime.Notification.Azure;

namespace CommonTime.Notification
{
  public sealed class MessageProviderFactory
  {
    private static MessageProviderFactory instance = new MessageProviderFactory();

    public static MessageProviderFactory Instance
    {
      get
      {
        return instance;
      }
    }

    private readonly IDictionary<string, MessageProvider> providers = new Dictionary<string, MessageProvider>();

    private Logger logger;

    private MessageProviderFactory()
    {
      LogManager logManager = LogManager.Instance;

      logger = new Logger("NFY", "notification");
      logManager.AddLogger(logger);
    }
    
    public string DefaultProviderName
    {
      get;
      set;
    }

    public MessageProvider DefaultProvider
    {
      get
      {
        return DefaultProviderName == null ? null : providers[DefaultProviderName];
      }
    }

    public Logger Logger
    {
      get
      {
        return logger;
      }
    }
    
    public void StartLogging()
    {
      LogManager logManager = LogManager.Instance;

      // Since we have no way of getting logs from the file system (atm)
      // don't bother adding the file destination
      //logger.AddDestination(logManager.FileDestination);
      logger.AddDestination(logManager.DebugDestination);

#if DEBUG
      logger.MinimumLevel = LogLevel.All;
#else
      logger.MinimumLevel = LogLevel.Info;
#endif
    }

    public void StopLogging()
    {
      logger.RemoveAllDestinations();
    }

    /// <summary>
    /// Adds a provider to the factory.
    /// </summary>
    /// <param name="provider">The factory to add</param>
    public void AddProvider(MessageProvider provider)
    {
      providers[provider.Name] = provider;    
    }

    /// <summary>
    /// Returns the provider with the given name.
    /// </summary>
    /// <param name="name">The name of the provider.</param>
    /// <returns>The provider with the given name, the default provider if name is null or empty.</returns>
    public MessageProvider GetProvider(string name)
    {
      MessageProvider provider = null;

      if (!string.IsNullOrWhiteSpace(name))
      {
        providers.TryGetValue(name, out provider);
      }

      return provider;
    }

    public bool HasProvider(string name)
    {
      return providers.ContainsKey(name);    
    }

    /// <summary>
    /// Clean up and dispose of any providers.
    /// </summary>
    public void Clear()
    {
      foreach (MessageProvider provider in providers.Values)
      {
        provider.Dispose();
      }

      providers.Clear();
    }
  }
}
