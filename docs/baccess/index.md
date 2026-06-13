# baccess

`baccess` is a predicate‑based authorization library for Go. It enables fine‑grained access control by combining simple boolean functions (predicates) into expressive policies. The library supports Role‑Based Access Control (RBAC) and Attribute‑Based Access Control (ABAC) through generic, type‑safe interfaces.

[View source on GitHub](https://github.com/brian-nunez/baccess){ .md-button }

## Installation

```bash
go get github.com/brian-nunez/baccess
```

## Quick Start

```go
package main

import (
    "fmt"

    "github.com/brian-nunez/baccess"
)

type User struct {
    ID    string
    Roles []string
}

func (u User) GetRoles() []string { return u.Roles }

type Document struct {
    OwnerID string
}

func main() {
    evaluator := baccess.NewEvaluator[User, Document]()
    rbac := baccess.NewRBAC[User, Document]()

    isOwner := baccess.FieldEquals(
        func(u User) string { return u.ID },
        func(d Document) string { return d.OwnerID },
    )

    // Admins may delete any document. Editors may delete documents they own.
    canDelete := rbac.HasRole("admin").Or(
        rbac.HasRole("editor").And(isOwner),
    )
    evaluator.AddPolicy("delete", canDelete)

    alice := User{ID: "alice", Roles: []string{"editor"}}
    document := Document{OwnerID: "alice"}
    request := baccess.AccessRequest[User, Document]{
        Subject:  alice,
        Resource: document,
        Action:   "delete",
    }

    fmt.Println(evaluator.Evaluate(request)) // true
}
```

`User` satisfies `baccess.RoleBearer` by implementing `GetRoles`. The typed
`RBAC` then creates role predicates for the same `User` and `Document` request
used by the evaluator. Predicates are reusable, so role checks can be composed
with ownership, attributes, or other application rules.

For a role-only check, evaluate the predicate against an access request:

```go
isAdmin := rbac.HasRole("admin")
allowed := isAdmin.IsSatisfiedBy(request)
```

Use `rbac.HasAnyRole("admin", "moderator")` when any role in a set should
match.

## Configuration-Based Policies

For policies stored in JSON, register application predicates and build an
evaluator from the loaded configuration:

```go
registry := baccess.NewRegistry[User, Document]()
registry.Register("isOwner", isOwner)

cfg, err := baccess.LoadConfigFromFile("config.json")
if err != nil {
    log.Fatal(err)
}

evaluator, err := baccess.BuildEvaluator(cfg, rbac, registry)
if err != nil {
    log.Fatal(err)
}
```

## Documentation

For a deeper dive into the core concepts, types, predicate composition, and
configuration format, see the
[technical documentation](https://github.com/brian-nunez/baccess/blob/main/TECHNICAL.md).
