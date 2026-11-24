# Security Policy

## Supported versions

Security fixes are best effort, with no guarantee. Only the latest release of each addon is considered, and only
inside its support period, after which nothing is expected (see [`SUPPORT.md`](SUPPORT.md)).

| Addon | Version line | Best-effort fixes until |
|---|---|---|
| Pixel FX Starter | 0.x | 2027-11-23 |

## What to report

The addons here are GDScript, shaders, demo scenes, tools and tests that run in Godot and in
CI. Report problems such as:

- A script, tool or test that reads, writes, or sends files or data it should not.
- A workflow that leaks a token or lets a stranger run code in CI.
- A shader that can crash or hang a GPU driver on valid input.
- Personal data (names, paths, emails, keys) in the repository or its history.

## How to report

Do not open a public issue. Use the private form:
<https://github.com/revenantworks/godot-addons/security/advisories/new>.

Include the addon, what you found, where it is (file and line), and steps to reproduce it. Use
placeholders instead of real secrets or other people's data.

## What to expect

Reports are read when time allows. No reply is guaranteed, and no fix or fix date is promised.
These addons are free, unpaid and provided "AS IS". Reporters are credited in the release notes
unless they ask not to be.

Disclosure is coordinated: please keep a report private until a fix is released or 90 days have passed,
whichever comes first. Reporters are credited if they want to be.
