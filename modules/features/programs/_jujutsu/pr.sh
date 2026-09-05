case "${1:-}" in
submit)
  rev=${2:-@}
  bookmarks=$(jj log --revisions "$rev" --no-graph --no-pager --template 'self.local_bookmarks().map(|b| b.name()).join("\n")')
  if [[ -z $bookmarks || $bookmarks == *$'\n'* ]]; then
    printf 'Choose a revision with exactly one local bookmark.\n' >&2
    exit 1
  fi
  gh pr create --head "$bookmarks"
  ;;
checkout | co)
  if [[ $# -lt 2 ]]; then
    prs=$(gh pr list --json number,title)
    if [[ $(jq 'length' <<<"$prs") == 0 ]]; then
      printf 'No PRs found\n'
      exit 0
    fi
    selection=$(jq -r '.[] | "#\(.number) | \(.title)"' <<<"$prs" | gum choose --header 'Pick a PR:') || exit 0
    [[ -n $selection ]] || exit 0
    pr_id=${selection%% *}
    pr_id=${pr_id#\#}
  else
    pr_id=$2
  fi
  details=$(gh pr view "$pr_id" --json headRefName,headRepository,headRepositoryOwner)
  branch=$(jq -er '.headRefName' <<<"$details")
  owner=$(jq -er '.headRepositoryOwner.login' <<<"$details")
  repository=$(jq -er '.headRepository.name' <<<"$details")
  # A temporary remote also handles forks and cannot collide with the user's
  # existing bookmarks/remotes. jj new retains the fetched commit after cleanup.
  temporary=$(mktemp -d)
  remote="seele-pr-${temporary##*/}"
  cleanup() {
    jj git remote remove "$remote" >/dev/null 2>&1 || true
    rmdir "$temporary"
  }
  trap cleanup EXIT
  jj git remote add "$remote" "https://github.com/$owner/$repository.git"
  jj git fetch --remote "$remote" --branch "$branch"
  jj new "$branch@$remote"
  ;;
*)
  printf 'Usage: jj pr submit [revision] | checkout [number-or-url]\n' >&2
  exit 2
  ;;
esac
