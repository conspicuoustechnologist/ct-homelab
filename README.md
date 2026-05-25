# ct-homelab

Homelab config for a Raspberry Pi 5 running nginx, Pi-hole, and Home Assistant in Docker Compose.

Full walkthrough: [Part 1 — Local Webserver](https://www.conspicuoustechnologist.com/2027/02/homelab-local-webserver/) (all parts at [conspicuoustechnologist.com](https://www.conspicuoustechnologist.com))

## Fresh install

```bash
curl -fsSL https://raw.githubusercontent.com/conspicuoustechnologist/ct-homelab/main/bootstrap.sh | sh
```

Bootstrap will pause and ask you to review `.env` before starting the stack. Set `NO_PROMPT=1` to skip:

```bash
NO_PROMPT=1 bash <(curl -fsSL https://raw.githubusercontent.com/conspicuoustechnologist/ct-homelab/main/bootstrap.sh)
```

To restore a Pi-hole backup automatically:

```bash
PIHOLE_BACKUP=/path/to/pihole-backup.zip bash <(curl -fsSL https://raw.githubusercontent.com/conspicuoustechnologist/ct-homelab/main/bootstrap.sh)
```

## Update

```bash
cd ~/ct-homelab && git pull && docker compose down && docker compose up -d
```

## Configuration

### bootstrap.sh

Bootstrap resolves configuration in this order:

1. **Env vars passed at runtime** — highest priority
2. **Existing `.env`** — if the file already exists, bootstrap reads values from it and skips writing it again
3. **Auto-detected or built-in defaults** — `PI_IP` falls back to `hostname -I`; `MAIN_SITE_IP` defaults to `PI_IP`

Override defaults with env vars at runtime:

```bash
HOMELAB_DIR=~/my-homelab MAIN_SITE_DIR=~/my-sites MAIN_SITE_HOST=mysite.home bash <(curl -fsSL https://raw.githubusercontent.com/conspicuoustechnologist/ct-homelab/main/bootstrap.sh)
```

You can also pass `HOMELAB_DIR` as a positional argument:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/conspicuoustechnologist/ct-homelab/main/bootstrap.sh) ~/homelab
```

### .env

Created automatically by bootstrap on first run. Edit it to change any values — bootstrap will not overwrite it on subsequent runs:

```bash
cp .env.example .env
vi .env
```

```bash
TZ=America/Denver
HOSTNAME=raspberrypi
DOMAIN=ct.home
MAIN_SITE_HOST=conspicuoustechnologist.ct.home

# PI_IP: your Pi's static IP (run: hostname -I)
PI_IP=
# PIHOLE_WEBPASSWORD: admin UI password
PIHOLE_WEBPASSWORD=
PIHOLE_HOST=pihole.ct.home
```

## Manual setup

See the [full walkthrough](https://www.conspicuoustechnologist.com/2027/02/homelab-local-webserver/) for step-by-step instructions.

## Structure

```
ct-homelab/
  bootstrap.sh              # fresh Pi setup — run once
  backup.sh                 # Pi-hole Teleporter backup
  docker-compose.yml        # all services
  .env.example              # copy to .env, fill in your values
  nginx/
    Dockerfile              # FROM nginx:alpine — extend as needed
    templates/              # envsubst config templates
      main-site.conf.template
      pihole.conf.template
```

## Deploying the site

From your dev machine, after building:

```bash
rsync -avz --delete your-output-dir/ $HOSTNAME:$MAIN_SITE_DIR/
```

For a one-command deploy, add this to your dev machine's `.zshrc` — adjust the site path, build command, and output directory for your setup:

```bash
deploy_pi() {
  ( cd /path/to/your/site && \
    your-build-command && \
    rsync -avz --delete your-output-dir/ $HOSTNAME:$MAIN_SITE_DIR/ && \
    ssh $HOSTNAME 'docker restart nginx' )
}
```

Then `source ~/.zshrc` and `deploy_pi` builds, deploys, and restarts nginx in one shot.

Build your site however you build it, then sync the output dir to `$MAIN_SITE_DIR` on the Pi.

**Hugo:** to preview drafts or future-dated posts on the Pi, add `-D --buildFuture` to your build command — Hugo excludes both by default:

```bash
hugo build -D --buildFuture
```
