# BKit API Template

The [BKit API Template](https://github.com/brian-nunez/bkit-api-template) is the BKit ecosystem assembled into a complete Go service. It is a working example of what these small libraries become when they meet: configuration flows into infrastructure, infrastructure becomes a service, and every part remains clear, direct, and yours.

[View the template on GitHub](https://github.com/brian-nunez/bkit-api-template){ .md-button .md-button--primary }

## The Complete Picture

The template brings together the full BKit stack with an Echo HTTP server, background worker, server-rendered interface, telemetry, and a Docker development environment.

- `bconfig` merges file and environment configuration.
- `bsuite` hydrates the selected database, key/value store, and telemetry services.
- `brun` gives the HTTP server and background worker one graceful lifecycle.
- `bdb`, `bkv`, and `btelemetry` remain focused behind their own small APIs.
- `baccess` can guard handlers and resource operations with composable policy.

Around those pieces, the template includes PostgreSQL, MariaDB, Redis, SQLite, OpenTelemetry, Prometheus, Templ, Tailwind CSS, templUI, HTMX, hot reloading, and a production container build.

```bash
git clone https://github.com/brian-nunez/bkit-api-template.git my-service
cd my-service
docker compose up --build
```

## Composed, Not Entangled

BKit does not ask one package to know everything. Configuration does not own persistence. Persistence does not own telemetry. The lifecycle manager does not care whether it is running an HTTP server, a worker, or something you have not written yet.

Each library has one role. Your application composes those roles at startup.

```text
bconfig ──> bsuite ──> bdb
                  ├──> bkv
                  └──> btelemetry

request ──> baccess ──> authorized application operation

HTTP server ─┐
             ├──> brun ──> one lifecycle
worker ──────┘
```

That separation is what lets the pieces mesh so naturally. They share familiar Go concepts such as contexts, errors, interfaces, and explicit constructors instead of hiding the application behind a framework.

## Freedom Through Small Boundaries

The template is complete, but it is not closed. Drivers are selected through configuration. Long-running processes implement a small `Run(context.Context) error` contract. The service container exposes the infrastructure your code needs without dictating how the rest of the application must be designed.

You can begin with the entire stack or adopt one package at a time. You can move from local storage to Redis, from SQLite to PostgreSQL, or from one runnable process to several while preserving the shape of the application around them.

The wider BKit journey remains open around the template. Add `objex` when the
service needs filesystem, S3, or MinIO objects. Apply `baccess` at handler and
service boundaries when operations need role, ownership, or resource policy.
Those capabilities stay explicit in application code instead of being hidden
inside the service container.

This is the freedom BKit is built for: useful defaults without permanent decisions, shared structure without tight coupling, and infrastructure that supports the service instead of becoming the service.

## A Beautiful Starting Point

There is a particular simplicity to a system where every piece has a visible purpose. Configuration enters in one place. Resources are initialized together. Servers and workers start together. Shutdown follows the same context back through the application. Nothing needs to pretend it owns more than it does.

The API template makes that design concrete. It gives you a service that already runs, builds, observes itself, and connects to real infrastructure while keeping the architecture open to what comes next.

[Explore how the packages fit together](getting-started.md){ .md-button }
[View the source](https://github.com/brian-nunez/bkit-api-template){ .md-button }
