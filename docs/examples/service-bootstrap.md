# Service Bootstrap & Lifecycle

This example demonstrates how to bootstrap a complete BKit application stack. We will use `bconfig` to load settings, `bsuite` to hydrate database, key-value, and telemetry connections, and `brun` to manage the concurrent lifecycles of an API server and background worker.

## Configuration File

The application is configured using a unified YAML file:

```yaml title="config.yaml"
telemetry:
  enabled: true
  service_name: "payment-api"
  environment: "production"
  enable_trace: true
  enable_metrics: true
  metric_mode: "pull"
  enable_stdout: false

kv:
  enabled: true
  driver: "local"

db:
  enabled: true
  driver: "sqlite"
  sqlite:
    path: "data.db"
  max_open_conns: 25
  max_idle_conns: 10
```

## Bootstrap Implementation

The entry point loads the config, boots up the BSuite service container, wraps our servers and tasks into runnables, and launches them using the runner manager:

```go
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os/signal"
	"syscall"
	"time"

	"github.com/brian-nunez/bconfig"
	"github.com/brian-nunez/bconfig/drivers/file"
	"github.com/brian-nunez/bhttp/pkg/brun"
	"github.com/brian-nunez/bhttp/pkg/bsuite"

	// Drivers self-register when imported
	_ "github.com/brian-nunez/bdb/drivers/sqlite"
	_ "github.com/brian-nunez/bkv/drivers/local"
)

// BackgroundWorker implements brun.Runnable
type BackgroundWorker struct {
	suite *bsuite.Service
}

func (w *BackgroundWorker) Run(ctx context.Context) error {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	kv := w.suite.KV()
	db := w.suite.DB()

	for {
		select {
		case <-ctx.Done():
			log.Println("Background worker shutting down...")
			return nil
		case <-ticker.C:
			// Perform routine task, e.g. cache validation
			if err := kv.Set(ctx, "last_tick", time.Now().String(), 0); err != nil {
				log.Printf("worker error: %v", err)
			}
			if err := db.Ping(ctx); err != nil {
				log.Printf("db check failed: %v", err)
			}
			log.Println("Worker task executed successfully.")
		}
	}
}

type KVWatcherWorker struct {
	suite *bsuite.Service
}

func (w *KVWatcherWorker) Run(ctx context.Context) error {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	kv := w.suite.KV()

	for {
		select {
		case <-ctx.Done():
			log.Println("KV Watcher worker shutting down...")
			return nil
		case <-ticker.C:
			val, err := kv.Get(ctx, "last_tick")
			if err != nil {
				log.Printf("worker error: %v", err)
			}

			log.Printf("Last tick value from KV store: %s", val)
		}
	}
}

// APIServer wraps our HTTP server and implements brun.Runnable
type APIServer struct {
	suite *bsuite.Service
}

func (s *APIServer) Run(ctx context.Context) error {
	mux := http.NewServeMux()

	// Expose Prometheus metrics scraping endpoint
	tel := s.suite.Telemetry()
	if tel != nil {
		mux.Handle("/metrics", tel.HTTPHandler())
	}

	// Application endpoint
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("healthy"))
	})

	srv := &http.Server{
		Addr:    ":8080",
		Handler: mux,
	}

	errChan := make(chan error, 1)
	go func() {
		log.Println("API Server listening on :8080...")
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errChan <- err
		}
	}()

	select {
	case <-ctx.Done():
		log.Println("API Server shutting down gracefully...")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		return srv.Shutdown(shutdownCtx)
	case err := <-errChan:
		return err
	}
}

func main() {
	ctx, stop := signal.NotifyContext(
		context.Background(),
		syscall.SIGINT,
		syscall.SIGTERM,
	)
	defer stop()

	// 1. Load configuration
	cfg, err := bconfig.New(file.Source("config.yaml"))
	if err != nil {
		log.Fatalf("failed to load configuration: %v", err)
	}

	// 2. Hydrate service container (automatically boots telemetry, KV, DB)
	service, err := bsuite.New(ctx, cfg)
	if err != nil {
		log.Fatalf("failed to bootstrap service: %v", err)
	}
	defer func() {
		log.Println("Releasing database and telemetry connections...")
		service.Shutdown(ctx)
	}()

	// 3. Register running tasks
	manager := brun.New()
	manager.Register(
		&BackgroundWorker{suite: service},
		&APIServer{suite: service},
		&KVWatcherWorker{suite: service},
	)

	// 4. Start concurrent lifecycle manager
	log.Println("Starting BKit application...")
	if err := manager.Start(ctx); err != nil && !errors.Is(err, context.Canceled) {
		log.Fatalf("Application stopped with error: %v", err)
	}
	log.Println("Application exited cleanly.")
}
```
