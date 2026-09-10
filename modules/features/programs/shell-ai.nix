{ ... }:
let
  module =
    { lib, selfPackages, ... }:
    let
      package = selfPackages.shell-ai;
      command = "${package}/bin/seele-shell-ai";
    in
    {
      home.packages = [ package ];

      programs.fish = {
        # A normal typed function runs after Fish has accepted its command line,
        # when replacing the next prompt is unsupported. Intercept only these
        # two leading modes and otherwise hand Enter back to Fish unchanged.
        binds = {
          shell-ai-enter-default = {
            name = "\\r";
            mode = "default";
            command = "__seele_ai_accept";
          };
          shell-ai-enter-insert = {
            name = "\\r";
            mode = "insert";
            command = "__seele_ai_accept";
          };
        };

        functions = {
          __seele_ai_accept = ''
            set -l buffer (commandline | string collect)
            if string match --quiet --regex '^[[:space:]]*how([[:space:]]|$)' -- "$buffer"
              set -l request (string replace --regex '^[[:space:]]*how[[:space:]]*' "" -- "$buffer" | string collect)
              __seele_ai_insert how "$request"
              return
            end
            if string match --quiet --regex '^[[:space:]]*debug([[:space:]]|$)' -- "$buffer"
              set -l request (string replace --regex '^[[:space:]]*debug[[:space:]]*' "" -- "$buffer" | string collect)
              __seele_ai_insert debug "$request"
              return
            end
            commandline -f execute
          '';

          __seele_ai_insert = ''
            set -l mode $argv[1]
            set -l request $argv[2]
            set -l suggestion (${command} suggest --mode "$mode" -- "$request")
            set -l result $status
            if test $result -ne 0
              commandline -f repaint
              return $result
            end
            commandline --replace -- "$suggestion"
            commandline -f repaint
          '';

          # These definitions make both modes discoverable to Fish's syntax
          # highlighter. The Enter binding consumes them before execution.
          how = {
            description = "Insert an AI-generated Fish command for review";
            body = ''
              printf '%s\n' 'Type how <request> at the prompt and press Enter.' >&2
              return 2
            '';
          };
          debug = {
            description = "Insert a correction for the last failed Fish command";
            body = ''
              printf '%s\n' 'Type debug at the prompt and press Enter.' >&2
              return 2
            '';
          };

          __seele_ai_preexec = {
            onEvent = "fish_preexec";
            body = ''
              ${command} begin
            '';
          };

          __seele_ai_finish = ''
            ${command} finish --status "$argv[1]" --command "$argv[2]"
          '';

          __seele_ai_postexec = {
            onEvent = "fish_postexec";
            body = ''
              set -l command_status $status
              __seele_ai_finish "$command_status" "$argv[1]"
              return "$command_status"
            '';
          };

          __seele_ai_posterror = {
            onEvent = "fish_posterror";
            body = ''
              set -l command_status $status
              __seele_ai_finish "$command_status" "$argv[1]"
              return "$command_status"
            '';
          };
        };

        # Wrap only ordinary terminal sessions. The child sees the private
        # session variable and does not recurse; `-ic` and script invocations
        # are rejected by `should-capture` and keep their original semantics.
        interactiveShellInit = lib.mkBefore ''
          if not set -q SEELE_SHELL_AI_SESSION
            if ${command} should-capture --pid $fish_pid
              set -lx SEELE_SHELL_AI_LOGIN 0
              if status is-login
                set SEELE_SHELL_AI_LOGIN 1
              end
              exec ${command} capture --fish (status fish-path)
            end
          end
        '';
      };
    };
in
{
  flake.modules.homeManager.shell-ai = module;
}
