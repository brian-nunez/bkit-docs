# bkv

`bkv` is a lightweight, driver-backed key/value abstraction with a common string-valued store interface. In our guided onboarding story, you initialize `bkv` using parameters loaded in **[Step 1: Configuration with bconfig](../bconfig/index.md)**.

[View source on GitHub](https://github.com/brian-nunez/bkv){ .md-button }

## Store Interface

```go
type Store interface {
	Get(ctx context.Context, key string) (string, error)
	Set(ctx context.Context, key string, value string, ttl time.Duration) error
	Exists(ctx context.Context, key string) (bool, error)
	Delete(ctx context.Context, key string) (bool, error)
	Clear(ctx context.Context) error
	Keys(ctx context.Context) ([]string, error)
	HealthCheck(ctx context.Context) error
	Close() error
}
```

## Installation

```bash
go get github.com/brian-nunez/bkv
```

You will also need to install the driver modules you plan to use:

```bash
go get github.com/brian-nunez/bkv/drivers/local
go get github.com/brian-nunez/bkv/drivers/redis
go get github.com/brian-nunez/bkv/drivers/sqlite
```

## Quick Start

```go
package main

import (
	"context"
	"errors"
	"log"
	"time"

	"github.com/brian-nunez/bkv"
	"github.com/brian-nunez/bkv/drivers/local"
)

func main() {
	// Open store (registers and starts the driver)
	store, err := bkv.New(local.Config{})
	if err != nil {
		log.Fatal(err)
	}
	defer store.Close()

	ctx := context.Background()

	// Store value with 15-minute expiration
	if err := store.Set(ctx, "session:123", "active", 15*time.Minute); err != nil {
		log.Fatal(err)
	}

	// Retrieve value
	value, err := store.Get(ctx, "session:123")
	if err != nil {
		if errors.Is(err, bkv.ErrKeyNotFound) {
			log.Println("session expired or does not exist")
			return
		}
		log.Fatal(err)
	}

	log.Println("Session state:", value)
}
```

## Common Operations

### Storing Permanent Values

Pass a TTL of `0` (or less) to store a key indefinitely without expiration:

```go
err := store.Set(ctx, "feature:checkout", "enabled", 0)
```

### Conditional Deletion

`Delete` returns a boolean indicating whether the key existed and was deleted:

```go
deleted, err := store.Delete(ctx, "session:123")
if err != nil {
	log.Fatal(err)
}
if !deleted {
	log.Println("key did not exist")
}
```

### Iterating Keys

`Keys` returns all keys stored in the store. Key ordering is driver-specific:

```go
keys, err := store.Keys(ctx)
if err != nil {
	log.Fatal(err)
}

for _, key := range keys {
	value, err := store.Get(ctx, key)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("%s = %s", key, value)
}
```

## Errors

The root package exports these sentinel errors:

```go
bkv.ErrUnknownDriver
bkv.ErrInvalidConfig
bkv.ErrKeyNotFound
bkv.ErrStoreClosed
```

Handle these using `errors.Is(err, bkv.Err...)`.

---

## Next Step: Database Persistence

With configuration loaded and temporary state cached, add durable structured
records by connecting to a SQL database.

Proceed to **[Step 3: Database Persistence with bdb](../bdb/index.md)** to see how to open structured connections using your loaded configuration.
