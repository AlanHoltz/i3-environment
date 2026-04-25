# Configuración de entorno i3-wm

## Antes de correr el playbook:

Instalar módulos necesarios de Ansible:

```bash
ansible-galaxy collection install community.general
ansible-galaxy collection install kewlfft.aur
```

## Correr el playbook

Pasar el host o grupo objetivo con `-l` (por ejemplo `local`, `ubuntu_test_vms`, `arch_test_vms` o `dev_vms`):

```bash
ansible-playbook prepare_environment.yml -i inventory/hosts -l local --ask-vault-password --ask-become-pass
```