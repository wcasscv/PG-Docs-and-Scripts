# Docker: “I Know This Stuff, But in the Interview I Freeze” Kit

## Strong intro

You can use Docker every week and still freeze in an interview.

That freeze usually does not mean you lack Docker experience. It means your knowledge is stored as real work: checking container logs, rebuilding images, debugging `Dockerfile` layers, fixing port mappings, tracing networking, cleaning volumes, handling registry auth, and figuring out why something works on your laptop but fails in CI or production.

In production, Docker is not just “run this image.” It is packaging, isolation, networking, storage, security, supply chain, runtime behavior, and operational discipline. A good Docker answer shows that you understand both the developer workflow and the runtime consequences.

This kit is built for that interview moment when you know the answer but need clean language.

It covers 30 common Docker issues interviewers ask about, with symptoms, causes, diagnostic steps, resolutions, and examples. It is written for DevOps, platform, SRE, CI/CD, and backend engineers who want practical interview-ready answers under pressure.

When you freeze, start with this sentence:

> “I would first identify whether the Docker issue is image build, container runtime, entrypoint, environment, networking, ports, volumes, permissions, registry access, resource limits, or host daemon health. Then I would inspect the Dockerfile, image metadata, container logs, exit code, runtime config, network settings, and host resources before changing anything.”

That answer sounds like someone who has debugged real systems.

---

## How to use this kit

For every Docker issue, use this structure:

```text
Symptom → Scope → Evidence → Cause → Fix → Verify → Prevent
```

A strong Docker interview answer usually includes:

1. What failed.
2. Whether the issue is image, container, host, network, storage, registry, or application related.
3. What command you run first.
4. What evidence proves the cause.
5. What safe fix you apply.
6. How you verify the fix.
7. How you prevent repeat issues.

Example:

> “If a container exits immediately, I would check `docker ps -a`, inspect the exit code, read logs, verify the entrypoint and command, check required environment variables, and test the image interactively if needed.”

That is better than saying:

> “I would rebuild the container.”

Rebuilding is an action. Diagnosis is engineering.

---

# Top 30 Docker issues and resolutions

---

## 1. Container exits immediately

### Interview freeze point

The interviewer asks:

> “A Docker container starts and then exits. What do you do?”

A weak answer is “check logs.” A strong answer includes exit codes, command, entrypoint, environment, and foreground process behavior.

### Strong interview answer

> “I would check the container exit code, logs, entrypoint, command, required environment variables, and whether the main process is staying in the foreground. Containers exit when PID 1 exits.”

### Symptoms

- Container starts then stops.
- `docker ps` does not show it.
- `docker ps -a` shows `Exited`.
- Restart policy keeps restarting it.
- No exposed app is reachable.

### Diagnostic commands

```bash
docker ps -a
docker logs <container>
docker inspect <container> --format '{{.State.ExitCode}}'
docker inspect <container> --format '{{.Config.Entrypoint}} {{.Config.Cmd}}'
```

Run interactively:

```bash
docker run --rm -it --entrypoint sh myimage:latest
```

### Common causes

- App crashes on startup.
- Required environment variable missing.
- Entrypoint script fails.
- Main process runs in background and exits.
- Command is wrong.
- File permission issue.
- Config file missing.
- Container is designed as a one-shot job.
- Wrong architecture image.
- Dependency unavailable.

### Bad example

```dockerfile
CMD service nginx start
```

This may start nginx in the background and then exit.

### Better example

```dockerfile
CMD ["nginx", "-g", "daemon off;"]
```

### Example missing environment variable

App expects:

```bash
DATABASE_URL
```

Run with:

```bash
docker run --rm \
  -e DATABASE_URL="postgres://user:pass@db:5432/app" \
  myapp:1.0.0
```

### Takeaway summary

A container lives as long as its main process lives. If PID 1 exits, the container exits.

---

## 2. Image build fails

### Interview freeze point

The build fails, but the cause could be Dockerfile syntax, missing files, network, package repos, build context, or platform.

### Strong interview answer

> “I would read the first failing build step, check the Dockerfile instruction, build context, copied files, package manager output, network access, and whether cache is hiding or exposing the issue.”

### Symptoms

- `docker build` fails.
- `COPY failed: file not found`
- Package install fails.
- Build works locally but fails in CI.
- Build hangs downloading dependencies.
- Build fails only with `--no-cache`.

### Diagnostic commands

```bash
docker build -t myapp:debug .
docker build --no-cache -t myapp:debug .
docker build --progress=plain -t myapp:debug .
```

### Common causes

- File not in build context.
- `.dockerignore` excludes required file.
- Wrong `COPY` path.
- Package repository unavailable.
- Network/proxy issue.
- Base image changed.
- Missing build argument.
- Wrong platform.
- BuildKit behavior difference.
- Dependency version changed.

### Bad example

```dockerfile
COPY ../app /app
```

Docker cannot copy files outside the build context.

### Better structure

```text
project/
  Dockerfile
  app/
  package.json
```

```dockerfile
COPY app/ /app/
```

Build from project root:

```bash
docker build -t myapp:1.0.0 .
```

### Check `.dockerignore`

Bad:

```dockerignore
app/
```

If the Dockerfile needs `app/`, this will break `COPY`.

### Takeaway summary

Docker builds only see the build context. Check the failing layer, context, `.dockerignore`, and copied paths first.

---

## 3. Build is slow

### Interview freeze point

The Dockerfile works, but builds take too long.

### Strong interview answer

> “I would check Docker layer cache usage, instruction order, dependency install steps, build context size, `.dockerignore`, multi-stage builds, and whether CI starts from a cold cache every time.”

### Symptoms

- Builds take several minutes.
- Small code change rebuilds dependencies.
- CI builds much slower than local.
- Large context upload.
- Package install happens every build.
- Image layers are huge.

### Diagnostic commands

```bash
docker build --progress=plain -t myapp:debug .
docker history myapp:debug
du -sh .
```

### Bad Dockerfile

```dockerfile
FROM node:20
WORKDIR /app
COPY . .
RUN npm ci
CMD ["npm", "start"]
```

Any source change invalidates the `npm ci` layer.

### Better Dockerfile

```dockerfile
FROM node:20
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
CMD ["npm", "start"]
```

Now dependency install is cached unless package files change.

