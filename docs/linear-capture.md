# Captures in Linear

On nerv, `Super + Ctrl + Shift + S` captures a region or window, offers the
existing Satty annotation, saves the local screenshot, then prepares a Linear
draft. You can also run `seele-linear-capture` to choose a PNG or MP4, or pass
one explicit local path. Files are limited to 128 MiB and retained locally.

Run `seele-linear-capture connect` once to enter a personal API key in a hidden
native field. It goes into Secret Service under `application=seele-linear-capture`
and `account=linear`, never a repository file, environment variable or Nix
option. A locked or missing wallet blocks submission. `disconnect` removes
that dedicated entry. Create and manage personal API keys in Linear's Security
& access settings; use a key whose permissions cover the desired uploads and
issue/comment creation. This integration does not borrow the coding agent's
connector credentials.

The draft contains an optional existing issue identifier, title and description.
An empty identifier creates a new issue in a selected Seele project and team;
an existing identifier is looked up and must belong to Seele. Existing issues
receive a new comment without replacing their descriptions. Optional kernel
version and architecture start unchecked; no hostname, user name, machine ID,
window title, logs or environment is collected.

A final plaintext review shows the destination, draft, attachment type/size and
selected details. Only **Upload to Linear** requests a private signed upload
and then creates the issue or comment. Cancel leaves the saved capture alone.
The file's actual name is shown locally but the upload uses `capture.png` or
`recording.mp4`. The resulting Linear link is copied. No public screenshot host
is used in this workflow.

The API key authenticates only the fixed Linear GraphQL endpoint. Signed
uploads receive only Linear's upload headers and no API key; redirects are
refused. Current storage destinations are restricted to Linear's own upload
host and Google Cloud Storage, with authenticated asset links under
`uploads.linear.app`. A changed provider fails closed and needs a reviewed
code change. GraphQL errors, including partial success responses, stop the flow.

Draft content lives in memory while the helper runs. A failed or uncertain
submission is never retried automatically: check Linear before submitting
again, since a response can be lost after a successful write. An upload whose
subsequent issue/comment creation fails may remain an unattached private asset
in Linear. The local capture remains intact.

The current draft UI uses native dialogs and identifier lookup; it has no rich
Markdown editor, issue title search or durable draft history. Local fake-wallet
and loopback HTTP tests cover safety boundaries. Real wallet connection,
Linear schema/permissions, full package builds, rendering and end-to-end upload
remain live acceptance checks; this batch uploads no personal capture.

Implementation follows Linear's [API authentication](https://linear.app/developers/graphql)
and [file upload guide](https://linear.app/developers/how-to-upload-a-file-to-linear).
