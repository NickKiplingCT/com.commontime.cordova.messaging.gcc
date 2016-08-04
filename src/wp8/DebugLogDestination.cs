using System;
using System.Diagnostics;

namespace CommonTime.Logging
{
  public sealed class DebugLogDestination : ILogDestination
  {
    #region ILogDestination Members

    public void Write(string line)
    {
      Debug.WriteLine(line);
    }

    public void Write(DateTime time, LogLevel level, string source, string message)
    {
      Debug.WriteLine(LogUtility.Format(time, level, source, message));
    }

    public byte[] GetContent()
    {
      return null;
    }

    #endregion

    #region IDisposable Members

    public void Dispose()
    {
    }

    #endregion
  }
}
