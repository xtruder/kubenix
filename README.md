# KubeNix

> Kubernetes resource builder written in nix

## About

KubeNix is a kubernetes resource builder, that uses nix module system for
definition of kubernetes resources and nix build system for building complex
kubernetes resources very easyly.

## Development

### Building tests

```shell
nix-build release.nix -A test --show-trace
```

## License

MIT © [Jaka Hudoklin](https://x-truder.net)
