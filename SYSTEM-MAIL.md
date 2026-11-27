# Docugarden system mail setup

System mail is disabled by default. After installing matching application images
that include system mail, a superuser can configure SMTP or Microsoft Graph from
the general admin settings page, save and send a test message. There is no central
Docugarden relay, queue, Redis or automatic retry. Each installation uses its own
SMTP server/provider or Microsoft 365 tenant and sender mailbox.

Configuration saved in the application overrides `.env` defaults. Passwords and
Client Secrets are encrypted with the existing MongoDB encryption key and are not
returned by the API. Keep that key with the installation backup. Leave a secret
input blank to preserve it, or use the explicit clear action to remove it.

For environment-based setup use the SYSTEM_MAIL variables in `.env.example`.
SMTP requires `starttls` (typically port 587) or `tls` (typically port 465).
Put the SMTP password in `mail-secrets/smtp-password.txt`, then set
`SYSTEM_MAIL_SMTP_PASSWORD_FILE=/run/mail-secrets/smtp-password.txt`.
For Graph put the Client Secret in `mail-secrets/graph-client-secret.txt` and set
`SYSTEM_MAIL_GRAPH_CLIENT_SECRET_FILE=/run/mail-secrets/graph-client-secret.txt`.
The backend mounts this directory read-only. Set restrictive file permissions
that still allow the backend container process to read the files. Never commit
credentials. Recreate the backend after environment or credential-file changes.

Graph requires Tenant ID, Client ID, Client Secret and an Exchange Online sender
mailbox in the customer tenant. No Microsoft partner membership is necessary.
Use Exchange Online Application RBAC `Application Mail.Send` scoped to the sender
mailbox, without an overlapping tenant-wide Entra Mail.Send grant. Client Secret
expiration/rotation remains the operator's responsibility.

`PUBLIC_URL` must be the canonical externally reachable HTTPS address; Compose
passes it as `FRONTEND_URL`, used for activation/reset links. Allow outbound SMTP
to your configured server or HTTPS to login.microsoftonline.com and
graph.microsoft.com. No inbound mail port is required.

Invitations last 48 hours and resets 30 minutes. A new link revokes the previous
one, with at least a minute between requests per user. Passwords change and
existing sessions are invalidated only when the recipient completes the link;
2FA is preserved. If sending fails, the pending user remains and can be reinvited.
The original first-admin and direct admin reset paths still work without mail.

The admin register retains only attempt metadata for 30 days. Accepted means
provider acceptance, not confirmed delivery. Unknown means delivery may have
occurred: check before resending. A crashed in-progress attempt appears unknown
after two minutes. No background retry is attempted.

Legacy SMTP passwords migrate to encrypted settings and are removed from the old
field. Migrated settings stay disabled until the operator reviews sender and TLS.
Use the application System mail page; the legacy update endpoint returns 410.

Review/merge the application and deployment branches, publish matching backend
and frontend images, then set IMAGE_TAG to that published release and perform the
normal update. This branch does not publish images or deploy changes. Keep
Mailpit and insecure SMTP in development only; neither is added to this stack.
