using System;
using System.Collections.Generic;
using System.IO;
using System.IO.IsolatedStorage;
using System.Text;

using CommonTime.Logging;

using Newtonsoft.Json.Linq;

namespace CommonTime.Notification
{
  internal sealed class ContentManager
  {
    public const uint MaxContentSize = 3 * 1024;

    private const string Directory = "/mDesign/shell";

    private readonly Logger logger;

    public ContentManager(Logger logger)
    {
      this.logger = logger;
    }

    public bool ContainsFileReferences(JToken source)
    {
      return Satisfies(s => s.IndexOf(FileReference.Prefix) == 0, source);
    }

    public bool ContainsFileData(JToken source)
    {
      return Satisfies(s => s.IndexOf(FileData.Prefix) == 0, source);
    }

    public JToken ExpandFileReferences(JToken source)
    {
      return CopyAndApply(ExpandFileReferences, source);
    }

    private string ExpandFileReferences(string source)
    {
      FileReference fileReference = FileReference.Parse(source);

      if (fileReference == null)
      {
        return source;
      }

      FileData fileData = FileData.Load(fileReference.Path);

      logger.TraceFormat("Expanded {0} to data of {1} bytes", source, fileData.Data.Length);

      return fileData.ToString();
    }

    public JToken ExtractFileData(JToken source)
    {
      return CopyAndApply(ExtractFileData, source);
    }

    private string ExtractFileData(string source)
    {
      FileData fileData = FileData.Parse(source);

      if (fileData == null)
      {
        return source;
      }

      string path = CreateUniqueFilename(".bin");
      FileReference fileReference = new FileReference(path, null);

      WriteContent(path, fileData.Data);

      logger.TraceFormat("Wrote file data of {0} bytes to file referred to by {1}", fileData.Data.Length, fileReference);

      return fileReference.ToString();
    }

    public void DeleteFiles(JToken source)
    {
      Apply(DeleteFiles, source);
    }

    private void DeleteFiles(string source)
    {
      try
      {
        FileReference fileReference = FileReference.Parse(source);

        if (fileReference != null)
        {
          logger.TraceFormat("Deleting file referrered to by {0}", source);

          using (IsolatedStorageFile userStore = IsolatedStorageFile.GetUserStoreForApplication())
          {
            userStore.DeleteFile(fileReference.Path);
          }

          return;
        }

        ContentReference contentReference = ContentReference.Parse(source);

        if (contentReference != null)
        {
          logger.TraceFormat("Deleting file referrered to by {0}", source);

          using (IsolatedStorageFile userStore = IsolatedStorageFile.GetUserStoreForApplication())
          {
            userStore.DeleteFile(contentReference.Path);
          }

          return;
        }
      }
      catch (Exception e)
      {
        logger.WarnFormat("Cannot delete file referrered to by {0}: {1}", source, e.Message);
      }
    }

    public IList<FileReference> GetAllFileReferences(JToken source)
    {
      IList<FileReference> references = new List<FileReference>();

      Apply(s => AddIfFileReference(s, references), source);

      return references;
    }

    private void AddIfFileReference(string source, IList<FileReference> references)
    {
      FileReference fileReference = FileReference.Parse(source);

      if (fileReference != null)
      {
        references.Add(fileReference);
      }
    }

    public JToken CopyAllFileReferences(JToken source)
    {
      return CopyAndApply(CopyIfFileReference, source);
    }

    private string CopyIfFileReference(string source)
    {
      FileReference sourceReference = FileReference.Parse(source);

      if (sourceReference == null)
      {
        return source;
      }

      string destinationPath = CreateUniqueFilename(Path.GetExtension(sourceReference.Path));

      using (IsolatedStorageFile userStore = IsolatedStorageFile.GetUserStoreForApplication())
      {
        using (IsolatedStorageFileStream outputStream = new IsolatedStorageFileStream(destinationPath, FileMode.CreateNew, userStore))
        {
          using (IsolatedStorageFileStream inputStream = new IsolatedStorageFileStream(sourceReference.Path, FileMode.Open, userStore))
          {
            inputStream.CopyTo(outputStream);
          }
        }
      }

      FileReference destinationReference = new FileReference(destinationPath, sourceReference.Context);

      logger.TraceFormat("Copied {0} to {1}", sourceReference, destinationReference);

      return destinationReference.ToString();
    }

    public JToken ReplaceReference(JToken source, FileReference sourceReference, AzureStorageBlobReference blobReference)
    {
      return CopyAndApply(s => ReplaceReference(s, sourceReference, blobReference), source);
    }

    private string ReplaceReference(string source, FileReference sourceReference, AzureStorageBlobReference blobReference)
    {
      FileReference fileReference = FileReference.Parse(source);

      return fileReference == sourceReference ? blobReference.ToString() : source;
    }

