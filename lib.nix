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
}
