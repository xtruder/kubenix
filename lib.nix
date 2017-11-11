{lib, pkgs}:

with lib;

rec {
  mkAllDefault = value: priority:
    if isAttrs value
    then mapAttrs (n: v: mkAllDefault v priority) value

    else if isList value
    then map (v: mkAllDefault v priority) value

    else mkOverride priority value;

  moduleToAttrs = value:
    if isAttrs value
    then mapAttrs (n: v: moduleToAttrs v) (filterAttrs (n: v: !(hasPrefix "_" n) && v != null) value)

    else if isList value
    then map (v: moduleToAttrs v) value

    else value;

  loadJSON = path: mkAllDefault (builtins.fromJSON (builtins.readFile path)) 1000;

  loadYAML = path: loadJSON (pkgs.runCommand "yaml-to-json" {
  } "${pkgs.remarshal}/bin/remarshal -i ${path} -if yaml -of json > $out");

  toBase64 = value:
    builtins.readFile
      (pkgs.runCommand "value-to-b64" {} "echo '${value}' | ${pkgs.coreutils}/bin/base64 -w0 > $out");
}
