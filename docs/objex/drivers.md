# Drivers

Objex drivers are separate Go modules. Import the driver package and pass its
configuration to `objex.New` to receive the shared `objex.Store` interface.

## Driver Comparison

| Feature | Filesystem | AWS S3 | MinIO |
| --- | --- | --- | --- |
| **Primary use** | Local development, tests, disk storage | AWS S3 and S3-compatible services | MinIO servers |
| **External service** | No | Yes | Yes |
| **Minimum Go version** | 1.22.2 | 1.22.2 | 1.23.0 |
| **Upload behavior** | Streams to a file | AWS multipart-capable uploader | Requires size; may buffer non-seekable readers |
| **Stored content type** | No | Yes | Yes |
| **Presigned URLs** | Application-enforced | S3-enforced | MinIO-enforced |
| **Health check** | Creates/verifies base directory | Calls `ListBuckets` | Validates configuration only |
| **Missing `Metadata`** | `ErrObjectNotFound` | `nil, nil` when recognized | `nil, nil` when recognized |

---

## Filesystem Driver

The filesystem driver maps buckets to directories and objects to files.

```go
import (
	"github.com/brian-nunez/objex"
	"github.com/brian-nunez/objex/drivers/filesystem"
)

store, err := objex.New(filesystem.Config{
	BasePath:  "./storage",
	BaseURL:   "https://files.example.com",
	SecretKey: os.Getenv("FILESYSTEM_URL_SECRET"),
})
```

| Field | Required | Description |
| --- | --- | --- |
| `BasePath` | Yes | Root directory for buckets and objects. |
| `BaseURL` | For presigning | URL prefix used when generating filesystem URLs. |
| `SecretKey` | Recommended for presigning | HMAC-SHA256 signing key. |

Call `Setup` before use to create `BasePath`:

```go
if err := store.Setup(ctx); err != nil {
	log.Fatal(err)
}
```

### Filesystem Behavior

* `SetBucket` creates and selects the bucket directory.
* `CreateObject` creates missing parent directories and returns an MD5 ETag.
* `UpdateObject` overwrites or creates an object.
* `DeleteBucket` recursively deletes the bucket and all of its objects.
* `Exists` and `Metadata` read the complete file to calculate its ETag.
* `contentType` is not persisted; metadata reports `application/octet-stream`.
* `CleanUp` does not remove files. Delete temporary storage explicitly.

!!! warning "Validate filesystem object names"
    Object names are passed through `filepath.Join`. Do not pass untrusted paths
    directly. Reject absolute paths, `..` traversal, and names outside your
    application's expected key format before calling the driver. Also consider
    symlink behavior when users can modify the storage directory.

### Filesystem Presigned URLs

The driver constructs URLs such as:

```text
https://files.example.com/assets/logo.png?method=GET&expires=...&signature=...
```

It does not run an HTTP server or authorize requests. The service behind
`BaseURL` must:

1. Require the query-string method to match the HTTP method.
2. Reject requests after the Unix `expires` value.
3. Recalculate the HMAC-SHA256 signature over
   `METHOD:URL_PATH:EXPIRES` using the same secret.
4. Resolve and serve the requested object without allowing path traversal.

Without `SecretKey`, generated URLs are not cryptographically signed.

---

## AWS S3 Driver

The AWS driver uses AWS SDK for Go v2 and supports AWS S3 plus compatible
services that implement the required S3 operations.

```go
import (
	"github.com/brian-nunez/objex"
	objexaws "github.com/brian-nunez/objex/drivers/aws"
)

store, err := objex.New(objexaws.Config{
	Region:    "us-east-1",
	Bucket:    "my-app-assets",
	AccessKey: os.Getenv("AWS_ACCESS_KEY_ID"),
	SecretKey: os.Getenv("AWS_SECRET_ACCESS_KEY"),
	Token:     os.Getenv("AWS_SESSION_TOKEN"),
})
```

