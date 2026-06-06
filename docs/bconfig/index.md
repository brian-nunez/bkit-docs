# bconfig

`bconfig` loads configuration from one or more sources, deep-merges the results, supports dot-path reads, and decodes the configuration into Go values.

[View source on GitHub](https://github.com/brian-nunez/bconfig){ .md-button }

## Installation

```bash
go get github.com/brian-nunez/bconfig
```

You will also need to install the source drivers you plan to use:

```bash
go get github.com/brian-nunez/bconfig/drivers/file
go get github.com/brian-nunez/bconfig/drivers/env
```

## Quick Start

Create a YAML configuration file:

```yaml title="config.yaml"
server:
  addr: ":8080"
  timeout: "5s"
debug: false
```

Load the file and access its values:

```go
package main

import (
	"context"
	"log"

	"github.com/brian-nunez/bconfig"
	"github.com/brian-nunez/bconfig/drivers/file"
)

func main() {
	// Load a single source
	cfg, err := bconfig.New(file.Source("config.yaml"))
	if err != nil {
		log.Fatal(err)
	}

	// Access nested configuration using dot notation
	addr := cfg.String("server.addr")
	debug := cfg.Bool("debug")

	log.Printf("Server address: %s, Debug: %t", addr, debug)
}
```

## Reading Values

`bconfig` provides typed accessor methods to retrieve values using dot notation path queries (e.g. `"server.addr"`):

```go
addr  := cfg.String("server.addr") // Returns string
port  := cfg.Int("server.port")     // Returns int
debug := cfg.Bool("debug")          // Returns bool
ratio := cfg.Float("limits.ratio")  // Returns float64
raw   := cfg.Get("features")        // Returns raw any (e.g. slice, map, etc.)
```

*   **Zero Values**: Incompatible types or missing paths return their type's zero value.
*   **Safe Copy**: `cfg.Data()` returns a deep copy of the underlying configuration map, allowing you to modify it without altering the loaded configuration.

## Struct Decoding

You can decode the loaded configuration directly into Go structs. Struct fields should be annotated with `json` tags:

```go
type AppConfig struct {
	Server struct {
		Addr    string `json:"addr"`
		Timeout string `json:"timeout"`
	} `json:"server"`
	Debug bool `json:"debug"`
}

var appCfg AppConfig
if err := cfg.Decode(&appCfg); err != nil {
	log.Fatal(err)
}
```

## Validation

You can validate the configuration after it is loaded and merged by providing a validation callback:

```go
cfg, err := bconfig.LoadWithOptions(
	context.Background(),
	[]bconfig.Source{file.Source("config.yaml")},
	bconfig.WithValidator(func(cfg *bconfig.Config) error {
		if cfg.String("server.addr") == "" {
			return errors.New("server.addr is required")
		}
		return nil
	}),
)
if err != nil {
	log.Fatal(err)
}
```

## Context-Aware Loading

If your sources require network calls or need to respect deadlines/cancellations at startup, use `Load` instead of `New`:

```go
ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
defer cancel()

cfg, err := bconfig.Load(ctx, file.Source("config.yaml"))
```

---

## Next Step: State & Caching

Now that your application has loaded its configuration parameters using `bconfig`, the next step in the onboarding journey is setting up shared cache and state stores.

Proceed to **[Step 2: Key/Value Caching with bkv](../bkv/index.md)** to see how to pass loaded parameters into memory or Redis.
