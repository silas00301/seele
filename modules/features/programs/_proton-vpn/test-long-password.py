import hashlib

from proton.session.srp.util import hash_password_3


password = b"x" * 73
salt = b"0123456789"
modulus = b"modulus"

assert hash_password_3(hashlib.sha512, password, salt, modulus) == hash_password_3(
    hashlib.sha512,
    password[:72],
    salt,
    modulus,
)
