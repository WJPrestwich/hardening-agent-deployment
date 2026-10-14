# C. Email integration and least-privilege scopes

- **Gmail API OAuth scopes** (fine-grained):
  - Read-only: `https://www.googleapis.com/auth/gmail.readonly`
  - Send-only: `https://www.googleapis.com/auth/gmail.send`
  - Read+modify: `https://www.googleapis.com/auth/gmail.modify`
  - Full mailbox / IMAP-SMTP XOAUTH2: `https://mail.google.com/`
- **Microsoft Graph Mail**:
  - Delegated: `Mail.Read`, `Mail.Send`, `Mail.ReadWrite`
  - Application: `Mail.Read.All`, `Mail.ReadWrite.All`, `Mail.Send`
  - Protocol app permissions: `IMAP.AccessAsApp`, `SMTP.SendAsApp`
- For least privilege, prefer REST/Graph APIs over IMAP/SMTP. Use OAuth
  delegated flows for a single user, app-only/client-credentials for
  background automation.
- Provider-side controls complement agent-side RBAC: OAuth app verification,
  admin consent, Conditional Access, refresh-token limits, and revocation.

## Sources

- Google OAuth 2.0 scopes reference
- Gmail XOAUTH2 protocol docs
- Google sensitive scope verification docs
- Microsoft Graph permissions reference
- Microsoft Graph `user: sendMail` docs
- EmailEngine Gmail OAuth / IMAP guide
- eLegere Microsoft Graph email auth example
