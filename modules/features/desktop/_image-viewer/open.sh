# Desktop file arguments are data, never imv options. Prefix relative paths
# without realpath/dirname command substitution, which loses trailing newlines.
paths=()
for path in "$@"; do
  if [[ -z "$path" ]]; then
    printf '%s\n' 'seele-images: empty file path' >&2
    exit 1
  fi
  case "$path" in
    /*) paths+=("$path") ;;
    *) paths+=("$PWD/$path") ;;
  esac
done

# Let imv enumerate the containing directory and resolve the starting image.
# Several explicitly selected files remain precisely that selection.
if [[ ${#paths[@]} -eq 1 && -f "${paths[0]}" ]]; then
  image="${paths[0]}"
  directory="${image%/*}"
  exec imv -n "$image" -- "${directory:-/}"
fi
exec imv -- "${paths[@]}"
