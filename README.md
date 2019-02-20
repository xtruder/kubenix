# KubeNix

> Kubernetes resource builder written in nix

## About

KubeNix is a kubernetes resource builder, that uses nix module system for
definition of kubernetes resources and nix build system for building complex
kubernetes resources very easyly.

## Development

### Building tests

```shell
nix-build release.nix -A tests.results --show-trace
```

**Building single e2e test**

```
nix-build release.nix  -A tests.tests.v1_10.testing.testsByName.<name>.script
```

**Debugging e2e test**

```
nix-build release.nix  -A tests.tests.v1_10.testing.testsByName.<name>.script.driver
resut/bin/nixos-test-driver
testScript;
```

## License

MIT © [Jaka Hudoklin](https://x-truder.net)
