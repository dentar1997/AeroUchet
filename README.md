# AeroUchet

## ChatGPT / AI entrypoint

**Start with [`00_START_HERE.md`](00_START_HERE.md) before inspecting code, commits, pull requests, or app version.**

AeroUchet uses a companion private repository as durable project memory. A fresh ChatGPT conversation must restore that context first, then return to this repository for the application-code work actually requested by the user.

This repository contains the Swift application code. It is **not** the canonical source for workflow/history/continuity rules.

## Application code

Current app source is maintained on `main`. Version state is defined by `AppVersion.swift` and must be checked together with the private project context when working on the app.
