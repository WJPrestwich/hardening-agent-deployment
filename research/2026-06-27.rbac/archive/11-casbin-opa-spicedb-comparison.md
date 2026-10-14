# Casbin vs. OPA vs. SpiceDB for a personal single-host agent

This is our own assessment, not a Tavily-sourced survey. The goal is to pick a policy engine for the proposed policy proxy running on a single Ubuntu host, managed by one person, with minimal operational overhead.

---

## Evaluation criteria

| Criterion                      | Why it matters for us                                                            |
|--------------------------------|----------------------------------------------------------------------------------|
| **Setup and admin burden**     | One-person stack; we want minutes-to-hours, not days.                            |
| **External dependencies**      | Fewer moving parts = fewer things to patch and back up.                          |
| **Policy language complexity** | Must be writable by a solo operator without becoming a full-time rules engineer. |
| **Deployment form**            | Single host means in-process or local sidecar; no Kubernetes required.           |
| **Latency**                    | Synchronous tool checks must be fast enough to not ruin the agent UX.            |
| **Audit and debugging**        | We need clear logs when a tool is blocked or allowed.                            |
| **Flexibility ceiling**        | Should handle per-tool ABAC now and not paint us into a corner later.            |

---

## Casbin

**What it is** — An authorization library, not a service. You link it into the policy proxy (Go, Python, Node, Rust, etc.), load a `model.conf` and a `policy.csv`, and call `e.Enforce(subject, object, action)`.

**Pros for our use case**

- **Zero external dependencies** for file-based policies. No database, no sidecar, no network hop.
- **Very fast** because it runs in-process. Sub-millisecond enforcement is normal.
- **Low conceptual overhead** for RBAC/ABAC-style rules. `model.conf` defines the request shape and effect; `policy.csv` lists concrete grants.
- **Plenty of examples** for classic patterns: ACL, RBAC, ABAC, REST path matching, domain tenants, priority rules.
- **Mature and widely used** (most GitHub stars in our open-source list).

**Cons**

- The PERM metamodel and CSV policy format can feel arcane at first.
- ReBAC/deep relationship modeling ("user A delegated to agent B which can access files in workspace C") is possible but not natural; you end up encoding relationships in attributes or policy rows.
- No built-in distributed decision-log pipeline; we would write our own audit wrapper.
- Policies live in flat files by default, so dynamic updates require reloading the model or using a watcher/adapter.

**Verdict for the policy proxy** — Strong first choice. It is the simplest way to check `allow/deny` for tool calls on a single host.

---

## OPA (Open Policy Agent)

**What it is** — A general-purpose policy engine with its own language, Rego. You write policies as code, load them into OPA (sidecar, embedded library, or WASM), and query it over HTTP or via a language SDK.

**Pros for our use case**

- **Very flexible**. Rego can express complex ABAC, transformations, and even obligations/advice in the response.
- **Policy-as-code** with built-in testing (`opa test`), bundles, and versioning. This is attractive if the policy proxy's policies become a real codebase.
- **Can run as a tiny local sidecar** or be embedded via the Go SDK / WASM. On a single host a sidecar is just another systemd unit next to Pipelock.
- **Decision logs** are a first-class feature.
- **Large ecosystem**: Envoy, Kubernetes, Terraform, etc. If we ever scale up, OPA skills transfer.

**Cons**

- **Rego has a learning curve**. For a one-person project, writing and debugging Rego is more work than Casbin's CSV/model split.
- **More parts to operate** if run as a sidecar: binary, policy bundle loading, health, logs, restart behavior.
- **Slightly higher latency** than in-process Casbin because of the extra hop, though still typically sub-millisecond on localhost.
- **Overkill for simple allow/deny tables**. We would be paying the complexity tax before we need it.

**Verdict for the policy proxy** — Good second step. Use it if Casbin policies become unwieldy or if we want stronger policy testing/versioning.

---

## SpiceDB

**What it is** — A Zanzibar/ReBAC authorization database. You define a schema of object types and relations, write tuples like `(user:alice, owner, workspace:home)`, then call `CheckPermission` to see if an action is allowed.

**Pros for our use case**

- **Natural for delegation and ownership graphs**: "Alice owns the agent; the agent may read files in workspace X; the agent may send email only after approval."
- **Very scalable** if we ever move beyond one host.
- **Correct-by-design patterns** for relationship-based access control.

**Cons**

- **Requires a datastore**. The in-memory backend is only for testing; for any persistence we need Postgres, CockroachDB, Spanner, or MySQL. That is a second service to install, back up, and patch on a personal machine.
- **Higher operational surface** than Casbin or OPA: schema migrations, relationship writes, datastore tuning, caching knobs.
- **Network hop + database query** means higher baseline latency than an in-process library, even though SpiceDB can be very fast at scale.
- **ReBAC is powerful but foreign** to a solo operator who just wants to say "allow `send_email` to example.com."

**Verdict for the policy proxy** — Overkill for a first implementation. Consider only if we discover that delegation chains or shared workspaces are central requirements.

---

## Side-by-side summary

| Dimension             | Casbin                    | OPA                           | SpiceDB                                    |
|-----------------------|---------------------------|-------------------------------|--------------------------------------------|
| External dependencies | None (file-based)         | OPA binary or embedded SDK    | Database service (Postgres/Cockroach/etc.) |
| Setup complexity      | Low                       | Medium                        | High                                       |
| Policy language       | PERM model + CSV/policies | Rego                          | Schema DSL + relationship tuples           |
| Deployment            | In-process library        | Sidecar / embedded / WASM     | Service + client library                   |
| Typical latency       | Sub-ms in-process         | ~sub-ms to low-ms sidecar     | Low-ms (network + DB)                      |
| Best paradigm         | RBAC / ABAC               | ABAC / complex policy-as-code | ReBAC / delegation graphs                  |
| Audit                 | Roll your own             | Built-in decision logs        | Built-in, but more infra                   |
| Single-host fit       | Excellent                 | Good                          | Poor-to-fair                               |
| Solo-operator fit     | Excellent                 | Good                          | Fair                                       |

