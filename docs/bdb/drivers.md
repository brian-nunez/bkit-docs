# Drivers

`bdb` utilizes Go's SQL driver registry mechanism. Importing a driver package automatically registers it, allowing you to establish database pools by passing the corresponding config to `bdb.New`.

## Driver Comparison

| Feature | SQLite | PostgreSQL | MariaDB / MySQL |
| --- | --- | --- | --- |
| **Driver Package** | `modernc.org/sqlite` | `github.com/lib/pq` | `github.com/go-sql-driver/mysql` |
| **CGO Required** | No (pure-Go) | No | No |
| **Placeholder** | `?` | `$1`, `$2`, ... | `?` |
| **Default DSN Target** | `:memory:` | `localhost:5432` | `localhost:3306` |

---

## SQLite Driver

An embedded, serverless SQL database that compiles to pure Go and does not require CGO.

```go
import "github.com/brian-nunez/bdb/drivers/sqlite"

// ...
db, err := bdb.New(sqlite.Config{
	Path: "app.db",
})
```

*   **In-Memory Mode**: Set `Path: ":memory:"` or leave it empty to use an in-memory SQLite database.
*   **Max Open Connections**: When `:memory:` is used, the driver automatically restricts the pool to 1 open connection (`MaxOpenConns(1)`) to ensure multiple threads access the same in-memory store.

---

## PostgreSQL Driver

A production-ready driver for PostgreSQL databases built on `lib/pq`.

```go
import "github.com/brian-nunez/bdb/drivers/postgres"

// ...
db, err := bdb.New(postgres.Config{
	Host:     "localhost",
	Port:     5432,
	User:     "app-user",
	Password: "secret-password",
	DBName:   "app_db",
	SSLMode:  "disable", // Defaults to disable
})
```

*   **DSN Override**: You can bypass individual connection parameters by providing a raw connection string (DSN):
    ```go
    db, err := bdb.New(postgres.Config{
    	DSN: "postgres://app-user:secret-password@localhost:5432/app_db?sslmode=require",
    })
    ```

!!! warning "Connection Timeout during Startup Ping"
    The PostgreSQL driver's startup connection ping does not enforce a default timeout. If the target database server is unreachable, the startup thread can hang indefinitely. Ensure you configure a `connect_timeout` parameter inside your DSN, or invoke constructors using request/deadline context bounds.

---

## MariaDB / MySQL Driver

A production-ready driver for MariaDB and MySQL databases built on `go-sql-driver/mysql`.

```go
import "github.com/brian-nunez/bdb/drivers/mariadb"

// ...
db, err := bdb.New(mariadb.Config{
	Host:     "localhost",
	Port:     3306,
	User:     "app-user",
	Password: "secret-password",
	DBName:   "app_db",
	Params: map[string]string{
		"parseTime": "true",
		"charset":   "utf8mb4",
	},
})
```

*   **DSN Override**: You can bypass parameters by providing a raw DSN:
    ```go
    db, err := bdb.New(mariadb.Config{
    	DSN: "app-user:secret-password@tcp(localhost:3306)/app_db?parseTime=true",
    })
    ```

!!! warning "URL Parameter Escaping"
    Connection parameters provided in the `Params` map are assembled directly into the connection query string without automatic URL-escaping. Make sure special characters in your keys or values are pre-escaped manually before passing them.
