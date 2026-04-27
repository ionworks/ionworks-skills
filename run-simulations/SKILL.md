---
name: run-simulations
description: >-
  Run electrochemical simulations with UCP protocols.
  Use when the user wants to simulate battery behavior,
  run protocol-based simulations, batch simulations with
  DOE, validate UCP protocols, or retrieve simulation
  results. Triggers: "simulation", "simulate", "protocol",
  "UCP", "DOE", "batch simulation", "design of experiments".
---

# Simulations

Guide for running battery simulations using the
Universal Cycler Protocol (UCP) format.

## Prerequisites

1. Run the **discover-api** skill first
2. Fetch the protocol schema:
   ```python
   protocol_schema = client.schema("protocol")   # UCP protocol format
   ```

## Single Simulation

```python
from ionworks import Ionworks

client = Ionworks()

# Option 1: Use an existing parameterized model by ID
config = {
    "parameterized_model": "pm-id-here",
    "protocol_experiment": {
        "protocol": "...",  # UCP YAML string
        "name": "1C discharge",
    },
}

# Option 2: Use a quick model (chemistry + capacity)
config = {
    "parameterized_model": {
        "capacity": 5.0,
        "chemistry": "NMC",
    },
    "protocol_experiment": {
        "protocol": "...",  # UCP YAML string
        "name": "1C discharge",
    },
}

# Option 3: Full model dict (inline parameters)
config = {
    "parameterized_model": {
        "model_id": "model-id",
        "parameters": { ... },
    },
    "protocol_experiment": {
        "protocol": "...",
        "name": "custom sim",
    },
}

# Submit and wait
sim = client.simulation.protocol(config)
# sim.simulation_id, sim.job_id

result = client.simulation.wait_for_completion(
    sim.simulation_id,
    timeout=60,        # seconds (default 60)
    poll_interval=2,   # seconds (default 2)
    verbose=True,      # print progress (default True)
)
```

### Optional Parameters

```python
config = {
    "parameterized_model": "pm-id",
    "protocol_experiment": {
        "protocol": "...",
        "name": "sim name",
    },
    # Optional:
    "experiment_parameters": { ... },
    "design_parameters": { ... },
    "max_backward_jumps": 100,
    "study_id": "study-id",
    "extra_variables": ["variable_name"],
}
```

## Batch Simulation (Design of Experiments)

Run multiple simulations with parameter variations:

```python
config = {
    "parameterized_model": "pm-id",
    "protocol_experiment": {
        "protocol": "...",
        "name": "batch sim",
    },
    "design_parameters_doe": {
        "sampling": "grid",  # grid, random, latin_hypercube
        "rows": [
            {
                "type": "range",
                "name": "Positive electrode thickness [m]",
                "min": 50e-6,
                "max": 100e-6,
                "count": 5,
            },
            {
                "type": "discrete",
                "name": "Current function [A]",
                "values": [1.0, 2.0, 5.0],
            },
            {
                "type": "normal",
                "name": "Negative electrode porosity",
                "mean": 0.3,
                "std": 0.05,
                "count": 10,
            },
        ],
        "count": 50,  # for random/latin_hypercube sampling
    },
}

sims = client.simulation.protocol_batch(config)
# Returns list of SimulationResponse (simulation_id, job_id)

# Wait for all
results = client.simulation.wait_for_completion(
    [s.simulation_id for s in sims],
    timeout=3600,
)
```

## Listing and Retrieving Results

```python
# List simulations (exactly one filter required)
sims = client.simulation.list(parameterized_model_id="pm-id")
sims = client.simulation.list(study_id="study-id")

# Get simulation details (returns dict)
sim = client.simulation.get("simulation-id")
# sim["status"], sim["storage_folder"], sim["simulation_data"]

# Get result (only after completion)
result = client.simulation.get_result("simulation-id")
```

## Protocol Validation

Validate a UCP protocol string before simulation:

```python
# Validate protocol YAML
validation = client.protocol.validate(protocol_yaml_string)

# Find input references (variables the protocol expects)
refs = client.protocol.find_input_references(protocol_yaml_string)
```

## Error Handling

```python
from ionworks import IonworksError

try:
    result = client.simulation.wait_for_completion(
        sim.simulation_id,
        timeout=120,
        raise_on_failure=True,  # default True
    )
except TimeoutError:
    print("Simulation timed out")
except IonworksError as e:
    print(f"Simulation failed: {e.message}")
```

Pass `raise_on_failure=False` to get the result dict
even on failure (check `result["status"]`).
