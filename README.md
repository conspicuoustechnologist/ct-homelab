# ct-homelab

Homelab config for a Raspberry Pi 5 running nginx, Pi-hole, and Home Assistant in Docker Compose.

Full walkthrough: [conspicuoustechnologist.com](https://www.conspicuoustechnologist.com)

## Fresh install

```bash
curl -fsSL https://raw.githubusercontent.com/conspicuoustechnologist/ct-homelab/main/bootstrap.sh | sh
```

Then:

```bash
nano ~/ct-homelab/.env      # fill in your values
cd ~/ct-homelab
docker compose up -d
```

## Manual setup

See the blog post for the full step-by-step walkthrough.

## Structure

```
ct-homelab/
  bootstrap.sh              # fresh Pi setup — run once
  docker-compose.yml        # all services
  .env.example              # copy to .env, fill in your values
  nginx/
    Dockerfile              # FROM nginx:alpine — extend as needed
    templates/              # envsubst config templates
      ct-site.conf.template
```

## Deploying the site

From your dev machine, after building:

```bash
rsync -avz --delete public/ malphas:~/sites/ct-site/
```
