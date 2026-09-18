{ ... }:
let
  module = {
    # Without this leaf nerv resolves through whatever the router's DHCP lease
    # names, in plaintext, with no cache: the ISP sees every name this machine
    # looks up, and so does anything else on the LAN. Resolve through the local
    # caching stub instead and send the queries themselves to Quad9 over
    # authenticated TLS.
    #
    # Quad9 rather than Cloudflare: a Swiss non-profit foundation operating
    # under GDPR, which neither sells nor monetizes query data and retains no
    # client IP addresses, validates DNSSEC itself, and refuses known-malicious
    # domains. That last part is the same defense-in-depth the browser's content
    # blocking already provides, and unlike a CDN's resolver its business is not
    # adjacent to serving the sites being resolved.
    services.resolved = {
      enable = true;

      settings.Resolve = {
        # The `#name` suffix is what turns encryption into authentication:
        # resolved validates the server certificate against that name and sends
        # it as SNI. Without it, even strict DNS-over-TLS only checks the
        # certificate against the bare address.
        DNS = [
          "9.9.9.9#dns.quad9.net"
          "149.112.112.112#dns.quad9.net"
          "2620:fe::fe#dns.quad9.net"
          "2620:fe::9#dns.quad9.net"
        ];

        # Only consulted when no other server is known at all, which is exactly
        # the moment worth pinning: left unset, the fallback is systemd's
        # compiled-in list of Cloudflare and Google.
        FallbackDNS = [
          "9.9.9.9#dns.quad9.net"
          "2620:fe::fe#dns.quad9.net"
        ];

        # Claiming the DNS root as a routing domain for these servers is what
        # actually keeps the lease's resolver out of the path. resolved sends a
        # name to the servers behind the longest matching routing domain, and
        # only falls back to "every link marked as a default route" when nothing
        # matched. Without `~.`, ordinary names land in that fallback and go to
        # the router and to Quad9 in parallel, so the LAN still learns
        # everything and usually answers first. With it, the encrypted servers
        # hold the root while longer domains still win for their own names:
        # tailscaled's `~ts.net` for MagicDNS, and the lease's own search and
        # reverse zones for LAN hosts.
        Domains = [ "~." ];

        # Strict rather than `opportunistic`. Opportunistic cannot authenticate
        # the server at all and downgrades to plaintext on a synthesized
        # failure, which leaves the decision with the network this is meant to
        # be private from. Strict is safe for the tailnet because resolved
        # applies this global mode to the system servers only: tailscaled sets
        # DNSOverTLS=no on tailscale0 itself, and the NetworkManager default
        # below does the same for the LAN link, so neither is asked to speak TLS
        # on port 853 to a resolver that does not.
        DNSOverTLS = "true";

        # Validation stays at Quad9 instead of being repeated here. The link to
        # it is already authenticated by the certificate name above, so local
        # validation would mostly add a second and far more brittle validator:
        # a revoked built-in trust anchor takes every lookup down until an
        # update lands, and `allow-downgrade` is by construction forgeable by
        # the network. Keeping it off also means the tailnet survives tailscaled
        # failing to apply its own per-link DNSSEC=no, which it only logs.
        DNSSEC = "false";

        # LLMNR asks and answers for single-label names on the LAN and is the
        # protocol credential-relay tooling lives on. Nothing here needs it.
        LLMNR = "false";

        # Resolve `.local` names, register nothing: nerv can find peers that
        # advertise themselves without announcing itself to every device on the
        # network. It has nothing to advertise anyway -- printing is off on this
        # host and KDE Connect discovers over its own broadcast.
        MulticastDNS = "resolve";
      };
    };

    networking.networkmanager = {
      # resolved's own module already asks NetworkManager for this; stating it
      # where the DNS decision is made keeps the hand-off visible. It then
      # hands each link's leased servers and search domains to resolved
      # rather than writing /etc/resolv.conf, which is what keeps LAN-local
      # names and the tailnet's split DNS working alongside the root above.
      dns = "systemd-resolved";

      # Defaults for every managed profile. NetworkManager.conf(5) takes only
      # the numeric enum values here, never their names.
      connectionConfig = {
        # 0 = no. The router's resolver does not speak DNS-over-TLS, and with
        # this unset NetworkManager tells resolved to fall back to the global
        # mode on that link too -- so the names the lease is actually
        # authoritative for would be attempted over port 853 and fail. Public
        # names never come down this path; the root routing domain above keeps
        # them on Quad9.
        "connection.dns-over-tls" = 0;

        # 0 = no. Under resolved NetworkManager otherwise pushes LLMNR=yes onto
        # every link, which would quietly reinstate it per link.
        "connection.llmnr" = 0;

        # 1 = resolve, matching the global setting: listen, never register.
        "connection.mdns" = 1;
      };
    };

    # Accepted cost: a captive portal now breaks resolution instead of
    # redirecting it, because interception lives on plaintext port 53 while
    # every ordinary name leaves over 853. That is the right trade for a desktop
    # that sits on one LAN. If this machine ever meets a hotel network,
    # `resolvectl dnsovertls <link> no` and `resolvectl domain <link> '~.'` put
    # the portal's resolver back in the path for the session, and
    # `resolvectl revert <link>` undoes both.
  };
in
{
  flake.modules.nixos.nerv-dns = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