### `.dockerignore` example

```dockerignore
node_modules
.git
coverage
dist
*.log
.env
```

### Multi-stage build example

```dockerfile
FROM golang:1.22 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o app ./cmd/app

FROM gcr.io/distroless/base-debian12
COPY --from=build /src/app /app
CMD ["/app"]
```

### Takeaway summary

Fast Docker builds depend on good layer ordering, small build context, caching, and multi-stage builds.

---

## 4. Image is too large

### Interview freeze point

The container works, but the image is bloated.

### Strong interview answer

> “I would inspect image layers, remove unnecessary build tools from the runtime image, use multi-stage builds, clean package manager caches, and choose an appropriate base image.”

### Symptoms

- Image is several GB.
- Push/pull is slow.
- CI/CD pipeline slow.
- Container startup delayed.
- Security scan finds many unnecessary packages.

### Diagnostic commands

```bash
docker images
docker history myimage:latest
docker image inspect myimage:latest
```

### Common causes

- Build tools included in runtime.
- Cache files left behind.
- Large base image.
- Entire repository copied.
- Dependencies installed but not cleaned.
- Artifacts from previous stages included.
- Logs or test data copied into image.

### Bad example

```dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y build-essential curl python3
COPY . /app
```

### Better pattern

```dockerfile
FROM node:20 AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
```

### Clean apt cache

```dockerfile
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*
```

### Takeaway summary

Keep runtime images focused. Build tools belong in build stages, not production runtime layers.

---

## 5. Container cannot connect to another container

### Interview freeze point

Two containers are running, but cannot communicate.

### Strong interview answer

> “I would check whether both containers are on the same Docker network, whether the application is using the container name or service name, whether the target process listens on the correct interface and port, and whether the wrong localhost assumption is being made.”

### Symptoms

- App cannot connect to database container.
- `connection refused`
- `no such host`
- Works on host but not from another container.
- App uses `localhost` incorrectly.

### Diagnostic commands

```bash
docker network ls
docker network inspect <network>
docker inspect <container>
docker exec -it <container> sh
```

Test inside container:

```bash
nc -vz db 5432
getent hosts db
```

### Common causes

- Containers are on different networks.
- App uses `localhost`.
- Target container not listening.
- Wrong port.
- Container name not resolvable on default bridge.
- Docker Compose service name misunderstood.
- Database still starting.
- Firewall rules on host.

### Example with user-defined network

```bash
docker network create appnet

docker run -d --name db --network appnet postgres:16

docker run --rm -it --network appnet myapp:latest
```

Inside `myapp`, connect to:

```text
db:5432
```

Not:

```text
localhost:5432
```

### Docker Compose example

```yaml
services:
  api:
    image: myapi:1.0.0
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/app
    depends_on:
      - db

  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: postgres
```

### Takeaway summary

Inside a container, `localhost` means that same container. Use service/container names on a shared Docker network.

---

## 6. Published port not reachable

### Interview freeze point

The container runs, but the app is not reachable from the host.

### Strong interview answer

> “I would check port publishing, container port, host port, bind address inside the app, container logs, and whether the app listens on `0.0.0.0` instead of only `127.0.0.1`.”

### Symptoms

- `curl localhost:8080` fails.
- Container is running.
- `docker ps` shows no port mapping.
- App works inside container but not from host.
- Connection refused.

### Diagnostic commands

```bash
docker ps
docker port <container>
docker logs <container>
docker exec -it <container> sh
ss -tlnp
```

### Correct port publish

```bash
docker run -p 8080:80 nginx
```

This maps:

```text
host 8080 → container 80
```

### Common causes

- Forgot `-p`.
- Mapped wrong port.
- App listens on 127.0.0.1 inside container.
- App listens on different port.
- Host firewall blocks port.
- Another process uses host port.
- Docker Desktop networking confusion.
- Container crashed.

### Bad app binding

```text
127.0.0.1:3000
```

Better app binding:

```text
0.0.0.0:3000
```

### Example

```bash
docker run -p 3000:3000 myapp:1.0.0
```

App must listen on port 3000 inside the container.

### Takeaway summary

Port publishing connects host ports to container ports. The app must listen on the mapped container port and bind to all interfaces.

---

## 7. DNS resolution fails inside container

### Interview freeze point

The network exists, but the container cannot resolve names.

### Strong interview answer

> “I would test DNS from inside the container, check Docker network DNS, host DNS configuration, custom DNS settings, Compose service names, and whether corporate VPN or proxy DNS is interfering.”

### Symptoms

- `could not resolve host`
- Container cannot resolve external domains.
- Container cannot resolve another service.
- Works on host but not in container.
- DNS fails only on Docker Desktop or VPN.

### Diagnostic commands

```bash
docker exec -it <container> sh
cat /etc/resolv.conf
nslookup google.com
getent hosts db
```

Run test:

```bash
docker run --rm busybox nslookup google.com
```

### Common causes

- Host DNS broken.
- Docker daemon DNS misconfigured.
- Corporate VPN changes DNS.
- Container on wrong network.
- Service name wrong.
- Custom DNS server unreachable.
- Internal domain not resolvable.
- Compose project/network name confusion.

### Docker daemon DNS example

`/etc/docker/daemon.json`:

```json
{
  "dns": ["10.0.0.10", "1.1.1.1"]
}
```

Restart Docker:

```bash
sudo systemctl restart docker
```

### Per-container DNS

```bash
docker run --dns 10.0.0.10 myimage
```

### Compose service name

```yaml
services:
  api:
    image: api
  db:
    image: postgres:16
```

From `api`, resolve:

```text
db
```

### Takeaway summary

DNS must be tested from inside the container. Host DNS success does not always mean container DNS success.

---

## 8. Volume data missing

### Interview freeze point

The application writes data, but data disappears or is not where expected.

### Strong interview answer

> “I would check whether the data is written inside the container filesystem, a named volume, or a bind mount. Container writable layers are ephemeral. Persistent data should use volumes or external storage.”

### Symptoms

- Data disappears after container removal.
- Database resets.
- Files not visible on host.
- App writes to unexpected path.
- Volume mount hides image content.

### Diagnostic commands

```bash
docker inspect <container> --format '{{json .Mounts}}' | jq
docker volume ls
docker volume inspect <volume>
```

### Container filesystem is not durable

