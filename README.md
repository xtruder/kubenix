# KubeNix

> Kubernetes resource builder written in nix

[![Build Status](https://travis-ci.com/xtruder/kubenix.svg?branch=master)](https://travis-ci.com/xtruder/kubenix)

## About

KubeNix is a kubernetes resource builder, that uses nix module system for
definition of kubernetes resources and nix build system for building complex
kubernetes resources very easyly.

## Development

### Building tests

```shell
nix-build release.nix -A test-results --show-trace
```

**Building single e2e test**

```
nix-build release.nix -A tests.k8s-1_10.testsByName.k8s-crd.test
nix-build release.nix -A tests.k8s-1_10.testsByName.<test-name>.test
```

**Debugging e2e test**

```
nix-build release.nix -A tests.k8s-1_10.testsByName.k8s-crd.test.driver
nix-build release.nix -A tests.k8s-1_10.testsByName.<test-name>.test.driver
resut/bin/nixos-test-driver
testScript;
```

## License

MIT © [Jaka Hudoklin](https://x-truder.net)
