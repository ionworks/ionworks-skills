---
name: process-data
description: "Process raw battery cycling data into the ionworks standardized format (parquet + JSON) or BDF. Use when the user wants to convert data from cyclers (Arbin, Maccor, Basytec, Neware, etc.), MATLAB files, CSVs, JSON, or any other raw format; adds a new open-source dataset; or mentions ionworksdata transforms, step summaries, the time_series/steps parquet format, or the BDF (.bdf) format."
---

# Battery Data Processing

This skill guides you through converting raw battery cycling data into the ionworks standardized format. Two output shapes are supported:

- **Parquet + JSON** — the canonical dataset format for the Ionworks platform (time series + step summaries as parquet, metadata as JSON).
- **BDF (.bdf)** — a single-file portable format (Battery Data Format) suitable for sharing, archiving, or uploading to the platform when a full JSON metadata bundle isn't needed.

Both use the same ionworksdata column conventions; choose based on what the user is trying to do.

## When to use this

- The user has raw battery data (MATLAB, CSV, JSON, HDF5, cycler exports, etc.) and wants to process it
- The user wants to add a new open-source dataset to the repository
- The user is debugging or modifying an existing processing script
- The user mentions ionworksdata, parquet output, BDF, or the standard battery data format

## High-level workflow

1. **Understand the raw data** — inspect the files, figure out what columns exist and what units they're in
2. **Write a processing script** that loads the raw data into a Polars DataFrame with the required columns
3. **Use ionworksdata** to compute derived quantities (cycle/step counts, capacity, energy, step summaries)
4. **Write the output files** — parquet + JSON for the full dataset format, or `.bdf` for a single-file export

The hardest part is usually step 1 — every dataset is different. Steps 2-4 follow a consistent pattern.

## Output structure (parquet + JSON)

The hierarchy mirrors the platform data model: **cell spec → cell instance → measurement**. One directory per level, each containing its own JSON metadata file. Parquet data lives under the measurement that produced it.

```
{cell_spec_name}/
├── spec.json
└── {cell_instance_name}/
    ├── instance.json
    └── {measurement_name}/
        ├── measurement.json
        ├── time_series.parquet
        └── steps.parquet
```

A cell spec directory can hold many instance subdirectories (cells built to the same design), and each instance can hold multiple measurement subdirectories (e.g. separate cycling + calendar aging + RPT periods). Names should be filesystem-safe identifiers.

## Time series requirements

The `time_series.parquet` must have these columns:

| Column | Type | Notes |
|--------|------|-------|
| `Time [s]` | float | Cumulative across all cycles — never resets to 0 |
| `Voltage [V]` | float | Cell voltage |
| `Current [A]` | float | Positive = charge, negative = discharge |
| `Cycle count` | int | Cumulative cycle number, 0-indexed |
| `Step count` | int | Cumulative step number across all cycles |

Optional columns: `Temperature [degC]`, `Cycle from cycler`, `Step from cycler`, `Discharge capacity [A.h]`, `Charge capacity [A.h]`, `Discharge energy [W.h]`, `Charge energy [W.h]`.

### The two most common pitfalls

**Time must be cumulative.** Raw data often resets time to 0 each cycle. Track an offset:

```python
cumulative_time_offset = 0.0
for cycle in cycles:
    time_sec = raw_time + cumulative_time_offset
    cumulative_time_offset = time_sec[-1]
```

**Step count must be cumulative.** Same idea — track the offset across cycles so step numbers never repeat.

## Using ionworksdata

The `ionworksdata` library handles the tedious derived quantities. Use it — don't reimplement these calculations by hand.

```python
import ionworksdata as iwdata
```

### Setting cycle and step counts

Choose based on what the raw data provides:

```python
# If the data has a "Cycle from cycler" column:
df = iwdata.transform.set_cycle_count(df)

# If the data has a "Step from cycler" column:
df = iwdata.transform.set_step_count(df, options={"step column": "Step from cycler"})

# If you need to detect steps from current changes (no step column available):
df = iwdata.transform.set_cumulative_step_number(df, options={"method": "current sign"})
df = df.with_columns(pl.col("Step number").alias("Step count"))
```

### Setting capacity and energy

Call these after cycle/step counts are set:

```python
df = iwdata.transform.set_capacity(df)   # Creates Discharge/Charge capacity [A.h]
df = iwdata.transform.set_energy(df)     # Creates Discharge/Charge energy [W.h]
```