Bad for persistent data:

```bash
docker run postgres:16
```

Better:

```bash
docker volume create pgdata

docker run -d \
  --name db \
  -v pgdata:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=postgres \
  postgres:16
```

### Bind mount example

```bash
docker run --rm \
  -v "$PWD/config:/app/config" \
  myapp:1.0.0
```

### Common causes

- No volume mounted.
- Mounted wrong path.
- Bind mount path wrong.
- Relative path confusion.
- Volume mount hides files already in image.
- Container writes to different directory.
- Permission issue prevents writing.
- Container removed with anonymous volume confusion.

### Takeaway summary

Container writable layers are disposable. Use volumes for persistent data and verify the mount path.

---

## 9. Permission denied on mounted volume

### Interview freeze point

The volume exists, but the app cannot read or write it.

### Strong interview answer

> “I would check the user running inside the container, file ownership on the host or volume, UID/GID mapping, SELinux/AppArmor labels, and whether the mount is read-only.”

### Symptoms

- `Permission denied`
- App cannot write logs/uploads.
- Works as root but not non-root.
- Bind mount fails on Linux.
- Works on Docker Desktop but not server.
- Database container cannot initialize data directory.

### Diagnostic commands

```bash
docker exec -it <container> id
docker exec -it <container> ls -ld /data
ls -ld ./data
docker inspect <container> --format '{{json .Mounts}}' | jq
```

### Common causes

- Container user UID does not own mounted path.
- Host directory owned by root.
- Read-only mount.
- SELinux label missing.
- App writes to path not mounted.
- Docker Desktop file sharing issue.
- Rootless Docker UID mapping.

### Fix ownership

```bash
sudo chown -R 1000:1000 ./data
```

Run with user:

```bash
docker run --user 1000:1000 -v "$PWD/data:/data" myapp
```

Read-write mount:

```bash
docker run -v "$PWD/data:/data:rw" myapp
```

SELinux example:

```bash
docker run -v "$PWD/data:/data:Z" myapp
```

### Takeaway summary

Volume permissions are about the container user, host ownership, mount flags, and security labels.

---

## 10. Docker Compose service cannot reach dependency

### Interview freeze point

Compose starts services, but the app cannot connect to the database or cache.

### Strong interview answer

> “I would check service names, networks, environment variables, dependency readiness, health checks, and whether `depends_on` is being mistaken for readiness.”

### Symptoms

- API starts before database is ready.
- Connection refused.
- Service name not resolved.
- Works after manual restart.
- Compose up succeeds but app fails.

### Example Compose file

```yaml
services:
  api:
    build: .
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/app
    depends_on:
      - db

  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: postgres
```

### Important detail

`depends_on` controls startup order, not application readiness.

### Better with healthcheck

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: postgres
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 10

  api:
    build: .
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/app
    depends_on:
      db:
        condition: service_healthy
```

### Common causes

- App uses `localhost` instead of service name.
- Database not ready.
- Wrong port.
- Wrong credentials.
- Services on different networks.
- Environment variable missing.
- Health checks absent.

### Verify

```bash
docker compose ps
docker compose logs db
docker compose logs api
docker compose exec api sh
```

Inside API:

```bash
nc -vz db 5432
```

### Takeaway summary

Compose service names are DNS names. `depends_on` is not a full readiness strategy unless health conditions are used.

---

## 11. Docker Compose environment variable confusion

### Interview freeze point

Variables do not have the values you expect.

### Strong interview answer

> “I would distinguish Compose variable substitution, container environment variables, `.env` files, shell environment, and `env_file`. These are related but not the same.”

### Symptoms

- Variable is empty.
- Wrong value used.
- Works locally but not CI.
- `.env` file ignored.
- Secret accidentally printed.
- Compose warns variable is not set.

### Compose substitution example

```yaml
services:
  api:
    image: myapi:${IMAGE_TAG}
```

`.env` file:

```env
IMAGE_TAG=1.2.3
```

### Container environment example

```yaml
services:
  api:
    image: myapi:1.2.3
    environment:
      APP_ENV: production
      LOG_LEVEL: info
```

### `env_file` example

```yaml
services:
  api:
    image: myapi:1.2.3
    env_file:
      - app.env
```

### Common causes

- `.env` affects Compose interpolation but is not automatically the same as `env_file`.
- Shell environment overrides `.env`.
- Wrong working directory.
- Variable not exported in CI.
- Quoting issue.
- Secret committed to `.env`.
- Variable used at build time but set only at runtime.

### Debug

```bash
docker compose config
```

This shows resolved Compose configuration.

### Takeaway summary

Use `docker compose config` to see what Compose actually resolved. Separate build-time, Compose-time, and runtime variables.

---

## 12. Build argument confused with environment variable

### Interview freeze point

The value exists during build but not at runtime, or vice versa.

### Strong interview answer

> “I would distinguish `ARG` and `ENV`. `ARG` is available during image build. `ENV` is persisted into the image and available at runtime unless overridden.”

### Example

```dockerfile
ARG APP_VERSION
ENV APP_VERSION=$APP_VERSION
```

Build:

```bash
docker build --build-arg APP_VERSION=1.2.3 -t myapp:1.2.3 .
```

Run:

```bash
docker run --rm myapp:1.2.3 env | grep APP_VERSION
```

### Common mistake

```dockerfile
ARG API_URL
```

Then expecting `API_URL` at runtime. It will not be available unless copied into `ENV` or passed during `docker run`.

### Runtime env

```bash
docker run -e API_URL=https://api.example.com myapp
```

Compose runtime env:

```yaml
services:
  api:
    image: myapp
    environment:
      API_URL: https://api.example.com
