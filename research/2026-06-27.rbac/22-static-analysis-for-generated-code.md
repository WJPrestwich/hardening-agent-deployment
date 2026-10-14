# Static analysis for LLM-generated code

> **Project decision:** the hardened Hermes stack will use **LlamaFirewall CodeShield** as the generated-code scanner, deployed as a container in the stack. This page documents the alternatives we considered and why CodeShield was chosen. See [23-llamafirewall-fit-assessment.md](./23-llamafirewall-fit-assessment.md) for the full rationale and integration plan.

Hermes has two code-generation paths that are dangerous in different ways:

- `execute_code` runs arbitrary Python inside the agent process (or a sandbox that still shares too much state).
- `terminal` can run arbitrary shell commands.

Even after those native tools are disabled, MCP-mediated code-execution servers may generate code. Before any generated code runs, we want a deterministic, fast, auditable check that catches the most common insecure patterns: subprocess calls, hardcoded secrets, unsafe deserialization, SQL injection skeletons, network egress, and filesystem writes outside the workspace.

This page looks at tools that do **CodeShield-style** validation without pulling in the rest of LlamaFirewall.

---

## What CodeShield actually is

CodeShield, the code-analysis piece of Meta's LlamaFirewall, is an online static-analysis engine that scans LLM-generated code before execution. According to Meta's paper and docs:

- It uses a hybrid engine: fast regex-based screening first, then Semgrep-based AST analysis for deeper patterns.
- It covers eight programming languages and 50+ CWEs.
- It is optimized for sub-second latency so it can sit in an interactive agent loop.
- It is released as part of PurpleLlama under the MIT license.

The catch is that CodeShield is packaged inside LlamaFirewall, which also includes PromptGuard 2, Agent Alignment Checks, and a broader framework. If we only want the code-scanning piece, we can either extract CodeShield from PurpleLlama or build an equivalent pipeline from smaller, focused tools.

Sources:

- Meta LlamaFirewall paper (arXiv 2505.03574)
- Meta PurpleLlama GitHub (`meta-llama/PurpleLlama`)
- Meta LlamaFirewall docs

---

## Option 1: Semgrep (recommended first choice)

**What it is.** Semgrep is a fast, open-source static-analysis engine from Semgrep Inc. Rules are written in a syntax close to the target language. It runs locally, supports 30+ languages, and can scan files or arbitrary snippets.

**Why it fits.**

- CodeShield itself uses Semgrep for its deeper analysis layer, so Semgrep gives us the same core capability without the surrounding framework.
- It can target a single snippet or a temporary workspace, which is exactly what an agent produces.
- It has an extensive open-source rule registry (Semgrep Registry) covering OWASP Top 10, CWEs, secrets, and dangerous APIs.
- It is fast enough to run inline before executing generated code.

**How to use it for generated code.**

```bash
# Write generated code to a temp file and scan it
semgrep --config=auto --error /tmp/agent-generated-code.py
```

For a more controlled policy, write a small custom rule set:

```yaml
# hermes-generated-code-policy.yml
rules:
  - id: ban-subprocess
    pattern: subprocess.call(...)
    languages: [python]
    message: "Generated code must not call subprocess directly."
    severity: ERROR

  - id: ban-os-system
    pattern: os.system(...)
    languages: [python]
    message: "Generated code must not use os.system."
    severity: ERROR
```

**Limitations.** Semgrep is pattern- and dataflow-based. It will not catch every novel vulnerability, and it can produce false positives on intentionally unusual agent-generated code. It is a filter, not a sandbox.

Sources:

- Semgrep GitHub (`semgrep/semgrep`)
- Semgrep docs
- Meta LlamaFirewall paper noting CodeShield's Semgrep layer

---

## Option 2: Bandit (Python-specific)

**What it is.** Bandit is an open-source Python security linter from the OpenStack Security Project. It parses the Python AST and checks for known anti-patterns: hardcoded credentials, weak crypto, unsafe subprocess use, eval/exec, SQL injection patterns, and more.

**Why it fits.**

- Hermes' `execute_code` is Python-first. If the generated code is Python, Bandit is the simplest specialized scanner.
- It is lightweight and easy to run on a single file or snippet.
- It has a clear severity model (LOW, MEDIUM, HIGH) and can fail CI-style on thresholds.

**How to use it.**

```bash
bandit -r /tmp/agent-generated-code.py -f json
```

Or for a single snippet written to a temp file:

```bash
bandit -f json /tmp/snippet.py
```

**Limitations.** Python only. Less flexible rule syntax than Semgrep. Best used alongside Semgrep, not as the only scanner.

Sources:

- Bandit PyPI and GitHub
- OWASP Source Code Analysis Tools list

