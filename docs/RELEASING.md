# Releasing

Default image: `egori4/cybercontroller-rdc-client:0.3.0`. Release images are public and `linux/amd64` only in this release. Source repositories never contain device state or credentials.

## Checks before release

Run the CI checks, review the security implications, and test the image on an authorized Linux lab host. Update `VERSION`, package metadata/lockfile, default image examples, and the changelog together. The image's bundled RDC version remains pinned at **0.2.52**. With explicit `RDC_AUTO_UPDATE=true` the restricted client independently checks npm's stable latest release **on start**, installs it as UID 10001 into the paired state volume and validates the CLI. This is not a new image release; document image and runtime versions separately. Upstream dependency changes can require a new base image.

This is the **restricted** client, not host-admin: validate the non-root/read-only Docker boundary, unit tests, upstream updater download/cache/disabled paths, and safe image migration with disposable volumes. Never use privileged host administration tests for this repo. Real account pairing and MCP authenticated connectivity are separate manual acceptance tests.

## GitHub Actions

The CI workflow runs on pushes and pull requests without publishing images. Publication is a manual workflow to avoid unintentionally overwriting release tags.

Configure:

- repository variable `DOCKERHUB_USERNAME` (or the existing secret with that name)
- repository secret `DOCKERHUB_TOKEN`, using a persistent Docker Hub personal/organization access token with appropriate push permission and expiry

A development-machine browser/device-login session is not a suitable long-lived CI credential. Never print tokens or copy Docker authentication files into a repository or image.

Create the Docker Hub repository with the intended **public** visibility before publication. Create an annotated `v<VERSION>` Git tag and push it. Dispatch Publish Docker image **at that tag** with the matching version. The workflow validates semantic version syntax, `VERSION`, and tag-to-commit agreement before accepting the publishing credentials. Workflow actions are pinned by commit, and untrusted inputs enter the shell through environment variables rather than direct code interpolation.

Images receive exact-version, minor, and `latest` tags. Use the exact tag/digest when installing. Do not overwrite an already released exact-version tag with different source.

## Maintainer first/manual publication

A maintainer already authenticated to Docker Hub can publish without storing that interactive credential in GitHub:

```bash
version=$(cat VERSION)
revision=$(git rev-parse HEAD)
docker build --build-arg VERSION="$version" --build-arg VCS_REF="$revision" \
  -t egori4/cybercontroller-rdc-client:"$version" .
docker push egori4/cybercontroller-rdc-client:"$version"
docker tag egori4/cybercontroller-rdc-client:"$version" egori4/cybercontroller-rdc-client:"${version%.*}"
docker tag egori4/cybercontroller-rdc-client:"$version" egori4/cybercontroller-rdc-client:latest
docker push egori4/cybercontroller-rdc-client:"${version%.*}"
docker push egori4/cybercontroller-rdc-client:latest
```

Record the image digest in release notes and verify an anonymous pull if the image is intended to be public. Package source/installer assets with `git archive`, not a filesystem tar that could accidentally include credentials or ignored files. Keep OS and upstream dependency updates current; a passing smoke test is not a security audit.
