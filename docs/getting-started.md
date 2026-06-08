# Getting Started

Every Go service begins its lifecycle with three fundamental infrastructure concerns:

1. **Configuration**: How do we load parameters from files and process environments?
2. **State & Caching**: How do we store temporary data and session states?
3. **Persistence**: How do we connect to SQL databases to save records?
4. **Telemetry**: How do we collect metrics and traces for observability?
5. **Lifecycle**: How do we manage concurrent processes and graceful shutdowns?
6. **Hydration**: How do we bootstrap and hydrate everything from config?

BKit solves these concerns with separate, focused packages. Instead of locking you into a monolithic service framework, BKit gives you small, modular building blocks that you import and compose directly in your application's bootstrap code.

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

Because BKit packages are completely decoupled, they never import one another. Your application bootstrap code is the glue that composes them. 

Here is a minimal example showing how they fit together:

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

	// Use the composed stack
	if err := cache.Set(ctx, "last_started", time.Now().Format(time.RFC3339), 0); err != nil {
		log.Fatal(err)
	}
}
```

---

## The Guided Journey

To build a service with BKit, we recommend following the onboarding story:

1. **[Step 1: Configuration with bconfig](bconfig/index.md)** — Start by loading configuration variables from your files and environment.
2. **[Step 2: Caching with bkv](bkv/index.md)** — Use your configuration to set up in-memory or Redis-backed state stores.
3. **[Step 3: Persistence with bdb](bdb/index.md)** — Connect your stack to SQLite, PostgreSQL, or MySQL.
4. **[Step 4: Observability with btelemetry](btelemetry/index.md)** — Instrument OpenTelemetry metrics and tracing.
5. **[Step 5: Lifecycle with brun](brun/index.md)** — Orchestrate tasks and servers concurrently with graceful shutdown.
6. **[Step 6: Service Hydration with bsuite](bsuite/index.md)** — Automatically hydrate and bootstrap the entire ecosystem.
