# Service bootstrap

A service bootstrap should load configuration first, construct dependencies, verify health, and close resources in reverse order.

```go
package main

import (
	"context"
	"errors"
	"log"
	"time"

	"github.com/brian-nunez/bconfig"
	"github.com/brian-nunez/bconfig/drivers/env"
	"github.com/brian-nunez/bconfig/drivers/file"
	"github.com/brian-nunez/bdb"
	dbsqlite "github.com/brian-nunez/bdb/drivers/sqlite"
	"github.com/brian-nunez/bkv"
	"github.com/brian-nunez/bkv/drivers/redis"
)

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cfg, err := bconfig.LoadWithOptions(
		ctx,
		[]bconfig.Source{
			file.Source("config.yaml"),
			env.Source("BAPP_"),
		},
		bconfig.WithValidator(func(cfg *bconfig.Config) error {
			if cfg.String("database.path") == "" {
				return errors.New("database.path is required")
			}
			if cfg.String("bapp_redis_addr") == "" {
				return errors.New("BAPP_REDIS_ADDR is required")
			}
			return nil
		}),
	)
	if err != nil {
		log.Fatal(err)
	}

	db, err := bdb.New(dbsqlite.Config{
		Path: cfg.String("database.path"),
	})
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	store, err := bkv.New(redis.Config{
		Addr:   cfg.String("bapp_redis_addr"),
		Prefix: "service",
	})
	if err != nil {
		log.Fatal(err)
	}
	defer store.Close()

	if err := db.Ping(ctx); err != nil {
		log.Fatal(err)
	}
	if err := store.HealthCheck(ctx); err != nil {
		log.Fatal(err)
	}

	// Start the service only after dependencies are ready.
}
```

The environment key is intentionally `bapp_redis_addr`: the current environment source retains prefixes and produces flat, lowercased keys.

Graceful signal handling and HTTP server shutdown are application concerns; BKit currently provides no combined service lifecycle package.
