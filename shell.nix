{
  system ? builtins.currentSystem,
  pkgs,
}:
let
  devshellGitRev = "709fe4d04a9101c9d224ad83f73416dce71baf21";

  devshellSrc = fetchTarball {
    url = "https://github.com/numtide/devshell/archive/${devshellGitRev}.tar.gz";
    sha256 = "1px9cqfshfqs1b7ypyxch3s3ymr4xgycy1krrcg7b97rmmszvsqr";
  };

  devshell = import devshellSrc { inherit system pkgs; };

in
devshell.fromTOML ./devshell.toml

