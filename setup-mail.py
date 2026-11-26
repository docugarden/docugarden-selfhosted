#!/usr/bin/env python3
"""Prepare local mail configuration without starting containers or sending messages."""
import argparse
import base64
import getpass
import hashlib
import json
import os
from pathlib import Path
import secrets
from urllib.parse import quote


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', required=True)
    parser.add_argument('--from-address', required=True)
    parser.add_argument('--username', required=True)
    parser.add_argument('--port', type=int, default=587)
    parser.add_argument('--tls', choices=['starttls', 'implicit'], default='starttls')
    args = parser.parse_args()
    if not 1 <= args.port <= 65535 or any('\n' in v or '\r' in v or '#' in v or '"' in v or "'" in v for v in [args.host, args.from_address, args.username]):
        parser.error('Invalid SMTP configuration')
    root = Path(__file__).resolve().parent / 'secrets'
    if (root / 'mail-platform').exists() or (root / 'mail-client-token.txt').exists():
        parser.error('Mail configuration already exists; edit or rotate it explicitly without regenerating encryption keys')
    user = (root / 'mongodb-username.txt').read_text().strip()
    password = (root / 'mongodb-password.txt').read_text().strip()
    smtp_password = getpass.getpass('SMTP password: ')
    if not smtp_password or '\n' in smtp_password or '\r' in smtp_password:
        parser.error('SMTP password is required and must be one line')
    os.umask(0o077)
    platform = root / 'mail-platform'
    platform.mkdir(mode=0o700)
    token = secrets.token_urlsafe(32)
    redis_password = secrets.token_urlsafe(32)
    values = {
        'encryption-key': base64.b64encode(secrets.token_bytes(32)).decode(),
        'redis-password': redis_password,
        'redis-url': f'redis://:{redis_password}@mail-redis:6379',
        'mongo-uri': f'mongodb://{quote(user, safe="")}:{quote(password, safe="")}@db:27017/docugarden_mail?authSource=admin',
        'tenants.json': json.dumps([{'id': 'self-hosted', 'enabled': True, 'tokenHash': hashlib.sha256(token.encode()).hexdigest()}]),
    }
    for name, value in values.items():
        (platform / name).write_text(value + '\n')
    (root / 'mail-client-token.txt').write_text(token + '\n')
    (root / 'mail-smtp-password.txt').write_text(smtp_password + '\n')
    (root / 'mail-runtime.env').write_text('\n'.join([
        f'MAIL_FROM={args.from_address}', f'MAIL_SMTP_HOST={args.host}', f'MAIL_SMTP_PORT={args.port}',
        f'MAIL_SMTP_TLS={args.tls}', f'MAIL_SMTP_USER={args.username}', '',
    ]))
    print('Local mail configuration prepared. No containers started and no messages sent.')


if __name__ == '__main__':
    main()
