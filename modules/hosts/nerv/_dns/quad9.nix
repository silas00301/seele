# The Quad9 resolvers nerv sends ordinary names to. dns.nix installs them into
# systemd-resolved, and drift.nix publishes the same list for the Control
# Center's dry-run, so the check cannot grow a second copy of the addresses.
{
  dns = [
    "9.9.9.9#dns.quad9.net"
    "149.112.112.112#dns.quad9.net"
    "2620:fe::fe#dns.quad9.net"
    "2620:fe::9#dns.quad9.net"
  ];
  fallback = [
    "9.9.9.9#dns.quad9.net"
    "2620:fe::fe#dns.quad9.net"
  ];
  domains = [ "~." ];
}
