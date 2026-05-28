# Stirling PDF — example app for open-web-app

Two entry points in this repo, one for each deploy mode:

- **`build.sh`** — used by EC2 mode (Image Builder runs this inside an AL2023 AMI build; details below).
- **`Dockerfile`** — used by ECS mode (CodeBuild clones this repo, runs `docker build .`, pushes the resulting image to a private ECR, then ECS Express updates its service to use the new image). Just `FROM stirlingtools/stirling-pdf:latest` — Stirling is already a container, so the Dockerfile is one line.

[Stirling PDF](https://stirlingtools.com) is an open-source PDF editor — merge, split, rotate, OCR, encrypt, etc. All processing is local; the server is stateless.

## What `build.sh` does

Runs as **root on AL2023**. Working directory is the repo root.

1. Installs Docker, enables + starts the daemon.
2. Pulls `stirlingtools/stirling-pdf:latest` (baked into the image so cold-boot has no network dependency).
3. Writes `/etc/systemd/system/app.service` that runs the container with `-p 80:8080`.
4. Writes `/etc/systemd/system/health.service` — a tiny `python3 -m http.server 8081` serving an `index.html` with `ok`. Decoupled health endpoint so the app's behavior on port 80 doesn't constrain liveness signaling.
5. Enables both services. **Does not start them** — designed to be called inside an AMI build pipeline (Image Builder, Packer, etc.) where the build instance gets snapshotted and terminated right after; the runtime instance starts the services on first boot.

## Use it as-is

```bash
# On a fresh AL2023 instance:
sudo ./build.sh
sudo systemctl start app.service health.service
curl http://localhost/        # Stirling PDF UI
curl http://localhost:8081/   # ok
```

## Use it from an AMI builder

The script is written to be the entire `ExecuteBash` step in an Image Builder component, or the `provisioner` in a Packer template:

- Don't `--now`-start anything; the AMI gets baked, terminated, then restored to fresh instances that boot up clean.
- Health endpoint on 8081 is independent from the app — wire your load balancer's health check there.

## Requirements at runtime

- Amazon Linux 2023 (or any RHEL-family with `dnf` + systemd; tweak the package install line for Debian/Ubuntu)
- ≥ 2 GB RAM (Stirling PDF + JVM idle ~500 MB)
- Outbound HTTPS for the initial image pull (after first run, no network needed)

## License

This repo is just glue around an open-source app. Stirling PDF itself is MIT-licensed — see [their repo](https://github.com/Stirling-Tools/Stirling-PDF) for app questions.
