using System;
using System.Diagnostics;
using System.IO;
using System.Text;

namespace CommonTime.Logging
{
  public sealed class FileLogDestination : ILogDestination
  {
    private static readonly byte[] newLine = { 13, 10 };

    private const int MaximumSize = 512 * 1024;

    private readonly object synchronizationLock = new object();
    private readonly string directory;
    private readonly string path;
    private readonly string rolloverPath;

    private FileStream stream;
    private int currentSize = 0;

    public FileLogDestination(string directory)
    {
      this.directory = directory;

      path = Path.Combine(directory, "current.log");
      rolloverPath = Path.Combine(directory, "old.log");

      Open();
    }

    public void Pause()
    {
      lock (synchronizationLock)
      {
        Close();
      }
    }

    public void Restart()
    {
      lock (synchronizationLock)
      {
        Open();
      }
    }

    private void Open()
    {
      if (stream == null)
      {
        try
        {
          stream = new FileStream(path, FileMode.Append, FileAccess.Write, FileShare.ReadWrite);
          currentSize = (int) (new FileInfo(path)).Length;
        }
        catch (Exception e)
        {
          Debug.WriteLine(string.Format("Cannot open log file {0}: {1}", path, e.Message));
        }
      }
    }

    private void Close()
    {
      if (stream != null)
      {
        stream.Close();
        stream.Dispose();
        stream = null;
      }
    }

    private void Rollover()
    {
      lock (synchronizationLock)
      {
        try
        {
          Close();

          File.Delete(rolloverPath);
          File.Copy(path, rolloverPath);
          File.Delete(path);

          Open();
        }
        catch (Exception e)
        {
          Debug.WriteLine(string.Format("Cannot roll-over log file: {0}", e.Message));
        }
      }
    }

    private void DeleteFilesIfTooBig()
    {
      lock (synchronizationLock)
      {
        try
        {
          FileInfo info = new FileInfo(path);

          if (info.Length > MaximumSize)
          {
            Close();
            File.Delete(path);
            Open();
          }

          info = new FileInfo(rolloverPath);

          if (info.Length > MaximumSize)
          {
            File.Delete(rolloverPath);
          }
        }
        catch (Exception e)
        {
          Debug.WriteLine(string.Format("Cannot delete too-big log files: {0}", e.Message));
        }
      }
    }

    public void DeleteFiles()
    {
      lock (synchronizationLock)
      {
        try
        {
          Close();

          File.Delete(rolloverPath);
          File.Delete(path);

          Open();
        }
        catch (Exception e)
        {
          Debug.WriteLine("Cannot delete files: {0}", e.Message);
        }
      }
    }

    #region ILogDestination Members

    public void Write(DateTime time, LogLevel level, string source, string message)
    {
      if (stream == null)
      {
        return;
      }

      string line = LogUtility.Format(time, level, source, message);
      byte[] bytes = Encoding.UTF8.GetBytes(line);

      if (currentSize + bytes.Length + newLine.Length > MaximumSize)
      {
        Rollover();
      }

      lock (synchronizationLock)
      {
        currentSize += bytes.Length + newLine.Length;

        try
        {
          stream.Write(bytes, 0, bytes.Length);
          stream.Write(newLine, 0, newLine.Length);
          stream.Flush();
        }
        catch (Exception e)
        {
          Debug.WriteLine(string.Format("Cannot write log line: {0}", e.Message));
        }
      }
    }

    public byte[] GetContent()
    {
        byte[] content = null;

        using (MemoryStream memoryStream = new MemoryStream())
        {
          ConcatenateLogsToStream(memoryStream);
          content = memoryStream.ToArray();
        }

        return content;
    }

    public string ConcatenateLogsToFile(string filename)
    {
      string path = Path.Combine(directory, filename);

      using (FileStream fileStream = new FileStream(path, FileMode.Create))
      {
        ConcatenateLogsToStream(fileStream);
      }

      return path;
    }

    public void ConcatenateLogsToStream(Stream outputStream)
    {
      lock (synchronizationLock)
      {
        Close();

        if (File.Exists(rolloverPath))
        {
          using (FileStream rolloverStream = new FileStream(rolloverPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
          {
            rolloverStream.CopyTo(outputStream);
          }
        }

        if (File.Exists(path))
        {
          using (FileStream currentStream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
          {
            currentStream.CopyTo(outputStream);
          }
        }

        Open();
      }
    }

    #endregion

    #region IDisposable Members

    public void Dispose()
    {
      if (stream != null)
      {
        Close();
      }
    }

    #endregion
  }
}
