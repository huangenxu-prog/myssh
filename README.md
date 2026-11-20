# MySSH

Minimal iOS SSH command client, based on the uploaded SSHTool prototype.

## Features
- Password authentication to a VPS on a custom port
- Execute individual remote commands and view output
- Disconnect and clear output
- GitHub Actions unsigned IPA build for later signing

## Limitations
- Not an interactive PTY terminal. Commands such as vim, nano, top and persistent cd sessions are not supported.
- **Security warning:** this initial prototype accepts any SSH server host key. Do not use on untrusted networks until host-key verification is implemented.
- Build and runtime behavior must be verified in GitHub Actions and on a real iPhone.
