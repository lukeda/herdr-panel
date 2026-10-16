# herdr-kde

A KDE Plasma 6 panel widget that shows your [herdr](https://herdr.dev) agents and what they're doing, the same list as herdr's agents sidebar.

- **Panel:** an icon with a status dot for the busiest agent (blocked → working → done → idle) and an `active/total` count.
- **Popup:** every agent as `source · workspace · title`, with the agent name and status underneath. It can show a flat list or group by workspace.
- **Sources:** every running local herdr session plus every enabled SSH machine from `herdr machine list`.

The widget only displays agents. It doesn't focus them or send them anything.

## Install

```sh
herdr plugin install lukeda/herdr-kde
```

The plugin's build step installs the widget with `kpackagetool6`. Then right-click your panel, choose **Add Widgets…**, and add **Herdr Agents**.

To update, run `herdr plugin update herdr-kde`. If the widget is already on a panel, restart Plasma afterwards (`systemctl --user restart plasma-plasmashell`).

To remove it, run `herdr plugin action invoke herdr-kde.uninstall-widget` and then `herdr plugin uninstall herdr-kde`.

### Without herdr's plugin manager

```sh
git clone https://github.com/lukeda/herdr-kde && sh herdr-kde/install.sh
```

## Requirements

- KDE Plasma 6 (`kpackagetool6`)
- herdr 0.9 or newer, findable on `PATH`, in `~/.local/bin` or `~/.cargo/bin`, or set in the widget's settings

## How it works

The widget runs `plasmoid/contents/code/herdr-snapshot.sh`, which calls the herdr CLI:

| What | Command | Default interval |
|---|---|---|
| Discover sources | `herdr session list --json`, `herdr machine list --json` | 30s |
| Local sessions | `herdr agent list` + `herdr workspace list` (per session socket) | 2s |
| SSH machines | `herdr --machine <id> agent list` + `workspace list` | 20s |

Every interval can be changed in the widget settings. Unreachable machines show an error line in the popup and don't block local agents.

## Development

```sh
sh install.sh                          # install/upgrade into ~/.local/share/plasma/plasmoids
plasmawindowed io.github.lukeda.herdr  # run it in a window
herdr plugin link "$PWD"               # register the herdr plugin locally
```

## License

MIT
