In imv, `y` copies the current path and `Shift+Y` copies image contents as PNG.
The first frame is used for animations; viewer zoom and rotation do not alter
that source image. stdin passes literal filenames to ImageMagick. Conversion
completes in a private temporary directory before wl-copy acquires the clipboard,
and cleanup runs on exit. Conversion errors leave the previous clipboard alone.
The same binding and pinned tools ship in portable imv.

Run the transaction fixture with:

```sh
python3 modules/features/programs/_imv/test-copy-image.py modules/features/programs/_imv/copy-image.sh
```

The fixture stubs conversion and clipboard delivery to cover error boundaries,
permissions, cleanup, and literal filenames. Live format decoding and Wayland
paste still require a desktop test.