```

### Security warning

Do not pass secrets as build args if they can end up in image layers or build history.

### Takeaway summary

`ARG` is for build-time. `ENV` is for runtime. Do not confuse them.

---

## 13. Registry login or image pull failure

### Interview freeze point

The image exists, but Docker cannot pull it.

### Strong interview answer

> “I would check registry URL, image name, tag, authentication, token expiry, network access, TLS trust, rate limits, and whether the host or CI runner is logged into the correct registry.”

### Symptoms

- `pull access denied`
- `unauthorized: authentication required`
- `manifest unknown`
- `repository does not exist`
- `x509 certificate signed by unknown authority`
- Works locally but not CI.
- Kubernetes or ECS cannot pull image.

### Diagnostic commands

```bash
docker login registry.example.com
docker pull registry.example.com/team/app:1.2.3
docker manifest inspect registry.example.com/team/app:1.2.3
```

### Common causes

- Wrong registry hostname.
- Wrong repository path.
- Wrong tag.
- Token expired.
- Not logged in on agent.
- Image was not pushed.
- Private registry CA not trusted.
- Docker Hub rate limit.
- Architecture-specific image missing.
- CI secret not available.

### Login example

```bash
echo "$REGISTRY_PASSWORD" | docker login registry.example.com \
  -u "$REGISTRY_USER" \
  --password-stdin
```

### Push example

```bash
docker tag app:local registry.example.com/team/app:1.2.3
docker push registry.example.com/team/app:1.2.3
```

### Takeaway summary

Registry issues are usually image name, tag, auth, token, network, TLS, or platform support.

---

## 14. Wrong image architecture

### Interview freeze point

The image builds or pulls, but fails on another machine.

### Strong interview answer

> “I would check host architecture and image architecture. An image built for `amd64` may not run on `arm64` unless emulation or a multi-architecture image is used.”

### Symptoms

- `exec format error`
- Works on Mac but not Linux server.
- Works on amd64 but not ARM.
- Kubernetes node cannot run image.
- CI builds wrong platform.

### Diagnostic commands

```bash
uname -m
docker image inspect myimage:latest --format '{{.Architecture}}'
docker buildx imagetools inspect registry.example.com/app:1.2.3
```

### Common causes

- Built on Apple Silicon as ARM image.
- Deployed to amd64 cluster.
- No multi-arch manifest.
- Base image lacks target platform.
- Binary compiled for wrong architecture.

### Build for specific platform

```bash
docker buildx build \
  --platform linux/amd64 \
  -t registry.example.com/app:1.2.3 \
  --push .
```

Multi-arch build:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t registry.example.com/app:1.2.3 \
  --push .
```

### Takeaway summary

`exec format error` often means architecture mismatch. Check host, image, and binary architecture.

---

## 15. Container cannot access host service

### Interview freeze point

A container needs to call something running on the Docker host.

### Strong interview answer

> “I would check whether the app is trying to use `localhost`. Inside a container, `localhost` is the container itself. To reach the host, use the proper host gateway mechanism or host network where appropriate.”

### Symptoms

- Container cannot reach local database.
- App uses `localhost:5432` and fails.
- Works outside Docker.
- Connection refused from container.

### Common cause

Inside container:

```text
localhost
```

means:

```text
the container
```

not the Docker host.

### Docker Desktop

Use:

```text
host.docker.internal
```

Example:

```bash
docker run --rm myapp \
  curl http://host.docker.internal:8080
```

### Linux host gateway

```bash
docker run --add-host=host.docker.internal:host-gateway myapp
```

Compose:

```yaml
services:
  api:
    image: myapp
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

### Alternative: host networking

Linux only:

```bash
docker run --network host myapp
```

Use carefully because it reduces network isolation.

### Takeaway summary

Inside containers, `localhost` is not the host. Use service names, host gateway, or explicit networking.

---

## 16. Container has no internet access

### Interview freeze point

The container cannot install packages or call APIs.

### Strong interview answer

> “I would test DNS and routing from inside the container, check Docker bridge network, host firewall, proxy settings, daemon DNS, corporate VPN behavior, and whether the container runs in an isolated network.”

### Symptoms

- `apt-get update` fails.
- Cannot resolve domain.
- Cannot connect to external API.
- Works on host but not container.
- Fails only under VPN.

### Diagnostic commands

```bash
docker run --rm busybox ping -c 3 8.8.8.8
docker run --rm busybox nslookup google.com
docker run --rm curlimages/curl curl -I https://example.com
```

### Common causes

- DNS failure.
- Proxy required.
- Docker daemon network issue.
- Host firewall blocks forwarding.
- Corporate VPN blocks Docker bridge.
- Container attached to internal-only network.
- Default bridge misconfigured.
- iptables/nftables conflict.

### Proxy build example

```bash
docker build \
  --build-arg HTTP_PROXY=http://proxy.example.com:8080 \
  --build-arg HTTPS_PROXY=http://proxy.example.com:8080 \
  -t myapp .
```

Runtime proxy:

```bash
docker run \
  -e HTTP_PROXY=http://proxy.example.com:8080 \
  -e HTTPS_PROXY=http://proxy.example.com:8080 \
  myapp
```

### Takeaway summary

Internet access failures are usually DNS, proxy, routing, host firewall, or Docker bridge problems.

---

## 17. Health check failing

### Interview freeze point

The container is running, but Docker marks it unhealthy.

### Strong interview answer

> “I would check the health check command, interval, timeout, start period, app bind address, app startup time, and whether the health endpoint actually reflects readiness.”

### Symptoms

- Container status shows `unhealthy`.
- Orchestrator restarts container.
- Health command fails manually.
- App starts slowly.
- Health endpoint requires auth.

### Diagnostic commands

```bash
docker ps
docker inspect <container> --format '{{json .State.Health}}' | jq
docker exec -it <container> sh
```

### Dockerfile health check

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1
```

### Common causes

- `curl` not installed in image.
- Wrong port.
- Wrong path.
- App not ready before health check starts.
- Health endpoint returns 401/500.
- App binds to different interface.
- Dependency check too strict.
- Timeout too low.

### Test inside container

```bash
docker exec -it myapp sh
curl -v http://localhost:8080/health
```

### Resolution

- Fix health path.
- Add required tool or use app-native check.
- Increase start period.
- Separate liveness from dependency readiness where orchestrator supports it.
- Avoid health checks that fail because a downstream optional service is slow.

### Takeaway summary

A health check is only useful if it tests the right thing at the right time.

---

## 18. Container uses too much memory or gets OOMKilled

### Interview freeze point

The container exits under load.

### Strong interview answer

> “I would check memory limits, container stats, exit code, application memory behavior, and host memory pressure. Exit code 137 often indicates the process was killed, commonly due to memory.”

### Symptoms

- Container exits with code 137.
- Restart loop under load.
- Host memory pressure.
- Docker stats shows high memory usage.
- App logs stop abruptly.

### Diagnostic commands

