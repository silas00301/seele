# Upstream Proton compatibility boundary

`bcrypt-5.patch` is a narrow compatibility change inside the upstream Proton
Python authentication package. The GUI and its Proton dependencies must use the
same Python package set; changing this adapter's language independently would
require replacing the upstream authentication implementation and its API.

The patch preserves Proton's established SRP password processing by explicitly
retaining bcrypt's previous 72-byte truncation behavior. It must not introduce a
new prehash or change the protocol. The upstream bcrypt project documents the
[new long-password error](https://github.com/pyca/bcrypt#maximum-password-length).
`test-long-password.py` runs against the patched package during the Nix check
phase and verifies equality across that boundary. It does not use an account or
contact Proton. The separate upstream CLI package remains unchanged.
