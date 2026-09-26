---
name: seele-credentials
description: Handle credentials for Seele desktop integrations that authenticate to external services or accept user tokens.
---

# Seele integration credentials

Store access tokens, refresh tokens, API keys, and other reusable secrets in the user's system Secret Service wallet. Use `secret-tool` with a stable application attribute and an account or server attribute; feed `store` through stdin and never place a secret in an argument, URL, environment variable, Nix option, repository file, log, or QML property that survives setup. Request the secret from the wallet in the native worker only when needed. Treat a locked or unavailable wallet as an actionable connection error rather than falling back to plaintext storage.

Keep non-secret account metadata and display preferences in a mode-0600 file under the user's XDG config or state directory, written atomically. Validate ownership and permissions before reading it. Cached remote content is private state too, but is not authentication material. Never expose an OAuth code or token in a UI snapshot, error, process list, or diagnostic.

For OAuth desktop flows, use the provider's current installed-app guidance, a loopback callback bound to localhost, PKCE and a random state value. Exchange codes in the native worker, then save the refresh token to the wallet before marking setup complete. Document the operator's OAuth client setup separately from the sign-in UI. On disconnect, delete the wallet entry and private integration state for that account.

Home Assistant's native integration is a local example of Secret Service access. GitHub uses `gh`'s managed authentication for its existing integration; don't copy its credential out into Seele state.
