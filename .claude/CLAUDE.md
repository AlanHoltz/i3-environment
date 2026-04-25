# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

An Ansible playbook that provisions a personal i3-wm desktop environment (i3 + polybar + rofi + alacritty + picom + dunst + zsh/oh-my-zsh + GTK theme + apps like Chrome/Discord/DBeaver/Visual Studio Code/Vagrant). It targets two OS families and dispatches at runtime based on `ansible_facts.os_family`:

- **Debian** (Ubuntu / Mint) → `roles/ubuntu` (apt + apt repos for VS Code and Vagrant; Chrome/Discord/DBeaver still use direct `.deb` URLs; i3lock-color built from source via `files/install_i3lock-color.sh`)
- **Archlinux** → `roles/arch` (pacman + `kewlfft.aur` for AUR packages, plus a bluetooth setup step Ubuntu doesn't have)

Distro-agnostic work (host fact gathering, directory creation, dotfile templating, ssh keys) lives in `roles/common`.

## Running the playbook

Install required collections once:
```bash
ansible-galaxy collection install community.general
ansible-galaxy collection install kewlfft.aur
```

Run against a host or group from `inventory/hosts` via `-l`:
```bash
ansible-playbook prepare_environment.yml -i inventory/hosts -l local --ask-vault-password --ask-become-pass
```

The play uses `hosts: all`, so always pass `-l <target>` — running without it targets every host in the inventory, which is rarely what you want.

Inventory groups: `local` (localhost), `ubuntu_test_vms`, `arch_test_vms`, and `dev_vms` (parent of both VM groups, sets `enable_picom: false` and the shared `ansible_user`). Group vars live in `inventory/group_vars/<group>.yml`.

`vault_password.txt` is gitignored — it's referenced by ansible.cfg conventions but you should still pass `--ask-vault-password` interactively unless the user explicitly tells you otherwise.

## Architecture

### Three roles: common + per-distro

The playbook wraps the distro-specific role with a `common` role that runs in two phases — a **prepare** phase before the distro work and a **finalize** phase after:

```yaml
tasks:
  - import_role: { name: common, tasks_from: prepare }
  - import_role: { name: ubuntu }   when: os_family == 'Debian'
  - import_role: { name: arch }     when: os_family == 'Archlinux'
  - import_role: { name: common, tasks_from: finalize }
```

This split exists because order matters around `configure_i3`: that step clones `adi1090x/polybar-themes` and runs its `setup.sh`, which writes baseline configs into `~/.config/polybar` and `~/.config/rofi`. The finalize phase then overlays the user's customizations on top — so `copy_config_files.yml` *must* run after `configure_i3.yml` for those overrides to win.

### Execution order

1. **`common/prepare.yml`**
   - `set_custom_facts.yml` — auto-detects `backlight_card`, `battery`, `adapter` from `/sys/class/backlight` and `/sys/class/power_supply`. These are templated into `polybar_modules.j2` so polybar shows the right hardware.
   - `create_directories.yml` — single loop creating `~/.config`, `~/.themes`, `~/.icons`, `~/Downloads`.
2. **Distro role (`ubuntu` or `arch`)**
   - `install_dependencies.yml` — distro package install (apt vs pacman/AUR), then imports `install_zsh.yml`, `install_vs_code.yml`, `install_vagrant.yml`.
   - `configure_bluetooth.yml` — **Arch only**.
   - `configure_i3.yml` — clones `adi1090x/polybar-themes`, runs `setup.sh` with stdin `1`, sets the wallpaper via `feh` (requires `DISPLAY=:0`), then installs i3lock-color (Ubuntu builds from source via `files/install_i3lock-color.sh`; Arch removes vanilla `i3lock` first, then installs `i3lock-color` from AUR).
   - `install_gtk_theme.yml` — Dracula GTK theme + Papirus icons (install method differs per distro).
3. **`common/finalize.yml`**
   - `copy_config_files.yml` — extracts `shared/files/base_config.zip` into `$HOME` and templates `shared/templates/*.j2` into `~/.config/...`. Runs after `configure_i3` so its templated polybar/rofi/i3/alacritty configs override the polybar-themes baseline.
   - `copy_ssh_keys.yml` — writes the vault-encrypted SSH keypair to `~/.ssh/`. Position is historical; it has no real ordering dependency.

### Shared assets (`shared/`)

- `shared/templates/*.j2` — Jinja2 templates for alacritty, dunst, i3, i3lock, rofi, polybar (bars/colors/modules). They consume:
  - Color variables from `inventory/group_vars/all/main.yml` (`primary_color`, `secondary_color`, `tertiary_color`, `danger_color`).
  - The auto-detected hardware facts (`backlight_card`, `battery`, `adapter`) in `polybar_modules.j2`.
  - The group var `enable_picom` (defaulted to `true` in the template) in `i3_config.j2`.
- `shared/files/base_config.zip` — pre-built tree of dotfiles unpacked into `$HOME`. Templates overlay specific files on top of this.
- `shared/files/initial_bg.png` — wallpaper.

### Variables

All vars live under `inventory/group_vars/` and are auto-loaded by ansible — no `vars_files:` plumbing in the playbook.

- `inventory/group_vars/all/main.yml` — non-secret defaults visible to every host (`user_name`, `user_home`, theme colors). `user_home` is derived from `user_name`, so changing the username flows through.
- `inventory/group_vars/all/ssh_keys.yml` — **vault-encrypted**. Contains `user_ssh_private_key` and `user_ssh_public_key`, consumed by `copy_ssh_keys.yml`. Edit with `ansible-vault edit inventory/group_vars/all/ssh_keys.yml`.
- `inventory/group_vars/dev_vms.yml` — `ansible_user` and `enable_picom: false` (picom causes tearing on VMs without GPU passthrough).

## Conventions when editing

- **Distro-agnostic work goes in `roles/common`.** If a task file would be byte-identical between `ubuntu` and `arch`, put it in `common`. Past drift (the missing `~/Downloads` dir on Ubuntu) is what motivated this split.
- **Distro-specific work goes in the distro role.** Keep that work narrowly scoped — package installs, OS-specific service setup, build-from-source paths.
- **Templates are shared.** Don't duplicate templates per role; route new templated configs through `shared/templates/` and add a loop entry in `roles/common/tasks/copy_config_files.yml`.
- **Almost-shared files (e.g., `install_zsh.yml`, `install_gtk_theme.yml`)** — currently live per-distro because they differ in their package install line, even though most of the body is shared. Candidates for a future refactor (split into a shared post-install helper plus a per-distro install line), but not byte-identical so they didn't move in the first common-role pass.
- **Naming convention for Visual Studio Code:** prose uses "Visual Studio Code" (Microsoft's full name); filenames and internal vars use `vs_code` (snake_case); external IDs (extension marketplace IDs, `name: vscode` on the apt source, `visual-studio-code-bin` AUR slug) are left alone.
- **Commit messages:** do not append `Co-Authored-By` trailers — the user wants solo-authorship history.
- **README is in Spanish** — match that style if updating it.