These integrate current (and power) over time per step. They need `Time [s]`, `Current [A]`, and `Voltage [V]` to exist first.

### Creating step summaries

```python
steps_df = iwdata.steps.summarize(time_series_df)
```

This produces a DataFrame with per-step aggregates: voltage/current/power statistics, inferred step types (Rest, CC charge, CC discharge, CV, etc.), durations, and accumulated capacity/energy. Write this to `steps.parquet`.

## Reading common raw formats

`ionworksdata.read` provides parsers for common cycler exports — use these before writing a custom parser:

```python
from ionworksdata import read

df = read.basytec("cell_001.txt")    # Basytec exports
df = read.bdf("cell_001.bdf")        # round-trip from BDF
# plus .biologic, .maccor, .neware, etc. — check `dir(read)` for current list
```

`read.detect(path)` will pick the right parser when the format is ambiguous.

## Writing the BDF format

When the user wants a single-file portable export rather than the full parquet/JSON bundle, use the BDF writer:

```python
from ionworksdata import write

write.bdf(df, "cell_001.bdf")
```

Inputs: a Polars DataFrame with at least `Time [s]`, `Voltage [V]`, `Current [A]`. Other ionworksdata columns (`Cycle count`, `Step count`, temperature, capacity, energy) are preserved. Columns not recognised by the BDF mapping are passed through under their ionworksdata names so `read.bdf` round-trips cleanly.

BDF uses a machine-readable vs. labeled column convention internally. Pass `use_machine_readable_names=True` if the consumer expects the compact form.

## JSON metadata files (for the parquet bundle)

Three JSON files, one per level of the hierarchy:

- **spec.json** — the cell design. One per cell spec directory.
- **instance.json** — one specific physical cell.
- **measurement.json** — one test run on that cell.

Parent/child relationships are implicit in the directory tree — the JSON files do not carry explicit cross-reference IDs.

### Getting the authoritative schema

Invoke the **discover-api** skill to fetch the live schemas via `client.schema("cell_specification")`, `client.schema("cell_instance")`, and `client.schema("cell_measurement")`. The Pydantic models served by `/discovery` are the single source of truth — field names, required/optional, allowed enum values, and inline guidance (on units, sign conventions, when to use which `measurement_type`, etc.) all come from there. Don't guess from memory; the platform evolves.

### Minimal examples

These sketches are just to show the shape — always cross-check field lists against `discover-api` output before writing a real file.

```json
// spec.json
{
  "name": "Example_18650",
  "form_factor": "18650",
  "manufacturer": "Example Manufacturer",
  "ratings": {
    "capacity": {"value": 1.1, "unit": "A*h"},
    "voltage_min": {"value": 2.0, "unit": "V"},
    "voltage_max": {"value": 3.6, "unit": "V"}
  },
  "source": {
    "doi": "https://doi.org/10.xxxx/xxxxx",
    "citation": "Author et al. Title. Journal vol, pages (year).",
    "publication_date": "YYYY-MM-DD"
  }
}
```

```json
// instance.json
{
  "name": "dataset_cell_id",
  "batch": "2023-05-12",
  "date_manufactured": null,
  "measured_properties": {"cell": {}}
}
```

```json
// measurement.json
{
  "name": "dataset_cell_id_cycling",
  "start_time": "2023-01-01T00:00:00+00:00",
  "measurement_type": "time_series",
  "protocol": {
    "name": "Fast charging cycling",
    "ambient_temperature_degc": 30.0
  },
  "test_setup": {"cycler": "Arbin LBT", "channel_number": 73},
  "step_labels_validated": false
}
```

All numeric values with physical units use the Quantity format: `{"value": 1.1, "unit": "A*h"}`. Pint-compatible units — `*` and `/` for compound units. Common: `V`, `A`, `A*h`, `W*h`, `degC`, `s`, `ohm`, `mg/cm**2`.

## Script organization

Place processing scripts under `{dataset}/scripts/process/` and analysis scripts under `{dataset}/scripts/analyze/`. The script should be runnable standalone and process all cells in the dataset.

## Existing examples

When writing a new processing script, look at the existing ones for patterns. They cover a range of raw formats:

- **MATLAB structs** loaded via h5py (nested references, time in minutes)
- **CSV files** with varying column names and units
- **JSON columnar data** requiring parsing and column renaming
- **Native cycler exports** handled via `ionworksdata.read.*`

Read the most similar existing script to the new dataset's format, but adapt it — don't copy blindly. Each dataset has its own quirks in column naming, time units, and data structure.
