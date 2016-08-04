using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace CommonTime.Logging
{
  /// <summary>
  /// A logger that can output to a number of destinations and at various levels. All methods are thread safe.
  /// It cannot be constructed directly, but must be created using a LogFactory. 
  /// <see cref="LogFactory"/>
  /// </summary>
  public sealed class Logger
  {
    #region Converting between log levels and their descriptions



    #endregion

    private readonly string source;
    private readonly string name;
    private readonly object synchronizationLock = new object();
    private readonly bool isSecure;

    private HashSet<ILogDestination> destinations = new HashSet<ILogDestination>();
    private LogLevel minimumLevel = LogLevel.Info;

    public Logger(string source, string name, bool isSecure = false)
    {
      this.source = source;
      this.name = name;
      this.isSecure = isSecure;
    }

    /// <summary>
    /// The source of this logger.
    /// </summary>
    public string Source
    {
      get
      {
        return source;
      }
    }

    /// <summary>
    /// The name of this logger.
    /// </summary>
    public string Name
    {
      get
      {
        return name;
      }
    }

    /// <summary>
    /// The minimum level at which this logger logs.
    /// </summary>
    public LogLevel MinimumLevel
    {
      get
      {
        return minimumLevel;
      }
      set
      {
        minimumLevel = value;
      }
    }

    /// <summary>
    /// All the destinations to which this logger logs.
    /// </summary>
    public ISet<ILogDestination> AllDestinations
    {
      get
      {
        return destinations;
      }
    }

    /// <summary>
    /// Add a destination to this logger. An attempt to add a destination twice will be ignored.
    /// </summary>
    /// <param name="destination">The destination to add.</param>
    public void AddDestination(ILogDestination destination)
    {
      lock (synchronizationLock)
      {
        destinations.Add(destination);
      }
    }

    /// <summary>
    /// Returns whether this logger is logging to the given destination.
    /// </summary>
    /// <param name="destination">The destination.</param>
    /// <returns>Whether this logger is logging to the given destination.</returns>
    public bool ContainsDestination(ILogDestination destination)
    {
      lock (synchronizationLock)
      {
        return destinations.Contains(destination);
      }
    }

    /// <summary>
    /// Remove a destination from this logger.
    /// </summary>
    /// <param name="destination">The destination to remove.</param>
    public void RemoveDestination(ILogDestination destination)
    {
      lock (synchronizationLock)
      {
        destinations.Remove(destination);
      }
    }

    /// <summary>
    /// Remove all destinations of the given type.
    /// </summary>
    /// <param name="type"></param>
    public void RemoveDestinations(Type type)
    {
      lock (synchronizationLock)
      {
        HashSet<ILogDestination> newDestinations = new HashSet<ILogDestination>();

        foreach (ILogDestination destination in destinations)
        {
          if (destination.GetType() != type)
          {
            newDestinations.Add(destination);
          }
        }

        destinations = newDestinations;
      }
    }

    /// <summary>
    /// Remove all destinations from this logger.
    /// </summary>
    public void RemoveAllDestinations()
    {
      lock (synchronizationLock)
      {
        destinations.Clear();
      }
    }

    /// <summary>
    /// Log a message at trace level, provided this logger is logging at that level.
    /// </summary>
    /// <param name="message">The message to log.</param>
    public void Trace(string message)
    {
      Log(LogLevel.Trace, message);
    }

    /// <summary>
    /// Format a message and log it at trace level, provided this logger is logging at that level.
    /// </summary>
    /// <param name="format">The format of the message.</param>
    /// <param name="args">The arguments to the format string.</param>
    /// <see cref="System.String.Format"/>
    public void TraceFormat(string format, params object[] args)
    {
      LogFormat(LogLevel.Trace, format, args);
    }

    /// <summary>
    /// Log a message at debug level, provided this logger is logging at that level.
    /// </summary>
    /// <param name="message">The message to log.</param>
    public void Debug(string message)
    {
      Log(LogLevel.Debug, message);
    }

    /// <summary>
    /// Format a message and log it at debug level, provided this logger is logging at that level.
    /// </summary>
    /// <param name="format">The format of the message.</param>
    /// <param name="args">The arguments to the format string.</param>
    /// <see cref="System.String.Format"/>
    public void DebugFormat(string format, params object[] args)
    {
      LogFormat(LogLevel.Debug, format, args);
    }

    /// <summary>
    /// Log a message at info level, provided this logger is logging at that level.
    /// </summary>
    /// <param name="message">The message to log.</param>
    public void Info(string message)
    {
      Log(LogLevel.Info, message);
    }

    /// <summary>
    /// Format a message and log it at info level, provided this logger is logging at that level.
    /// </summary>
    /// <param name="format">The format of the message.</param>
    /// <param name="args">The arguments to the format string.</param>
    /// <see cref="System.String.Format"/>
    public void InfoFormat(string format, params object[] args)
    {
      LogFormat(LogLevel.Info, format, args);
    }

    /// <summary>
    /// Log a message at warn level, provided this logger is logging at that level.
    /// </summary>
    /// <param name="message">The message to log.</param>
    public void Warn(string message)
    {
      Log(LogLevel.Warn, message);
    }

    /// <summary>
    /// Format a message and log it at warn level, provided this logger is logging at that level.
    /// </summary>
    /// <param name="format">The format of the message.</param>
    /// <param name="args">The arguments to the format string.</param>
    /// <see cref="System.String.Format"/>
    public void WarnFormat(string format, params object[] args)
    {
      LogFormat(LogLevel.Warn, format, args);
    }

    /// <summary>
    /// Log a message at error level, provided this logger is logging at that level.
    /// </summary>
    /// <param name="message">The message to log.</param>
    public void Error(string message)
    {
      Log(LogLevel.Error, message);
    }

    /// <summary>
    /// Format a message and log it at error level, provided this logger is logging at that level.
    /// </summary>
    /// <param name="format">The format of the message.</param>
    /// <param name="args">The arguments to the format string.</param>
    /// <see cref="System.String.Format"/>
    public void ErrorFormat(string format, params object[] args)
    {
      LogFormat(LogLevel.Error, format, args);
    }

    /// <summary>
    /// Log a message at fatal level, provided this logger is logging at that level.
    /// </summary>
    /// <param name="message">The message to log.</param>
    public void Fatal(string message)
    {
      Log(LogLevel.Fatal, message);
    }

    /// <summary>
    /// Format a message and log it at fatal level, provided this logger is logging at that level.
    /// </summary>
    /// <param name="format">The format of the message.</param>
    /// <param name="args">The arguments to the format string.</param>
    /// <see cref="System.String.Format"/>
    public void FatalFormat(string format, params object[] args)
    {
      LogFormat(LogLevel.Fatal, format, args);
    }

    /// <summary>
    /// Log a message at the given level, provided this logger is logging at that level.
    /// </summary>
    /// <param name="level">The level at which to log</param>
    /// <param name="message">The message to log.</param>
    public void Log(LogLevel level, string message)
    {
      if (level >= minimumLevel)
      {
        Write(level, message);
      }
    }

    /// <summary>
    /// Format a message and log it at the given leve, provided this logger is logging at that level.
    /// </summary>
    /// <param name="level">The level at which to log.</param>
    /// <param name="format">The format of the message.</param>
    /// <param name="args">The arguments to the format string.</param>
    /// <see cref="System.String.Format"/>
    public void LogFormat(LogLevel level, string format, params object[] args)
    {
      if (level >= minimumLevel)
      {
        Write(level, string.Format(format, args));
      }
    }

    private void Write(LogLevel level, string message)
    {
      DateTime now = DateTime.Now;

      if (isSecure)
      {
        message = Encrypt(message);
      }

      lock (synchronizationLock)
      {
        foreach (ILogDestination destination in destinations)
        {
          destination.Write(now, level, source, message);
        }
      }
    }

    private string Encrypt(string plainText)
    {
      return Convert.ToBase64String(Encrypt(Encoding.UTF8.GetBytes(plainText)));
    }

    private byte[] Encrypt(byte[] plainText)
    {
      using (AesManaged aes = new AesManaged())
      {
        aes.Key = new byte[] { 0xb4, 0x2a, 0x73, 0x73, 0xc7, 0xf1, 0x4c, 0xa3, 0x99, 0x09, 0x5b, 0x06, 0xbe, 0xc9, 0xc6, 0x78 };
        aes.IV = new byte[] { 0xd0, 0x7b, 0x6b, 0xaf, 0x86, 0x5d, 0x47, 0x19, 0xaa, 0x80, 0xef, 0x87, 0xc7, 0x24, 0x19, 0xb };

        using (ICryptoTransform encryptor = aes.CreateEncryptor())
        {
          MemoryStream memoryStream = new MemoryStream();

          using (CryptoStream cryptoStream = new CryptoStream(memoryStream, encryptor, CryptoStreamMode.Write))
          {
            cryptoStream.Write(plainText, 0, plainText.Length);
            cryptoStream.FlushFinalBlock();

            return memoryStream.ToArray();
          }
        }
      }
    }
  }
}
