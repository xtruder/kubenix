{
  pkgs ? import <nixpkgs> {}
}:

with pkgs.lib;
with import ./lib.nix { inherit pkgs; inherit (pkgs) lib; };

let
  evalKubernetesModules = configuration: evalModules {
    modules = [./kubernetes.nix ./modules.nix configuration];
    args = {
      inherit pkgs;
      name = "default";
      k8s = { inherit loadJSON loadYAML toBase64; };
    };
  };

  flattenResources = resources: flatten (
    mapAttrsToList (name: resourceGroup:
      mapAttrsToList (name: resource: resource) resourceGroup
    ) resources
  );

  filterResources = resourceFilter: resources:
    mapAttrs (groupName: resources:
      (filterAttrs (name: resource:
        resourceFilter groupName name resource
      ) resources)
    ) resources;

  toKubernetesList = resources: {
    kind = "List";
    apiVersion = "v1";
    items = resources;
  };

  removeNixOptions = resources:
    map (filterAttrs (name: attr: name != "nix")) resources;

  buildResources = {
    configuration ? {},
    resourceFilter ? groupName: name: resource: true,
    withDependencies ? true
  }: let
    evaldConfiguration = evalKubernetesModules configuration;

    allResources = moduleToAttrs (
      evaldConfiguration.config.kubernetes.resources //
      evaldConfiguration.config.kubernetes.customResources
    );

    filteredResources = filterResources resourceFilter allResources;

    allDependencies = flatten (
      mapAttrsToList (groupName: resources:
        mapAttrsToList (name: resource: resource.nix.dependencies) resources
      ) filteredResources
    );

    resourceDependencies =
      filterResources (groupName: name: resource:
        elem "${groupName}/${name}" allDependencies
      ) allResources;

    finalResources =
      if withDependencies
      then recursiveUpdate resourceDependencies filteredResources
      else filteredResources;

    resources = removeNixOptions (
      # custom resource definitions have to be allways created first
      (flattenResources (filterResources (groupName: name: resource:
        groupName == "customResourceDefinitions"
      ) finalResources)) ++

      # everything but custom resource definitions
      (flattenResources (filterResources (groupName: name: resource:
        groupName != "customResourceDefinitions"
      ) finalResources))
    );

    kubernetesList = toKubernetesList resources;
  in pkgs.writeText "resources.json" (builtins.toJSON kubernetesList);

in {
  inherit buildResources;

  test = buildResources { configuration = ./test/default.nix; };
}
