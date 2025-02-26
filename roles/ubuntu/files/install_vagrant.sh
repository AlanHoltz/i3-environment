sudo rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
ubuntu_codename=$(grep UBUNTU_CODENAME /etc/os-release | cut -d= -f2)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $ubuntu_codename main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vagrant