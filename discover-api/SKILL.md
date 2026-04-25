---
name: discover-api
description: >-
  Query the Ionworks API /discovery endpoints before any
  API operation. Use when the user asks to interact with
  the Ionworks API, battery data, cell specifications,
  measurements, simulations, pipelines, or UCP protocols.
  Triggers: "ionworks", "battery data", "cell spec",
  "measurement", "simulation", "pipeline", "UCP", "cycler",
  "SDK", "Python client".
---

# Ionworks API Discovery

Before making any request to the Ionworks API, fetch
`GET /discovery/capabilities` to load domain context,
auth requirements, and schema references. This avoids
guessing at endpoints or data shapes.

## When to Use

Use this skill when the user:
- Asks to read, create, or modify battery data
- Wants to run a simulation or work with UCP protocols
- Mentions cell specifications, instances, or measurements
- Needs to explore what the Ionworks API offers
- Asks about data hierarchy or schema
- Wants to run a pipeline or parameterization

Do NOT use this skill for:
- Frontend-only changes with no API calls
- Infrastructure or deployment tasks unrelated to the API

## Step 1: Fetch Capabilities, Then the Relevant Schema (MANDATORY)

**You MUST do this before any other API call.** Do NOT
skip this step. Do NOT guess at data shapes, column
names, metadata fields, or entity structures — they are
all defined in these responses.

```python
from ionworks import Ionworks

client = Ionworks()  # reads IONWORKS_API_KEY from env
caps = client.capabilities()
```

`caps` returns the data hierarchy, what each entity
contains (`domain_context.key_concepts`), auth
requirements, and which schemas are available
(`schemas` key). Then fetch whichever schema is
relevant to the user's query:

```python
# Cell data hierarchy (specs, instances, measurements,
# columns, metadata):
schema = client.schema("data")

# Universal Cycler Protocol (UCP) for simulations:
schema = client.schema("protocol")

# Per-resource request/response shapes:
schema = client.schema("project")
schema = client.schema("study")
schema = client.schema("model")
schema = client.schema("parameterized_model")
schema = client.schema("optimization")
schema = client.schema("pipeline")
```

Each per-resource schema includes `create_schema`,
`update_schema`, and `response_schema` (where
applicable), plus extras like `mapping_endpoints` (for
study) or `element_types` (for pipeline). Read `caps`
and the relevant schema response before writing any
query or analysis code.

## Step 2: Use the Python Client

Prefer the `ionworks` Python client over raw HTTP. It
handles auth, retries, signed-URL uploads, pagination,
and parallel fetching automatically. Tabular data
(time_series, steps, cycles) is returned as **Polars
DataFrames** by default.

```python
from ionworks import Ionworks

client = Ionworks()
```

### Sub-clients

| Sub-client | Methods |
|---|---|
| `client.project` | `.list()`, `.get(project_id)`, `.create(data)`, `.update(project_id, data)`, `.delete(project_id)` |
| `client.model` | `.list()`, `.get(model_id)`, `.create(data)`, `.update(model_id, data)`, `.delete(model_id)`, `.add_custom_variable(model_id, data)` |
| `client.parameterized_model` | `.list(cell_spec_id)`, `.get(id)`, `.create(cell_spec_id, data)`, `.update(cell_spec_id, pm_id, data)`, `.get_parameter_values(id)`, `.get_variable_names(id)` |
| `client.study` | `.list(project_id)`, `.get(project_id, study_id)`, `.create(project_id, data)`, `.update(...)`, `.delete(...)`, `.assign_simulation(...)`, `.remove_simulation(...)`, `.assign_measurement(...)`, `.list_measurements(...)`, `.remove_measurement(...)` |
| `client.cell_spec` | `.list()`, `.get(id)`, `.create(data)`, `.create_or_get(data)`, `.update(id, data)`, `.delete(id)` |
| `client.cell_instance` | `.list(spec_id)`, `.get(id)`, `.create(spec_id, data)`, `.create_or_get(spec_id, data)`, `.update(id, data)`, `.delete(id)`, `.detail(id)` |
| `client.cell_measurement` | `.list(instance_id)`, `.get(id)`, `.detail(id)`, `.steps(id)`, `.cycles(id)`, `.steps_and_cycles(id)`, `.time_series(id)`, `.create(instance_id, data)`, `.create_or_get(instance_id, data)`, `.create_properties(instance_id, name, properties)`, `.create_file(instance_id, name, filepaths)`, `.update(id, data)`, `.delete(id)`, `.list_files(id)`, `.download_files(id)`, `.get_file(id, filename)` |
| `client.simulation` | `.protocol(config)`, `.protocol_batch(config)`, `.list(parameterized_model_id=, study_id=)`, `.get(id)`, `.get_result(id)`, `.wait_for_completion(id)` |
| `client.pipeline` | `.create(config)`, `.list(project_id=, limit=)`, `.get(id)`, `.result(id)`, `.wait_for_completion(id)` |
| `client.optimization` | `.run(data)`, `.get(id)`, `.list(project_id=)`, `.update(id, data)`, `.cancel(id)`, `.wait_for_completion(id)` |
| `client.protocol` | `.validate(protocol_yaml)`, `.find_input_references(protocol_yaml)` |
| `client.job` | `.create(payload)`, `.get(id)`, `.list()`, `.cancel(id)` |
| `client` (direct) | `.capabilities()`, `.schema(name)` where name is `"data"`, `"protocol"`, `"project"`, `"study"`, `"model"`, `"parameterized_model"`, `"optimization"`, or `"pipeline"`, `.health_check()` |