```bash
docker stats
docker inspect <container> --format '{{.State.ExitCode}}'
docker inspect <container> --format '{{.State.OOMKilled}}'
dmesg | grep -i kill
```

### Run with memory limit

```bash
docker run --memory=512m --memory-swap=512m myapp
```

Compose:

```yaml
services:
  api:
    image: myapp
    mem_limit: 512m
```

### Common causes

- Memory leak.
- Limit too low.
- JVM/Node/Python runtime not tuned for container limits.
- Large request payload.
- Too many workers.
- Host memory exhausted.
- No swap allowed.
- Cache grows unbounded.

### JVM example

```bash
docker run -e JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75" my-java-app
```

### Takeaway summary

OOM issues require checking both container limits and application memory behavior.

---

## 19. CPU throttling or poor performance

### Interview freeze point

The app is slow, but not crashing.

### Strong interview answer

> “I would check CPU limits, CPU shares, host load, container stats, application concurrency, and whether the workload is being throttled. CPU limits can protect the host but also reduce performance.”

### Symptoms

- High latency.
- CPU usage capped.
- App slow under load.
- Host CPU high.
- More replicas help.
- Container does not crash.

### Diagnostic commands

```bash
docker stats
docker inspect <container> --format '{{json .HostConfig.CpuQuota}}'
docker inspect <container> --format '{{json .HostConfig.NanoCpus}}'
```

Run with CPU limit:

```bash
docker run --cpus="1.5" myapp
```

Set CPU shares:

```bash
docker run --cpu-shares=512 myapp
```

### Common causes

- CPU limit too low.
- Host overloaded.
- Too many containers on host.
- Single-threaded app.
- Excess workers causing context switching.
- Slow dependency mistaken for CPU issue.
- Debug logging too heavy.

### Resolution

- Adjust CPU limits.
- Right-size app worker count.
- Scale horizontally.
- Move noisy neighbors.
- Profile application.
- Monitor host and container CPU.

### Takeaway summary

CPU limits shape runtime performance. Slow containers may be throttled rather than broken.

---

## 20. Docker daemon not running or unhealthy

### Interview freeze point

All Docker commands fail.

### Strong interview answer

> “I would check whether the Docker daemon is running, whether the user can access the socket, daemon logs, disk space, container runtime health, and recent host changes.”

### Symptoms

- `Cannot connect to the Docker daemon`
- `permission denied while trying to connect to the Docker daemon socket`
- Docker commands hang.
- Containers stop unexpectedly.
- Docker service fails to start.

### Diagnostic commands

Linux:

```bash
systemctl status docker
journalctl -u docker -n 100
docker info
df -h
```

Check socket:

```bash
ls -l /var/run/docker.sock
```

### Common causes

- Docker service stopped.
- User not in docker group.
- Disk full.
- Bad daemon config.
- Container runtime issue.
- iptables conflict.
- Docker Desktop not running.
- Rootless Docker environment mismatch.

### Resolution

Start Docker:

```bash
sudo systemctl start docker
```

Enable on boot:

```bash
sudo systemctl enable docker
```

Add user to docker group:

```bash
sudo usermod -aG docker "$USER"
```

Log out and back in.

### Security warning

Membership in the `docker` group is effectively root-level access on the host.

### Takeaway summary

Docker daemon issues are host-level issues. Check service health, socket permissions, logs, and disk.

---

## 21. Docker disk usage too high

### Interview freeze point

The host is full because Docker accumulated images, containers, volumes, and build cache.

### Strong interview answer

> “I would inspect Docker disk usage, identify whether space is used by images, containers, volumes, logs, or build cache, and clean safely without deleting needed persistent volumes.”

### Symptoms

- Host disk full.
- Builds fail.
- Containers fail to start.
- Logs consume huge space.
- `No space left on device`.

### Diagnostic commands

```bash
docker system df
docker system df -v
docker image ls
docker container ls -a
docker volume ls
du -sh /var/lib/docker/*
```

### Cleanup commands

Remove stopped containers:

```bash
docker container prune
```

Remove unused images:

```bash
docker image prune -a
```

Remove build cache:

```bash
docker builder prune
```

Full prune:

```bash
docker system prune -a
```

Dangerous for volumes:

```bash
docker system prune -a --volumes
```

Use `--volumes` carefully because it can delete persistent data.

### Log rotation

`/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  }
}
```

Restart Docker:

```bash
sudo systemctl restart docker
```

### Takeaway summary

Clean Docker storage carefully. Images and caches are usually safe to prune; volumes may contain production data.

---

## 22. Container logs too large

### Interview freeze point

Disk fills up because container logs are unbounded.

### Strong interview answer

> “I would check the Docker logging driver and log options. The default json-file logs can grow indefinitely unless rotation is configured.”

### Symptoms

- `/var/lib/docker/containers` is huge.
- Disk fills over time.
- Container logs are massive.
- `docker logs` is slow.
- Host becomes unstable.

### Diagnostic commands

```bash
docker inspect <container> --format '{{.LogPath}}'
sudo du -sh /var/lib/docker/containers/*/*-json.log 2>/dev/null | sort -h
```

### Configure log rotation

`/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
```

Restart Docker:

```bash
sudo systemctl restart docker
```

Existing containers may need recreation to pick up new logging settings.

### Compose logging example

```yaml
services:
  api:
    image: myapp
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "3"
```

### Common causes

- Debug logs enabled.
- No log rotation.
- App logs too verbose.
- Logs written both to stdout and file.
- High request volume.
- Error loop.

### Takeaway summary

Container logs need rotation. Otherwise stdout logging can fill the host disk.

---

## 23. Secrets baked into image

### Interview freeze point

This tests supply-chain and security maturity.

### Strong interview answer

> “I would never intentionally bake secrets into images. Images are copied, cached, pushed to registries, scanned, and shared. If a secret is in a Docker layer, deleting it in a later layer does not necessarily remove it from history.”

### Symptoms

- Secret appears in image history.
- `.env` copied into image.
- Credentials found in registry scan.
- API token exposed in build logs.
- Secret remains after `rm` in later layer.

### Bad Dockerfile

```dockerfile
COPY .env /app/.env
RUN export API_KEY=secret
```

### Worse pattern

```dockerfile
RUN echo "password=supersecret" > /app/config
RUN rm /app/config
```

