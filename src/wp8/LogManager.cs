using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

using Windows.Storage;

namespace CommonTime.Logging
{
  public sealed class LogManager
  {
    private static LogManager instance = new LogManager();

    private static string TrimLogContent(string content, int maximumLength)
    {
      if (content.Length <= maximumLength)
      {
        return content;
      }

      int start = content.Length - maximumLength;
      int firstLinePosition = content.IndexOf("\r\n", start);

      if (firstLinePosition >= 0)
      {
        start = firstLinePosition + 2;
      }

      return content.Substring(start, content.Length - start);
    }

    private static string GetLogFilename()
    {
      return SanitizeFilename(string.Format("mDesign-{0}.log", DateTime.Now));
    }

    private static string SanitizeFilename(string filename)
    {
      StringBuilder builder = new StringBuilder(filename.Length);
      char[] invalidCharacters = Path.GetInvalidFileNameChars();

      for (int i = 0; i != filename.Length; ++i)
      {
        char c = filename[i];
        bool sanitize = false;

        for (int j = 0; !sanitize && j != invalidCharacters.Length; ++j)
        {
          if (invalidCharacters[j] == c)
          {
            sanitize = true;
          }
        }

        builder.Append(sanitize ? '_' : c);
      }

      return builder.ToString();
    }

    private readonly IDictionary<string, Logger> loggers = new Dictionary<string, Logger>();

    private readonly FileLogDestination fileDestination;
    private readonly DebugLogDestination debugDestination;

    /// <summary>
    /// The single instance of this class.
    /// </summary>
    public static LogManager Instance
    {
      get
      {
        return instance;
      }
    }

    private LogManager()
    {
      StorageFolder folder = Windows.Storage.ApplicationData.Current.LocalFolder;
      string logPath = Path.Combine(folder.Path);

      debugDestination = new DebugLogDestination();
      fileDestination = new FileLogDestination(logPath);
    }

    /// <summary>
    /// The destination for all file output.
    /// </summary>
    public FileLogDestination FileDestination
    {
      get
      {
        return fileDestination;
      }
    }

    /// <summary>
    /// The destination for all debug (console) output.
    /// </summary>
    public DebugLogDestination DebugDestination
    {
      get
      {
        return debugDestination;
      }
    }

    /// <summary>
    /// Returns the logger with the given name.
    /// </summary>
    /// <param name="name">The name of the logger.</param>
    /// <returns>The logger with the given name, null if no such logger</returns>
    public Logger GetLoggerByName(string name)
    {
      Logger logger = null;

      loggers.TryGetValue(name, out logger);

      return logger;
    }

    /// <summary>
    /// Adds a logger to this manager's collection, replacing any existing 
    /// logger with the the logger's name.
    /// </summary>
    /// <param name="logger">the logger to add</param>
    public void AddLogger(Logger logger)
    {
      loggers[logger.Name] = logger;    
    }

    /// <summary>
    /// Removes the logger from this manager's collection.
    /// </summary>
    /// <param name="logger">the logger to remove</param>
    public void RemoveLogger(Logger logger)
    {
      loggers.Remove(logger.Name);
    }

    /// <summary>
    /// Enables all loggers by setting their minimum level to All.
    /// </summary>
    public void EnableAllLoggers()
    {
      foreach (Logger logger in loggers.Values)
      {
        logger.MinimumLevel = LogLevel.All;
      }
    }

    /// <summary>
    /// Disables all loggers by setting their minimum level to Off.
    /// </summary>
    public void DisableAllLoggers()
    {
      foreach (Logger logger in loggers.Values)
      {
        logger.MinimumLevel = LogLevel.Off;
      }
    }

    #region IDisposable Members

    public void Dispose()
    {
      fileDestination.Dispose();
      debugDestination.Dispose();
    }

    #endregion
  }
}
