using System;
using System.IO;

using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace CommonTime.Notification
{
  public sealed class FileReference : IEquatable<FileReference>
  {
    public const string Prefix = "#fileref:";
    private const char Separator = '#';

    public static FileReference Parse(string description)
    {
      if (description.IndexOf(Prefix) == 0)
      {
        string path = null;
        JToken context = null;

        int separatorPosition = description.IndexOf(Separator, Prefix.Length);

        if (separatorPosition == -1)
        {
          path = description.Substring(Prefix.Length);
        }
        else
        {
          path = description.Substring(Prefix.Length, separatorPosition - Prefix.Length);
          context = JToken.Parse(description.Substring(separatorPosition + 1));
        }

        return new FileReference(path, context, description);
      }
      else
      {
        return null;
      }
    }

    private static string MakeDescription(string path, JToken context)
    {
      if (context == null)
      {
        return string.Format("{0}{1}", Prefix, path);
      }
      else
      {
        using (TextWriter textWriter = new StringWriter())
        {
          using (JsonTextWriter jsonWriter = new JsonTextWriter(textWriter))
          {
            jsonWriter.Formatting = Formatting.None;

            context.WriteTo(jsonWriter);

            return string.Format("{0}{1}{2}{3}", Prefix, path, Separator, textWriter.ToString());
          }
        }
      }
    }

    private readonly string path;
    private readonly JToken context;
    private readonly string description;

    public FileReference(string path, JToken context)
      : this(path, context, MakeDescription(path, context))
    {
    }    

    private FileReference(string path, JToken context, string description)
    {
      if (path == null)
      {
        throw new ArgumentException("the path in a file reference cannot be null");
      }

      this.path = path;
      this.context = context;
      this.description = description;
    }

    public string Path
    {
      get
      {
        return path;
      }
    }

    public JToken Context
    {
      get
      {
        return context;
      }
    }

    public override string ToString()
    {
      return description;
    }

    public override int GetHashCode()
    {
      return path.GetHashCode();
    }

    public override bool Equals(object obj)
    {
      return this.Equals(obj as FileReference);
    }

    public static bool operator ==(FileReference lhs, FileReference rhs)
    {
      if (object.ReferenceEquals(lhs, null))
      {
        return object.ReferenceEquals(rhs, null);
      }
      else
      {
        return lhs.Equals(rhs);
      }
    }

    public static bool operator !=(FileReference lhs, FileReference rhs)
    {
      return !(lhs == rhs);
    }

    #region IEquatable<FileReference> Members

    public bool Equals(FileReference other)
    {
      if (object.ReferenceEquals(other, null))
      {
        return false;
      }

      if (object.ReferenceEquals(this, other))
      {
        return true;
      }

      return path == other.Path;
    }

    #endregion
  }
}
