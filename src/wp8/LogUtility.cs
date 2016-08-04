using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CommonTime.Logging
{
  public class LogUtility
  {
    public const string AllDescription = "ALL";
    public const string TraceDescription = "TRACE";
    public const string DebugDescription = "DEBUG";
    public const string InfoDescription = "INFO";
    public const string WarnDescription = "WARN";
    public const string ErrorDescription = "ERROR";
    public const string FatalDescription = "FATAL";
    public const string OffDescription = "OFF";

    public const string AllPrettyDescription = "All";
    public const string TracePrettyDescription = "Trace";
    public const string DebugPrettyDescription = "Debug";
    public const string InfoPrettyDescription = "Info";
    public const string WarnPrettyDescription = "Warn";
    public const string ErrorPrettyDescription = "Error";
    public const string FatalPrettyDescription = "Fatal";
    public const string OffPrettyDescription = "Off";

    public static string GetDescriptionFromLevel(LogLevel level)
    {
      switch (level)
      {
        case LogLevel.All:
        {
          return AllDescription;
        }
        case LogLevel.Trace:
        {
          return TraceDescription;
        }
        case LogLevel.Debug:
        {
          return DebugDescription;
        }
        case LogLevel.Info:
        {
          return InfoDescription;
        }
        case LogLevel.Warn:
        {
          return WarnDescription;
        }
        case LogLevel.Error:
        {
          return ErrorDescription;
        }
        case LogLevel.Fatal:
        {
          return FatalDescription;
        }
        case LogLevel.Off:
        {
          return OffDescription;
        }
        default:
        {
          throw new ApplicationException("Unrecognised log level: " + level);
        }
      }
    }

    public static string GetPrettyDescriptionFromLevel(LogLevel level)
    {
      switch (level)
      {
        case LogLevel.All:
        {
          return AllPrettyDescription;
        }
        case LogLevel.Trace:
        {
          return TracePrettyDescription;
        }
        case LogLevel.Debug:
        {
          return DebugPrettyDescription;
        }
        case LogLevel.Info:
        {
          return InfoPrettyDescription;
        }
        case LogLevel.Warn:
        {
          return WarnPrettyDescription;
        }
        case LogLevel.Error:
        {
          return ErrorPrettyDescription;
        }
        case LogLevel.Fatal:
        {
          return FatalPrettyDescription;
        }
        case LogLevel.Off:
        {
          return OffPrettyDescription;
        }
        default:
        {
          throw new ApplicationException("Unrecognised log level: " + level);
        }
      }
    }

    public static LogLevel GetLevelFromDescription(string description)
    {
      string canonical = description.Trim().ToUpperInvariant();

      switch (canonical)
      {
        case AllDescription:
        {
          return LogLevel.All;
        }
        case TraceDescription:
        {
          return LogLevel.Trace;
        }
        case DebugDescription:
        {
          return LogLevel.Debug;
        }
        case InfoDescription:
        {
          return LogLevel.Info;
        }
        case WarnDescription:
        {
          return LogLevel.Warn;
        }
        case ErrorDescription:
        {
          return LogLevel.Error;
        }
        case FatalDescription:
        {
          return LogLevel.Fatal;
        }
        case OffDescription:
        {
          return LogLevel.Off;
        }
        default:
        {
          throw new ApplicationException("Cannot convert " + description + " to log level");
        }
      }
    }

    public static string Format(DateTime time, LogLevel level, string source, string message)
    {
      return string.Format("{0} {1,-5} {2} - {3}",
                           DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff"),
                           GetDescriptionFromLevel(level),
                           source,
                           message);
    }

    private LogUtility()
    {
    }
  }
}
