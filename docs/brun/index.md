# brun

`brun` is a lightweight, concurrent task runner and lifecycle orchestrator for Go services. It utilizes `golang.org/x/sync/errgroup` underneath to ensure that multiple runnables (servers, consumers, workers) start concurrently, propagate context cleanly, and stop gracefully.

[View source on GitHub](https://github.com/brian-nunez/bhttp){ .md-button }

## Runnable Contract

Any component registered with the runner must satisfy the `brun.Runnable` interface:

```go
type Runnable interface {
	Run(ctx context.Context) error
}
```

## Installation

```bash
go get github.com/brian-nunez/bhttp/pkg/brun
```

## Quick Start

```go
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"time"

	"github.com/brian-nunez/bhttp/pkg/brun"
)

type Worker struct{}

func (w *Worker) Run(ctx context.Context) error {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Println("Worker shutting down...")
			return nil
		case <-ticker.C:
			log.Println("Worker ticking...")
		}
	}
}

type Server struct {
	httpServer *http.Server
}

func (s *Server) Run(ctx context.Context) error {
	s.httpServer = &http.Server{
		Addr:    ":8080",
		Handler: http.DefaultServeMux,
	}

	errChan := make(chan error, 1)
	go func() {
		if err := s.httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errChan <- err
		}
	}()

	select {
	case <-ctx.Done():
		log.Println("Server shutting down...")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		return s.httpServer.Shutdown(shutdownCtx)
	case err := <-errChan:
		return err
	}
}

func main() {
	manager := brun.New()
	
	// Register background tasks and HTTP servers
	manager.Register(&Worker{}, &Server{})

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	log.Println("Starting service manager...")
	if err := manager.Start(ctx); err != nil && !errors.Is(err, context.Canceled) {
		log.Fatalf("Manager stopped with error: %v", err)
	}
	log.Println("Service stopped gracefully.")
}
```
