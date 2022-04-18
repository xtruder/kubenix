{ lib, pkgs }:

with lib;

rec {
  moduleToAttrs = value:
    if isAttrs value
    then mapAttrs (n: v: moduleToAttrs v) (filterAttrs (n: v: !(hasPrefix "_" n) && v != null) value)

    else if isList value
    then map (v: moduleToAttrs v) value

    else value;

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

  octalToDecimal = value: (foldr (char: acc: {
    i = acc.i + 1;
    value = acc.value + (toInt char) * (exp 8 acc.i);
  }) {i = 0; value = 0;} (stringToCharacters value)).value;

  submoduleWithSpecialArgs = opts: specialArgs:
    let
      opts' = toList opts;
      inherit (lib.modules) evalModules;
    in
    mkOptionType rec {
      name = "submodule";
      check = x: isAttrs x || isFunction x;
      merge = loc: defs:
        let
          coerce = def: if isFunction def then def else { config = def; };
          modules = opts' ++ map (def: { _file = def.file; imports = [(coerce def.value)]; }) defs;
        in (evalModules {
          inherit modules specialArgs;
          prefix = loc;
        }).config;
      getSubOptions = prefix: (evalModules
        { modules = opts'; inherit prefix specialArgs; }).options;
      getSubModules = opts';
      substSubModules = m: submoduleWithSpecialArgs m specialArgs;
      functor = (defaultFunctor name) // {
        # Merging of submodules is done as part of mergeOptionDecls, as we have to annotate
        # each submodule with its location.
        payload = [];
        binOp = lhs: rhs: [];
      };
    };

    coerceListOfSubmodulesToAttrs = submodule: keyFn: let
      mergeValuesByFn = keyFn: values:
        listToAttrs (map (value:
          nameValuePair (toString (keyFn value)) value
        ) values);

      # Either value of type `finalType` or `coercedType`, the latter is
      # converted to `finalType` using `coerceFunc`.
      coercedTo = coercedType: coerceFunc: finalType:
        mkOptionType rec {
          name = "coercedTo";
          description = "${finalType.description} or ${coercedType.description}";
          check = x: finalType.check x || coercedType.check x;
          merge = loc: defs:
            let
              coerceVal = val:
                if finalType.check val then
                  val
                else
                  let coerced = coerceFunc val; in assert finalType.check coerced; coerced;

            in finalType.merge loc (map (def: def // { value = coerceVal def.value; }) defs);
          getSubOptions = finalType.getSubOptions;
          getSubModules = finalType.getSubModules;
          substSubModules = m: coercedTo coercedType coerceFunc (finalType.substSubModules m);
          typeMerge = t1: t2: null;
          functor = (defaultFunctor name) // { wrapped = finalType; };
        };
    in coercedTo
      (types.listOf (types.submodule submodule))
      (mergeValuesByFn keyFn)
      (types.attrsOf (types.submodule submodule));
}
