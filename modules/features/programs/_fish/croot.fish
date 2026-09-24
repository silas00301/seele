if test (count $argv) -eq 1; and contains -- "$argv[1]" -h --help
    printf 'Usage: croot\nJump to the current Jujutsu workspace root, or Git worktree root.\n'
    return 0
end
if test (count $argv) -ne 0
    printf 'Usage: croot\n' >&2
    return 2
end

# read --null retains embedded and trailing newlines in a directory name.
# Inspect the producer status, not read's status, before accepting its output.
set -l root
set -l lookup_status 1
if command --query jj
    command jj root --ignore-working-copy 2>/dev/null | read --null root
    set lookup_status $pipestatus[1]
end
if test "$lookup_status" -ne 0; and command --query git
    command git rev-parse --show-toplevel 2>/dev/null | read --null root
    set lookup_status $pipestatus[1]
end
if test "$lookup_status" -ne 0
    printf 'croot: no readable Jujutsu workspace or Git worktree here\n' >&2
    return 1
end

# Both commands terminate their path with one newline. A named capture removes
# exactly that delimiter without command substitution trimming the path itself.
if not string match --quiet --regex '(?s)\A(?<root>/.*)\n\z' -- "$root"
    printf 'croot: the repository did not return an absolute root\n' >&2
    return 1
end
builtin cd -- "$root"
