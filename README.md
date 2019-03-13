**Kubenix 2.0 is in development, with much more features, better tests and better docs.
It will be merged into master in following weeks. For progress and features take a look here: https://github.com/xtruder/kubenix/issues/9**

# KubeNix

> Kubernetes resource builder written in nix

## About

KubeNix is a kubernetes resource builder, that uses nix module system for
definition of kubernetes resources and nix build system for building complex
kubernetes resources very easily.

### Features

- Loading and override of kubernetes json and yaml files
- Support for complex merging of kubernetes resource definitions
- No more helm stupid yaml templating, nix is a way better templating language
- Support for all kubernetes versions

## License

MIT © [Jaka Hudoklin](https://x-truder.net)
