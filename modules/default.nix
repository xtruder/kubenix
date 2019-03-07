{
  k8s = ./k8s.nix;
  istio = ./istio.nix;
  submodules = ./submodules.nix;
  helm = ./helm.nix;
  docker = ./docker.nix;
  testing = ./testing.nix;
  test = ./test.nix;
  module = ./module.nix;
}
