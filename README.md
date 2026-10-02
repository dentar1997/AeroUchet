# AeroUchet

## ChatGPT / AI entrypoint

For a deterministic fresh-chat start, do **not** rely on repository discovery alone.

Open and execute:

[`WORKFLOW_AEROUCHET_BOOTSTRAP.md`](WORKFLOW_AEROUCHET_BOOTSTRAP.md)

Canonical command:

`WORKFLOW AEROUCHET START`

The bootstrap explicitly routes ChatGPT to the private durable project state and requires the Workflow Stage Sequence to be executed rather than merely summarized.

`00_START_HERE.md` remains a secondary routing document after the AeroUchet profile is active.

AeroUchet uses a companion private repository as durable project memory. Public source/commits/PRs/versions must not be inspected before the required private Context Recovery when Workflow is active.

This repository contains the Swift application code. It is **not** the canonical source for Workflow/history/continuity rules.

## Application code

Current app source is maintained on `main`. Version state is defined by `AppVersion.swift` and must be checked together with the private project context when working on the app.