### Direct HTTP fallback

When the client doesn't cover an endpoint:

```python
data = client.get("/some/endpoint")
data = client.post("/some/endpoint", {"key": "value"})
client.patch("/some/endpoint", {"key": "value"})
client.delete("/some/endpoint")
```

## Step 3: Use the Responses — Do Not Guess

Use column names, field names, and entity structures
**from the responses you already fetched** — do not
hardcode or guess them.

## Step 4: Navigate the Data Hierarchy

```
organization
  -> project
    -> cell_specification
      -> cell_instance
        -> cell_measurement
          -> [time_series, steps, cycles]
      -> parameterized_model
    -> study
      -> simulation_mappings
      -> measurement_mappings
```

## Pagination

All `list()` methods on cell_spec, cell_instance, and
cell_measurement return a `PaginatedList` with `.items`,
`.count`, and `.total`. `PaginatedList` behaves like a
regular `list` (iteration, indexing, `len`, truthiness),
so existing code that treats the return value as a list
keeps working.

```python
specs = client.cell_spec.list()
for spec in specs:
    print(spec.name)

page = client.cell_spec.list(limit=10, offset=0)
page.total   # total matching records across all pages
page.count   # number of items in this page
```

## Filtering and Ordering

Cell specs, instances, and measurements support
keyword-only filter parameters:

```python
specs = client.cell_spec.list(
    name="LGM50",              # case-insensitive substring match
    name_exact="LGM50 Demo",   # exact match (precedence over name)
    form_factor="cylindrical",
    created_by_email="user@",
    created_after="2025-01-01",
    order_by="name",           # name, created_at, updated_at
    order="asc",               # asc or desc
)
```

Common filter parameters across cell list methods:
- `name` — case-insensitive substring match
- `name_exact` — exact match
- `created_by_email` — substring match on creator email
- `created_after` / `created_before` — date range
- `updated_after` / `updated_before` — date range
- `order_by` — sort column
- `order` — `"asc"` or `"desc"`

## Create-or-Get

Cell specs, instances, and measurements support
`create_or_get()` directly. If a resource with the
same name already exists, the existing one is returned
in a single round-trip:

```python
spec = client.cell_spec.create_or_get({"name": "LGM50"})
# Returns existing spec if "LGM50" already exists
```

For projects, studies, models, and parameterized models,
`create_or_get` is not yet available on the SDK. Use the
duplicate-error fallback pattern instead:

```python
from ionworks import IonworksError

def create_or_get_project(client, data):
    try:
        return client.project.create(data)
    except IonworksError as e:
        if e.error_code == "CONFLICT" and e.data:
            existing_id = e.data.get("detail", {}).get("existing_id")
            if existing_id:
                return client.project.get(existing_id)
        raise
```

The backend includes `existing_id` in the error detail
on duplicates for projects, studies, models, and
parameterized models, so the fallback is reliable.

## Related Skills

- **manage-cells** — detailed guide for cell specs, instances, measurements
- **upload-data** — measurement upload flows (time series, files, properties)
- **run-simulations** — running simulations with UCP protocols
- **manage-projects** — project, study, model, and optimization management
