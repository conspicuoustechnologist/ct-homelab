# ct-homelab

Homelab config for a Raspberry Pi 5 running nginx and Pi-hole in Docker Compose, with Claude Code as a persistent SSH-accessible dev environment.

Full walkthrough: [Part 1 — Local Webserver](https://www.conspicuoustechnologist.com/2027/02/homelab-local-webserver/) (all parts at [conspicuoustechnologist.com](https://www.conspicuoustechnologist.com))

## Fresh install

```bash
curl -fsSL https://raw.githubusercontent.com/conspicuoustechnologist/ct-homelab/main/bootstrap.sh | sh
```

Bootstrap will pause and ask you to review `.env` before starting the stack. Set `NO_PROMPT=1` to skip:

```bash
NO_PROMPT=1 bash <(curl -fsSL https://raw.githubusercontent.com/conspicuoustechnologist/ct-homelab/main/bootstrap.sh)
```

## Managing sites

Add a new site (prompts for any missing values):

```bash
bash ~/ct-homelab/add-site.sh [name] [host] [dir]
```

Creates the nginx config template, updates `docker-compose.yml` and `.env`, creates the content directory, adds a Pi-hole DNS record, and optionally clones a git repository into the site directory. Run `docker compose up -d --build` after to apply.

Remove a site:

```bash
bash ~/ct-homelab/remove-site.sh [name]
```

Removes config, `.env` vars, and the Pi-hole DNS record. Prompts separately before removing site file content.

## Backup

```bash
bash ~/ct-homelab/backup.sh
```

Saves a timestamped Pi-hole Teleporter zip and a copy of `.env` to `BACKUP_DIR` (default: `~/ct-homelab/backups/`). Keeps the last 5 Pi-hole zips. Move backups off the Pi — if the Pi dies, the backup directory goes with it.

Override the backup location:

```bash
BACKUP_DIR=/mnt/nas/backups bash ~/ct-homelab/backup.sh
```

## Restore

After bootstrap, run the restore scripts to bring back your configuration:

```bash
bash ~/ct-homelab/restore_all.sh
```

Runs in order: `.env` first (other scripts depend on it), then Pi-hole, then Claude config.

Or run them individually:

```bash
bash ~/ct-homelab/restore_env.sh      # .env + recreate site content directories
bash ~/ct-homelab/restore_pihole.sh   # Pi-hole Teleporter backup
bash ~/ct-homelab/restore_claude.sh   # Claude config from GitHub
```

`restore_env.sh` reads `BACKUP_DIR` from the environment (default: `~/ct-homelab/backups/`) — set it if your backup is in a non-default location. Both pihole and claude scripts prompt interactively.

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
  bootstrap.sh              # fresh Pi setup -- run once
  add-site.sh               # add a new site to the stack
  remove-site.sh            # remove a site from the stack
  backup.sh                 # Pi-hole backup + .env backup
  restore_all.sh            # restore everything (runs all three below)
  restore_env.sh            # restore .env + recreate site directories
  restore_pihole.sh         # restore Pi-hole from Teleporter backup
  restore_claude.sh         # restore ~/.claude config from GitHub
  docker-compose.yml        # all services
  .env.example              # copy to .env, fill in your values
  nginx/
    Dockerfile              # FROM nginx:alpine -- extend as needed
    templates/              # envsubst config templates (one per site)
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
