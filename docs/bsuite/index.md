# bsuite

`bsuite` acts as the configuration-driven glue layer for the BKit ecosystem. It reads a `bconfig.Config` configuration, automatically parses the configuration keys, and initializes telemetry (`btelemetry`), databases (`bdb`), and key-value stores (`bkv`).

[View source on GitHub](https://github.com/brian-nunez/bhttp){ .md-button }

## Configuration Keys

`bsuite` hydrates BKit components based on standard dot-path configuration keys:

| Key Path | Type | Description |
|---|---|---|
| `telemetry.enabled` | `bool` | Enables the telemetry subsystem |
| `telemetry.service_name` | `string` | The service name resource identifier |
| `telemetry.environment` | `string` | The execution environment (e.g. "production", "development") |
| `telemetry.enable_trace` | `bool` | Enables OpenTelemetry tracing |
| `telemetry.enable_metrics` | `bool` | Enables OpenTelemetry metrics |
| `telemetry.metric_mode` | `string` | Metric collection mode: "push" (OTLP) or "pull" (Prometheus) |
| `telemetry.enable_stdout` | `bool` | Enables concurrent stdout metric export |
| `telemetry.otlp_endpoint` | `string` | Target OTLP gRPC collector endpoint (e.g. "localhost:4317") |
| `telemetry.otlp_insecure` | `bool` | Skips TLS verification on OTLP endpoints |
| `kv.enabled` | `bool` | Hydrates and connects to a KV store |
| `kv.driver` | `string` | KV driver name: "local", "redis", or "sqlite" |
| `db.enabled` | `bool` | Hydrates and opens a database pool |
| `db.driver` | `string` | DB driver name: "sqlite" or "postgres" |
| `db.max_open_conns` | `int` | Database pool maximum open connections |
| `db.max_idle_conns` | `int` | Database pool maximum idle connections |

## Installation

```bash
go get github.com/brian-nunez/bhttp/pkg/bsuite
```

Ensure you import the drivers (e.g., redis, sqlite, postgres) in your application to trigger their self-registration.

## Quick Start

```go
package main

import (
	"context"
	"log"

	"github.com/brian-nunez/bconfig"
	"github.com/brian-nunez/bconfig/drivers/file"
	"github.com/brian-nunez/bhttp/pkg/bsuite"
	
	// Import drivers for registration
	_ "github.com/brian-nunez/bdb/drivers/sqlite"
	_ "github.com/brian-nunez/bkv/drivers/local"
)

func main() {
	ctx := context.Background()

	// Load configuration
	cfg, err := bconfig.New(file.Source("config.yaml"))
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	// Initialize bsuite service container
	service, err := bsuite.New(ctx, cfg)
	if err != nil {
		log.Fatalf("failed to bootstrap service container: %v", err)
	}
	defer service.Shutdown(ctx)

	// Access components directly
	db := service.DB()
	kv := service.KV()
	
	if db != nil {
		log.Println("Database is active!")
	}
	if kv != nil {
		log.Println("KV store is active!")
	}
}
```

## Errors

The constructor returns the following error if component initialization fails (which automatically cleans up any partially initialized resources before returning):

```go
bsuite.ErrSuiteInit
```
