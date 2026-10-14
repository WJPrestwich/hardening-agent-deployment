# G. Credential scoping and short-lived tokens

- **Provider key scoping**:
  - OpenAI: project/org headers exist but no public key-minting API with TTL.
  - Anthropic: workspace-scoped keys with read-only vs full permissions.
  - Azure OpenAI: managed identities + API Management + Key Vault.
  - Mistral/Portkey/Cohere: workspace or service/project keys.
- **OAuth device flow** is the standard for headless agents; use refresh-token
  rotation and minimize persistence.
- **Broker pattern**:
  - HashiCorp Vault AppRole with response wrapping can mint short-lived
    provider keys (e.g., 15m TTL, 1h max) and audit issuance.
  - AWS STS `AssumeRole` / IRSA for container identity.
  - GCP Workload Identity Federation + service-account impersonation.
- Recommended pattern for our stack: platform identity → broker → short-lived
  provider key kept in memory only; never pass long-lived keys into the agent
  container.

## Sources

- HashiCorp Vault AppRole docs
- Riptides short-lived OpenAI keys blog
- AWS STS docs
- GCP Workload Identity docs
- Okta refresh-token guide
- OAuth device-authorization RFC
