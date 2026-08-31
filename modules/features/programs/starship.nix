{ ... }:
let
  module = (
    { pkgs, ... }: {
      home.packages = [ pkgs.jj-starship ];

      programs.starship = {
        enable = true;
        enableFishIntegration = true;
        enableNushellIntegration = true;
        enableTransience = true;
        settings = {
          aws.symbol = "  ";
          buf.symbol = " ";
          c.symbol = " ";
          cmake.symbol = " ";
          conda.symbol = " ";
          crystal.symbol = " ";
          dart.symbol = " ";
          directory.read_only = " 󰌾";
          docker_context.symbol = " ";
          elixir.symbol = " ";
          elm.symbol = " ";
          fennel.symbol = " ";
          fossil_branch.symbol = " ";
          git_branch.symbol = " ";
          git_commit.tag_symbol = "  ";
          golang.symbol = " ";
          guix_shell.symbol = " ";
          haskell.symbol = " ";
          haxe.symbol = " ";
          hg_branch.symbol = " ";
          hostname.ssh_symbol = " ";
          java.symbol = " ";
          julia.symbol = " ";
          kotlin.symbol = " ";
          lua.symbol = " ";
          memory_usage.symbol = "󰍛 ";
          meson.symbol = "󰔷 ";
          nim.symbol = "󰆥 ";
          nix_shell.symbol = " ";
          nodejs.symbol = " ";
          ocaml.symbol = " ";
          package.symbol = "󰏗 ";
          perl.symbol = " ";
          php.symbol = " ";
          pijul_channel.symbol = " ";
          python.symbol = " ";
          rlang.symbol = "󰟔 ";
          ruby.symbol = " ";
          rust.symbol = "󱘗 ";
          scala.symbol = " ";
          swift.symbol = " ";
          zig.symbol = " ";
          gradle.symbol = " ";

          os.symbols = {
            Alpaquita = " ";
            Alpine = " ";
            AlmaLinux = " ";
            Amazon = " ";
            Android = " ";
            Arch = " ";
            Artix = " ";
            CachyOS = " ";
            CentOS = " ";
            Debian = " ";
            DragonFly = " ";
            Emscripten = " ";
            EndeavourOS = " ";
            Fedora = " ";
            FreeBSD = " ";
            Garuda = "󰛓 ";
            Gentoo = " ";
            HardenedBSD = "󰞌 ";
            Illumos = "󰈸 ";
            Kali = " ";
            Linux = " ";
            Mabox = " ";
            Macos = " ";
            Manjaro = " ";
            Mariner = " ";
            MidnightBSD = " ";
            Mint = " ";
            NetBSD = " ";
            NixOS = " ";
            Nobara = " ";
            OpenBSD = "󰈺 ";
            openSUSE = " ";
            OracleLinux = "󰌷 ";
            Pop = " ";
            Raspbian = " ";
            Redhat = " ";
            RedHatEnterprise = " ";
            RockyLinux = " ";
            Redox = "󰀘 ";
            Solus = "󰠳 ";
            SUSE = " ";
            Ubuntu = " ";
            Unknown = " ";
            Void = " ";
            Windows = "󰍲 ";
          };
          git_state.disabled = true;
          git_commit.disabled = true;
          git_metrics.disabled = true;
          git_branch.disabled = true;
          git_status.disabled = true;
          custom.jj = {
            when = "${pkgs.jj-starship}/bin/jj-starship detect";
            shell = [ "${pkgs.jj-starship}/bin/jj-starship" ];
            format = "$output ";
          };
        };
      };
    }
  );
in
{
  flake.modules.homeManager."starship" = module;

  seele.portable.starship = { };
}
