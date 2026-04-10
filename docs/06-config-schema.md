# Config Schema Reference

This document describes the YAML schema for every config file in `configs/`.
All config files are the source of truth for selectable options.
Bash logic in `lib/` reads them but never duplicates their content.

---

## General Rules

- All list fields use inline YAML syntax: `[item1, item2, item3]`
- The pipe character `|` must not appear in any field value (it is the plan entry delimiter)
- The keyword `all` in list fields means "matches every possible value"
- Script path fields are relative to `HYUNARCH_ROOT`
- If a config entry points to a script, that script must exist before it can be executed

---

## configs/distros.yaml

Defines supported Linux distributions and their package manager options.

### Schema

```yaml
distros:
  - id: <string>                          # required, unique, lowercase, hyphens ok
    display_name: <string>                # required, shown in menus
    supported_package_managers: [<list>]  # required, at least one PM id
    default_package_manager: <string>     # required, must be in supported_package_managers
```

### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Machine identifier. Used as `HYUNARCH_DISTRO` value. |
| `display_name` | string | yes | Human-readable name shown in distro menu. |
| `supported_package_managers` | list | yes | PMs available for this distro. |
| `default_package_manager` | string | yes | Used when only one PM is valid (auto-select). |

### Special Values

`supported_package_managers` recognized values: `pacman`, `yay`, `paru`, `apt`, `dnf`

### Example

```yaml
- id: arch
  display_name: "Arch Linux"
  supported_package_managers: [pacman, yay, paru]
  default_package_manager: pacman
```

---

## configs/desktops.yaml

Defines desktop environments and the distros they are available on.

### Schema

```yaml
desktops:
  - id: <string>                  # required, unique
    display_name: <string>        # required
    supported_distros: [<list>]   # required; use [all] for universal availability
    description: <string>         # optional, informational
```

### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Machine identifier. Used as `HYUNARCH_DE` value. |
| `display_name` | string | yes | Shown in DE selection menu. |
| `supported_distros` | list | yes | Distro ids this DE supports, or `[all]`. |
| `description` | string | no | One-line description shown to the user. |

### Special Values

`supported_distros: [all]` — the DE is shown for every distro.

### Example

```yaml
- id: hyprland
  display_name: "Hyprland"
  supported_distros: [arch, fedora]
  description: "Tiling Wayland compositor"
```

---

## configs/presets.yaml

Defines opinionated end-to-end setup presets. A preset is a single selection
that triggers one or more scripts in sequence.

### Schema

```yaml
presets:
  - id: <string>                        # required, unique
    display_name: <string>              # required
    desktop_environments: [<list>]      # required; which DEs this preset targets
    description: <string>              # optional
    scripts: [<list>]                  # required; relative script paths, executed in order
```

### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Machine identifier. |
| `display_name` | string | yes | Shown in preset selection menu. |
| `desktop_environments` | list | yes | DE ids this preset applies to. |
| `description` | string | no | One-line description. |
| `scripts` | list | yes | Script paths relative to `HYUNARCH_ROOT`, run in order. |

### Dispatch Wiring

Each script in `scripts` becomes a plan entry with `install_mode=direct`.
`HYUNARCH_INSTALL_MODE` is exported as `direct` when the script runs.

### Example

```yaml
- id: hyunarch-hyprland-full
  display_name: "Hyunarch Hyprland Full Setup"
  desktop_environments: [hyprland]
  description: "Complete Hyprland setup with Hyunarch defaults"
  scripts: ["scripts/presets/hyunarch-hyprland-full.sh"]
```

---

## configs/themes.yaml

Defines theme installation scripts, each tied to one or more DEs.

### Schema

```yaml
themes:
  - id: <string>                        # required, unique
    display_name: <string>              # required
    desktop_environments: [<list>]      # required
    description: <string>              # optional
    script: <string>                   # required; single script path
```

### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Machine identifier. |
| `display_name` | string | yes | Shown in theme menu. |
| `desktop_environments` | list | yes | DE ids this theme supports. |
| `description` | string | no | One-line description. |
| `script` | string | yes | Script path relative to `HYUNARCH_ROOT`. |

### Dispatch Wiring

The `script` field maps directly to a plan entry with `install_mode=direct`.

### Example

```yaml
- id: catppuccin-hyprland
  display_name: "Catppuccin (Hyprland)"
  desktop_environments: [hyprland]
  description: "Catppuccin color theme for Hyprland"
  script: "scripts/themes/catppuccin-hyprland.sh"
```

---

## configs/apps.yaml

This file has two top-level sections: `categories` and `apps`.

### Section: categories

```yaml
categories:
  - id: <string>        # required, unique
    display_name: <string>  # required
```

Used to group apps in the selection menu. Categories are shown first; the
user selects which categories to browse, then sees apps within each.

### Section: apps

```yaml
apps:
  - id: <string>                        # required, unique
    display_name: <string>              # required
    category: <string>                  # required; must match a categories id
    desktop_environments: [<list>]      # required; use [all] for universal
    supports_clean_install: <bool>      # required; true or false
    supports_hyunarch_config: <bool>    # required; true or false
    clean_install_script: <string>      # required when supports_clean_install=true
    hyunarch_script: <string>          # required when supports_hyunarch_config=true
```

### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Machine identifier. |
| `display_name` | string | yes | Shown in app selection menu. |
| `category` | string | yes | Category id this app belongs to. |
| `desktop_environments` | list | yes | DE ids where the app is available. |
| `supports_clean_install` | bool | yes | Whether a clean install path exists. |
| `supports_hyunarch_config` | bool | yes | Whether a Hyunarch-configured path exists. |
| `clean_install_script` | string | conditional | Path to clean install script. Empty string when not applicable. |
| `hyunarch_script` | string | conditional | Path to Hyunarch config script. Empty string when not applicable. |

### Dispatch Wiring

When the user selects an app:
- If both modes are supported, the user is prompted to choose.
- If only one mode is supported, it is auto-selected.
- `install_mode` is set to `clean` or `hyunarch` accordingly.
- `HYUNARCH_INSTALL_MODE` is exported to the child script at execution time.
- Hyunarch scripts must only be the predefined scripts in `scripts/hyunarch/`.

### install_mode values

| Value | Meaning |
|-------|---------|
| `clean` | Install using `clean_install_script` |
| `hyunarch` | Install using `hyunarch_script` |
| `direct` | Used for presets and themes (no mode choice) |

### Example

```yaml
- id: kitty
  display_name: "Kitty"
  category: terminal
  desktop_environments: [all]
  supports_clean_install: true
  supports_hyunarch_config: true
  clean_install_script: "scripts/apps/kitty-clean.sh"
  hyunarch_script: "scripts/hyunarch/kitty.sh"
```

---

## Adding New Entries

### New distro

1. Add entry to `configs/distros.yaml`
2. Create any PM-specific install logic in installer scripts
3. Update `configs/desktops.yaml` `supported_distros` if the new distro supports a DE that previously excluded it

### New desktop environment

1. Add entry to `configs/desktops.yaml`
2. Add matching entries in `configs/presets.yaml`, `configs/themes.yaml` with the new DE id in `desktop_environments`
3. Add app entries (or update existing ones) to reference the new DE

### New preset

1. Add entry to `configs/presets.yaml` with correct `desktop_environments`
2. Create the script(s) under `scripts/presets/`

### New theme

1. Add entry to `configs/themes.yaml`
2. Create the script under `scripts/themes/`

### New application

1. Add the app entry to `configs/apps.yaml` under the correct `category`
2. Create `scripts/apps/<app>-clean.sh` if `supports_clean_install: true`
3. Create `scripts/hyunarch/<app>.sh` if `supports_hyunarch_config: true`
4. Run `tests/dispatch/test_script_paths.sh` to verify path integrity
