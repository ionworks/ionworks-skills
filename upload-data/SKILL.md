---
name: upload-data
description: >-
  Upload battery measurement data: time series, files,
  and properties. Use when the user wants to upload
  cycling data, parquet files, images, CSV data, or
  measurement properties to the Ionworks API.
  Triggers: "upload", "import data", "upload measurement",
  "upload time series", "upload file", "upload parquet",
  "create measurement".
---

# Data Upload

Guide for uploading measurement data to the Ionworks
platform. Three measurement types: time_series, file,
and properties.

## Prerequisites

1. Run the **discover-api** skill first
2. Fetch the data schema: `client.schema("data")`
3. You need a cell instance ID (see **manage-cells** skill)

## Time Series Upload

The most common upload: cycling data with voltage,
current, and time columns. Uses a signed-URL flow
internally (the client handles this automatically).

```python
import polars as pl
from ionworks import Ionworks

client = Ionworks()

# Prepare a DataFrame with required columns
df = pl.DataFrame({
    "Time [s]": [0.0, 1.0, 2.0, 3.0],
    "Current [A]": [1.0, 1.0, -1.0, -1.0],
    "Voltage [V]": [3.8, 3.9, 3.7, 3.6],
    "Step count": [0, 0, 1, 1],
})

# Upload
result = client.cell_measurement.create(
    "instance-id",
    {
        "measurement": {
            "name": "discharge_1C",
            "notes": "1C discharge at 25°C",
            "protocol": {"name": "1C discharge"},
            "start_time": "2025-03-15T10:00:00Z",
            "test_setup": {"temperature": "25°C"},
        },
        "time_series": df,       # Polars or Pandas DataFrame, or dict
        "steps": None,           # auto-calculated if None
    },
)
# result.id, result.name, result.steps_created
```

### Required Columns

- `Time [s]` — elapsed time (must start at 0, monotonically increasing)
- `Current [A]` — current (positive = discharge by convention)
- `Voltage [V]` — voltage
- `Step count` — monotonically increasing step index

### Optional Columns

- `Cycle count` — cycle index
- `Charge capacity [A.h]`, `Discharge capacity [A.h]`
- `Charge energy [W.h]`, `Discharge energy [W.h]`
- `Power [W]`, `Temperature [degC]`
- Any additional numeric columns are preserved

### Validation

The client validates data before upload:
- Positive current = discharge (sign convention)
- Cumulative values (capacity, energy) reset at step boundaries
- Time starts at zero and is monotonic
- Step count is sequential

Use `validate_strict=True` for stricter checks:

```python
result = client.cell_measurement.create(
    "instance-id",
    measurement_detail,
    validate_strict=True,
)
```

### Create-or-Get for Time Series

Idempotent upload — returns existing measurement if
name already exists under the instance:

```python
result = client.cell_measurement.create_or_get(
    "instance-id",
    measurement_detail,
)
# Returns existing measurement (200) or creates new (201)
```

## File Upload

Upload files (images, CSVs, arbitrary files) as a
file-type measurement:

```python
result = client.cell_measurement.create_file(
    "instance-id",
    name="SEM images",
    filepaths=["/path/to/image1.png", "/path/to/image2.jpg"],
    notes="SEM images at 5000x magnification",
    protocol={"name": "SEM imaging"},
    start_time="2025-03-15T14:00:00Z",
    test_setup={"magnification": "5000x"},
)
# result.id, result.name

# Optional: validate image files have correct magic bytes
result = client.cell_measurement.create_file(
    "instance-id",
    name="validated images",
    filepaths=["/path/to/image.png"],
    validate_images=True,
)
```

Supported image formats (when `validate_images=True`):
jpg, jpeg, png, gif, webp, tiff, bmp.

Files are uploaded in parallel via signed URLs.

## Properties Upload

Upload structured key-value properties (no binary data):

```python
meas = client.cell_measurement.create_properties(
    "instance-id",
    name="impedance_25C",
    properties={
        "R0": {"value": 0.015, "unit": "Ohm"},
        "thickness": {"value": 0.52, "unit": "mm"},
        "weight": {"value": 48.5, "unit": "g"},
    },
    notes="Room temperature impedance",
    protocol={"name": "EIS"},
    start_time="2025-03-15T16:00:00Z",
    test_setup={"temperature": "25°C"},
)
```

Properties use the Quantity format:
`{"value": <number>, "unit": "<string>"}`.

## Bulk Upload Pattern

Upload multiple measurements for a cell instance:

```python
import polars as pl
from pathlib import Path

client = Ionworks()

# Create-or-get the hierarchy
spec = client.cell_spec.create_or_get({"name": "LGM50"})
inst = client.cell_instance.create_or_get(spec.id, {"name": "SN-001"})

# Upload each measurement file
for parquet_path in Path("data/").glob("*.parquet"):
    df = pl.read_parquet(parquet_path)
    client.cell_measurement.create_or_get(
        inst.id,
        {
            "measurement": {"name": parquet_path.stem},
            "time_series": df,
        },
    )
```

## Error Handling

```python
from ionworks import IonworksError, MeasurementValidationError

try:
    result = client.cell_measurement.create(
        "instance-id", measurement_detail
    )
except MeasurementValidationError as e:
    # Data validation failed (sign convention, monotonicity, etc.)
    print(f"Validation errors: {e.errors}")
except IonworksError as e:
    if e.error_code == "CONFLICT":
        print("Measurement with this name already exists")
    else:
        print(f"Upload failed: {e.message}")
```
