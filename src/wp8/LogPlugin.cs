using System;
using System.Text;

using Microsoft.Phone.Controls;

using WPCordovaClassLib.Cordova;

using CommonTime.Logging;

using Newtonsoft.Json.Linq;

namespace WPCordovaClassLib.Cordova.Commands
{
  public sealed class LogPlugin : BaseCommand
  {
    public void log(string args)
    {
      try
      {
        JArray parameters = JArray.Parse(args);
        string name = (string) parameters[0];
        LogLevel priority = LogUtility.GetLevelFromDescription((string) parameters[1]);
        string message = (string) parameters[2];

        LogManager.Instance.GetLoggerByName(name).Log(priority, message);
 
        DispatchCommandResult(new PluginResult(PluginResult.Status.OK));
      }
      catch (Exception e)
      {
        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message));
      }
    }

    public void enable()
    {
      try
      {
        LogManager.Instance.EnableAllLoggers();
      }
      catch (Exception e)
      {
        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message));
      }
    }

    public void disable()
    {
      try
      {
        LogManager.Instance.DisableAllLoggers();
      }
      catch (Exception e)
      {
        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message));
      }
    }

    public void upload(string callbackId, Uri uri)
    {
      try
      {
        throw new NotImplementedException("upload is not implemented");
      }
      catch (Exception e)
      {
        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message));
      }
    }

    public void mail(string callbackId, string recipient)
    {
      try
      {
        throw new NotImplementedException("upload is not implemented");
      }
      catch (Exception e)
      {
        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message));
      }
    }

    private void DeleteLogFiles(string callbackId)
    {
      try
      {
        LogManager.Instance.FileDestination.DeleteFiles();

        DispatchCommandResult(new PluginResult(PluginResult.Status.OK));
      }
      catch (Exception e)
      {
        DispatchCommandResult(new PluginResult(PluginResult.Status.ERROR, e.Message));
      }
    }
  }
}
