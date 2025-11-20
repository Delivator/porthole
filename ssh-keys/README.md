# SSH Keys Directory

Place your SSH private key here as `id_ed25519` to use with the tunnel.

**Important Security Notes:**
- This directory should contain your SSH private key for authentication
- Make sure this directory is in `.gitignore` to prevent accidentally committing keys
- Set proper permissions: `chmod 600 id_ed25519`
- Optionally, you can also place a `known_hosts` file here

## Creating an SSH Key Pair

If you don't have an SSH key pair, create one:

```bash
ssh-keygen -t ed25519 -f ./ssh-keys/id_ed25519 -N "" -C "porthole-tunnel-key"
```

Then copy the public key to your remote server:

```bash
ssh-copy-id -i ./ssh-keys/id_ed25519.pub user@your-remote-server.com
```

## File Structure

```
ssh-keys/
├── id_ed25519      # Your private key (required)
└── known_hosts     # Optional: known hosts file for strict host checking
```