---

## Recommendation

**Project decision:** the hardened Hermes stack uses **ContextForge** as the MCP gateway. ContextForge has its own native RBAC/ABAC engine, so we do not need a separate Casbin/OPA/SpiceDB sidecar.

**OPA and Casbin are explicitly out of scope.** If ContextForge's native RBAC/ABAC proves insufficient, the next option is ContextForge's Cedar plugin. The comparison below is kept for reference only.

### If we were building a custom policy proxy

**OPA** is the superior dedicated engine. It has decision logs, policy bundles, `opa test`, broader ecosystem support, and can inspect full JSON request bodies for argument-level policy decisions. OPA is the right choice if the proxy lives in Kong, if policies are complex, or if strong audit/versioning is required.

**Casbin** is simpler and faster as an embedded in-process library with no extra services, but it lacks OPA's operational tooling, audit features, and gateway integrations. It is only the right choice for a tiny custom proxy where adding a sidecar is unacceptable.

**SpiceDB** should be deferred unless we explicitly need relationship-based authorization (multi-user delegation, shared workspaces, complex ownership chains).

---

## Verification of core claims

### Casbin

- **Library, file-based, no external service**: verified by Casbin docs and tutorials (`newEnforcer('model.conf', 'policy.csv')`).
- **Sub-millisecond enforcement for small policies**: verified by the official Casbin benchmarks — ACL/RBAC/ABAC test cases run in roughly 0.015–0.05 ms/op for small rule sets.
- **Memory-load caveat**: Casbin loads the whole policy set into memory and evaluates against it. For the small policy counts expected in the policy proxy this is fine; very large rule sets require sharding or filtered loading.

### OPA

- **Built-in decision logs**: verified by the OPA decision-logs docs (`decision_logs: console: true` and remote upload options).
- **Sidecar/local low latency**: verified by OPA deploy docs and AWS sidecar blog — local calls avoid network hops; simple Rego policies can be evaluated in tens to hundreds of microseconds. Complex policies or large data sets can push this higher, which is a known trade-off.
- **Deployment forms (sidecar, embedded, WASM, central service)**: verified by OPA deployment documentation.

### SpiceDB

- **Requires an external datastore**: verified by AuthZed docs (`authzed.com/docs/spicedb/concepts/datastores`). Supported production datastores are CockroachDB, Cloud Spanner, PostgreSQL, and MySQL. The `memory`/`memdb` backend is explicitly recommended only for local development and integration testing.
- **Migrations required**: verified by the SpiceDB datastore-migrations docs.

---

## Can Casbin reject tool calls that contain forbidden values?

Yes, with the right request shape and matcher. Casbin is not a generic content scanner, but it can inspect attributes that you pass into the `Enforce()` call and match them with patterns, regular expressions, or custom functions.

### Option 1: Deny-override with regex patterns

If the tool call exposes the target path/string as a request attribute, you can write allow/deny policies with regex patterns:

**model.conf**

```ini
[request_definition]
r = sub, obj, act, target

[policy_definition]
p = sub, obj, act, pattern, eft

[policy_effect]
e = some(where (p.eft == allow)) && !some(where (p.eft == deny))

[matchers]
m = r.sub == p.sub && r.obj == p.obj && r.act == p.act && regexMatch(r.target, p.pattern)
```

**policy.csv**

```csv
p, hermes, filesystem, write, ^/workspace/.*$, allow
p, hermes, filesystem, write, ^/etc/.*$, deny
p, hermes, filesystem, write, ^/root/.*$, deny
```

This rejects `filesystem` `write` calls whose target starts with `/etc/` or `/root/`, while allowing writes under `/workspace/`.

### Option 2: Custom function for a deny list

For arbitrary words or paths, register a custom function that checks a deny list loaded from config:

```go
e.AddFunction("forbidden", func(args ...interface{}) (interface{}, error) {
    text := args[0].(string)
    blacklist := []string{"/etc/passwd", "rm -rf", "drop table"}
    for _, w := range blacklist {
        if strings.Contains(text, w) {
            return false, nil
        }
    }
    return true, nil
})
```

```ini
[matchers]
m = r.sub == p.sub && r.obj == p.obj && r.act == p.act && forbidden(r.args)
```

The request would include the serialized tool arguments in `r.args`.

### Caveat

Casbin evaluates the attributes you give it. If the agent passes a raw shell command string, you must either parse it before calling Casbin or register a function that understands the command syntax. Casbin will not do that parsing for you.

---

## Suggested policy-proxy design

> **Superseded.** This section was written before we chose ContextForge as the MCP gateway. ContextForge's native RBAC/ABAC is now the policy engine; no separate PDP interface or Casbin/OPA implementation is needed. The text below is retained for reference only.

Define a small PDP interface inside the policy proxy:

```go
type PDP interface {
    Authorize(req AuthzRequest) (Decision, []Obligation, error)
}
```

Implement the first version with Casbin. Leave the door open to plug in OPA later by implementing the same interface for an OPA sidecar or embedded engine. That keeps the architecture clean without paying OPA's complexity tax on day one.
