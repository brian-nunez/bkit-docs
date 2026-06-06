# Config + KV + DB

This example composes all three packages while keeping their lifecycles independent.

```yaml title="config.yaml"
database:
  path: "app.db"
cache:
  ttl_seconds: 300
```

```go
package main

import (
	"context"
	"log"
	"time"

	"github.com/brian-nunez/bconfig"
	"github.com/brian-nunez/bconfig/drivers/file"
	"github.com/brian-nunez/bdb"
	dbsqlite "github.com/brian-nunez/bdb/drivers/sqlite"
	"github.com/brian-nunez/bkv"
	"github.com/brian-nunez/bkv/drivers/local"
)

func main() {
	ctx := context.Background()

	cfg, err := bconfig.New(file.Source("config.yaml"))
	if err != nil {
		log.Fatal(err)
	}

	cache, err := bkv.New(local.Config{})
	if err != nil {
		log.Fatal(err)
	}
	defer cache.Close()

	db, err := bdb.New(dbsqlite.Config{
		Path: cfg.String("database.path"),
	})
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	if _, err := db.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS settings (
			key TEXT PRIMARY KEY,
			value TEXT NOT NULL
		)
	`); err != nil {
		log.Fatal(err)
	}

	if _, err := db.Exec(ctx,
		"INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
		"region", "us-west",
	); err != nil {
		log.Fatal(err)
	}

	var region string
	if err := db.QueryOne(ctx,
		"SELECT value FROM settings WHERE key = ?",
		[]any{"region"},
		&region,
	); err != nil {
		log.Fatal(err)
	}

	ttl := time.Duration(cfg.Int("cache.ttl_seconds")) * time.Second
	if err := cache.Set(ctx, "settings:region", region, ttl); err != nil {
		log.Fatal(err)
	}
}
```

`bconfig` supplies startup values, `bdb` owns persistent records, and `bkv` caches a derived value. None of the packages imports another BKit package.
