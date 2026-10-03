umask 077

if [[ -z ${imv_current_file:-} || ! -f $imv_current_file || ! -r $imv_current_file ]]; then
  printf '%s\n' 'imv: no readable image file to copy' >&2
  exit 1
fi

directory=$(mktemp -d)
trap 'rm -rf -- "$directory"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
image="$directory/image.png"

# Stdin keeps filenames literal: ImageMagick otherwise interprets brackets
# and coder prefixes in filenames. Copy the first frame of animated images.
magick '-[0]' "PNG:$image" < "$imv_current_file"
[[ -s $image ]]
wl-copy --type image/png < "$image"
