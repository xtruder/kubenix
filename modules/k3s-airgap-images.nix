{ stdenv, fetchurl, k3s }:

stdenv.mkDerivation rec {
  pname = "k3s-airgap-images";
  version = k3s.version;

  src = let
    throwError = throw "Unsupported system ${stdenv.hostPlatform.system}";
  in {
    x86_64-linux = fetchurl {
      url = "https://github.com/rancher/k3s/releases/download/v${version}/k3s-airgap-images-amd64.tar";
      sha256 = "1fiq211vvsnxdzfx9ybb28yyyif08zls7bx3kl8xmv4hrf8xza4i";
    };
    aarch64-linux = fetchurl {
      url = "https://github.com/rancher/k3s/releases/download/v${version}/k3s-airgap-images-arm64.tar";
      sha256 = "1xaggiw5h0zndgvdikg7babwd9903n9vabp1dkh53g8al812sfnd";
    };
    armv7l-linux = fetchurl {
      url = "https://github.com/rancher/k3s/releases/download/v${version}/k3s-airgap-images-arm.tar";
      sha256 = "1v90wyvj47hz4nphdq7isfbl758yrzg4bx7c73ghmlgvr6p9cdzb";
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
