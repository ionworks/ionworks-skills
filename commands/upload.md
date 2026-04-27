---
description: Upload a battery measurement (time series, files, properties) via the Ionworks SDK, guided by the upload-data skill.
argument-hint: [path-to-file-or-dir]
---

Invoke the `ionworks:upload-data` skill and use it to upload the data at `$ARGUMENTS`.

Before uploading:
1. Run `ionworks:discover-api` if it has not already been invoked this session.
2. Confirm the target cell specification and cell instance with the user.
3. Use `ionworks:process-data` if the data is not already in the standardized parquet/JSON or BDF format.

Then perform the upload, report the created measurement IDs, and print a short summary of what was uploaded.
