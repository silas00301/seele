# Temporary file shelf

On `nerv`, `Super + Ctrl + Shift + E`, **Seele File Shelf** in Vicinae, or
`seele-shellctl shelf` opens the shelf on the focused output. In Yazi's manager
layer, `Alt + S` collects the hovered or selected files; its input layer retains
ordinary text entry. `seele-shellctl shelf <path>...` collects explicit files and
`seele-shellctl shelf --text` collects bounded stdin text. CLI text goes through a
mode-0600 same-user Unix socket, never through process arguments.

Drop local files or text into the panel, choose **Add files**, or explicitly
**Collect clipboard text**. There is no clipboard watcher. File entries are
references to originals, including saved screenshots; text snippets are private
mode-0600 runtime files. A changed or removed original is not frozen into an old
copy: the panel reports an unavailable file and excludes it from handoffs.

The shelf holds up to 64 items and 16 text snippets, each up to 64 KiB. Selection
is independent of its keyboard cursor. `j/k` or arrows move through entries,
`gg/G` or Home/End reach the ends, Ctrl+D/U move half a page, Space toggles the
entry, and Enter previews it through Quick Look. Delete or `d` removes selected
references. Tab reaches the shared buttons, whose Enter/Space activation stays
separate from list actions. Escape or `q` closes the panel and retains its items.

The separate drag handle exports selected available entries together as an
encoded `text/uri-list` with copy semantics. Collection and selection never
start a drag. **Send with Transfers** preselects the files in the existing panel;
choosing a destination remains explicit. It never sends merely by collecting.

**Capture in Notes** copies up to sixteen regular files (32 MiB each, 128 MiB
together) into the configured vault attachment directory and creates a new
ordinary Markdown capture. Images, PDFs and supported media receive Obsidian
embeds; other attachments receive wiki links. The current Notes editor and all
originals remain untouched. The new capture appears in the app's capture folder;
opening Notes does not force a switch away from an unsaved editor. A missing vault
or unavailable source keeps the shelf and reports a setup/access error. Notes
copies are durable vault data and remain independent of the shelf's lifetime.
Nothing automatically deletes a published attachment another note might use.

Clear or remove deletes only shelf-owned snippets, never original files or vault
copies. Closing the panel retains collection; shell worker exit, including a QML
reload, clears it. EOF, SIGTERM and normal error paths remove private runtime text
and the worker's own socket. A forced SIGKILL cannot run cleanup; the operating
system's private runtime directory remains the retention boundary for that case.
An owned inactive socket can be retired on restart under an exclusive process lock; active or unsafe endpoints are preserved. The empty private lock file remains in the runtime directory. The shelf writes no persistent cache or collection history.

Validation drives the production worker, CLI socket and Notes copier using only
fixture files. It covers atomic file batches, deduplication, limits, remote URI
refusal, private modes, absence of text in IPC argv, source preservation,
independent Notes copies, and EOF/idle-SIGTERM cleanup. A real offscreen Qt test
loads the production shelf panel and shared controls with process I/O stubbed,
checking keyboard selection/preview, cancellation, explicit clipboard action and
the drag MIME payload. A real Wayland external drag/drop, compositor focus,
file-dialog choice, Notes UI and Transfers destination acceptance remain live
checks; the offscreen fixture does not prove those boundaries.
