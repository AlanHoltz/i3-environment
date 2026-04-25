# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

An Ansible playbook that provisions a personal i3-wm desktop environment (i3 + polybar + rofi + alacritty + picom + dunst + zsh/oh-my-zsh + GTK theme + apps like Chrome/Discord/DBeaver/Visual Studio Code/Vagrant). It targets two OS families and dispatches at runtime based on `ansible_facts.os_family`:

- **Debian** (Ubuntu) → `roles/ubuntu` (apt + manual `.deb` installs + a script for i3lock-color)
- **Archlinux** → `roles/arch` (pacman + `kewlfft.aur` for AUR packages, plus a bluetooth setup step Ubuntu doesn't have)

## Running the playbook

Install required collections once:
```bash
ansible-galaxy collection install community.general
ansible-galaxy collection install kewlfft.aur
```

Run against a host from `inventory/hosts` (the playbook prompts for `target_host`):
```bash
ansible-playbook prepare_environment.yml -i inventory/hosts --ask-vault-password --ask-become-pass
```

Inventory groups: `local` (localhost), `ubuntu_test_vms`, `arch_test_vms`, and `dev_vms` (which is the union of both VMs and sets `enable_picom=false` plus the shared `ansible_user`). When prompted for `target_host`, enter one of these group names. Group vars live in `inventory/group_vars/<group>.yml`.

`vault_password.txt` is gitignored — it's referenced by ansible.cfg conventions but you should still pass `--ask-vault-password` interactively unless the user explicitly tells you otherwise.

## Architecture

### Role structure (mirrors between ubuntu and arch)

Both `roles/<distro>/tasks/main.yml` import the same sequence of task files, so the two roles are intentionally parallel — when adding a step, add it to **both** roles (with package-manager-specific differences) unless the feature is OS-specific. Order:

1. `set_custom_facts.yml` — auto-detects the machine's `backlight_card`, `battery`, and `adapter` from `/sys/class/backlight` and `/sys/class/power_supply`. These facts are then templated into `polybar_modules.j2` so polybar shows the right hardware. Identical between roles.
2. `create_directories.yml` — creates `~/.config`, `~/.themes`, `~/.icons`.
3. `install_dependencies.yml` — distro-specific package install (apt vs pacman/AUR), then imports `install_zsh.yml`, `install_vs_code.yml`, `install_vagrant.yml`.
4. `configure_bluetooth.yml` — **Arch only**.
5. `configure_i3.yml` — clones `adi1090x/polybar-themes`, runs its `setup.sh` with stdin `1`, sets the initial wallpaper via `feh` (requires `DISPLAY=:0`), then installs i3lock-color (Ubuntu uses `files/install_i3lock-color.sh`; Arch removes vanilla `i3lock` first, then installs the AUR package).
6. `install_gtk_theme.yml`
7. `copy_config_files.yml` — extracts `shared/files/base_config.zip` into `$HOME` and templates the `shared/templates/*.j2` files into `~/.config/...`. **Identical between roles** — when changing config templating, edit both copies.
8. `copy_ssh_keys.yml` — writes the vault-encrypted SSH keypair to `~/.ssh/`.

### Shared assets (`shared/`)

- `shared/templates/*.j2` — Jinja2 templates for alacritty, dunst, i3, i3lock, rofi, polybar (bars/colors/modules). They consume:
  - Color variables from `vars/common.yml` (`primary_color`, `secondary_color`, `tertiary_color`, `danger_color`).
  - The auto-detected hardware facts (`backlight_card`, `battery`, `adapter`) in `polybar_modules.j2`.
  - The group-var `enable_picom` (defaulted to `true` in the template) in `i3_config.j2`.
- `shared/files/base_config.zip` — pre-built tree of dotfiles unpacked into `$HOME` before templates overlay specific files.
- `shared/files/initial_bg.png` — wallpaper.

### Variables

- `vars/common.yml` — non-secret defaults (`user_name`, `user_home`, theme colors). `user_home` is derived from `user_name`, so changing the username flows through.
- `vars/ssh_keys.yml` — **vault-encrypted**. Contains `user_ssh_private_key` and `user_ssh_public_key`, consumed by `copy_ssh_keys.yml`. Edit with `ansible-vault edit vars/ssh_keys.yml`.

## Conventions when editing

- **Keep the two roles in sync.** A new step almost always needs a parallel implementation in both `roles/ubuntu/tasks/` and `roles/arch/tasks/`. The exceptions already in the tree are bluetooth (Arch only) and the i3lock-color install path (script vs AUR).
- **Templates are shared, tasks are per-distro.** Don't duplicate templates per role; route new templated configs through `shared/templates/` and add a loop entry in both `copy_config_files.yml` files.
- **README is in Spanish** — match that style if updating it.
