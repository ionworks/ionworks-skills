#!/usr/bin/env bash
# SessionStart hook for the Ionworks Claude Code plugin.
# Emits a short context banner so Claude knows the SDK skills are available
# and points at the canonical discovery endpoint.

set -euo pipefail

cat <<'EOF'
# Ionworks Plugin

The `ionworks` plugin is active — skills for battery R&D workflows:
ingesting cycling data, organizing cell characterization, and running
simulations.

Skills available via the Skill tool:

- `ionworks:install` — set up the SDK, configure credentials, upgrade, troubleshoot
- `ionworks:discover-api` — always call this first to ground in current platform capabilities
- `ionworks:process-data` — convert raw cycling data into the standard parquet/JSON or BDF format
- `ionworks:upload-data` — bring experimental measurement data into the platform
- `ionworks:manage-cells` — organize cell designs, instances, and their measurements
- `ionworks:run-simulations` — run electrochemical simulations and DOE sweeps
- `ionworks:manage-projects` — structure R&D work across projects and studies

Before any platform operation, invoke `ionworks:discover-api` to load
current capabilities. Do not guess at endpoints or schemas from memory —
the platform evolves.
EOF
