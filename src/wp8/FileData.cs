using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO;
using System.IO.IsolatedStorage;

namespace CommonTime.Notification
{
  public sealed class FileData
  {
    public const string Prefix = "#file:";

    private readonly byte[] data;

    public static FileData Load(string path)
    {
      using (MemoryStream outputStream = new MemoryStream())
      {
        using (IsolatedStorageFile userStore = IsolatedStorageFile.GetUserStoreForApplication())
        {
          using (IsolatedStorageFileStream inputStream = new IsolatedStorageFileStream(path, FileMode.Open, userStore))
          {
            inputStream.CopyTo(outputStream);

            return new FileData(outputStream.ToArray());
          }
        }
      }
    }

    public static FileData Parse(string source)
    {
      if (source.IndexOf(Prefix) == 0)
      {
        return new FileData(Convert.FromBase64String(source.Substring(Prefix.Length)));
      }
      else
      {
        return null;
      }
    }

    private FileData(byte[] data)
    {
      this.data = data;
    }

    public byte[] Data
    {
      get
      {
        return data;
      }
    }

    public override string ToString()
    {
      StringBuilder result = new StringBuilder(Prefix);

      result.Append(Convert.ToBase64String(data));

      return result.ToString();
    }
  }
}
