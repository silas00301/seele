{ ... }:
let
  module = (
    { pkgs, ... }:
    {
      programs.tmux = {
        enable = true;
        keyMode = "vi";
        prefix = "C-s";
        clock24 = true;
        escapeTime = 0;
        baseIndex = 1;
        mouse = true;
        terminal = "tmux-256color";
        plugins = with pkgs; [
          tmuxPlugins.vim-tmux-navigator
        ];
        shell = "${pkgs.fish}/bin/fish";
        extraConfig = ''
          set-option -g status-position top
          set-option -g renumber-windows on
          set-option -g status-right-length 80
          set-option -g focus-events on
          set -g extended-keys on
          set -g extended-keys-format csi-u

          bind-key r source-file ~/.config/tmux/tmux.conf \; display-message "~/.config/tmux/tmux.conf reloaded"
          bind-key < split-window -h
          bind-key > split-window
          bind-key q kill-pane
          bind-key y copy-mode

          bind-key "T" display-popup -E -w 80% -h 70% -d '#{pane_current_path}' -T 'Sesh' tv sesh

          vim_pattern='(\S+/)?g?\.?(view|l?n?vim?x?|fzf)(diff)?(-wrapped)?'
          is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
              | grep -iqE '^[^TXZ ]+ +$\{vim_pattern}$'"
          bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
          bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
          bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
          bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
          tmux_version='$(tmux -V | sed -En "s/^tmux ([0-9]+(.[0-9]+)?).*/\1/p")'
          if-shell -b '[ "$(echo "$tmux_version < 3.0" | bc)" = 1 ]' \
              "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\'  'select-pane -l'"
          if-shell -b '[ "$(echo "$tmux_version >= 3.0" | bc)" = 1 ]' \
              "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\\\'  'select-pane -l'"

          bind-key -T copy-mode-vi 'C-h' select-pane -L
          bind-key -T copy-mode-vi 'C-j' select-pane -D
          bind-key -T copy-mode-vi 'C-k' select-pane -U
          bind-key -T copy-mode-vi 'C-l' select-pane -R
          bind-key -T copy-mode-vi 'C-\' select-pane -l
        '';
      };
      programs.fzf.tmux.enableShellIntegration = true;

      catppuccin.tmux.extraConfig = ''
        set -g @catppuccin_window_status_style "rounded"
        set -g @catppuccin_window_number_position "right"
        set -g @catppuccin_window_default_fill "number"
        set -g @catppuccin_window_default_text "#W"
        set -g @catppuccin_window_current_fill "number"
        set -g @catppuccin_window_current_text "#W"
        set -g @catppuccin_status_left_separator  ""
        set -g @catppuccin_status_right_separator ""
        set -g @catppuccin_status_fill "icon"
        set -g @catppuccin_status_connect_separator "yes"
        set -g @catppuccin_status_background "default"
        set -g @catppuccin_directory_text "#{pane_current_path}"
        set -g status-left ""
        set -g status-right "#{E:@catppuccin_status_date_time}"
        set -ag status-right "#{E:@catppuccin_status_session}"
      '';
    }
  );
in
{
  flake.modules.homeManager."tmux" = module;

  seele.portable.tmux = {
    # tmux launches fish, and its popup binding reaches for television and sesh,
    # so the wrapper carries them rather than borrowing whatever the foreign
    # host happens to have.
    modules = [
      "tmux"
      "fish"
      "fzf"
      "television"
      "sesh"
    ];
  };
}
