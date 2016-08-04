using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CommonTime.Notification
{
  public sealed class AzureStorageBlobAttachment : Attachment
  {
    private readonly FileReference fileReference;
    private AzureStorageBlobReference blobReference;

    public AzureStorageBlobAttachment(string identifier, IMessage message, FileReference fileReference)
      : this(identifier, message, fileReference, null)
    {
    }

    public AzureStorageBlobAttachment(string identifier, IMessage message, FileReference fileReference, AzureStorageBlobReference blobReference)
      : base(identifier, message)
    {
      this.fileReference = fileReference;
      this.blobReference = blobReference;
    }

    public FileReference FileReference
    {
      get
      {
        return fileReference;
      }
    }

    public AzureStorageBlobReference BlobReference
    {
      get
      {
        return blobReference;
      }
      set
      {
        blobReference = value;
      }
    }

    public override string LocalReference
    {
      get
      {
        return fileReference.ToString();
      }
    }

    public override string RemoteReference
    {
      get
      {
        return blobReference.ToString();
      }
    }

    public override string ToString()
    {
      return string.Format("Attachment {0}", Id);
    }
  }
}
