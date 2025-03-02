Antes de correr playbook:

1. Instalar servidor SSH para poder conectarse con Ansible
2. Crear grupo "ansible" y darle permisos NOPASSWD (asegurarse que no haya archivo sobreescribiendo los permisos)
3. Asignar usuario a utilizar al grupo recién creado

# Para instalar módulo Pacman
ansible-galaxy collection install community.general
# Para instalar módulo AUR
ansible-galaxy collection install kewlfft.aur