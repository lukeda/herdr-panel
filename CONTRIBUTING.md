# Contributing to herdr-panel

Thanks for helping out. Bug fixes, new desktop frontends, and small polish are all welcome.

## Before you start

- **Bugs:** open an issue, or go straight to a PR if the fix is small and obvious.
- **New features or a new desktop/bar:** open an issue first so we can agree on the shape before you write the code.
- Keep each PR to one change. Two small PRs are easier to review than one big one.

## Project layout

```
core/herdr-snapshot.sh   shared: calls the herdr CLI and prints JSON (no desktop code here)
kde/                     KDE Plasma 6 widget (QML)
  contents/code/raise.sh   KDE-only: raises the terminal for click-to-focus
install.sh               detects desktops and installs each frontend
herdr-plugin.toml        the herdr plugin manifest (build step + actions)
assets/animation/        HTML scene that renders the README animation
```

The rule of thumb: **anything that talks to herdr goes in `core/`; anything that draws or talks to a desktop goes in that desktop's folder.** `install.sh` copies `core/` into each frontend at install time, so there's one copy of the data script.

## Development setup

You need herdr 0.9.1+ and, for the KDE widget, Plasma 6.

```bash
git clone https://github.com/lukeda/herdr-panel
cd herdr-panel
herdr plugin link "$PWD"               # register the plugin from your checkout
sh install.sh                          # install or upgrade the widget
plasmawindowed io.github.lukeda.herdr  # run it in a window
```

Plasma caches widget code, so after `install.sh`, reload a widget that's already on a panel with:

```bash
kquitapp6 plasmashell && systemctl --user start plasma-plasmashell
```

You can also run the data script directly to see what the widget sees:

```bash
sh core/herdr-snapshot.sh sources
sh core/herdr-snapshot.sh local ~/.config/herdr/herdr.sock
```

## Adding a new desktop or bar

1. Create a folder for it (e.g. `waybar/`).
2. Get the data from `core/herdr-snapshot.sh`. Don't call herdr from the frontend directly, and if you need something new from herdr, add a mode to the core script.
3. Add a detection block to `install.sh`, and handle `--uninstall` too.
4. Add a row to the "Works with your desktop" table in the README.

## Style

- **Shell:** POSIX `sh`, not bash. It has to run anywhere herdr does.
- **No new runtime dependencies.** Users should get a working install from `herdr plugin install` alone. Things a desktop already ships (`qdbus6` on KDE) are fine.
- Match the surrounding code's naming and comment density.
- Commit messages: a short summary line, then a body explaining *why* if it isn't obvious.

## Testing

There's no automated test suite yet. Before opening a PR:

- [ ] `sh install.sh` installs or upgrades cleanly.
- [ ] The widget loads with no QML errors (`plasmawindowed io.github.lukeda.herdr`, or `journalctl --user -u plasma-plasmashell`).
- [ ] You tested with at least one running agent, and with herdr stopped.
- [ ] If you touched SSH machines: you tested a machine that can't be reached.
- [ ] If you changed how it looks: screenshots in the PR.

## AI-written code

AI-assisted contributions are welcome. A few things we ask:

- **Use a capable model.** Preferred: **DeepSeek V4 Flash** or higher, **GLM 5.3 Flash** or higher, **GPT-6 Astra** or higher, or **Claude Opus 5.5** or higher. Smaller or older models tend to produce QML and shell code that looks right but breaks on a real desktop.
- **Say so in the PR.** Tick the AI box in the PR template and name the model.
- **You own it.** Read every line, run it on your own desktop, and be ready to answer review questions about it. "The AI wrote it" isn't an answer to a review comment.
- **No unreviewed bulk changes.** Don't let an agent reformat or "clean up" files your change doesn't need.

## Pull request templates

When you open a PR, pick the template that fits by adding it to the URL:

- Bug fix: `?template=bug_fix.md`
- New feature: `?template=feature.md`

The default template works for anything else.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
