# bdb

`bdb` is a driver-based wrapper around Go's `database/sql` package. It provides a clean, unified interface for SQL execution, transactions, connection pool management, and statistics.

In the guided journey, `bdb` turns the values loaded with
**[Step 1: bconfig](../bconfig/index.md)** into durable SQL persistence alongside
the temporary state introduced in **[Step 2: bkv](../bkv/index.md)**.

[View source on GitHub](https://github.com/brian-nunez/bdb){ .md-button }

## DB Interface

```go
type DB interface {
	Ping(ctx context.Context) error
	Exec(ctx context.Context, query string, args ...any) (sql.Result, error)
	Close() error
	Prepare(ctx context.Context, query string) (*sql.Stmt, error)
	Query(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	BeginTx(ctx context.Context, opts *sql.TxOptions) (*sql.Tx, error)
	QueryOne(ctx context.Context, query string, args []any, dest ...any) error

	SetMaxIdleConns(n int)
	SetMaxOpenConns(n int)
	SetConnMaxLifetime(d time.Duration)
	SetConnMaxIdleTime(d time.Duration)

	OpenConnections() int
	MaxOpenConnections() int
	IdleConnections() int
	InUseConnections() int

	GetConnection() *sql.DB
}
```

## Installation

```bash
go get github.com/brian-nunez/bdb
```

You will also need to install the driver modules you plan to use:

```bash
go get github.com/brian-nunez/bdb/drivers/sqlite
go get github.com/brian-nunez/bdb/drivers/postgres
go get github.com/brian-nunez/bdb/drivers/mariadb
```

## Quick Start

```go
package main

import (
	"context"
	"log"

	"github.com/brian-nunez/bdb"
	"github.com/brian-nunez/bdb/drivers/sqlite"
)

func main() {
	// Open connection pool (automatically performs a Ping)
	db, err := bdb.New(sqlite.Config{Path: "app.db"})
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	ctx := context.Background()

	// Execute a statement
	_, err = db.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS users (
			id INTEGER PRIMARY KEY,
			name TEXT NOT NULL
		)
	`)
	if err != nil {
		log.Fatal(err)
	}

	// Insert a row
	_, err = db.Exec(ctx, "INSERT INTO users (name) VALUES (?)", "Alice")
	if err != nil {
		log.Fatal(err)
	}

	// Query a single row
	var name string
	err = db.QueryOne(ctx, "SELECT name FROM users WHERE id = ?", []any{1}, &name)
	if err != nil {
		log.Fatal(err)
	}

	log.Printf("User: %s", name)
}
```

## Common Operations

### Pool Configuration

`bdb` exposes standard Go connection pool tuning parameters:

```go
db.SetMaxOpenConns(20)
db.SetMaxIdleConns(5)
db.SetConnMaxLifetime(30 * time.Minute)
db.SetConnMaxIdleTime(5 * time.Minute)
```

### Pool Statistics

Monitor connection pool health at runtime:

```go
log.Printf(
	"open=%d max=%d idle=%d in_use=%d",
	db.OpenConnections(),
	db.MaxOpenConnections(),
	db.IdleConnections(),
	db.InUseConnections(),
)
```

### Querying Multiple Rows

```go
rows, err := db.Query(ctx, "SELECT id, name FROM users")
if err != nil {
	log.Fatal(err)
}
defer rows.Close()

for rows.Next() {
	var id int
	var name string
	if err := rows.Scan(&id, &name); err != nil {
		log.Fatal(err)
	}
}
if err := rows.Err(); err != nil {
	log.Fatal(err)
}
```

### Prepared Statements

```go
stmt, err := db.Prepare(ctx, "SELECT name FROM users WHERE id = ?")
if err != nil {
	log.Fatal(err)
}
defer stmt.Close()

var name string
if err := stmt.QueryRowContext(ctx, 1).Scan(&name); err != nil {
	log.Fatal(err)
}
```

### Accessing the Underlying `*sql.DB`

Expose the standard Go database handle to integrate with third-party libraries (e.g. migration tools or ORMs):

```go
sqlDB := db.GetConnection()
stats := sqlDB.Stats()
```

## Errors

`bdb` exports these standard sentinel errors:

```go
bdb.ErrUnknownDriver
bdb.ErrInvalidConfig
bdb.ErrDBClosed
```

Handle these using `errors.Is(err, bdb.Err...)`.

---

## Next Step: Object Storage

Your service can now load configuration, cache temporary values, and persist
structured records. Files and binary assets have different access patterns and
should not be forced into the database.

Proceed to **[Step 4: Object Storage with objex](../objex/index.md)** to add
filesystem, AWS S3, or MinIO storage behind one streaming interface.
