# Change IDs survive the rewrites, so no temporary bookmarks are needed.
current=$(jj log --no-graph -r @ -T change_id)
previous=$(jj log --no-graph -r @- -T change_id)
jj parallelize "$current" "$previous"
jj rebase --branch "$previous" --destination "$current"
