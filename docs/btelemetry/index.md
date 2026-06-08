# btelemetry

`btelemetry` provides a unified observability wrapper for Go applications using OpenTelemetry. It supports metrics generation (Prometheus and OTLP push) and distributed tracing (OTLP and console log fallbacks).

## Configuration

The package is configured via a standard config structure:

```go
type Config struct {
	ServiceName   string
	Environment   string
	EnableTrace   bool
	EnableMetrics bool
	MetricMode    string // "push", "pull"
	EnableStdout  bool
	OTLPEndpoint  string
	OTLPInsecure  bool
}
```

## Installation

```bash
go get github.com/brian-nunez/bhttp/pkg/btelemetry
```

## Quick Start

```go
package main

import (
	"context"
	"log"
	"net/http"

	"github.com/brian-nunez/bhttp/pkg/btelemetry"
)

func main() {
	ctx := context.Background()

	// Configure telemetry for Prometheus (pull) metrics, enabling stdout export
	cfg := btelemetry.Config{
		ServiceName:   "my-service",
		Environment:   "development",
		EnableTrace:   true,
		EnableMetrics: true,
		MetricMode:    "pull",
		EnableStdout:  true,
	}

	tel, err := btelemetry.New(ctx, cfg)
	if err != nil {
		log.Fatalf("failed to initialize telemetry: %v", err)
	}
	defer tel.Shutdown(ctx)

	// Expose metrics for Prometheus scraping
	http.Handle("/metrics", tel.HTTPHandler())
	
	log.Println("Serving metrics on :2222/metrics...")
	if err := http.ListenAndServe(":2222", nil); err != nil {
		log.Fatal(err)
	}
}
```

## Errors

The package exposes the following errors to handle configuration and initialization failures:

```go
btelemetry.ErrInvalidConfig // Config constraints violated
btelemetry.ErrInitFailed    // Exporter or resource initialization failed
```
