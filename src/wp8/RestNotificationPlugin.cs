using System;

using CommonTime.Logging;
using CommonTime.Notification;
using CommonTime.Notification.Rest;

using Newtonsoft.Json.Linq;

namespace WPCordovaClassLib.Cordova.Commands
{
  public sealed class RestNotificationPlugin : BaseCommand
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

        callbackId = (string) parameters[0];

        if (MessageProviderFactory.Instance.HasProvider(MessageProvider.RestName))
        {
          Logger.Info("The RESTT notification plugin has already been started");

          DispatchCommandResult(new PluginResult(PluginResult.Status.OK), callbackId);

          return;
        }
        
        Logger.Info("Will start the REST notification plugin");

        MessageProvider provider = new RestProvider(Logger);

        MessageProviderFactory.Instance.AddProvider(provider);
        provider.SendAllPendingMessages();

        DispatchCommandResult(new PluginResult(PluginResult.Status.OK), callbackId);
      }
      catch (Exception e)
      {
        Logger.WarnFormat("Cannot start the REST notification plugin: {0}", e.Message);

        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message), callbackId);
      }
    }
  }
}
