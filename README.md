# Configuración de entorno i3-wm

## Antes de correr el playbook:

Crear el grupo `ansible` y asignar el usuario actual al mismo:
```bash
sudo groupadd ansible
sudo usermod -a -G ansible aholtz
```

Dar permisos necesarios a todos los usuarios que pertenezcan al grupo `ansible` (asegurarse que no haya ningún otro archivo sobreescribiendo dichos permisos).

```bash
sudo visudo

# Agregar línea
%ansible ALL=(ALL:ALL) NOPASSWD: ALL
```

Instalar módulo necesarios de Ansible:

```bash
ansible-galaxy collection install community.general
ansible-galaxy collection install kewlfft.aur
```

## Correr el playbook

```bash
ansible-playbook  prepare_environment.yml -i inventory/hosts --ask-vault-password
```

## Luego de haber corrido el playbook

- Algunos componentes del `polybar` pueden haberse roto. Es necesario verificar el estado de la misma y fixearlos.
- En algunas distros como Arch, es necesario establecer a mano el tema GTK.