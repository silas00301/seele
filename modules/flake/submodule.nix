{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      updateSubmodule = pkgs.writeShellApplication {
        name = "update-submodule";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.git
          pkgs.gawk
          pkgs.jujutsu
          pkgs.nix
        ];
        text = ''
          usage() {
            printf 'usage: %s [submodule]\n' "$0" >&2
            exit 2
          }

          if [ "$#" -gt 1 ]; then
            usage
          fi

          submodule="''${1:-seele-shell}"
          root="$(git rev-parse --show-superproject-working-tree 2>/dev/null || true)"
          if [ -z "$root" ]; then
            root="$(git rev-parse --show-toplevel)"
          fi
          path="$root/$submodule"

          if ! git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            printf 'error: %s is not a Git submodule in %s\n' "$submodule" "$root" >&2
            exit 1
          fi

          if [ -n "$(git -C "$path" status --porcelain=v1)" ]; then
            printf 'error: commit the clean %s submodule before updating its parent pointer\n' "$submodule" >&2
            exit 1
          fi

          old_submodule="$(git -C "$root" ls-tree HEAD -- "$submodule" | awk '$1 == "160000" { print $3 }')"
          new_submodule="$(git -C "$path" rev-parse HEAD)"

          if [ -z "$old_submodule" ]; then
            printf 'error: %s is not tracked as a submodule in the parent\n' "$submodule" >&2
            exit 1
          fi

          if [ "$old_submodule" = "$new_submodule" ]; then
            printf '%s already points to %s\n' "$submodule" "$new_submodule"
            exit 0
          fi

          git -C "$root" add -- "$submodule"
          git -C "$root" commit --only -m "Update $submodule submodule" -- "$submodule"
          jj -R "$root" git import

          if jj -R "$root" log -r 'main' --no-graph -T 'commit_id' | grep -q .; then
            jj -R "$root" bookmark set main -r @-
            printf 'advanced bookmark main to the new parent commit\n'
          else
            printf 'no main bookmark exists; advance the active bookmark manually\n' >&2
          fi

          ${pkgs.nix}/bin/nix flake lock --update-input seele-shell
          printf '%s now points to %s\n' "$submodule" "$new_submodule"
          printf 'commit the refreshed flake.lock with jj, then push the parent with: jj git push --bookmark main\n'
        '';
      };
    in
    {
      apps.update-submodule = {
        type = "app";
        program = "${updateSubmodule}/bin/update-submodule";
        meta.description = "Update a submodule gitlink in the parent repository";
      };
    };
}
