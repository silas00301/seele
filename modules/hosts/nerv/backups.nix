{ config, ... }:
{
  flake.modules.nixos.nerv =
    { username, ... }:
    {
      imports = [ config.flake.modules.nixos.backups ];
      seele.backup = {
        # Whole home includes wallet, app state and development data. Explicit
        # disposable exclusions do not decide the later root persistence list.
        paths = [ "/home/${username}" "/etc/machine-id" ];
        exclude = [
          "/home/${username}/.cache"
          "/home/${username}/.local/share/Trash"
          "/home/${username}/Developer/**/node_modules"
          "/home/${username}/Developer/**/target"
          "/home/${username}/Developer/**/.direnv"
        ];
        restoreSamples = [ "/etc/machine-id" ];
        # No repository has been supplied. Provision runtime references and
        # deliberately enable only after reviewing this path list.
      };
    };
}
