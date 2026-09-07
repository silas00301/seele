build=false
while [[ $# -gt 0 ]]; do
  case "$1" in
  --build) build=true ;;
  -h | --help)
    printf 'Usage: nix run .#check -- [--build]\n\n'
    printf 'Run from the Seele checkout root. Formats the whole repository, checks\n'
    printf 'flake outputs, and evaluates the native host. --build also builds it.\n'
    printf 'Keeps flake.lock unchanged and does not activate the system.\n'
    exit 0
    ;;
  *)
    printf 'Unknown argument: %s\nTry --help.\n' "$1" >&2
    exit 2
    ;;
  esac
  shift
done

if [[ ! -f flake.nix || ! -d modules/hosts ]]; then
  printf 'Run this command from the Seele checkout root.\n' >&2
  exit 2
fi
if ! command -v nix >/dev/null 2>&1; then
  printf 'Nix must be available on PATH.\n' >&2
  exit 127
fi

system=$(nix eval --impure --raw --expr builtins.currentSystem)
case "$system" in
x86_64-linux) host='.#nixosConfigurations.nerv.config.system.build.toplevel' ;;
aarch64-darwin) host='.#darwinConfigurations.asuka.system' ;;
*)
  if "$build"; then
    printf 'No native Seele host is defined for %s.\n' "$system" >&2
    exit 2
  fi
  host=''
  ;;
esac

printf 'Formatting the repository…\n'
nix fmt --no-write-lock-file
printf 'Checking flake outputs…\n'
nix flake show --no-write-lock-file
nix flake check --no-build --no-write-lock-file
if [[ -n $host ]]; then
  printf 'Evaluating the %s host…\n' "$system"
  nix eval --raw "$host.drvPath" --no-write-lock-file
  printf '\n'
else
  printf 'No native host for %s; portable outputs were checked.\n' "$system"
fi
if "$build"; then
  printf 'Building the native host…\n'
  nix build "$host" --no-link --no-write-lock-file
fi
printf 'Seele validation completed.\n'
