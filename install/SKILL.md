---
name: install
description: >-
  Install and configure the Ionworks Python SDK: pick the right
  package, set the API key, verify the install, and keep it up
  to date. Use when the user wants to install ionworks, set up
  the SDK for the first time, configure API credentials, check
  the installed version, or upgrade. Triggers: "install
  ionworks", "set up SDK", "API key", "IONWORKS_API_KEY",
  "upgrade ionworks", "pip install ionworks", "uv add ionworks",
  "getting started".
---

# Ionworks SDK Install

Use this skill to walk the user through installing the Ionworks Python SDK, configuring credentials, and verifying the setup. Prefer `uv` over bare `pip` — modern Python projects should pin dependencies in `pyproject.toml` and use a lockfile.

## When to Use

- User is installing Ionworks for the first time
- User asks about `IONWORKS_API_KEY`
- User hits an authentication error calling the Ionworks API
- User wants to check which version is installed
- User wants to upgrade to the latest release

## Packages

Most users only need **`ionworks-api`** — the high-level Python client. The other packages are usually transitive dependencies, but you can install them directly if you only need a subset.

| Package | PyPI | When to install |
|---|---|---|
| `ionworks-api` | [link](https://pypi.org/project/ionworks-api/) | Default — high-level client for the Ionworks API |
| `ionworks-schema` | [link](https://pypi.org/project/ionworks-schema/) | Pydantic schemas only (no HTTP client) |
| `ionworksdata` | [link](https://pypi.org/project/ionworksdata/) | Battery data processing (parquet/JSON standardization) |
| `iwutil` | [link](https://pypi.org/project/iwutil/) | Shared utilities only |

The `ionworkspipeline` package is **licensed** (not public on PyPI) and requires a separate license key — skip unless the user has explicitly asked to parameterize models.

## Install

### With `uv` (recommended)

```bash
uv add ionworks-api
```

Or, for a one-off script without a project:

```bash
uv pip install ionworks-api
```

### With `pip`

```bash
pip install ionworks-api
```

### Python version

The SDK targets Python 3.12+. Older versions may work but are not tested.

## Configure credentials

The SDK reads one environment variable:

| Variable | Required | Where to get it |
|---|---|---|
| `IONWORKS_API_KEY` | Yes | [app.ionworks.com → Account Settings](https://app.ionworks.com/dashboard/account) |

### Getting an API key

1. Sign in at [app.ionworks.com](https://app.ionworks.com)
2. Go to **Account Settings** (top-right avatar menu, or the [direct link](https://app.ionworks.com/dashboard/account))
3. Under **API Keys**, click **Create API key**
4. Copy the key immediately — it is only shown once
5. Store it somewhere safe (password manager, `.env` file that is gitignored, or a secrets vault)

**Never commit the API key to a repo.** Add `.env` to `.gitignore` if it isn't already.

### Setting the environment variable

Shell session (temporary):

```bash
export IONWORKS_API_KEY="iwk_..."
```

Shell config (persistent — add to `~/.zshrc` or `~/.bashrc`):

```bash
export IONWORKS_API_KEY="iwk_..."
```

Project `.env` file (recommended for apps):

```
IONWORKS_API_KEY=iwk_...
```

Then load it with `python-dotenv` or your framework's env loader. The SDK itself does **not** auto-load `.env`.

## Verify the install

```python
from ionworks import Ionworks

client = Ionworks()
caps = client.capabilities()
print(caps.version)
```

If this runs without error and prints a version string, the install and credentials are working. A `401` or `403` means the API key is missing, wrong, or expired. A connection error with the default URL usually means the user is behind a corporate proxy or the API URL needs to be overridden.

## Check installed version

```bash
uv pip show ionworks-api      # or: pip show ionworks-api
```

Or from Python:

```python
from importlib.metadata import version
print(version("ionworks-api"))
```

Compare against the latest published version:

```bash
uv pip install --upgrade ionworks-api --dry-run
```

Or check PyPI directly: https://pypi.org/project/ionworks-api/

## Upgrade

```bash
uv add ionworks-api@latest       # uv project
uv pip install -U ionworks-api   # standalone
pip install -U ionworks-api      # pip
```

After upgrading, re-run `client.capabilities()` — the `discover-api` skill's reference files may be stale relative to a newer SDK. If endpoints look unfamiliar, invoke `discover-api` to refresh context.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `AuthenticationError` / 401 | `IONWORKS_API_KEY` not set, or points to a revoked/wrong-env key |
| `403 Forbidden` | Key is valid but lacks permission for the requested resource — check org/project scope |
| `ConnectionError` to `api.ionworks.com` | Corporate proxy, VPN, or outage — test with `curl https://api.ionworks.com/healthz` |
| `ModuleNotFoundError: ionworks` | Install wrong package name; it's `ionworks-api` (PyPI) but `from ionworks import ...` (module) |

## What not to do

- Do not install `ionworkspipeline` unless the user has a license key — it will fail at import time.
- Do not hardcode the API key in source files or Jupyter notebooks that might be shared.
- Do not pin to an old major version without reason — the SDK is pre-1.0 and improvements ship frequently.
