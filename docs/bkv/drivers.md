# Drivers

`bkv` uses a driver registry. When you import a driver package, it registers itself during package initialization, allowing you to instantiate it by passing its configuration structure to `bkv.New`.

## Driver Comparison

| Feature | Local | Redis | SQLite |
| --- | --- | --- | --- |
| **Storage Type** | In-process map | Networked server | Embedded database file / memory |
| **Persistence** | Ephemeral (lost on exit) | Server-determined | Persistent |
| **CGO Required** | No | No | No (pure-Go) |
| **TTL Expiration** | Evaluated lazily on read | Native Redis TTL | Evaluated lazily and stored in db |
| **Key Namespaces** | No | Yes (via prefix configuration) | Yes (via prefix configuration) |

---

## Local Driver

An in-process, mutex-protected map.

```go
import "github.com/brian-nunez/bkv/drivers/local"

// ...
store, err := bkv.New(local.Config{})
```

*   **Config Options**: `local.Config` contains no fields.
*   **TTL**: Evaluated lazily whenever a key is accessed. There is no background cleanup worker.
*   **Use Case**: Ideal for unit tests, local development, and process-local cache.

---

## Redis Driver

A networked backend wrapper around `github.com/redis/go-redis/v9`.

```go
import "github.com/brian-nunez/bkv/drivers/redis"

// ...
store, err := bkv.New(redis.Config{
	Addr:     "localhost:6379",
	Username: "",
	Password: "secret-password",
	DB:       0,
	Prefix:   "sessions",
	Secure:   false, // Set to true to enable TLS (min version 1.2)
})
```

*   **Pinging**: The constructor automatically pings the server with a 5-second context timeout before returning.
*   **Missing Keys**: Redis missing-key responses are converted into `bkv.ErrKeyNotFound`.

---

## SQLite Driver

An embedded, serverless persistent driver that uses pure-Go `modernc.org/sqlite` (CGO-free).

```go
import "github.com/brian-nunez/bkv/drivers/sqlite"

// ...
store, err := bkv.New(sqlite.Config{
	Path:   "state.db",
	Table:  "cache_entries", // Defaults to "bkv" if empty
	Prefix: "sessions",
})
```

*   **In-Memory Mode**: Set `Path: ":memory:"` or leave it empty to use an in-memory database.
*   **Schema Migration**: Automatically runs migrations at startup to create the target table if it does not exist.
*   **TTL**: Positive expiration durations are stored as Unix nanoseconds. An expired key is deleted and returns `bkv.ErrKeyNotFound` on read.

---

## Key Prefix Handling

Both **Redis** and **SQLite** drivers support a namespace `Prefix` parameter.

*   **Normalization**: Prefixes are automatically normalized (e.g. `myapp` becomes `myapp:`).
*   **Transparency**: Key prefixing is transparent to the caller. Operations like `Get`, `Set`, `Exists`, and `Delete` automatically prepend the prefix to the key.
*   **Key Listing**: `Keys` lists only the keys that match the configured prefix, and strips the prefix before returning them.
*   **Clearing**: `Clear` only deletes keys starting with the prefix. Calling `Clear` with an empty prefix will delete all keys in the database/table.
