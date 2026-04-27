---
name: manage-cells
description: >-
  Work with battery cell data: specifications, instances,
  and measurements. Use when creating, reading, updating,
  or deleting cell specs, instances, or measurements, or
  when fetching time series, steps, or cycles data.
  Triggers: "cell spec", "cell instance", "measurement",
  "time series", "steps", "cycles", "battery data",
  "cell data".
---

# Cell Data

Guide for working with the cell data hierarchy:
cell specifications, cell instances, and cell
measurements (including time series, steps, and cycles).

## Prerequisites

Always run the **discover-api** skill first to fetch
capabilities and the data schema.

## Data Hierarchy

```
cell_specification (blueprint: chemistry, form factor, ratings, components)
  -> cell_instance (physical cell: serial number, batch, manufacturing date)
    -> cell_measurement (test result: time_series | file | properties)
      -> time_series (high-res voltage/current/time data)
      -> steps (per-step summary: duration, capacity, voltage stats)
      -> cycles (per-cycle metrics: capacity, efficiency, energy)
```

## Cell Specifications

A cell specification defines a cell type: chemistry,
form factor, rated capacity, voltage limits, and
component materials.

```python
from ionworks import Ionworks

client = Ionworks()

# List with filtering
specs = client.cell_spec.list(
    name="LGM50",              # case-insensitive substring
    form_factor="cylindrical",
    order_by="created_at",
    order="desc",
    limit=10,
)

# List with nested components inlined
specs = client.cell_spec.list(include_components=True)

# Get by ID
spec = client.cell_spec.get("spec-id")

# Create (include components/materials for full definition)
spec = client.cell_spec.create({
    "name": "LGM50 Demo",
    "form_factor": "cylindrical",
    "rated_capacity": {"value": 5.0, "unit": "A.h"},
    "voltage_range_dc": {"min": 2.5, "max": 4.2, "unit": "V"},
    "components": [
        {
            "component_type": "positive_electrode",
            "materials": [{"name": "NMC811", "is_active": True}],
        }
    ],
})

# Create-or-get (idempotent by name)
spec = client.cell_spec.create_or_get({"name": "LGM50 Demo"})

# Update (partial)
spec = client.cell_spec.update("spec-id", {"form_factor": "pouch"})

# Delete
client.cell_spec.delete("spec-id")
```

## Cell Instances

A cell instance is a specific physical cell built from
a specification.

```python
# List instances for a spec
instances = client.cell_instance.list(
    "spec-id",
    name="SN-001",
    order_by="name",
    order="asc",
)

# Get by ID
instance = client.cell_instance.get("instance-id")

# Create under a spec
instance = client.cell_instance.create("spec-id", {
    "name": "SN-001",
    "batch": "2025-Q1",
    "manufacturing_date": "2025-03-15",
})

# Create-or-get
instance = client.cell_instance.create_or_get("spec-id", {
    "name": "SN-001",
})

# Get full detail (instance + all measurements with data)
detail = client.cell_instance.detail(
    "instance-id",
    include_steps=True,
    include_cycles=True,
    include_time_series=True,
)
# detail.instance, detail.specification_id, detail.measurements
```

## Cell Measurements

A measurement is a test performed on a cell instance.
Three types: `time_series`, `file`, `properties`.

```python
# List measurements for an instance
measurements = client.cell_measurement.list(
    "instance-id",
    measurement_type="time_series",   # filter by type
    name="discharge_1C",
    order_by="created_at",
    order="desc",
)

# Get metadata
meas = client.cell_measurement.get("measurement-id")
# meas.id, meas.name, meas.measurement_type, meas.cell_instance_id

# Get full detail (adapts to measurement type automatically)
detail = client.cell_measurement.detail("measurement-id")
# detail.time_series  -> Polars DataFrame (if time_series type)
# detail.steps        -> Polars DataFrame
# detail.cycles       -> Polars DataFrame
# detail.files        -> dict[str, bytes] (if file type)
```

## Fetching Tabular Data

For time_series measurements, fetch data individually:

```python
# Individual endpoints (each returns a Polars DataFrame)
ts = client.cell_measurement.time_series("measurement-id")
steps = client.cell_measurement.steps("measurement-id")
cycles = client.cell_measurement.cycles("measurement-id")

# Combined (more efficient than separate calls)
sc = client.cell_measurement.steps_and_cycles("measurement-id")
# sc.steps, sc.cycles

# Caching: data is cached locally by default
# Pass use_cache=False to force a fresh fetch
ts = client.cell_measurement.time_series("measurement-id", use_cache=False)
```

### Time Series Columns

Standard columns (from `client.schema("data")`):
- `Time [s]` (required)
- `Current [A]` (required)
- `Voltage [V]` (required)
- `Step count` (required)
- `Cycle count`, `Charge capacity [A.h]`,
  `Discharge capacity [A.h]`, `Charge energy [W.h]`,
  `Discharge energy [W.h]`, `Power [W]`,
  `Temperature [degC]` (optional)

Additional columns are preserved as-is.

## File Measurements

```python
# List files in a measurement
filenames = client.cell_measurement.list_files("measurement-id")

# Download all files (cached)
files = client.cell_measurement.download_files("measurement-id")
# files = {"image1.png": b"...", "data.csv": b"..."}

# Download specific files only (faster, skips listing)
files = client.cell_measurement.download_files(
    "measurement-id",
    filenames=["image1.png"],
)

# Get single file
data = client.cell_measurement.get_file("measurement-id", "image1.png")
```

## DataFrame Backend

By default, all tabular data is returned as Polars
DataFrames. Switch to pandas:

```python
from ionworks import set_dataframe_backend
set_dataframe_backend("pandas")
```

Or set `IONWORKS_DATAFRAME_BACKEND=pandas` in the env.

## Navigating the Hierarchy by Name

```python
client = Ionworks()

# Find a specific measurement by walking the hierarchy
specs = client.cell_spec.list(name_exact="LGM50 Demo")
spec = specs[0]
instances = client.cell_instance.list(spec.id, name_exact="SN-001")
inst = instances[0]
measurements = client.cell_measurement.list(
    inst.id, name_exact="rate_capability_2C"
)
meas = measurements[0]
ts = client.cell_measurement.time_series(meas.id)
```
