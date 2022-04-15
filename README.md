**Kubenix 2.0 is in still work in progress, expect breaking changes**

# KubeNix

> Kubernetes resource builder written in nix

[![Build Status](https://travis-ci.com/xtruder/kubenix.svg?branch=master)](https://travis-ci.com/xtruder/kubenix)

## About

KubeNix is a kubernetes resource builder, that uses nix module system for
definition of kubernetes resources and nix build system for building complex
kubernetes resources very easily.

## Development

### Adding support for new version of Kubernetes

Edit release.nix, and add a new block for the new version of Kubernetes in `generate.k8s`. For example:

```nix
{
  name = "v1.23.nix";
  path = generateK8S "v1.23" (builtins.fetchurl {
    url = "https://github.com/kubernetes/kubernetes/raw/v1.23.0/api/openapi-spec/swagger.json";
    sha256 = "0jivg8nlxka1y7gzqpcxkmbvhcbxynyrxmjn0blky30q5064wx2a";
  });
}
```

Run the following command to build the specs:

```bash
nix-build release.nix -A generate.k8s
```

Finally, copy all specs from the output of the previous command to `modules/generated/`.

Putting all this together in one command:

```bash
cp $(nix-build --no-out-link release.nix -A generate.k8s)/* modules/generated
```

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

[MIT](LICENSE) © [Jaka Hudoklin](https://x-truder.net)
