{lib, pkgs}:

with lib;

let
in rec {
  mkOptionDefault = mkOverride 1001;

  mkAllDefault = value: priority:
    if isAttrs value
    then mapAttrs (n: v: mkAllDefault v priority) value

    else if isList value
    then map (v: mkAllDefault v priority) value

    else mkOverride priority value;

  loadYAML = path: importJSON (pkgs.runCommand "yaml-to-json" {
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

  importModule = {module ? null, modules ? [module], config}: let
    specialArgs = {
      kubenix = import ./. { inherit pkgs lib; };
      parentConfig = config;
    };

    isModule = hasAttr "module" config;

    moduleDefinition = (evalModules {
      inherit modules specialArgs;
      check = false;
    }).config.module.definition;
  in mkOption {
    description = "Module ${moduleDefinition.name} version ${moduleDefinition.version}";
    type = submoduleWithSpecialArgs ({name, ...}: let
      name' = if isModule then "${config.module.name}-${name}" else name;
    in {
      imports = modules;
      module.name = mkOptionDefault name';
    }) specialArgs;
    default = {};
  };
}
