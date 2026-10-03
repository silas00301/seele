{
  lib,
  configHome,
  configDirectory,
}:
value:
let
  text = toString value;
  prefix = "${configHome}/";
in
if text == configHome then
  configDirectory
else if lib.hasPrefix prefix text then
  "${configDirectory}/${lib.removePrefix prefix text}"
else
  text
