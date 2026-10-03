if test (count $argv) -eq 0
    printf 'Usage: gitignore TEMPLATE [TEMPLATE ...]\n' >&2
    return 2
end
if contains -- "$argv[1]" --help -h
    printf 'Usage: gitignore TEMPLATE [TEMPLATE ...]\nPrint templates to stdout; accepts names separated by spaces or commas.\n'
    return 0
end
for template in $argv
    if not string match -qr '^[A-Za-z0-9+._-]+(,[A-Za-z0-9+._-]+)*$' -- "$template"; or string match -q -- '-*' "$template"
        printf 'gitignore: invalid template name: %s\n' "$template" >&2
        return 2
    end
end
set -l templates (string join , -- $argv)
@curl@ --fail --silent --show-error --location --connect-timeout 10 --max-time 30 --proto '=https' --proto-redir '=https' --url "https://www.toptal.com/developers/gitignore/api/$templates"
