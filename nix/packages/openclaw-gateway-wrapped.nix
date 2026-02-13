{ lib
, coreutils
, symlinkJoin
, writeShellScriptBin
, runCommand
, openclaw-gateway
, plugins ? []   # list of resolved plugin attrsets (output of lib.openclaw.resolvePlugin)
, skills ? []    # list of store paths to skill directories
}:

let
  pluginPackages = lib.flatten (map (p: p.packages) plugins);
  pluginSkills = lib.flatten (map (p: p.skills) plugins);
  allSkills = skills ++ pluginSkills;

  pluginEnvEntries = lib.flatten (map (p:
    let env = p.config.env or {};
    in map (k: { key = k; value = env.${k}; }) (lib.attrNames env)
  ) plugins);

  wrapper = writeShellScriptBin "openclaw" ''
    set -euo pipefail

    if [ -n "${lib.makeBinPath pluginPackages}" ]; then
      export PATH="${lib.makeBinPath pluginPackages}:$PATH"
    fi

    ${lib.concatStringsSep "\n" (map (entry:
      let
        isFile = lib.hasSuffix "_FILE" entry.key;
      in ''
      if [ -f "${entry.value}" ]; then
        if ${if isFile then "true" else "false"}; then
          export ${entry.key}="${entry.value}"
        else
          rawValue="$("${lib.getExe' coreutils "cat"}" "${entry.value}")"
          if [ "''${rawValue#${entry.key}=}" != "$rawValue" ]; then
            export ${entry.key}="''${rawValue#${entry.key}=}"
          else
            export ${entry.key}="$rawValue"
          fi
        fi
      else
        export ${entry.key}="${entry.value}"
      fi
    '') pluginEnvEntries)}

    exec "${openclaw-gateway}/bin/openclaw" "$@"
  '';

  skillsDir = lib.optionalAttrs (allSkills != []) {
    drv = runCommand "openclaw-skills" {} ''
      mkdir -p $out/share/openclaw/skills
      ${lib.concatStringsSep "\n" (map (s:
        "ln -s ${s} $out/share/openclaw/skills/${builtins.baseNameOf s}"
      ) allSkills)}
    '';
  };

in symlinkJoin {
  name = "openclaw-gateway-wrapped";
  paths = [ wrapper ] ++ lib.optional (skillsDir ? drv) skillsDir.drv;

  passthru = {
    inherit plugins skills openclaw-gateway;
    inherit pluginPackages allSkills;
  };

  meta = {
    description = "OpenClaw gateway with plugins and skills";
    mainProgram = "openclaw";
  };
}
