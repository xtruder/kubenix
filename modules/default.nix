{
  k8s = ./k8s.nix;
  istio = ./istio.nix;
  submodules = ./submodules.nix;
  submodule = ./submodule.nix;
  helm = ./helm.nix;
  docker = ./docker.nix;
  testing = ./testing.nix;
  test = ./test.nix;
  module = ./module.nix;
  v1 = {
    modules = ./v1/modules.nix;
  };
}
