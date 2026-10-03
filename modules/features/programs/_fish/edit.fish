# EDITOR is a command plus optional arguments, not a shell script. Fish's
# tokenizer removes quotes/escapes without evaluating substitutions or globs.
if not set -q EDITOR[1]; or test (count $EDITOR) -ne 1; or test -z "$EDITOR"
    printf 'edit: set EDITOR to an editor command first\n' >&2
    return 2
end

set -l editor_command
# Preserve an executable pathname containing spaces, which the old function
# already accepted without quotes inside EDITOR.
if test -f "$EDITOR"; and test -x "$EDITOR"
    set editor_command "$EDITOR"
else
    printf '%s\0' "$EDITOR" | read --null --tokenize --array editor_command
end
if not set -q editor_command[1]; or test -z "$editor_command[1]"
    printf 'edit: EDITOR must name an editor command\n' >&2
    return 2
end

# Neither editor words nor filenames are evaluated as Fish source. Keep the
# editor's exit status and allow ordinary no-file editor invocations.
$editor_command $argv
