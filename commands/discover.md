---
description: Fetch Ionworks API capabilities and print a short summary of the available domains and endpoints.
---

Invoke the `ionworks:discover-api` skill, then call `GET /discovery/capabilities` against the configured Ionworks API. Summarize:

- Authentication method in use
- Available sub-clients (cells, measurements, simulations, pipelines, projects)
- Any endpoints that have changed shape since the skill reference files were last updated

Do not make any write calls. This command is read-only.
