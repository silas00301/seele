# Yazi diff result handling

The packaged diff plugin copies a patch only after `diff` exits with status 1.
Status 0 reports identical inputs, while failures and terminated processes report
an error and preserve the previous clipboard. Error details are bounded to 512
characters with control characters replaced by spaces. This is a patch to the
existing nixpkgs plugin, so upstream source changes fail at patch application.

After applying `diff-status.patch` to the pinned plugin, run:

```sh
NVIM=/path/to/nvim python3 modules/features/programs/_yazi/test-diff.py /path/to/diff.yazi/main.lua
```

The fixture uses real `diff` for identical/different/unreadable inputs and a Lua
Yazi API fixture for notifications and clipboard writes. It also injects process
launch failure, partial output on error, and signal termination. Native Yazi UI
and package evaluation remain separate checks.
