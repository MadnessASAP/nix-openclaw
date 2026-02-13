{ bundledPluginInputs, resolvePlugin }:

{ config, lib, pkgs, ... }:
{
  imports = [
    (lib.mkRenamedOptionModule [ "programs" "openclaw" "firstParty" ] [ "programs" "openclaw" "bundledPlugins" ])
    (lib.mkRenamedOptionModule [ "programs" "openclaw" "plugins" ] [ "programs" "openclaw" "customPlugins" ])
    (import ./options.nix { inherit bundledPluginInputs; })
    (import ./config.nix { inherit bundledPluginInputs resolvePlugin; })
  ];
}
