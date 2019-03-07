# Example: kubernetes nginx deployment

A simple example creating kubernetes nginx deployment and associated docker
image

## Usage

### Building and applying kubernetes yaml file

```
nix-instantiate --eval --strict  --json  -A listObject | kubectl apply -f -
```

### Building and pushing docker images

```
nix run -f ./. pushDockerImages -c copy-docker-images
```
