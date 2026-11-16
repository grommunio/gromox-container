# Container registry: container.grommunio.com

grommunio publishes the images and the Helm chart on
`https://container.grommunio.com`.

| Path | Access | Content |
|---|---|---|
| `community/gromox-{core,archive,office}` | public, no login | built from the grommunio community packages |
| `community/mariadb` | public | mirror of `docker.io/library/mariadb:11.8` used by the Helm chart |
| `community/charts/grommunio` | public | Helm chart (OCI) |
| `supported/gromox-{core,archive,office}` | grommunio subscription customers | built from the grommunio supported packages |

## Tags

* `<version>` (for example `2026.11`): newest build of that release; moves
  when the image is rebuilt (base OS updates, package fixes).
* `<version>-<YYYYMMDDhhmm>`: one specific build. Images are rebuilt daily;
  the last 14 builds of each image are kept.
* `latest`: newest build of the newest release.

Images are scanned for known vulnerabilities after upload. Pin a digest for
reproducible deployments.

## Signatures

All images, the MariaDB mirror and the Helm chart are signed with
[cosign](https://docs.sigstore.dev/cosign/). The registry refuses to serve
unsigned images. The public key is [`cosign.pub`](../cosign.pub) in this
repository:

```
ECDSA P-256, SHA-256 fingerprint (DER):
fbc44512234982ede455c69a7386db363bde9c73975016bbbc0794a3515c590f
```

Verify before use (cosign 2.x or 3.x):

```bash
cosign verify --key cosign.pub container.grommunio.com/community/gromox-core:2026.11
cosign verify --key cosign.pub container.grommunio.com/community/charts/grommunio:0.2.0
```

Signatures are also recorded in the public Sigstore transparency log
(Rekor). In Kubernetes, admission controllers such as Kyverno
(`verifyImages`) or the Sigstore policy-controller can enforce the
signature with the same key.

## Pulling

```bash
# community: no login
docker pull container.grommunio.com/community/gromox-core:2026.11
helm install grommunio oci://container.grommunio.com/community/charts/grommunio -f values.yaml

# supported: credentials (robot account) are provided with the subscription
docker login container.grommunio.com -u 'robot$supported+<customer>'
docker pull container.grommunio.com/supported/gromox-core:2026.11
```

In the Helm chart select the channel with `global.edition` and pass the
credentials with `global.imageCredentials` or `global.imagePullSecrets`
(see `charts/grommunio/README.md`). For docker-compose replace the image
names in `docker-compose.yml`.

For air-gapped environments copy the images into your own registry
(`skopeo copy --all docker://container.grommunio.com/... docker://registry.example.com/...`)
and set `global.imageRegistry`.

## Building the images yourself

`tools/publish-images.sh` builds the three images for one channel and
pushes them to a registry of your choice:

```bash
COSIGN_KEY=my-cosign.key COSIGN_PASSWORD=... \
  tools/publish-images.sh -r registry.example.com -c community core archive office
tools/publish-images.sh -r registry.example.com --no-sign   # push without signing
tools/publish-images.sh -n -c community                     # build only, no push
```

Pushed images are signed with your own cosign key (`cosign generate-key-pair`);
grommunio's signing key is not part of this repository. Each image is pushed
under its unique build tag, signed by digest, and only then tagged
`<version>`/`latest`, so the moving tags never point at an unsigned image.

Registries that refuse unsigned images (Harbor with cosign enforcement) need
a staging project without enforcement: `-s staging` pushes and signs there,
then Harbor copies image, signature and tags into the channel project
(`HARBOR_USER`/`HARBOR_PASSWORD` for the API). `tools/publish-chart.sh` does
the same for the Helm chart.

Supported builds need grommunio subscription credentials in zypper
credentials format, passed as a BuildKit secret (never stored in an image):

```bash
printf 'username=%s\npassword=%s\n' "$USER" "$PASS" > supported.credentials
SUPPORTED_CREDENTIALS=$PWD/supported.credentials tools/publish-images.sh -r registry.example.com -c supported
```