| Field | Description |
| --- | --- |
| `Region` | Signing region; defaults to `us-east-1`. |
| `Bucket` | Optional bucket selected when the store is created. |
| `Endpoint` | Optional custom endpoint without `http://` or `https://`. |
| `AccessKey` | Static access key. |
| `SecretKey` | Static secret key. |
| `Token` | Optional session token. |
| `UseSSL` | Uses HTTPS for a custom endpoint. |
| `UsePathStyle` | Enables path-style URLs for compatible providers. |

For a local S3-compatible endpoint:

```go
store, err := objex.New(objexaws.Config{
	Region:       "us-east-1",
	Endpoint:     "localhost:9000",
	AccessKey:    "minioadmin",
	SecretKey:    "minioadmin",
	UseSSL:       false,
	UsePathStyle: true,
})
```

### AWS Behavior

* `HealthCheck` calls `ListBuckets`. Credentials need `s3:ListAllMyBuckets`,
  even when the application only accesses one bucket.
* `SetBucket` verifies the bucket with `HeadBucket`; any failure is returned as
  `objex.ErrBucketNotFound`.
* `CreateBucket` maps every service error to
  `objex.ErrBucketAlreadyExists`.
* `CreateObject` uses the AWS multipart-capable uploader.
* `UpdateObject` requires an existing object and preserves its content type.
* `ListObjects` performs one `ListObjectsV2` request and does not paginate.
  Applications must not rely on it returning more than one response page.
* `SetRegion` does not rebuild the AWS client or change its signing region.
  Configure the correct region before constructing the store.
* Several AWS SDK errors are returned directly rather than normalized.

!!! note "AWS credentials"
    The driver always installs a static credential provider from `AccessKey`,
    `SecretKey`, and `Token`. Configure these values explicitly; it does not
    rely on the SDK's default environment, shared-config, or instance-role
    credential chain.

---

## MinIO Driver

The MinIO driver uses `minio-go` and is intended for MinIO object servers.

```go
import (
	"github.com/brian-nunez/objex"
	objexminio "github.com/brian-nunez/objex/drivers/minio"
)

store, err := objex.New(objexminio.Config{
	Endpoint:  "localhost:9000",
	AccessKey: os.Getenv("MINIO_ACCESS_KEY"),
	SecretKey: os.Getenv("MINIO_SECRET_KEY"),
	UseSSL:    false,
	Region:    "us-east-1",
})
```

| Field | Required | Description |
| --- | --- | --- |
| `Endpoint` | Yes | Host and port without a URL scheme. |
| `AccessKey` | Yes | Static access key. |
| `SecretKey` | Yes | Static secret key. |
| `Token` | No | Optional session token. |
| `UseSSL` | No | Uses HTTPS when `true`. |
| `Region` | No | Bucket creation region; defaults to `us-east-1`. |
| `UsePathStyle` | No | Present in config but currently unused. |

### MinIO Behavior

* `NewStore` validates required configuration but does not contact the server.
* `HealthCheck` only validates local configuration; use a bucket or object call
  when startup must prove server reachability and credentials.
* `SetBucket` checks the bucket with `BucketExists`.
* `UpdateObject` requires an existing object and preserves its content type.
* `ListObjects` is recursive and consumes the SDK result channel until closed.
* Uploads require a known size. Files and `io.ReadSeeker` values avoid
  buffering; other readers are fully buffered in memory before upload.
* `UsePathStyle` currently has no effect.

For large uploads, prefer an `*os.File` or another `io.ReadSeeker`:

```go
file, err := os.Open("large-video.mp4")
if err != nil {
	return err
}
defer file.Close()

_, err = store.CreateObject(
	ctx,
	"videos/large-video.mp4",
	file,
	"video/mp4",
)
```

## Choosing a Driver

Use the filesystem driver for local development, tests, and deployments where
the application owns a durable local volume. Use AWS for S3 or providers with
S3-compatible APIs. Use MinIO when targeting MinIO directly and its SDK
behavior is preferred.

Keep business logic typed against `objex.Store`, but test the selected
production driver for the backend-specific behaviors listed above.

