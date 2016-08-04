using System;
using System.Collections.Generic;

using CommonTime.Logging;

namespace CommonTime.Notification.Azure
{
  public sealed class AzureProvider : MessageProvider
  {
    public class SharedAccessProperties
    {
      private readonly string key;
      private readonly string keyName;

      public SharedAccessProperties(string keyName, string key)
      {
        this.keyName = keyName;
        this.key = key;
      }

      internal string Key
      {
        get
        {
          return key;
        }
      }

      internal string KeyName
      {
        get
        {
          return keyName;
        }
      }
    }

    public class AccessControlProperties
    {
      private readonly string hostname;
      private readonly string namespaceOwner;
      private readonly string namespaceKey;

      public AccessControlProperties(string hostname, string namespaceOwner, string namespaceKey)
      {
        this.hostname = hostname;
        this.namespaceOwner = namespaceOwner;
        this.namespaceKey = namespaceKey;
      }

      internal string Hostname
      {
        get
        {
          return hostname;
        }
      }

      internal string NamespaceKey
      {
        get
        {
          return namespaceKey;
        }
      }

      internal string NamespaceOwner
      {
        get
        {
          return namespaceOwner;
        }
      }

    }


    private readonly Logger logger;

    private readonly string serviceBusHostname;
    private readonly string serviceNamespace;
    private readonly AccessControlProperties accessControl;
    private readonly SharedAccessProperties sharedAccess;
    private readonly bool autoCreate;
    private readonly string brokerType;

    private readonly IDictionary<string, AzureReceiver> receivers = new Dictionary<string, AzureReceiver>();
    private readonly object synchronizationObject = new object();

    private AzureProvider(Logger logger,
                          string serviceBusHostname,
                          string serviceNamespace,
                          bool autoCreate,
                          string brokerType)
      : base(logger)
    {
      this.logger = logger;
      this.serviceBusHostname = serviceBusHostname;
      this.serviceNamespace = serviceNamespace;
      this.autoCreate = autoCreate;
      this.brokerType = brokerType;
    }

    public AzureProvider(Logger logger,
                         string serviceBusHostname,
                         string serviceNamespace,
                         AccessControlProperties accessControl,
                         bool autoCreate,
                         string brokerType)
      : this(logger, serviceBusHostname, serviceNamespace, autoCreate, brokerType)
    {
      this.accessControl = accessControl;
    }

    public AzureProvider(Logger logger,
                         string serviceBusHostname,
                         string serviceNamespace,
                         SharedAccessProperties sharedAccess,
                         bool autoCreate,
                         string brokerType)
      : this(logger, serviceBusHostname, serviceNamespace, autoCreate, brokerType)
    {
      this.sharedAccess = sharedAccess;
    }

    internal string ServiceBusHostname
    {
      get
      {
        return serviceBusHostname;
      }
    }

    internal string ServiceNamespace
    {
      get
      {
        return serviceNamespace;
      }
    }

    internal AccessControlProperties AccessControl
    {
      get
      {
        return accessControl;
      }
    }

    internal SharedAccessProperties SharedAccess
    {
      get
      {
        return sharedAccess;
      }
    }

    internal bool AutoCreate
    {
      get
      {
        return autoCreate;
      }
    }

    internal string BrokerType
    {
      get
      {
        return brokerType;
      }
    }

    internal bool UseQueues
    {
      get
      {
        return !UseTopics;
      }
    }

    internal bool UseTopics
    {
      get
      {
        return brokerType != null && string.Equals(brokerType, "topic", StringComparison.InvariantCultureIgnoreCase);
      }
    }

    public override string Name
    {
      get
      {
        return AzureName;
      }
    }

    protected override MessageSender MakeSender(IMessage message)
    {
      return new AzureSender(this, Logger, message.Channel, message);
    }

    protected override MessageReceiver MakeReceiver(string channel)
    {
      return new AzureReceiver(this, Logger, channel);
    }
  }
}
