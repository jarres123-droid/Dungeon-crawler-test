# Godot development environment

This repository is a Godot **4.7** mobile project. The required engine version is
read from `config/features` in `project.godot`; using the same minor version avoids
silently rewriting scene or resource formats.

The project is source-based: GDScript (`.gd`) and text scenes (`.tscn`) can be
edited with any UTF-8 editor. PNG files and their checked-in `.import` metadata
are left untouched, while Godot's generated `.godot/` import cache is ignored.

## Install Godot

```bash
tools/setup_godot.sh
```

The installer uses an already available compatible `godot`/`godot4` executable
when possible. Otherwise it discovers and downloads the current stable patch of
the project's Godot minor release into the ignored `.tools/godot/` directory. In a network-restricted environment,
download the official ZIP elsewhere and use:

```bash
GODOT_ARCHIVE=/path/to/Godot_v4.7-stable_linux.x86_64.zip tools/setup_godot.sh
```

Override `GODOT_VERSION` only when intentionally testing another compatible
engine. Override `GODOT_BIN` to use a specific existing executable.

## Import and validate

```bash
tools/validate_godot.sh
```

Validation runs three distinct phases so infrastructure failures can be told
apart from project defects:

1. headless resource import (including PNG textures);
2. headless editor loading of `project.godot`;
3. a short main-scene run to resolve scene and resource references; and
4. an explicit parse check of every tracked or untracked `.gd` script.

Exit code `2` means the environment or import setup failed. Exit code `1` means
Godot ran but found a project/scene or GDScript error. Exit code `0` means all
checks passed.
