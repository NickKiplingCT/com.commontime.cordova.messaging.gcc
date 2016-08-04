using System;

namespace CommonTime.Logging
{
  /// <summary>
  /// A destination for a logger's output. All methods should be thread safe.
  /// </summary>
  public interface ILogDestination : IDisposable
  {
    /// <summary>
    /// Writes a line to ths destination.
    /// </summary>
    /// <param name="time">The time at which this line was generated.</param>
    /// <param name="level">The level at which the line is logged.</param>
    /// <param name="source">The logger that generated the message.</param>
    /// <param name="message">The message to write.</param>
    void Write(DateTime time, LogLevel level, string source, string message);

    /// <summary>
    /// Gets the contents of the destination in UTF-8.
    /// In future implementations, the content will be compressed.
    /// </summary>
    /// <returns>A byte array containing the data, null if the content is not available.</returns>
    /// <exception cref="System.IO.Exception">Thrown if the contents can't be read.</exception>
    byte[] GetContent();
  }
}