The secret can still exist in an earlier layer.

### Diagnostic commands

```bash
docker history myimage:latest
docker save myimage:latest -o image.tar
```

Secret scanning tools can also inspect images.

### Better runtime secret injection

```bash
docker run --env-file runtime.env myapp
```

Compose secrets pattern:

```yaml
services:
  api:
    image: myapp
    secrets:
      - db_password

secrets:
  db_password:
    file: ./db_password.txt
```

### BuildKit secret example

```dockerfile
# syntax=docker/dockerfile:1.6
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN=$(cat /run/secrets/npm_token) npm ci
```

Build:

```bash
docker build --secret id=npm_token,src=.npm_token -t myapp .
```

### Takeaway summary

Secrets do not belong in images. If a secret is baked into an image, rotate it.

---

## 24. Running as root security issue

### Interview freeze point

The image works, but it runs as root.

### Strong interview answer

> “I would prefer running containers as a non-root user unless there is a clear reason. Running as root increases the impact of container escape, volume permission mistakes, and host-mounted socket risks.”

### Symptoms

- Security scan flags root user.
- Container can write too broadly.
- Mounted files become root-owned.
- Kubernetes restricted policy rejects image.
- App does not need root but runs as root.

### Bad Dockerfile

```dockerfile
FROM node:20
WORKDIR /app
COPY . .
CMD ["node", "server.js"]
```

This may run as root depending on base image/default user.

### Better Dockerfile

```dockerfile
FROM node:20-alpine
WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

USER node

CMD ["node", "server.js"]
```

Custom user:

```dockerfile
RUN addgroup -S app && adduser -S app -G app
USER app
```

### Common issues after switching to non-root

- App cannot write to directory.
- Port below 1024 requires privilege.
- File ownership wrong.
- Volume permissions wrong.
- Package install attempted at runtime.

### Fix ownership

```dockerfile
RUN chown -R app:app /app
USER app
```

### Takeaway summary

Run as non-root by default and fix file ownership intentionally.

---

## 25. Docker socket mounted into container

### Interview freeze point

A container needs Docker access, but mounting the socket has security risk.

### Strong interview answer

> “Mounting `/var/run/docker.sock` gives the container control over the host Docker daemon, which is effectively root on the host. I would avoid it unless necessary and use safer build approaches where possible.”

### Symptoms

- CI container builds Docker images by mounting socket.
- Security team flags Docker socket mount.
- Container can start privileged containers.
- Build system has broad host control.

### Common pattern

```bash
docker run -v /var/run/docker.sock:/var/run/docker.sock docker:cli docker ps
```

### Risk

A container with Docker socket access can often mount host filesystems or start privileged containers.

### Safer alternatives

- BuildKit rootless.
- Kaniko.
- Buildah.
- Dedicated isolated builder nodes.
- Remote builder.
- Cloud-native build service.
- Ephemeral CI runners.

### If socket must be used

- Use dedicated build hosts.
- Avoid sharing with untrusted jobs.
- Restrict who can trigger builds.
- Do not run arbitrary PR code with socket access.
- Monitor and rotate hosts.

### Takeaway summary

Docker socket access is host-level power. Treat it like privileged infrastructure access.

---

## 26. Multi-stage build artifact missing

### Interview freeze point

The build succeeds in one stage, but the runtime image does not contain the artifact.

### Strong interview answer

> “I would check stage names, build output paths, `COPY --from`, working directories, and whether the artifact exists at the expected path in the build stage.”

### Symptoms

- Runtime container says binary not found.
- Static files missing.
- `COPY --from=build` fails.
- Image builds but app cannot start.
- Wrong artifact version copied.

### Example multi-stage Dockerfile

```dockerfile
FROM golang:1.22 AS build
WORKDIR /src
COPY . .
RUN go build -o /out/app ./cmd/app

FROM gcr.io/distroless/base-debian12
COPY --from=build /out/app /app
CMD ["/app"]
```

### Common causes

- Wrong stage name.
- Wrong output path.
- Build command writes elsewhere.
- Workdir misunderstood.
- Artifact excluded by `.dockerignore`.
- Runtime image lacks required libraries.
- Static files not copied.

### Debug build stage

```bash
docker build --target build -t myapp-build .
docker run --rm -it myapp-build sh
```

If shell is unavailable in build image, add temporary debug step or use a build image with shell.

### Takeaway summary

Multi-stage copy errors are path and stage errors. Verify the artifact exists in the build stage.

---

## 27. Entrypoint and CMD confusion

### Interview freeze point

The image starts with unexpected arguments or ignores command overrides.

### Strong interview answer

> “I would distinguish `ENTRYPOINT` from `CMD`. `ENTRYPOINT` defines the executable. `CMD` provides default arguments. Runtime arguments replace `CMD` but usually append to `ENTRYPOINT`.”

### Example

```dockerfile
ENTRYPOINT ["python", "app.py"]
CMD ["--port", "8080"]
```

Run default:

```bash
docker run myapp
```

Runs:

```text
python app.py --port 8080
```

Override CMD:

```bash
docker run myapp --port 9090
```

Runs:

```text
python app.py --port 9090
```

### Shell form problem

```dockerfile
CMD python app.py
```

Exec form is usually better:

```dockerfile
CMD ["python", "app.py"]
```

### Common causes

- Shell form swallows signals.
- Runtime args replace CMD unexpectedly.
- Entrypoint script does not `exec`.
- Quoting issues.
- App receives wrong args.
- Kubernetes command/args override misunderstood.

### Entrypoint script best practice

```sh
#!/bin/sh
set -e
exec "$@"
```

Dockerfile:

```dockerfile
ENTRYPOINT ["/entrypoint.sh"]
CMD ["python", "app.py"]
```

### Takeaway summary

Use `ENTRYPOINT` for the executable and `CMD` for defaults. Prefer exec form for signal handling.

---

## 28. Container does not stop gracefully

### Interview freeze point

The app gets killed instead of shutting down cleanly.

### Strong interview answer

> “I would check signal handling, PID 1 behavior, exec form, entrypoint scripts, stop timeout, and whether the application handles SIGTERM. Containers should shut down gracefully before SIGKILL.”

### Symptoms

- App loses in-flight requests.
- Database connections not closed.
- `docker stop` takes too long.
- Container receives SIGKILL.
- Kubernetes termination behaves badly.
- Shell script PID 1 does not forward signals.