---

## Option 3: CodeQL (GitHub)

**What it is.** CodeQL is GitHub's semantic code-analysis engine. It builds a database of the code's AST, control flow, and data flow, then runs queries written in QL.

**Why it fits.**

- Much deeper analysis than regex or simple patterns. It can follow taint from user input to a sink.
- Free for public repositories; CLI can run locally on arbitrary code.
- Good for building a small set of high-confidence checks that Semgrep might miss.

**Why it is not the first choice.**

- Higher setup cost: must build a CodeQL database before querying.
- Slower than Semgrep or Bandit, making it harder to run inline in an interactive agent loop.
- Rule authoring in QL is more complex.

**Best use.** As an offline deeper scan, or for the most security-sensitive generated-code paths, rather than the default inline gate.

Sources:

- GitHub CodeQL docs
- Academic comparisons of CodeQL and Semgrep on LLM-generated code

---

## Option 4: Code Pathfinder

**What it is.** Code Pathfinder is an open-source static-analysis tool with inter-file dataflow/taint analysis and an MCP server interface. It is designed for security teams that need to find vulnerabilities across multi-language codebases.

**Why it might fit.**

- It exposes an MCP server, so an agent or proxy could call it as a tool.
- It targets dataflow, not just pattern matching.

**Concerns.** It is newer and less battle-tested than Semgrep or Bandit. Evaluate it only if the simpler tools do not provide enough depth.

Sources:

- `analysis-tools-dev/static-analysis` curated list
- Code Pathfinder GitHub

---

## Option 5: Joern

**What it is.** Joern is an open-source code-analysis platform for C/C++, Java, JavaScript, Python, Kotlin, JVM bytecode, PHP, Go, and Ruby. It builds a property graph and supports custom queries.

**Why it might fit.**

- Good if we need to scan generated code in multiple languages with a unified graph model.
- More flexible than language-specific linters.

**Concerns.** Steeper learning curve and heavier than Semgrep. Best considered only if the agent generates code in languages that Semgrep covers poorly.

Sources:

- OWASP Source Code Analysis Tools list
- Joern GitHub

---

## Recommended stack

The project's chosen stack is **LlamaFirewall CodeShield**, because it already combines the layers below into a single, maintained scanner:

- Fast regex-based screening.
- Semgrep-based AST analysis for deeper patterns.
- Coverage of eight languages and 50+ CWEs.
- Sub-second latency suitable for an interactive agent loop.

CodeShield runs as a container in the stack and is called over a local HTTP endpoint before generated code is executed. See [23-llamafirewall-fit-assessment.md](./23-llamafirewall-fit-assessment.md) for the integration diagram and API sketch.

If CodeShield proves too heavy or its rule set is too noisy for a specific deployment, the fallback pipeline is:

1. **Semgrep** as the primary inline scanner, using the Semgrep Registry plus Hermes-specific rules (ban subprocess, os.system, eval, exec, network calls, and writes outside `/workspace`).
2. **Bandit** as a Python-specific second opinion when the generated code is Python.
3. **CodeQL** as an offline deeper scan for high-sensitivity tasks, not as the inline gate.
4. A **one-shot sandbox** (no network, read-only `/workspace`) as the final execution boundary.

In either case, static analysis is the filter and the sandbox is the boundary; neither replaces the other.

---

## How it fits the broader architecture

```
Agent generates code
        │
        ▼
┌───────────────────┐
│ Semgrep + Bandit  │  ← fast static check on the snippet
│ (fail-closed)     │
└─────────┬─────────┘
          │ pass
          ▼
┌───────────────────┐
│ One-shot sandbox  │  ← no network, read-only workspace, time limit
│ (Docker/gVisor)   │
└─────────┬─────────┘
          │ result
          ▼
       Agent
```

Static analysis is the filter. The sandbox is the boundary. Neither replaces the other.

---

## Open questions

- Which Semgrep rules produce acceptable false-positive rates on agent-generated code?
- Should the scanner run inside the MCP code-execution server, or as a separate tool-call validation step in ContextForge/the policy proxy?
- How do we handle generated code that intentionally needs "dangerous" APIs (e.g., a one-off `subprocess` call requested by the operator)?
- Do we need a small custom rule set for shell scripts generated by `terminal` replacements?

---

## Sources

- Meta LlamaFirewall paper (arXiv 2505.03574)
- Meta PurpleLlama GitHub (`meta-llama/PurpleLlama`)
- Meta LlamaFirewall docs
- Semgrep GitHub and docs (`semgrep/semgrep`)
- Bandit GitHub and docs
- GitHub CodeQL docs
- Code Pathfinder GitHub
- Joern GitHub
- OWASP Source Code Analysis Tools list
