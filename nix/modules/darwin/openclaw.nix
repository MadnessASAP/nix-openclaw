{ hmModule }:

{ config, lib, ... }:

{
  config = lib.mkIf (config ? home-manager) {
    home-manager.sharedModules = [ hmModule ];
  };
}