### Docker stop behavior

```text
docker stop sends SIGTERM
waits grace period
then sends SIGKILL
```

### Bad Dockerfile

```dockerfile
CMD python app.py
```

Shell form can interfere with signal handling.

### Better Dockerfile

```dockerfile
CMD ["python", "app.py"]
```

### Bad entrypoint

```sh
#!/bin/sh
python app.py
```

Better:

```sh
#!/bin/sh
exec python app.py
```

### Configure stop timeout

```bash
docker stop --time 30 mycontainer
```

Compose:

```yaml
services:
  api:
    image: myapp
    stop_grace_period: 30s
```

### Takeaway summary

Graceful shutdown depends on PID 1, signal handling, and enough stop time.

---

## 29. Docker Compose project name or network conflict

### Interview freeze point

Two Compose stacks interfere with each other.

### Strong interview answer

> “I would check Compose project name, generated network names, container names, volume names, and port conflicts. Compose scopes resources by project name unless explicit names are used.”

### Symptoms

- Wrong containers communicate.
- Port already allocated.
- Volumes reused unexpectedly.
- `docker compose down` removes wrong resources.
- CI jobs conflict.
- Multiple local stacks collide.

### Diagnostic commands

```bash
docker compose ps
docker network ls
docker volume ls
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

### Compose project name

```bash
docker compose -p myproject up -d
```

Environment variable:

```bash
COMPOSE_PROJECT_NAME=myproject docker compose up -d
```

### Bad pattern

```yaml
services:
  api:
    container_name: api
