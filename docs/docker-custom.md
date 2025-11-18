# Custom Docker Image for LinkStack

This repository now ships with a production Dockerfile so you can keep the same
`docker-compose.yml` (Traefik, volumes, env vars, etc.) that you were already
using with the upstream `linkstackorg/linkstack` image.

## Build the image

```bash
docker build \
  --build-arg BASE_IMAGE=linkstackorg/linkstack:latest \
  -t linkstackorg/linkstack:custom .
```

Notes:

- Set `BASE_IMAGE` to the upstream tag you want to inherit from (e.g.
  `linkstackorg/linkstack:3.3.0`) so you stay aligned with their runtime stack.
- The build installs Composer deps and compiles the frontend assets, so your
  image already contains everything required at runtime.

## Push (optional)

```bash
docker tag linkstackorg/linkstack:custom registry.example.com/linkstack:custom
docker push registry.example.com/linkstack:custom
```

## Update `docker-compose.yml`

Change **only** the `image` line for the `linkstack` service so it keeps the same
ports, labels, Traefik configuration, volume mount (`linkstack_data:/htdocs`),
and healthcheck:

```yaml
  linkstack:
    image: linkstackorg/linkstack:custom
    # ... everything else stays untouched ...
```

or, if you prefer to build locally as part of `docker compose up`, swap the
`image` key for a build section:

```yaml
  linkstack:
    build:
      context: .
      dockerfile: Dockerfile
```

## Deploy

```
docker compose pull            # if you pushed to a registry
docker compose up -d linkstack
```

Because the runtime image still uses `/htdocs` as its persistent root, the named
volume continues to hold uploads, avatars, `.env`, and database files exactly as
before. Recreating the container is enough to roll out code changes, while the
volume keeps your data intact.

## CI/CD hint

Add a pipeline step that runs `docker build` + `docker push` whenever the repo
changes. Your servers can stay on the exact same compose file; they just need to
`docker compose pull && docker compose up -d` to receive updates.

