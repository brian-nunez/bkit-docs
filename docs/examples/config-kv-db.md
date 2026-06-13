# Config + KV + DB + Objects + Access

This example composes storage and authorization while keeping every boundary
independent. Configuration selects local drivers today; the application-facing
interfaces can remain unchanged when production uses Redis, PostgreSQL, or S3.
`baccess` decides whether the user may publish the derived object before Objex
writes it.

```yaml title="config.yaml"
database:
  path: "app.db"
cache:
  ttl_seconds: 300
objects:
  path: "./objects"
```

```go
package main

import (
	"context"
	"log"
	"strings"
	"time"

	"github.com/brian-nunez/baccess"
	"github.com/brian-nunez/bconfig"
	"github.com/brian-nunez/bconfig/drivers/file"
	"github.com/brian-nunez/bdb"
	dbsqlite "github.com/brian-nunez/bdb/drivers/sqlite"
	"github.com/brian-nunez/bkv"
	"github.com/brian-nunez/bkv/drivers/local"
	"github.com/brian-nunez/objex"
	"github.com/brian-nunez/objex/drivers/filesystem"
)

type User struct {
	ID    string
	Roles []string
}

func (u User) GetRoles() []string { return u.Roles }

type Export struct {
	OwnerID string
}

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

	objects, err := objex.New(filesystem.Config{
		BasePath: cfg.String("objects.path"),
	})
	if err != nil {
		log.Fatal(err)
	}
	if err := objects.Setup(ctx); err != nil {
		log.Fatal(err)
	}
	if _, err := objects.SetBucket("exports"); err != nil {
		log.Fatal(err)
	}

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

	// Authorization stays in application code, close to the operation it guards.
	rbac := baccess.NewRBAC[User, Export]()
	isOwner := baccess.FieldEquals(
		func(user User) string { return user.ID },
		func(export Export) string { return export.OwnerID },
	)
	canPublish := rbac.HasRole("admin").Or(
		rbac.HasRole("editor").And(isOwner),
	)

	user := User{ID: "alice", Roles: []string{"editor"}}
	export := Export{OwnerID: "alice"}
	request := baccess.AccessRequest[User, Export]{
		Subject:  user,
		Resource: export,
		Action:   "publish",
	}
	if !canPublish.IsSatisfiedBy(request) {
		log.Fatal("user cannot publish this export")
	}

	_, err = objects.CreateObject(
		ctx,
		"settings/region.txt",
		strings.NewReader(region),
		"text/plain",
	)
	if err != nil {
		log.Fatal(err)
	}
}
```

`bconfig` supplies startup values, `bdb` owns structured records, `bkv` caches
a derived value, `baccess` guards the publish operation, and `objex` writes the
file representation. Each package keeps one responsibility; the application
decides how data and decisions move between them.
