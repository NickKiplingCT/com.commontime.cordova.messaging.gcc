using System;
using System.IO;

using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace CommonTime.Notification
{
  public sealed class AzureStorageBlobReference
  {
    public const string Prefix = "#azureStorageBlobRef:";
    private const char Separator = '#';

    public static AzureStorageBlobReference Parse(string description)
    {
      if (description.IndexOf(Prefix) == 0)
      {
        string uriString = null;
        JToken context = null;

        int separatorPosition = description.IndexOf(Separator, Prefix.Length);

        if (separatorPosition == -1)
        {
          uriString = description.Substring(Prefix.Length);
        }
        else
        {
          uriString = description.Substring(Prefix.Length, separatorPosition - Prefix.Length);
          context = JToken.Parse(description.Substring(separatorPosition + 1));
        }

        return new AzureStorageBlobReference(new Uri(uriString), context, description);
      }
      else
      {
        return null;
      }
    }

    private static string MakeDescription(Uri uri, JToken context)
    {
      if (context == null)
      {
        return string.Format("{0}{1}", Prefix, uri);
      }
      else
      {
        if (context == null)
        {
          return string.Format("{0}{1}", Prefix, uri);
        }
        else
        {
          using (TextWriter textWriter = new StringWriter())
          {
            using (JsonTextWriter jsonWriter = new JsonTextWriter(textWriter))
            {
              jsonWriter.Formatting = Formatting.None;

              context.WriteTo(jsonWriter);

              return string.Format("{0}{1}{2}{3}", Prefix, uri, Separator, textWriter.ToString());
            }
          }
        }
      }
    }

    private readonly Uri uri;
    private readonly JToken context;
    private readonly string description;

    public AzureStorageBlobReference(Uri uri, JToken context)
      : this(uri, context, MakeDescription(uri, context))
    {
    }

    private AzureStorageBlobReference(Uri uri, JToken context, string description)
    {
      if (uri == null)
      {
        throw new ArgumentException("the URI in a content reference cannot be null");
      }

      this.uri = uri;
      this.context = context;
      this.description = description;
    }

    public Uri Uri
    {
      get
      {
        return uri;
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
      return uri.GetHashCode();
    }

    public override bool Equals(object obj)
    {
      return obj is AzureStorageBlobReference && Equals((AzureStorageBlobReference) obj);
    }

    public static bool operator ==(AzureStorageBlobReference lhs, AzureStorageBlobReference rhs)
    {
      if (lhs == null)
      {
        return rhs != null;
      }
      else
      {
        return lhs.Equals(rhs);
      }
    }

    public static bool operator !=(AzureStorageBlobReference lhs, AzureStorageBlobReference rhs)
    {
      return !(lhs == rhs);
    }

    #region IEquatable<FileReference> Members

    public bool Equals(AzureStorageBlobReference other)
    {
      return other != null & uri.Equals(other.uri);
    }

    #endregion
  }
}
