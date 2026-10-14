# A. Hermes native security primitives

- `Tirith` is a pre-execution command scanner integrated into Hermes’ approval
  flow. It is fail-open by default (`tirith_fail_open: true`); set it to
  `false` for fail-closed behavior. There is no documented user-editable rule
  language in the public docs.
- The `security` block supports `tirith_enabled`, `tirith_path`,
  `tirith_timeout`, `tirith_fail_open`, and `redact_secrets`. `redact_secrets`
  has known caveats (can redact before passing to tools; config toggle may not
  be respected during early startup).
- Toolset/skill allow and deny lists exist: `agent.disabled_toolsets`,
  `platform_toolsets.cli`, and programmatic `enabled_toolsets` /
  `disabled_toolsets` in the `AIAgent` constructor. Hermes also has a “Blank
  Slate” mode that pins toolsets.
- Tool approval modes are documented (`always_allow`, `always_ask`, `smart`,
  `deny`) and bridge sessions expose pending approvals.
- Skill trust tiers (`builtin`, `official`, `trusted`, `community`) are
  enforced at install time; `dangerous` scan verdicts block community installs
  even with `--force`.
- Subagent/delegate isolation is **only OS-level**. The internal sandbox can
  expose `PYTHONPATH`, `HERMES_HOME`, `.env`, and provider keys, so external
  containment (our hardened container) is essential.

## Sources

- Hermes docs: security, skills, MCP, tools runtime
- GitHub `cli-config.yaml.example`
- GitHub issues #16700, #11009, #7071, #7826, #33905
- MolTrust skill-trust post
- MarkTechPost Blank Slate article
