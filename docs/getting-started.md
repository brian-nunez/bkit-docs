# Getting Started

Building a Go service is a sequence of decisions. BKit makes that sequence
feel like one journey while keeping every decision reversible:

1. **Configuration**: How do we load parameters from files and process environments?
2. **State & Caching**: How do we store temporary data and session states?
3. **Persistence**: How do we connect to SQL databases to save records?
4. **Object Storage**: Where do files, uploads, and generated assets live?
5. **Authorization**: Which subjects may perform an action on a resource?
6. **Telemetry**: How do we collect metrics and traces for observability?
7. **Lifecycle**: How do we manage concurrent processes and graceful shutdowns?
8. **Hydration**: How do we bootstrap common infrastructure from config?

BKit solves these concerns with separate, focused packages. The beauty is in
the composition: each package is useful alone, each driver can be exchanged at
the application boundary, and the assembled service still reads like ordinary
Go rather than a framework-specific runtime.

---

## Installation

Install only the modules and drivers your service requires:

=== "bconfig"
	```bash
	go get github.com/brian-nunez/bconfig
	# Install drivers as needed
	go get github.com/brian-nunez/bconfig/drivers/file
	go get github.com/brian-nunez/bconfig/drivers/env
	```

=== "bkv"
	```bash
	go get github.com/brian-nunez/bkv
	# Install drivers as needed
	go get github.com/brian-nunez/bkv/drivers/local
	go get github.com/brian-nunez/bkv/drivers/redis
	go get github.com/brian-nunez/bkv/drivers/sqlite
	```

=== "bdb"
	```bash
	go get github.com/brian-nunez/bdb
	# Install drivers as needed
	go get github.com/brian-nunez/bdb/drivers/sqlite
	go get github.com/brian-nunez/bdb/drivers/postgres
	go get github.com/brian-nunez/bdb/drivers/mariadb
	```

=== "objex"
	```bash
	go get github.com/brian-nunez/objex
	# Install drivers as needed
	go get github.com/brian-nunez/objex/drivers/filesystem
	go get github.com/brian-nunez/objex/drivers/aws
	go get github.com/brian-nunez/objex/drivers/minio
	```

=== "baccess"
	```bash
	go get github.com/brian-nunez/baccess
	```

=== "btelemetry"
	```bash
	go get github.com/brian-nunez/bhttp/pkg/btelemetry
	```

=== "brun"
	```bash
	go get github.com/brian-nunez/bhttp/pkg/brun
	```

=== "bsuite"
	```bash
	go get github.com/brian-nunez/bhttp/pkg/bsuite
	```

---

## Composing the Ecosystem

The core libraries do not need to own one another. Configuration supplies
values, drivers turn those values into infrastructure, and your application
passes the resulting interfaces to the code that needs them.

Here is a minimal example showing how they fit together:

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
	Roles []string
}

func (u User) GetRoles() []string { return u.Roles }

type Asset struct{}

func main() {
	ctx := context.Background()

	// 1. Load configuration parameters
	cfg, err := bconfig.New(file.Source("config.yaml"))
	if err != nil {
		log.Fatal(err)
	}

	// 2. Initialize the key/value cache
	cache, err := bkv.New(local.Config{})
	if err != nil {
		log.Fatal(err)
	}
	defer cache.Close()

	// 3. Connect to the persistent database using the loaded configuration
	db, err := bdb.New(dbsqlite.Config{
		Path: cfg.String("database.path"),
	})
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	// 4. Open object storage for files and generated assets
	objects, err := objex.New(filesystem.Config{
		BasePath: cfg.String("objects.path"),
	})
	if err != nil {
		log.Fatal(err)
	}
	if err := objects.Setup(ctx); err != nil {
		log.Fatal(err)
	}
	if _, err := objects.SetBucket("assets"); err != nil {
		log.Fatal(err)
	}

	// Use the composed stack
	if err := cache.Set(ctx, "last_started", time.Now().Format(time.RFC3339), 0); err != nil {
		log.Fatal(err)
	}
	if _, err := objects.CreateObject(
		ctx, "status/ready.txt", strings.NewReader("ready"), "text/plain",
	); err != nil {
		log.Fatal(err)
	}

	// 5. Keep authorization policy close to the operation it protects
	rbac := baccess.NewRBAC[User, Asset]()
	request := baccess.AccessRequest[User, Asset]{
		Subject: User{Roles: []string{"admin"}},
		Action:  "publish",
	}
	if !rbac.HasRole("admin").IsSatisfiedBy(request) {
		log.Fatal("not authorized")
	}
}
```

The example is intentionally explicit. `bconfig` supplies values; `bkv`, `bdb`,
and `objex` own different forms of data; `baccess` makes a policy decision
before application code performs a protected operation. No package needs to
become the application's framework.

---

## The Guided Journey

To build a service with BKit, we recommend following the onboarding story:

1. **[Step 1: Configuration with bconfig](bconfig/index.md)** — Start by loading configuration variables from your files and environment.
2. **[Step 2: Caching with bkv](bkv/index.md)** — Use your configuration to set up in-memory or Redis-backed state stores.
3. **[Step 3: Persistence with bdb](bdb/index.md)** — Connect your stack to SQLite, PostgreSQL, or MySQL.
4. **[Step 4: Object storage with objex](objex/index.md)** — Stream files through a local filesystem, AWS S3, or MinIO without changing application code.
5. **[Step 5: Authorization with baccess](baccess/index.md)** — Express role and resource rules as composable predicates.
6. **[Step 6: Observability with btelemetry](btelemetry/index.md)** — Instrument OpenTelemetry metrics and tracing.
7. **[Step 7: Lifecycle with brun](brun/index.md)** — Orchestrate tasks and servers concurrently with graceful shutdown.
8. **[Step 8: Service hydration with bsuite](bsuite/index.md)** — Hydrate the common database, key/value, and telemetry infrastructure when that convenience fits your service.

The final destination is the **[BKit API Template](api-template.md)**, where
these boundaries become a running service. The template is not the framework
you must adopt; it is a concrete demonstration of how naturally the pieces fit
together.
