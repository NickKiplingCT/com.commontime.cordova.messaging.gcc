using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CommonTime.Notification
{
  internal sealed class ContentReference : IEquatable<ContentReference>
  {
    public const string Prefix = "#contentref:";

    public static ContentReference Parse(string description)
    {
      if (description.IndexOf(Prefix) == 0)
      {
        string path = description.Substring(Prefix.Length);

        return new ContentReference(path, description);
      }
      else
      {
        return null;
      }
    }

    private static string MakeDescription(string path)
    {
      return string.Format("{0}{1}", Prefix, path);
    }

    private readonly string path;
    private readonly string description;

    public ContentReference(string path)
      : this(path, MakeDescription(path))
    {
    }

    private ContentReference(string path, string description)
    {
      if (path == null)
      {
        throw new ArgumentException("the path in a file reference cannot be null");
      }

      this.path = path;
      this.description = description;
    }

    public string Path
    {
      get
      {
        return path;
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
      return Equals(obj as ContentReference);
    }

    public static bool operator ==(ContentReference lhs, ContentReference rhs)
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

    public static bool operator !=(ContentReference lhs, ContentReference rhs)
    {
      return !(lhs == rhs);
    }

    #region IEquatable<ContentReference> Members

    public bool Equals(ContentReference other)
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
