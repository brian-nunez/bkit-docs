# objex

`objex` provides one object-storage interface for AWS S3, MinIO, and the local
filesystem. Application code can upload, download, inspect, copy, move, and
presign objects without depending directly on a provider SDK.

[View source on GitHub](https://github.com/brian-nunez/objex){ .md-button }

## Store Interface

```go
type Store interface {
	Setup(ctx context.Context) error
	SetBucket(bucketName string) (bool, error)
	SetRegion(region string) error

	CreateBucket(ctx context.Context, bucketName string) error
	DeleteBucket(ctx context.Context, bucketName string) error
	ListBuckets(ctx context.Context) ([]Bucket, error)

	CreateObject(ctx context.Context, objectName string, data io.Reader, contentType string) (string, error)
	ReadObject(ctx context.Context, objectName string) (io.ReadCloser, error)
	ReadObjectRange(ctx context.Context, objectName string, offset, length int64) (io.ReadCloser, error)
	UpdateObject(ctx context.Context, objectName string, data io.Reader) (string, error)
	DeleteObject(ctx context.Context, objectName string) error
	ListObjects(ctx context.Context, bucketName string) ([]*ObjectMetaData, error)
	Exists(ctx context.Context, objectName string) (bool, *ObjectMetaData, error)
	Metadata(ctx context.Context, objectName string) (*ObjectMetaData, error)
	CopyObject(ctx context.Context, source, destination string) error
	MoveObject(ctx context.Context, source, destination string) error

	PresignGet(ctx context.Context, objectName string, expiration time.Duration) (string, error)
	PresignPut(ctx context.Context, objectName string, expiration time.Duration) (string, error)

	CleanUp() error
	HealthCheck(ctx context.Context) error
}
```

## Installation

Install the core package and the driver used by your application:

```bash
go get github.com/brian-nunez/objex
go get github.com/brian-nunez/objex/drivers/filesystem
go get github.com/brian-nunez/objex/drivers/aws
go get github.com/brian-nunez/objex/drivers/minio
```

Each driver is a separate Go module. Importing its package registers it with
`objex.New`.

## Quick Start

The filesystem driver is useful for learning the API without running an object
storage service:

```go
package main

import (
	"context"
	"io"
	"log"
	"strings"

	"github.com/brian-nunez/objex"
	"github.com/brian-nunez/objex/drivers/filesystem"
)

func main() {
	ctx := context.Background()

	store, err := objex.New(filesystem.Config{BasePath: "./storage"})
	if err != nil {
		log.Fatal(err)
	}
	defer store.CleanUp()

	if err := store.Setup(ctx); err != nil {
		log.Fatal(err)
	}
	if _, err := store.SetBucket("assets"); err != nil {
		log.Fatal(err)
	}

	etag, err := store.CreateObject(
		ctx,
		"notes/hello.txt",
		strings.NewReader("hello from objex"),
		"text/plain",
	)
	if err != nil {
		log.Fatal(err)
	}
	log.Println("ETag:", etag)

	reader, err := store.ReadObject(ctx, "notes/hello.txt")
	if err != nil {
		log.Fatal(err)
	}
	defer reader.Close()

	data, err := io.ReadAll(reader)
	if err != nil {
		log.Fatal(err)
	}
	log.Println(string(data))
}
```

`ReadObject` and `ReadObjectRange` return an `io.ReadCloser`. Always close it.

## Application Setup

Keep application services dependent on `objex.Store`, then choose a driver at
startup:

```go
type AvatarService struct {
	objects objex.Store
}

func NewAvatarService(objects objex.Store) *AvatarService {
	return &AvatarService{objects: objects}
}
```

```go
store, err := objex.New(filesystem.Config{BasePath: "./storage"})
if err != nil {
	return err
}
if err := store.Setup(ctx); err != nil {
	return err
}
if err := store.HealthCheck(ctx); err != nil {
	return err
}
```

`CleanUp` currently has no work for the bundled drivers, but calling it keeps
the application lifecycle independent of the selected backend.

## Buckets and Object Names

The simplest pattern is to dedicate one store instance to one bucket:

```go
found, err := store.SetBucket("assets")
if err != nil {
	return err
}
if !found {
	return objex.ErrBucketNotFound
}

_, err = store.CreateObject(ctx, "images/logo.png", body, "image/png")
```

After a bucket is selected, object methods accept keys relative to that bucket.
Without a selected bucket, AWS and MinIO require `bucket/key` names:

```go
_, err := store.CreateObject(
	ctx,
	"assets/images/logo.png",
	body,
	"image/png",
)
```

!!! warning "Store instances hold mutable bucket state"
    `SetBucket` changes the store instance. Do not switch buckets on a shared
    store while concurrent requests are using it. Prefer one initialized store
    per bucket, or consistently use full `bucket/key` names without calling
    `SetBucket`.

## Common Operations

### Uploading

```go
file, err := os.Open("report.pdf")
if err != nil {
	return err
}
defer file.Close()

etag, err := store.CreateObject(
	ctx,
	"reports/quarterly.pdf",
	file,
	"application/pdf",
)
```

The returned ETag is backend-specific. Do not treat it as a portable checksum:
filesystem ETags are MD5 values, while S3-compatible ETags may represent
multipart uploads or provider-specific behavior.

### Downloading

Stream downloads instead of loading complete objects into memory:

```go
reader, err := store.ReadObject(ctx, "reports/quarterly.pdf")
if err != nil {
	return err
}
defer reader.Close()

_, err = io.Copy(responseWriter, reader)
```

Read a section of a large object with a zero-based offset and byte length:

```go
reader, err := store.ReadObjectRange(
	ctx,
	"videos/demo.mp4",
	1_048_576,
	262_144,
)
```

Use a non-negative offset and a positive length.

### Existence and Metadata

Use `Exists` when a missing object is an expected result:

```go
exists, metadata, err := store.Exists(ctx, "images/logo.png")
if err != nil {
	return err
}
if !exists {
	return nil
}

log.Println(metadata.Key, metadata.Size, metadata.ContentType, metadata.ETag)
```

`Metadata` returns the same information, but missing-object behavior differs by
driver. Use `Exists` when portable not-found handling matters.

```go
type ObjectMetaData struct {
	Key          string
	Size         int64
	ContentType  string
	ETag         string
	LastModified string
}
```

`ListObjects` can return less detail than `Metadata`. In particular, filesystem
listings omit ETags, and AWS and filesystem listings report
`application/octet-stream` as the content type.

### Updating and Deleting

```go
etag, err := store.UpdateObject(
	ctx,
	"reports/quarterly.pdf",
	newBody,
)
```

AWS and MinIO require the object to exist and preserve its current content type.
The filesystem driver overwrites or creates the file and does not persist
content types.

```go
if err := store.DeleteObject(ctx, "reports/quarterly.pdf"); err != nil {
	return err
}
```

Missing-object deletion is backend-specific: S3-style deletion is generally
idempotent, while the filesystem driver returns an operating-system error.

### Copying and Moving

```go
err := store.CopyObject(
	ctx,
	"incoming/report.pdf",
	"reports/report.pdf",
)
```

```go
err := store.MoveObject(
	ctx,
	"incoming/report.pdf",
	"reports/report.pdf",
)
```

`MoveObject` is implemented as copy followed by delete. It is not atomic. If
deletion fails, both source and destination may remain.

### Presigned URLs

```go
downloadURL, err := store.PresignGet(
	ctx,
	"reports/quarterly.pdf",
	15*time.Minute,
)

uploadURL, err := store.PresignPut(
	ctx,
	"uploads/new-report.pdf",
	15*time.Minute,
)
```

Treat presigned URLs as temporary credentials: use short expirations and avoid
logging them. AWS and MinIO return provider-enforced URLs. The filesystem
driver only generates a URL and optional signature; your HTTP service must
serve the file and validate the method, expiration, and signature.

## Bucket Management

Create and select a bucket during deployment or application startup:

```go
if err := store.CreateBucket(ctx, "assets"); err != nil &&
	!errors.Is(err, objex.ErrBucketAlreadyExists) {
	return err
}

if _, err := store.SetBucket("assets"); err != nil {
	return err
}
```

Deleting a bucket has different consequences by driver. AWS and MinIO require
an empty bucket; the filesystem driver recursively deletes the directory and
all contained objects.

## Errors

Use `errors.Is` with Objex sentinel errors:

```go
metadata, err := store.Metadata(ctx, "missing.txt")
if errors.Is(err, objex.ErrObjectNotFound) {
	return nil
}
if err != nil {
	return err
}
```

Common errors include:

```go
objex.ErrUnknownDriver
objex.ErrInvalidEndpoint
objex.ErrInvalidAccessKey
objex.ErrInvalidSecretKey
objex.ErrClientInit
objex.ErrBucketNotFound
objex.ErrInvalidBucketName
objex.ErrObjectNotFound
objex.ErrAccessDenied
objex.ErrBucketNotEmpty
objex.ErrPreconditionFailed
objex.ErrBucketAlreadyExists
objex.ErrInvalidObjectName
objex.ErrInvalidFile
```

Not every backend error is normalized. AWS SDK errors and filesystem errors may
be returned directly, so retain a general error path after checking sentinels.

---

## Next Step: Authorization

The service now has configuration, temporary state, structured persistence, and
binary object storage. The next question is no longer where data lives, but who
may act on it.

Proceed to **[Step 5: Authorization with baccess](../baccess/index.md)** to
compose role checks with ownership and resource predicates.
