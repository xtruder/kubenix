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

  toYAML = config: builtins.readFile (pkgs.runCommand "to-yaml" {
    buildInputs = [pkgs.remarshal];
  } ''
    remarshal -i ${pkgs.writeText "to-json" (builtins.toJSON config)} -if json -of yaml > $out
  '');

  toBase64 = value:
    builtins.readFile
      (pkgs.runCommand "value-to-b64" {} "echo -n '${value}' | ${pkgs.coreutils}/bin/base64 -w0 > $out");

  exp = base: exp: foldr (value: acc: acc * base) 1 (range 1 exp);

  octalToDecimal = value:
    (foldr (char: acc: {
      i = acc.i + 1;
      value = acc.value + (toInt char) * (exp 8 acc.i);
    }) {i = 0; value = 0;} (stringToCharacters value)).value;

  mkSecretOption = {...}@options: mkOption (options // {
    type = types.nullOr (types.submodule {
      options = {
        name = mkOption {
          description = "Name of the secret where secret is stored";
          type = types.str;
        } // optionalAttrs (hasAttr "default" options && options.default != null && hasAttr "name" options.default) {
          default = options.default.name;
        };

        key = mkOption {
          description = "Name of the key where secret is stored";
          type = types.str;
        } // optionalAttrs (hasAttr "default" options && options.default != null && hasAttr "key" options.default) {
          default = options.default.key;
        };
      };
    });

    apply = value: if value == null then null else {
      valueFrom.secretKeyRef = {
        inherit (value) name key;
      };
    };

    default = null;
  });
}
