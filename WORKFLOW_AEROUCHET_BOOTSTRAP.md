# WORKFLOW AEROUCHET BOOTSTRAP

## Purpose

This file is the deterministic first-hit bootstrap for starting the reusable **Workflow** tool with the **AeroUchet** project profile in a fresh ChatGPT chat.

This is an execution protocol, not background documentation.

## Activation command

Canonical command:

`WORKFLOW AEROUCHET START`

Stop command:

`WORKFLOW AEROUCHET STOP`

Interpretation:
- `WORKFLOW` = reusable workflow tool;
- `AEROUCHET` = selected project profile;
- `START` / `STOP` = action.

Generic GitHub requests, repository links, or the word `GitHub` do **not** activate this Workflow.

## Mandatory execution rule

If the user explicitly directs you to this file and asks you to start/follow it, or sends the canonical activation command in a startup instruction, you must **execute** the protocol below.

Do **not** merely summarize, explain, paraphrase, review, or acknowledge these instructions.

Do **not** answer the user's substantive AeroUchet question yet.

Do **not** inspect AeroUchet commits, branches, pull requests, versions, source code, CI results, or repository health before the private Recovery route below is completed.

## Required route

Execute in this exact order:

1. Treat AeroUchet Workflow as active for the current chat.
2. Open `dentar1997/AeroUchet-Private/00_START_HERE.md`.
3. Read and follow `dentar1997/AeroUchet-Private/docs/WORKFLOW_ACTIVATION.md`.
4. Read `dentar1997/AeroUchet-Private/INDEX.yaml`.
5. Read `dentar1997/AeroUchet-Private/PROJECT_CONTEXT.md`.
6. Enter the fixed Workflow state machine. The first substantive visible Workflow output must be `1.1 Preflight`.
7. Complete canonical `1.2 Context Recovery` from the private project state before interpreting or executing the user's substantive AeroUchet task.
8. Continue through the mandatory Stage Sequence for the rest of the substantive turn:
   - `1.1 Preflight`
   - `1.2 Context Recovery`
   - `2.1 Intake`
   - `2.2 Plan`
   - `2.3 Research`
   - `2.4 Work Gates`
   - `3 Execution / Implementation`
   - `4 Verification`
   - `5 Finalization`
9. For every completed stage/substage, follow the canonical receipt/durability rules from the private Workflow state. A stage receipt is not valid merely because these instructions were read.
10. Only after Context Recovery may you inspect public AeroUchet code/commits/PRs/versions if the user's actual task requires it.

## Critical anti-failure rules

The following are Workflow bootstrap failures:

- replying with ordinary prose before starting `1.1 Preflight`;
- inspecting public AeroUchet repository state before private Context Recovery;
- reading Workflow files and then treating them only as context instead of executing the Stage Sequence;
- summarizing this file instead of following it;
- asking the user to repeat `восстанови память`, `включи workflow`, `проверь историю`, or another activation reminder;
- starting a different project's Workflow merely because GitHub was mentioned.

If you discover that you already performed one of those actions in the current startup attempt, record the bootstrap as FAIL and recover prospectively; do not pretend the run was clean.

## Relationship to application-code authorization

`WORKFLOW AEROUCHET START` activates the Workflow + AeroUchet profile only.

It does **not** authorize changes to AeroUchet application code.

AeroUchet Swift/application-code mutation still requires the separate explicit user command:

`Программируй`

Do not infer that authorization from `START`, from GitHub access, or from a request to inspect/recover the project.

## Scope and lifetime

Once started, AeroUchet Workflow remains active for the current chat until:
- the user sends `WORKFLOW AEROUCHET STOP`; or
- the chat ends.

A new chat requires a new bootstrap/start.

## Clean-chat PASS criterion

A clean startup PASS requires all of the following:

1. The assistant opens this bootstrap as explicitly instructed.
2. No public repository inspection happens before private Recovery.
3. The assistant treats the file as executable instructions, not as reference material.
4. The first substantive Workflow response is `1.1 Preflight`.
5. `1.2 Context Recovery` follows and restores the private project state.
6. The assistant continues the fixed Workflow without another reminder.

Anything else is FAIL.
