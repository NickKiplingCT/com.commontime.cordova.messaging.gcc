namespace CommonTime.Logging
{
  /// <summary>
  /// The levels at which a logger can log. Note the values correspond to those used in Log4Net.
  /// </summary>
  public enum LogLevel
  {
    All = 0,
    Trace = 5000,
    Debug = 10000,
    Info = 20000,
    Warn = 30000,
    Error = 40000,
    Fatal = 50000,
    Off = 1000000,
  }
}
