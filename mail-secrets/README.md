# Docugarden mail credentials

This directory is mounted read-only at `/run/mail-secrets` in the backend.
For optional environment-based SMTP or Graph setup, create `smtp-password.txt`
or `graph-client-secret.txt` locally and restrict their permissions to the
container operator and backend process. These files are ignored by Git.
Set the corresponding `SYSTEM_MAIL_*_FILE` variable to the container path.
The directory is unnecessary for credentials configured through the admin UI.
Do not commit credentials or paste them into support logs.
