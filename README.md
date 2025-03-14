# Configuración de entorno i3-wm

## Antes de correr el playbook:

Instalar módulos necesarios de Ansible:

```bash
ansible-galaxy collection install community.general
ansible-galaxy collection install kewlfft.aur
```

## Correr el playbook

```bash
ansible-playbook  prepare_environment.yml -i inventory/hosts --ask-vault-password --ask-become-pass
```