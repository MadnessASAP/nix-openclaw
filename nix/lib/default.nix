{ lib }:

{
  openclaw = {
    # Resolve an OpenClaw plugin flake into a normalised attribute set.
    #
    # Usage:
    #   resolvePlugin { system = "x86_64-linux"; } { flake = inputs.my-plugin; config.env.API_KEY = "..."; }
    #
    # `flake` must be an already-evaluated flake (i.e. a flake input, NOT a URI
    # string).  The flake is expected to expose an `openclawPlugin` output that
    # is either an attrset or a function `system -> attrset`.
    #
    # Returns:
    #   { name, skills, packages, needs.{ stateDirs, requiredEnv }, config }
    resolvePlugin = { system }: { flake, config ? {} }:
      let
        openclawPluginRaw =
          if flake ? openclawPlugin then flake.openclawPlugin
          else throw "openclawPlugin attribute missing from plugin flake";
        openclawPlugin =
          if builtins.isFunction openclawPluginRaw
          then openclawPluginRaw system
          else openclawPluginRaw;
        resolvedPlugin =
          if openclawPlugin == null
          then throw "openclawPlugin is null for ${system}"
          else openclawPlugin;
        needs = resolvedPlugin.needs or {};
      in {
        name = resolvedPlugin.name or (throw "openclawPlugin.name missing from plugin flake");
        skills = resolvedPlugin.skills or [];
        packages = resolvedPlugin.packages or [];
        needs = {
          stateDirs = needs.stateDirs or [];
          requiredEnv = needs.requiredEnv or [];
        };
        config = config;
      };
  };
}
