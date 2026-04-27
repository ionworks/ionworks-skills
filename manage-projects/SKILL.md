---
name: manage-projects
description: >-
  Manage projects, studies, models, parameterized models,
  and optimizations. Use when the user wants to create or
  manage projects, organize simulations into studies,
  work with custom or parameterized models, or run
  optimizations. Triggers: "project", "study", "model",
  "parameterized model", "optimization", "custom model".
---

# Projects and Studies

Guide for managing projects, studies, models,
parameterized models, and optimizations.

## Prerequisites

Run the **discover-api** skill first.

## Idempotent create (create-or-get pattern)

Projects, studies, models, and parameterized models do
NOT have a `create_or_get()` method on the SDK. To get
the same idempotent behavior, catch the `CONFLICT` error
on `create()` and read `existing_id` from the error
detail (the backend includes it on duplicate errors):

```python
from ionworks import IonworksError

def _get_or_create(create_fn, get_fn, *args, **kwargs):
    try:
        return create_fn(*args, **kwargs)
    except IonworksError as e:
        if e.error_code == "CONFLICT" and e.data:
            existing_id = e.data.get("detail", {}).get("existing_id")
            if existing_id:
                return get_fn(existing_id)
        raise

# Example: project
project = _get_or_create(
    client.project.create,
    client.project.get,
    {"name": "NMC Characterization"},
)
```

The same pattern works for `client.study.create` /
`.get`, `client.model.create` / `.get`, and
`client.parameterized_model.create` / `.get` (the get
signatures vary — see each section below).

## Projects

Projects group cell specifications and studies within
an organization.

```python
from ionworks import Ionworks

client = Ionworks()

# List projects (with optional filters)
projects = client.project.list(
    name="Battery",            # case-insensitive substring
    order_by="created_at",
    order="desc",
)

# Get by ID
project = client.project.get("project-id")

# Create
project = client.project.create({
    "name": "NMC Characterization",
    "description": "Q1 2025 NMC cell testing",
})

# Update (partial)
project = client.project.update(
    "project-id",
    {"description": "Updated description"},
)

# Delete
client.project.delete("project-id")
```

## Studies

Studies group simulations and measurements within a
project for comparison and analysis.

```python
# List studies for a project (with filtering)
studies = client.study.list(
    "project-id",
    name="Discharge",
    order_by="name",
    order="asc",
)

# Get
study = client.study.get("project-id", "study-id")

# Create
study = client.study.create(
    "project-id",
    {"name": "1C Discharge Study", "description": "..."},
)

# Update
study = client.study.update(
    "project-id",
    "study-id",
    {"description": "Updated"},
)

# Delete
client.study.delete("project-id", "study-id")
```

### Study Mappings

Assign simulations and measurements to studies:

```python
# Assign a simulation to a study (idempotent)
client.study.assign_simulation(
    "project-id",
    "study-id",
    "sim-id",
)

# Remove a simulation from a study
client.study.remove_simulation(
    "project-id",
    "study-id",
    "sim-id",
)

# Assign a measurement
client.study.assign_measurement(
    "project-id",
    "study-id",
    "meas-id",
)

# List measurements in a study (paginated)
result = client.study.list_measurements(
    "project-id",
    "study-id",
    limit=50,
    offset=0,
)

# Remove a measurement
client.study.remove_measurement(
    "project-id",
    "study-id",
    "meas-id",
)
```

## Custom Models

Models define the electrochemical model structure
(before parameterization).

```python
# List models (with filtering)
models = client.model.list(
    name="SPM",
    order_by="name",
)

# Get
model = client.model.get("model-id")

# Create
model = client.model.create({
    "name": "Custom SPM",
    "description": "Single Particle Model with SEI",
})

# Add a custom variable to a model
model = client.model.add_custom_variable(
    "model-id",
    {"name": "Custom diffusivity", "domain": "negative electrode"},
)

# Update
model = client.model.update("model-id", {"description": "..."})

# Delete
client.model.delete("model-id")
```

## Parameterized Models

A parameterized model combines a model with specific
parameter values, attached to a cell specification.

```python
# List parameterized models for a cell spec
pms = client.parameterized_model.list("cell-spec-id")

# Get by ID
pm = client.parameterized_model.get("pm-id")

# Create
pm = client.parameterized_model.create("cell-spec-id", {
    "name": "LGM50 Chen2020",
    "description": "Chen2020 parameters for LGM50",
    "model_id": "model-id",
    "parameters": { ... },
})

# Update (cell_spec_id, pm_id, data) — name and description only
pm = client.parameterized_model.update(
    "cell-spec-id", "pm-id", {"name": "Renamed"},
)

# Get parameter values (flat dict, excludes version/citations)
params = client.parameterized_model.get_parameter_values("pm-id")

# Get variable names (scalar variables only)
var_names = client.parameterized_model.get_variable_names("pm-id")
```

## Optimizations

Run design optimization on parameterized models:

```python
# Submit optimization
opt = client.optimization.run({
    "name": "fast charge optimization",
    "project_id": "project-id",
    "parameterized_model_id": "pm-id",
    # plus type-specific config (objective, design_variables, protocol, ...)
})
# opt.id, opt.name, opt.job_id, opt.project_id

# Wait for completion
result = client.optimization.wait_for_completion(
    opt.id,
    timeout=600,
    poll_interval=3,
    verbose=True,
)

# List optimizations
opts = client.optimization.list(project_id="project-id")

# Get details (returns dict with status + job info)
opt_detail = client.optimization.get("optimization-id")

# Update
client.optimization.update("optimization-id", {"name": "Renamed"})

# Cancel
client.optimization.cancel("optimization-id")
```
