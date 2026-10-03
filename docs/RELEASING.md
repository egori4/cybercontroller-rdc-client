# Releasing

Runtime images are published to Docker Hub:

```text
egori4/rdc-client
```

The target server should pull a prebuilt release and should not build the image locally.

## GitHub Actions requirements

Configure these repository Actions secrets:

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
```

`DOCKERHUB_TOKEN` should be a Docker Hub access token with only the permissions required to publish this repository.

## Release build behavior

For each release, CI:

1. checks out the exact Git commit;
2. resolves the current `@wonderwhy-er/desktop-commander@latest` version once;
3. builds the image using that exact resolved version;
4. records it as an OCI image label;
5. publishes version, minor and `latest` tags.

Example release:

```text
0.1.0
0.1
latest
```

Production deployments should use the exact version or digest rather than `latest`.

## Manual first publication

A maintainer who is already authenticated to Docker Hub can perform an initial/manual publication:

```bash
docker build --pull -t egori4/rdc-client:0.1.0 .
docker tag egori4/rdc-client:0.1.0 egori4/rdc-client:0.1
docker tag egori4/rdc-client:0.1.0 egori4/rdc-client:latest
docker push egori4/rdc-client:0.1.0
docker push egori4/rdc-client:0.1
docker push egori4/rdc-client:latest
```

Do not publish images containing credentials or device-state volumes.
