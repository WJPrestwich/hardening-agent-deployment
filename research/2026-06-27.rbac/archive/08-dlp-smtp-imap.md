# H. DLP and content filtering beyond HTTP

- SMTP/IMAP scanning needs MIME parsing, multipart reassembly, text
  extraction (Apache Tika), OCR for images, archive unpacking, and handling
  password-protected attachments.
- Detection should be hybrid: regex for known patterns, entropy for secrets,
  NER/ML for PII, plus allowlists and staged analysis to control false
  positives.
- Integration points: agent egress proxy (lowest coupling), SMTP milter/proxy
  (enterprise), MDA/IMAP gateway (post-delivery quarantine).
- Candidate open-source tools: **Rspamd**, **Haraka**, **Apache James**,
  **MIMEDefang**, **Amavis**, **MailScanner**, **Proxmox Mail Gateway**,
  **Stalwart**.
- Cautions: parser mismatches can be exploited; body/header modifications can
  break DKIM; password workflows must not persist user-supplied secrets.

## Sources

- CCS24 MIME-ambiguity paper
- Apache Tika docs
- Rspamd proxy worker docs
- Haraka / Apache James / MIMEDefang / MailScanner / Stalwart repos
- GitGuardian secret-detection blog
- Microsoft SIT scanning docs
