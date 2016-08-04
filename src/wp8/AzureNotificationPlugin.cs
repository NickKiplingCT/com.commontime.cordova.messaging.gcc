using System;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Resources;
using System.Xml.Linq;

using CommonTime.Logging;
using CommonTime.Notification;
using CommonTime.Notification.Azure;

using Newtonsoft.Json.Linq;

namespace WPCordovaClassLib.Cordova.Commands
{
  public sealed class AzureNotificationPlugin : BaseCommand
  {
    public Logger Logger
    {
      get
      {
        return MessageProviderFactory.Instance.Logger;
      }
    }

    public void start(string args)
    {
      string callbackId = "";

      try
      {
        JArray parameters = JArray.Parse(args);
        string parameter = (string) parameters[0];

        callbackId = (string) parameters[1];

        if (MessageProviderFactory.Instance.HasProvider(MessageProvider.AzureName))
        {
          Logger.Info("The Azure Service Bus (ASB) notification plugin has already been started");

          DispatchCommandResult(new PluginResult(PluginResult.Status.OK), callbackId);

          return;
        }

        Logger.Info("Will start Azure Service Bus (ASB) notification plugin");
        
        string serviceBusHostname = null;
        string serviceNamespace = null;
        string sasKeyName = null;
        string sasKey = null;
        string brokerType = null;
        bool autoCreate = true;

        if (parameter == null)
        {
          StreamResourceInfo streamInfo = Application.GetResourceStream(new Uri("config.xml", UriKind.Relative));

          if (streamInfo != null)
          {
            StreamReader reader = new StreamReader(streamInfo.Stream);
            XDocument document = XDocument.Parse(reader.ReadToEnd());

            var preferences = from results in document.Descendants()
                              where results.Name.LocalName == "preference"
                              select new
                              {
                                name = (string) results.Attribute("name"),
                                value = (string) results.Attribute("value")
                              };

            foreach (var preference in preferences)
            {
              if (preference.name == "sbHostName")
              {
                serviceBusHostname = preference.value;
              }
              else if (preference.name == "serviceNamespace")
              {
                serviceNamespace = preference.value;
              }
              else if (preference.name == "sasKeyName")
              {
                sasKeyName = preference.value;
              }
              else if (preference.name == "sasKey")
              {
                sasKey = preference.value;
              }
              else if (preference.name == "brokerType")
              {
                brokerType = preference.value;
              }
              else if (preference.name == "brokerAutoCreate")
              {
                autoCreate = bool.Parse(preference.value);
              }
            }
          }
        }
        else
        {
          JObject options = JObject.Parse(parameter);

          serviceBusHostname = (string) options["sbHostName"];
          serviceNamespace = (string) options["serviceNamespace"];
          sasKeyName = (string) options["sasKeyName"];
          sasKey = (string) options["sasKey"];

          JToken brokerTypeToken;

          if (options.TryGetValue("brokerType", out brokerTypeToken))
          {
            brokerType = (string) brokerTypeToken;
          }

          JToken autoCreateToken;

          if (options.TryGetValue("brokerAutoCreate", out autoCreateToken))
          {
            autoCreate = (bool) autoCreateToken;
          }
        }

        MessageProvider provider = new AzureProvider(Logger, serviceBusHostname, serviceNamespace, new AzureProvider.SharedAccessProperties(sasKeyName, sasKey), autoCreate, brokerType);

        MessageProviderFactory.Instance.AddProvider(provider);
        provider.SendAllPendingMessages();

        DispatchCommandResult(new PluginResult(PluginResult.Status.OK), callbackId);
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot start Azure Service Bus notification plugin: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }
  }
}