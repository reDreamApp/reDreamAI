# The key the box runs with. It can call Generative APIs (chat, Whisper) and
# read/write objects in this project's buckets — nothing else: no instances,
# no IAM, no deleting backups. The admin key used to run OpenTofu never goes
# onto the box.

resource "scaleway_iam_application" "runtime" {
  name        = "redreamai-runtime"
  description = "Runtime identity of the reDreamAI box: Generative APIs + backup uploads."
}

resource "scaleway_iam_policy" "runtime" {
  name           = "redreamai-runtime"
  description    = "Generative APIs model access and Object Storage read/write (no delete) in the reDreamAI project."
  application_id = scaleway_iam_application.runtime.id

  rule {
    project_ids = [var.project_id]
    permission_set_names = [
      "GenerativeApisModelAccess",
      # Backups: upload, list, and download for a restore. Expiry is the
      # bucket's lifecycle rules (storage.tf), so no delete permission.
      "ObjectStorageBucketsRead",
      "ObjectStorageObjectsRead",
      "ObjectStorageObjectsWrite",
    ]
  }
}

# Rotate with: tofu apply -replace=scaleway_iam_api_key.runtime
resource "scaleway_iam_api_key" "runtime" {
  application_id     = scaleway_iam_application.runtime.id
  description        = "reDreamAI box runtime (ai.env SCALEWAY_API_KEY, backup.env)"
  default_project_id = var.project_id
}
