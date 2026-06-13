# BKit documentation

Central documentation portal for the BKit ecosystem: composable Go libraries
for configuration, data storage, object storage, authorization, observability,
and service lifecycle management.

## Run with Docker Compose

Build and start the documentation server:

```bash
docker compose up --build
```

Open <http://127.0.0.1:8000/bkit-docs/>. Changes under `docs/` or to
`mkdocs.yml` reload automatically.

Stop and remove the container and Compose network:

```bash
docker compose down
```

Run in the background with `docker compose up --build --detach`. View logs
with `docker compose logs --follow docs`.

## Run with Python

Python 3.9 or newer is recommended.

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
mkdocs serve
```

Open <http://127.0.0.1:8000/bkit-docs/>.

## Build

```bash
mkdocs build --strict
```

The static site is written to `site/`.

## Deployment

The workflow in `.github/workflows/pages.yml` builds and publishes the site
when changes are pushed or merged to `main`. In the repository's GitHub Pages
settings, set **Source** to **GitHub Actions** once before the first deployment.

The workflow can also be started manually from the Actions tab. For another
static host, run `mkdocs build --strict` and publish the generated `site/`
directory.

## Source libraries

- [bconfig](https://github.com/brian-nunez/bconfig)
- [bkv](https://github.com/brian-nunez/bkv)
- [bdb](https://github.com/brian-nunez/bdb)
- [objex](https://github.com/brian-nunez/objex)
- [baccess](https://github.com/brian-nunez/baccess)
- [bhttp](https://github.com/brian-nunez/bhttp)
