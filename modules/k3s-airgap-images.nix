{ stdenv, fetchurl, k3s }:

stdenv.mkDerivation rec {
  pname = "k3s-airgap-images";
  version = k3s.version;

  src =
    let
      throwError = throw "Unsupported system ${stdenv.hostPlatform.system}";
    in
      {
        x86_64-linux = fetchurl {
          url = "https://github.com/rancher/k3s/releases/download/v${version}/k3s-airgap-images-amd64.tar";
          sha256 = "sha256-6kQmlpNV+4cU1Kn5lyZhutXYK5qYdey0jubzYRRF3vA=";
        };
        aarch64-linux = fetchurl {
          url = "https://github.com/rancher/k3s/releases/download/v${version}/k3s-airgap-images-arm64.tar";
          sha256 = "sha256-OlqqdAmBN+azT0kfjZ/Bd0CFbbW5hTg9/8T9U05N0zE=";
        };
        armv7l-linux = fetchurl {
          url = "https://github.com/rancher/k3s/releases/download/v${version}/k3s-airgap-images-arm.tar";
          sha256 = "sha256-j/ARBtHDnfRk/7BpOvavoHe7L5dmsCZe5+wuZ5t4V/k=";
        };
      }.${stdenv.hostPlatform.system} or throwError;

  preferLocalBuild = true;
  dontUnpack = true;
  installPhase = "cp $src $out";

  meta = with stdenv.lib; {
    description = "Lightweight Kubernetes. 5 less than k8s. Airgap images.";
    homepage = https://k3s.io/;
    license = licenses.asl20;
    maintainers = [ maintainers.offline ];
    platforms = [ "x86_64-linux" "aarch64-linux" "armv7l-linux" ];
  };
}
