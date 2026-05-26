# example_app — Stirling PDF

A deployable example for the open-web-app deploy API. Pushes Stirling PDF (an end-user PDF editor) to your ALB on port 80.

## The build.sh contract

The deploy Step Function clones whatever `git_repo` + `git_commit` you POST, then runs `./build.sh` as root from `/src` on a fresh AL2023 EC2 instance inside Image Builder. The instance is snapshotted to an AMI immediately after `build.sh` exits, then terminated.

So `build.sh` must leave the system such that the **runtime instance** (launched later from the AMI by the ASG) serves:

- **Port 80**: the app (whatever HTTP content you want to expose)
- **Port 8081, path `/`**: an HTTP 200 health responder (ALB target-group health check hits this; decoupled from port 80 so the app's own behavior on `/` doesn't constrain liveness signaling)

Both must be **enabled** systemd services (don't `start` them in build.sh — the build instance dies immediately; runtime instance starts them on first boot).

This `build.sh`:
- Installs Docker, pre-pulls `stirlingtools/stirling-pdf:latest`, enables `app.service` running the container with `-p 80:8080`.
- Drops a one-line `index.html` and enables `health.service` running `python3 -m http.server 8081`.

## Usage

1. **Push this directory to a fresh public GitHub repo you own** (the deploy SFN does `git clone` over HTTPS, no auth):
   ```bash
   cd example_app
   git init && git add . && git commit -m "stirling pdf"
   git remote add origin https://github.com/YOUR_USERNAME/REPO.git
   git push -u origin main
   ```

2. **Get the commit sha** to deploy:
   ```bash
   git rev-parse HEAD
   ```

3. **Get the current AL2023 AMI** (needs admin creds — mint via root console → IAM → admin → create temp access key):
   ```bash
   aws ssm get-parameter \
     --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
     --query 'Parameter.Value' --output text
   ```

4. **Edit `../deploy_client/sample_payload.json`** with your values:
   ```json
   {
     "git_repo": "https://github.com/YOUR_USERNAME/REPO.git",
     "git_commit": "<sha from step 2>",
     "base_ami_id": "<ami from step 3>"
   }
   ```

   Optional: add `"instance_type": "t3.medium"` to override the LT's default `t3.small`. Requires the SFN ASL extension (already applied if you ran `update-stack` per the project README).

5. **POST the deploy** (URL + key are in `../bootstrap_outputs.json`):
   ```bash
   cd ..
   .venv/bin/python -m deploy_client.deploy \
     --url "$(jq -r .deploy_api_url bootstrap_outputs.json)" \
     --key "$(jq -r .deploy_api_key bootstrap_outputs.json)" \
     --payload-file deploy_client/sample_payload.json
   ```

The Step Function takes ~15 min (~10 min Image Builder + ~3-5 min ASG instance refresh). After it `SUCCEEDED`:

```bash
curl -L "http://$(jq -r .alb_dns bootstrap_outputs.json)/"
```

Or open the URL in a browser → Stirling PDF UI.

## Notes

- **Stateless server-side**: Stirling PDF processes uploaded files in-memory / per-request. No persistent state to lose across deploys / ASG instance refreshes.
- **First boot**: the systemd unit pulls nothing (image is baked in), starts the container in seconds. The ALB health check (`HealthCheckGracePeriod: 120`) easily covers cold start.
- **Image pinning**: this uses `:latest`. For a real production deploy you'd pin to a digest so each `git_commit` reliably produces the same AMI. Out of scope here.
