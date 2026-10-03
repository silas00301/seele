The desktop image association uses `seele-images.desktop`. One regular file
opens its containing directory in imv, selected through `-n`, so h/l can browse
neighboring pictures. Multiple selected files stay an exact selection. imv owns
ordering, image decoding, nonrecursive enumeration and selection resolution.
The standalone imv command and its portable output retain their usual behavior.

`open.sh` is only an exec adapter. It accepts local paths from desktop `%F`,
prefixes relative arguments without command substitution, and ends imv options
before the file arguments. It does not interpret URLs, scan directories itself,
copy files or persist a selection.

Run the argument-boundary fixture without graphical services:

```sh
python3 modules/features/desktop/_image-viewer/test-open.py
bash -n modules/features/desktop/_image-viewer/open.sh
```

The fixture runs Bash with the same strict flags as `writeShellApplication` and
an argv-recording fake imv. It covers shell punctuation, leading dashes,
newlines, symlinks, multiple files and empty input. It does not exercise image
decoding or the graphical viewer. On nerv, open a middle image in a directory,
confirm it appears first and h/l reach its neighbors, then open a multi-file
selection and confirm no unselected picture appears. `nix fmt` and native flake
evaluation/build still need a machine with Nix.
