"""Offline SRP password boundary checks shared by the GUI and CLI package set."""
import hashlib

from proton.session.srp.util import hash_password, hash_password_3


salt = b"0123456789"
modulus = b"modulus"

# This is a byte boundary, not a character limit: the final case cuts a UTF-8
# sequence in half, exactly as bcrypt did before version 5.
for password in [
    b"",
    b"x" * 71,
    b"x" * 72,
    b"x" * 73,
    b"x" * 256,
    ("x" * 71 + "ä").encode("utf-8"),
]:
    expected = hash_password_3(hashlib.sha512, password[:72], salt, modulus)
    assert hash_password_3(hashlib.sha512, password, salt, modulus) == expected
    for version in (3, 4):
        assert hash_password(hashlib.sha512, password, salt, modulus, version) == expected

# Truncation must not accidentally become a character slice or a prehash.
assert hash_password_3(hashlib.sha512, b"x" * 71, salt, modulus) != hash_password_3(
    hashlib.sha512, b"x" * 72, salt, modulus
)
