# Ionworks Agentic Toolkit

Agent-ready skills for battery R&D workflows on the [Ionworks](https://ionworks.com) platform. Give your coding agent the context it needs to ingest cycling data, organize cell characterization, run simulations, and structure research projects — without hand-holding on endpoints, schemas, or conventions.

## What it does

- **7 action-oriented skills** covering the full R&D loop: install, discovery, data processing, upload, cell management, simulations, project structure.
- **Live schema grounding.** Skills direct agents to query `/discovery/capabilities` so field names, enums, and units always match the deployed API — not a static reference that drifts.
- **Plain-Markdown skill files.** Each skill is a single `SKILL.md` with YAML frontmatter. No runtime. Any agent that understands the [SKILL.md convention](https://www.anthropic.com/news/skills) (Claude Code, Anthropic SDK agents, custom frameworks) can load them.
- **Self-contained.** No MCP server required. Skills drive the official [Ionworks Python SDK](https://pypi.org/project/ionworks-api/); all they need is an `IONWORKS_API_KEY`.
- **Optional slash commands** for Claude Code users who want one-shot entry points.

## Supported platforms

| Platform | Install path | Notes |
|---|---|---|
| Claude Code | `/plugin marketplace add ionworks/ionworks-skills` → `/plugin install ionworks` | Native plugin support. SessionStart hook injects a skill index on start. |
| Claude Agent SDK / API | `Skill(path=".../skills/<skill-name>")` or copy SKILL.md files into your agent's skills directory | Works with any Anthropic-SDK agent that implements the Skill tool. |
| Other agent frameworks | Copy the `SKILL.md` files into your agent's context / system prompt | Frontmatter descriptions act as triggers; bodies are general-purpose guidance. |

## Skills

| Skill | What it teaches your agent |
|---|---|
| `install` | Installing the SDK with `uv` / `pip`, getting and configuring `IONWORKS_API_KEY`, verifying the install, upgrading, troubleshooting auth/proxy errors. |
| `discover-api` | Always call `client.capabilities()` and `client.schema(name)` first; live endpoint, schema, and enum discovery so later steps don't guess. |
| `process-data` | Converting raw cycler data (MATLAB, CSV, JSON, vendor exports) into the platform's parquet + JSON hierarchy or the portable BDF format. Cumulative time / step / cycle conventions, sign conventions, Polars + ionworksdata pipelines. |
| `upload-data` | Uploading time-series, file, and properties measurements. When to use each measurement type. |
| `manage-cells` | Creating and querying cell specifications (designs), cell instances (physical cells), and their measurements. Parent/child relationships. |
| `run-simulations` | Running electrochemical simulations with UCP (Universal Cycling Protocol), design-of-experiments sweeps, and retrieving results. |
| `manage-projects` | Organizing work across projects, studies, models, parameterized models, and optimizations. |

## Slash commands (Claude Code only)

- `/ionworks:discover` — print a read-only summary of the connected platform
- `/ionworks:upload <path>` — guided measurement upload

## Quick start

**Prerequisites:** Python 3.12+, an Ionworks account ([sign up](https://app.ionworks.com)), and an API key from [Account Settings](https://app.ionworks.com/dashboard/account).

1. Install the toolkit for your agent (see table above).
2. Install the SDK in the Python environment your agent will run code in:
   ```
   uv add ionworks-api    # or: pip install ionworks-api
   ```
3. Export your key:
   ```
   export IONWORKS_API_KEY="iwk_..."
   ```
4. Ask your agent something like *"Use the ionworks install skill to verify my setup"* — it will invoke `install`, then `discover-api`, and confirm the connection.

The `install` skill walks through the full onboarding, including optional `.env` handling and the `ionworkspipeline` licensed package.

## Repository layout

```
.
├── .claude-plugin/         # Claude Code plugin manifest + marketplace entry
├── commands/               # Claude Code slash commands (.md)
├── discover-api/SKILL.md
├── install/SKILL.md
├── manage-cells/SKILL.md
├── manage-projects/SKILL.md
├── process-data/SKILL.md
├── run-simulations/SKILL.md
├── upload-data/SKILL.md
├── hooks/                  # Claude Code SessionStart hook (optional)
└── LICENSE
```

Each `SKILL.md` is fully self-contained — you can read or copy one without pulling the rest.

## Model capability

The skills assume the agent can read Markdown, follow multi-step procedures, call a Python SDK, and handle JSON/parquet data. They've been authored and tested against Claude Sonnet / Opus and should work with any comparable frontier model. Smaller local models may struggle with the multi-step data-processing workflows in `process-data` and `run-simulations`.

## Requirements

- Python 3.12+ in the environment the agent will execute code
- [`ionworks-api`](https://pypi.org/project/ionworks-api/) — the Python SDK (required)
- Optional: [`ionworksdata`](https://pypi.org/project/ionworksdata/) for `process-data` workflows
- Optional: `ionworkspipeline` for `run-pipelines`-style parameterization (licensed — contact Ionworks)

## Source

This toolkit is maintained in an internal repo and mirrored here on every release. Open issues here for bugs and requests; maintainers propagate fixes upstream.

## License

MIT — see [LICENSE](./LICENSE).
