# Sources

A source is any type that implements the `Source` interface. It provides a string-keyed map of configuration values:

```go
type Source interface {
	Name() string
	Load(ctx context.Context) (map[string]any, error)
}
```

## Merging Behavior

Sources are loaded and merged from left to right. Later values override earlier values when they share the same key path.

```go
cfg, err := bconfig.New(
	file.Source("defaults.yaml"),
	file.Source("production.yaml"),
)
```

*   **Maps**: Merged recursively.
*   **Scalars and Slices**: Later sources completely replace earlier values.

For example:
```yaml title="defaults.yaml"
server:
  addr: ":8080"
  timeout: "5s"
features:
  - login
```

```yaml title="production.yaml"
server:
  addr: ":9090"
features:
  - login
  - billing
```

The resulting configuration will contain:
```yaml
server:
  addr: ":9090"
  timeout: "5s"
features:
  - login
  - billing
```

---

## File Source

The File source loads configuration files in YAML or JSON format based on the file extension.

```go
import "github.com/brian-nunez/bconfig/drivers/file"

// ...
source := file.Source("config.yaml")
```

| Extension | Parser |
| --- | --- |
| `.yaml`, `.yml` | `gopkg.in/yaml.v3` |
| `.json` | `encoding/json` |

*   Paths may be relative or absolute.
*   Empty files or a JSON `null` load as an empty map.

---

## Environment Source

The Environment source reads environment variables, filters them by optional prefixes, lowercases key names, and returns a flat map.

```go
import "github.com/brian-nunez/bconfig/drivers/env"

// ...
source := env.Source("BAPP_")
```

*   **Key Formatting**: Keys are converted to lowercase. For example, `BAPP_SERVER_PORT` becomes `bapp_server_port`.
*   **Prefix Retention**: Prefixes are retained in key names.
*   **Multiple Prefixes**: You can supply multiple prefix filters: `env.Source("BAPP_", "SHARED_")`.

### Value Parsing

Flat environment string values are automatically parsed into typed Go values:

| Environment text | Parsed Type |
| --- | --- |
| `true`, `false` | `bool` (case-sensitive) |
| `42` | `int` |
| `3.14` | `float64` |
| Any other value | `string` |

---

## Custom Sources

You can implement custom configuration loaders (e.g. database loaders, remote configuration stores) by implementing the `Source` interface:

```go
type staticSource map[string]any

func (staticSource) Name() string { return "static" }

func (s staticSource) Load(ctx context.Context) (map[string]any, error) {
	return map[string]any(s), nil
}
```