    public FileReference FindFirstFileReference(JToken source)
    {
      FileReference fileReference = null;

      Satisfies(s =>
      {
        fileReference = FileReference.Parse(s);

        return fileReference != null;
      }, source);

      return fileReference;
    }

    #region Reading and write file

    public void WriteContent(string path, byte[] content)
    {
      using (IsolatedStorageFile userStore = IsolatedStorageFile.GetUserStoreForApplication())
      {
        using (IsolatedStorageFileStream outputStream = new IsolatedStorageFileStream(path, FileMode.Create, userStore))
        {
          using (MemoryStream inputStream = new MemoryStream(content))
          {
            inputStream.CopyTo(outputStream);
          }
        }
      }
    }

    public byte[] ReadContent(string path)
    {
      using (IsolatedStorageFile userStore = IsolatedStorageFile.GetUserStoreForApplication())
      {
        using (IsolatedStorageFileStream inputStream = new IsolatedStorageFileStream(path, FileMode.Open, userStore))
        {
          using (MemoryStream outputStream = new MemoryStream())
          {
            inputStream.CopyTo(outputStream);

            return outputStream.ToArray();
          }
        }
      }
    }

    public string CreateUniqueFilename(string extension)
    {
      using (IsolatedStorageFile userStore = IsolatedStorageFile.GetUserStoreForApplication())
      {
        if (!userStore.DirectoryExists(Directory))
        {
          userStore.CreateDirectory(Directory);
        }
      }

      string filename = string.Format("{0}{1}", Guid.NewGuid(), extension);

      return Path.Combine(Directory, filename);
    }

    #endregion

    #region Satisfies

    private bool Satisfies(Predicate<string> predicate, JToken source)
    {
      switch (source.Type)
      {
        case JTokenType.Array:
        {
          return Satisfies(predicate, (JArray) source);
        }
        case JTokenType.Object:
        {
          return Satisfies(predicate, (JObject) source);
        }
        case JTokenType.String:
        {
          return Satisfies(predicate, (string) source);
        }
        default:
        {
          return false;
        }
      }
    }

    private bool Satisfies(Predicate<string> predicate, JArray source)
    {
      for (int i = 0; i != source.Count; ++i)
      {
        if (Satisfies(predicate, source[i]))
        {
          return true;
        }
      }

      return false;
    }

    private bool Satisfies(Predicate<string> predicate, JObject source)
    {
      foreach (KeyValuePair<string, JToken> property in source)
      {
        if (Satisfies(predicate, property.Value))
        {
          return true;
        }
      }

      return false;
    }

    private bool Satisfies(Predicate<string> predicate, string source)
    {
      return predicate(source);
    }

    #endregion

    #region CopyAndApply

    public JToken CopyAndApply(Func<string, string> function, JToken source)
    {
      switch (source.Type)
      {
        case JTokenType.Array:
        {
          return CopyAndApply(function, (JArray) source);
        }
        case JTokenType.Object:
        {
          return CopyAndApply(function, (JObject) source);
        }
        case JTokenType.String:
        {
          return (JToken) CopyAndApply(function, (string) source);
        }
        default:
        {
          return source;
        }
      }
    }

    private JArray CopyAndApply(Func<string, string> function, JArray source)
    {
      JArray dest = new JArray();

      for (int i = 0; i != source.Count; ++i)
      {
        dest.Add(CopyAndApply(function, source[i]));
      }

      return dest;
    }

    private JObject CopyAndApply(Func<string, string> function, JObject source)
    {
      JObject dest = new JObject();

      foreach (KeyValuePair<string, JToken> property in source)
      {
        JToken expandedValue = CopyAndApply(function, property.Value);

        dest[property.Key] = expandedValue;
      }

      return dest;
    }

    private string CopyAndApply(Func<string, string> function, string source)
    {
      return function(source);
    }

    #endregion

    #region Apply

    public void Apply(Action<string> action, JToken source)
    {
      switch (source.Type)
      {
        case JTokenType.Array:
        {
          Apply(action, (JArray) source);

          break;
        }
        case JTokenType.Object:
        {
          Apply(action, (JObject) source);

          break;
        }
        case JTokenType.String:
        {
          Apply(action, (string) source);

          break;
        }
      }
    }

    private void Apply(Action<string> action, JArray source)
    {
      for (int i = 0; i != source.Count; ++i)
      {
        Apply(action, source[i]);
      }
    }

    private void Apply(Action<string> action, JObject source)
    {
      foreach (KeyValuePair<string, JToken> property in source)
      {
        Apply(action, property.Value);
      }
    }

    private void Apply(Action<string> action, string source)
    {
      action(source);
    }

    #endregion
  }
}
