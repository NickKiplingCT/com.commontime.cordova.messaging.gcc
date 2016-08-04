using System;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Resources;
using System.Xml.Linq;

using Microsoft.Phone.Controls;

using CommonTime.Logging;
using CommonTime.Notification;
using CommonTime.Notification.Zumo;

using Newtonsoft.Json.Linq;

namespace WPCordovaClassLib.Cordova.Commands
{
  public sealed class ZumoNotificationPlugin : BaseCommand
  {
    private readonly CordovaView cordovaView;

    private string authenticationMethod = null;

    public ZumoNotificationPlugin()
    {
      try
      {
        PhoneApplicationFrame frame = (PhoneApplicationFrame) Application.Current.RootVisual;
        PhoneApplicationPage page = (PhoneApplicationPage) frame.Content;

        cordovaView = (CordovaView) page.FindName("CordovaView");
      }
      catch (Exception)
      {
      }
    }

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

        if (MessageProviderFactory.Instance.HasProvider(MessageProvider.ZumoName))
        {
          Logger.Info("The Azure App Services notification plugin has already been started");

          DispatchCommandResult(new PluginResult(PluginResult.Status.OK), callbackId);

          return;
        }

        Logger.Info("Will start the Azure App Services notification plugin");

        Uri applicationUri = null;
        bool useStorage = false;

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
              if (preference.name.Equals("zumoUrl", StringComparison.InvariantCultureIgnoreCase))
              {
                applicationUri = new Uri(preference.value);
              }
              else if (preference.name.Equals("zumoAuthenticationMethod", StringComparison.InvariantCultureIgnoreCase))
              {
                authenticationMethod = preference.value;
              }
              else if (preference.name.Equals("zumoUseBlobStorage", StringComparison.InvariantCultureIgnoreCase))
              {
                useStorage = bool.Parse(preference.value);
              }
            }
          }
        }
        else
        {
          JObject options = JObject.Parse(parameter);

          applicationUri = new Uri((string) options["url"]);
          authenticationMethod = (string) options["authenticationMethod"];

          JToken useStorageToken;

          if (options.TryGetValue("useBlobStorage", out useStorageToken))
          {
            useStorage = (bool) useStorageToken;
          }
        }

        ZumoProvider provider = new ZumoProvider(Logger, applicationUri, useStorage);

        provider.AuthenticationRequired += OnAuthenticationRequired;

        MessageProviderFactory.Instance.AddProvider(provider);
        provider.SendAllPendingMessages();

        DispatchCommandResult(new PluginResult(PluginResult.Status.OK), callbackId);
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot start the Azure App Services notification plugin: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    public void logout(string args)
    {
      string callbackId = "";

      try
      {
        JArray parameters = JArray.Parse(args);

        callbackId = (string) parameters[0];

        ((ZumoProvider) MessageProviderFactory.Instance.GetProvider(MessageProvider.ZumoName)).ClearAuthenticationToken();

        DispatchCommandResult(new PluginResult(PluginResult.Status.OK), callbackId);
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot log out of Azure App Services: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }

    private void OnAuthenticationRequired(object sender, EventArgs e)
    {
      try
      {
        cordovaView.Dispatcher.BeginInvoke(() => ((ZumoProvider) sender).Authenticate(authenticationMethod));
      }
      catch (Exception ex)
      {
        Logger.WarnFormat("Cannot authenticate ZUMO call: {0}", ex.Message);
      }
    }
  }
}
