# Contributing

Thanks for helping. This repo ships to the public, so one rule comes before everything else:
**no personal data reaches a commit.** No name, no personal or machine path, no machine or
account name, no email address, no secret.

## How the repo is laid out

One folder per addon (`pixel-fx/`, and so on). Each folder is a whole Godot project: open it in
Godot to run that addon's demo and tests. The addon itself is the folder's `addons/<name>/`,
which is what a release zip carries. The root holds only the shared files: licence, notice,
community files, CI and the PII barrier.

Each folder is published from the Revenantworks source tree, so a pull request here is read
and, when it is taken, carried over by hand into the next release of that addon.

## Set up a clone (once)

```bash
git clone https://github.com/revenantworks/godot-addons.git
cd godot-addons
git config core.hooksPath .githooks      # arms the PII pre-commit hook
```

`core.hooksPath` is stored in the clone's own config. A fresh clone does not have it: run the
`git config` line in each new clone.

Commit with your GitHub no-reply address (Settings, Emails, "Keep my email addresses private"):

```bash
git config user.email "<id>+<login>@users.noreply.github.com"
```

The hook blocks a commit whose author or committer email is not a no-reply address.

## The PII barrier

- **Pre-commit hook** (`.githooks/pre-commit`): runs `python tools/pii_scan.py --staged` on the
  added lines of the staged diff and blocks the commit on any hit. It fails closed: with no
  Python 3.9+ it blocks too.
- **Your own global guard, if you have one:** `core.hooksPath` makes git skip a machine-wide
  hooks folder, so `.githooks/pre-commit` and `.githooks/pre-push` also call the `pii_guard.py`
  found in your global `core.hooksPath`. Without one, nothing extra runs.
- **CI** (`.github/workflows/pii-scan.yml`): runs `python tools/pii_scan.py --tree --identities`
  over every tracked file and every commit identity on each push to `main`.

The scanner is vendored from revenantworks/claude-skills (`tools/pii_scan.py` and
`tools/pii/`). A hit prints `path:line  rule  fp=<fingerprint>`, never the value. Fix the line
and stage again. **Never use `--no-verify`.** A file that must hold a fake path or key is
accepted by rule and by one file in `.pii-scan.json`; use example values (`example.com`,
`~/path/to/file`).

## Tests

Each addon folder says how its tests run in its own README. Pixel FX Starter's run in CI
(`.github/workflows/ci.yml`): `pixel-fx/tools/check.sh` imports the project, runs 9 headless
tests, then 21 render tests checked pixel by pixel on a software GPU:

```bash
GODOT=/path/to/godot pixel-fx/tools/check.sh
```

Addons with GUT tests (`addons/<name>/tests/`) need GUT 9.x in that folder's `addons/gut/`.

- Never weaken a check to make it pass. Fix the code or the test's expectation, and say why.

## Art

Demo art must be CC0 or your own work, credited in the addon folder. No AI-made images,
sounds or fonts.

## Commits

`<scope>: <imperative summary>` on the first line, then a body that says why. The scope is
the addon's folder name, or `ci`, `docs` or `tools` for the shared files.
