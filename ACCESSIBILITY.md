# Accessibility

## Our commitment

We want everyone to be able to read, install, and use these addons. That includes people who
use screen readers, a keyboard only, or high zoom.

## Supported environments

- Documentation: Markdown, read on GitHub or in any text editor.
- Addons and demos: Godot 4.7 or later.
- Check scripts: Bash on Linux or macOS, PowerShell 7 on Windows.

## What we do

- We write documentation in plain language, with short sentences.
- We keep headings in order and give links descriptive text.
- Each demo scene lists its keys in its addon's README.
- We fix reported barriers when we can.

## Known limits

- We have not had a formal accessibility audit.
- The demo scenes have not been tested with a screen reader.
- Pixel FX Starter: `hit_flash` and its demo's animate mode flash the screen. Turn animate off
  with **A**.
- Some documents use tables and code blocks that a screen reader may read slowly.

## Report a barrier

Open an issue and choose "Accessibility barrier":
<https://github.com/revenantworks/godot-addons/issues/new/choose>.
Tell us which addon, where you hit the barrier and what you use. If you would rather not use a
public issue, use the private form in `SECURITY.md`.