```

Explicit `container_name` can cause collisions.

Better: let Compose name containers by project.

### Common causes

- Same project name in CI.
- Explicit container names.
- Explicit volume names.
- Same host port.
- Old stack not removed.
- Shared external network.

### Resolution

- Use unique project names.
- Avoid `container_name` unless necessary.
- Use dynamic ports in CI.
- Clean up after test runs.
- Be explicit with external resources.

### Takeaway summary

Compose project names scope resources. Hardcoded names create collisions.

---

## 30. Works locally but fails in CI or production

### Interview freeze point

This is the classic Docker interview scenario.

### Strong interview answer

> “I would compare image version, build context, environment variables, secrets, platform architecture, runtime user, mounted volumes, network access, resource limits, and external dependencies. Docker reduces differences but does not remove them.”

### Symptoms

- Works on laptop but not CI.
- Works in Compose but not Kubernetes.
- Works with local `.env` but not deployment.
- Fails only on ARM or amd64.
- Fails only as non-root.
- Fails only without bind mounts.
- Fails only under resource limits.

### Diagnostic checklist

```text
Same image digest?
Same environment variables?
Same command and entrypoint?
Same platform architecture?
Same user?
Same ports?
Same network access?
Same secrets?
Same volume mounts?
Same resource limits?
Same working directory?
```

### Verify image digest

```bash
docker image inspect myapp:1.2.3 --format '{{.Id}}'
docker pull registry.example.com/app:1.2.3
docker inspect registry.example.com/app:1.2.3 --format '{{.Id}}'
```

### Common causes

- Local bind mount hides missing files.
- Local `.env` not present in CI.
- Image tag reused.
- Different CPU architecture.
- CI lacks Docker credentials.
- Running as root locally but non-root in prod.
- Production has memory/CPU limits.
- Network dependency not reachable.
- Different Compose/Kubernetes command overrides.

### Prevention

- Use immutable image tags or digests.
- Build once, promote same image.
- Keep config explicit.
- Test container without local bind mounts.
- Run CI with production-like command.
- Avoid relying on local files.
- Use health checks.
- Pin dependencies.

### Takeaway summary

Docker improves portability, but runtime environment still matters. Compare image, config, platform, network, storage, and limits.

---

# Bonus: Docker interview answer frameworks

## Framework 1: The container will not start answer

Use this when asked:

> “A Docker container exits immediately. What do you do?”

```text
1. Check docker ps -a.
2. Check exit code.
3. Check docker logs.
4. Inspect entrypoint and command.
5. Check required env vars and config.
6. Run interactively with shell.
7. Verify file permissions.
8. Check architecture.
9. Fix image or runtime config.
10. Re-run and verify.
```

Interview version:

> “A container exits when its main process exits. I would inspect the exit code, logs, entrypoint, command, and runtime environment first.”

---

## Framework 2: The Docker networking answer

Use this when asked:

> “Two containers cannot communicate. How do you troubleshoot?”

```text
1. Identify source and destination.
2. Check container network membership.
3. Use service/container name, not localhost.
4. Check DNS resolution inside source container.
5. Check target port and listener.
6. Check port mapping only if host access is needed.
7. Check firewall and host networking.
8. Test with curl, nc, or getent.
9. Fix network or app config.
10. Verify from inside the source container.
```

Interview version:

> “Inside a container, localhost is the container itself. For container-to-container traffic, I use service names on a shared Docker network.”

---

## Framework 3: The Docker build answer

Use this when asked:

> “A Docker build fails or is slow. What do you check?”

```text
1. Read the failing layer.
2. Check build context.
3. Check .dockerignore.
4. Check COPY paths.
5. Check dependency install step.
6. Check network/proxy.
7. Check base image changes.
8. Check cache behavior.
9. Reorder layers for caching.
10. Use multi-stage builds.
```

Interview version:

> “Docker builds are layer-based. I would identify which layer fails or invalidates cache.”

---

## Framework 4: The Docker storage answer

Use this when asked:

> “Data disappeared from a container. What happened?”

```text
1. Check whether data was written to container layer.
2. Check volume mounts.
3. Check bind mount paths.
4. Check named volumes.
5. Check permissions.
6. Check whether container was removed.
7. Check Compose project volume names.
8. Restore from volume or backup if available.
9. Add durable volume.
10. Document data path.
```

Interview version:

> “Container writable layers are disposable. Persistent data belongs in volumes or external storage.”

---

## Framework 5: The Docker security answer

Use this when asked:

> “How do you make Docker images and containers safer?”

```text
1. Use minimal trusted base images.
2. Pin versions and scan images.
3. Do not bake secrets into images.
4. Run as non-root.
5. Drop unnecessary capabilities.
6. Avoid privileged containers.
7. Avoid Docker socket mounts.
8. Use read-only filesystem where possible.
9. Keep images patched.
10. Use signed or verified images where appropriate.
```

Interview version:

> “Docker security starts at build time and continues at runtime: image content, user, secrets, capabilities, mounts, and registry trust.”

---

# Common Docker interview traps and better answers

## Trap 1: “The container is running, so the app is reachable, right?”

Weak answer:

> “Yes.”

Better answer:

> “Not necessarily. I would check the app listener, port mapping, bind address, logs, and health check.”

---

## Trap 2: “Can containers use localhost to talk to each other?”

Weak answer:

> “Yes.”

Better answer:

> “No. Inside a container, localhost means that container. Containers should use service or container names on a shared network.”

---

## Trap 3: “If I delete a secret in a later Dockerfile layer, is it gone?”

Weak answer:

> “Yes.”

Better answer:

> “No. It may still exist in an earlier layer or build history. Secrets should not be copied into images.”

---

## Trap 4: “Is Docker socket mounting safe?”

Weak answer:

> “Yes, it is common.”

Better answer:

> “It is powerful but risky. Docker socket access is effectively host-level control. I would avoid it for untrusted workloads.”

---

## Trap 5: “Does EXPOSE publish a port?”

Weak answer:

> “Yes.”

Better answer:

> “No. `EXPOSE` documents the intended port. `docker run -p` publishes it to the host.”

---

## Trap 6: “Does depends_on mean the database is ready?”

Weak answer:

> “Yes.”

Better answer:

> “Not by itself. It controls startup order. Use health checks or application retry logic for readiness.”

---

## Trap 7: “Can I use latest in production?”

Weak answer:

> “Yes, it gets the newest image.”

Better answer:

> “I avoid `latest` in production. I prefer immutable tags or digests so deployments are reproducible.”

---

# Docker interview quick-reference table

| Issue | Main symptom | First thing to check | Common fix |
|---|---|---|---|
| Container exits | Status Exited | Logs and exit code | Fix CMD/env/app crash |
| Build fails | Build error | Failing layer | Fix context/COPY/deps |
| Slow build | Long builds | Cache/context | Reorder layers/.dockerignore |
| Large image | Slow pull/push | Image history | Multi-stage/minimal base |
| Container network fail | Cannot reach service | Network membership | Use shared network/service name |
| Port unreachable | Host cannot connect | `docker ps` ports | Fix `-p`, app bind/port |
| DNS fail | Cannot resolve | DNS inside container | Fix daemon DNS/network |
| Data missing | Data disappeared | Mounts/volumes | Use named volume |
| Volume permission | Permission denied | UID/GID/mount flags | Fix ownership/user |
| Compose dependency | DB not ready | Logs/health | Add healthcheck/retry |
| Compose env issue | Wrong variable | `docker compose config` | Fix `.env`/env_file |
| ARG vs ENV | Missing value | Dockerfile/runtime | Use correct scope |
| Registry pull fail | Unauthorized/tag missing | Image/tag/login | Fix auth/name/tag |
| Architecture mismatch | Exec format error | Image architecture | Build multi-arch |
| Host access fail | Cannot reach host | localhost assumption | Use host gateway |
| No internet | External calls fail | DNS/routing/proxy | Fix DNS/proxy/network |
| Healthcheck fail | Unhealthy | Health command | Fix path/port/timing |
| OOM | Exit 137 | Memory stats | Tune limit/app memory |
| CPU slow | High latency | CPU limits/stats | Adjust CPU/profile |
| Daemon down | Docker commands fail | Docker service | Start/fix daemon |
| Disk full | No space left | `docker system df` | Prune safely/log rotate |
| Logs huge | Disk growth | Log path | Configure log rotation |
| Secret in image | Secret leak | Image history | Rotate/use runtime secrets |
| Runs as root | Security finding | Image user | Add non-root user |
| Socket mounted | Host risk | Volume mounts | Avoid/isolate builders |
| Multi-stage missing | Binary not found | `COPY --from` | Fix paths/stages |
| CMD confusion | Wrong command | Entrypoint/CMD | Use exec form |
| Bad shutdown | SIGKILL/data loss | PID 1/signals | Use exec/handle SIGTERM |
| Compose conflict | Port/name collision | Project name | Avoid hardcoded names |
| Local vs CI fail | Inconsistent behavior | Image/config/platform | Compare runtime environment |

---

# Strong closing takeaway

Docker interviews are not just command tests. They are operational reasoning tests.

A weak answer sounds like:

> “I would rebuild the image.”

A strong answer sounds like:

> “I would check the container exit code, logs, entrypoint, command, environment, network, volumes, image architecture, and host daemon health. Then I would make the smallest fix and verify from inside the container and from the host path.”

Docker problems usually leave evidence in:

```text
docker logs
docker inspect
docker ps -a
docker events
docker network inspect
docker volume inspect
docker history
docker system df
container exit codes
host daemon logs
```

When you freeze, return to this sequence:

```text
Image → Dockerfile → Build context → Container config → Logs → Exit code → Network → Volumes → Resources → Host daemon → Fix → Verify
```

That sequence will carry you through most Docker interview questions.

---

# Final takeaway summaries

## The one-minute summary

Docker issues usually come from image builds, Dockerfile layers, build context, container entrypoints, environment variables, port mappings, DNS, Docker networks, volumes, permissions, registry authentication, architecture mismatch, resource limits, daemon health, disk usage, logs, secrets, or runtime security. The best answer starts with logs, exit code, inspect output, and the actual runtime configuration.

## The senior-engineer summary

A senior Docker user understands that containers package processes, not magic. They know that localhost changes meaning inside a container, volumes are required for durable data, secrets do not belong in images, `EXPOSE` does not publish ports, `latest` is not reproducible, and Docker socket access is dangerous. Seniority is shown by clear diagnosis, minimal images, safe runtime defaults, and repeatable builds.

## The interview survival summary

When your mind goes blank, say:

> “I would first check whether the issue is build-time or runtime. Then I would inspect the Dockerfile, build context, image layers, container logs, exit code, entrypoint, environment, networks, ports, volumes, permissions, resource limits, and daemon health. I would fix the proven cause and verify both from inside the container and from the host.”

That answer works across most Docker interview scenarios.
