# KVM/Libvirt Automated Provisioning via Cloud-init & Linked Clones

[Português](#portugues) | [English](#english)

---

<a name="portugues"></a>
## 🇧🇷 [BR] Automação de Provisionamento KVM via Cloud-init

Este projeto implementa uma solução robusta, modular e idempotente em Shell Script Avançado para o provisionamento sequencial e seguro de Máquinas Virtuais (VMs) Linux no hipervisor *KVM/Libvirt*, utilizando *cloud-init* e *Linked Clones* para configurações iniciais automatizadas e otimização extrema de armazenamento.

### 🏗️ Arquitetura e Recursos Técnicos
* **Linked Clones Eficientes:** Utiliza imagens base puras (Backing Files) e gera discos diferenciais QCOW2 para as instâncias, minimizando o IOPS e o consumo de storage.
* **Isolamento de Rede:** Criação de uma rede virtual específica para as VMs, isolada de outras possíveis redes configuradas no host físico ou no hipervisor.
* **Isolamento de Credenciais com OpenSSL:** Chaves e senhas sensíveis são criptografadas/descriptografadas estritamente em tempo de execução na memória, com destruição imediata dos tokens brutos em memória, garantindo zero vazamento de segredos.
* **Purificação de Templates com `virt-sysprep`:** Provisiona uma instância temporária para validação e executa a limpeza completa de identificadores residuais (Machine IDs, chaves antigas e logs) antes do isolamento do Backing File.
* **Injeção de Metadados via `cloud-init`:** Orquestração dinâmica de hostname, usuários locais, chaves SSH autorizadas do host e configurações de rede através da substituição automatizada de variáveis.
* **Inventário Dinâmico Automatizado:** Validação ativa do status de rede via terminal e geração automática de um mapa estruturado de IPs locais na pasta de inventário para integrações externas.

### 🛠️ Pré-requisitos do Ambiente
* **Sistema Operacional:** Linux com virtualização habilitada (testado em Debian 13.6.0 / Ubuntu 26.04.1 / RHEL 10.2 / Rocky 10.2 / Alma 10.2 / Fedora 44-1.7).
* **Privilégios:** Acesso administrativo (`sudo`).
* **Chave SSH:** Existência de uma chave pública em `~/.ssh/`.
* **Pacotes necessários (opcionalmente instalados por este projeto):** `openssh`, `curl`, `guestfs-tools`, `gettext` (RedHat) | `gettext-base` (Debian), `libvirt` (RedHat) | `libvirt-daemon-system` + `libvirt-clients` (Debian), `virt-install` (RedHat) | `virtinst` (Debian), `qemu-utils` (Debian). 
* **Serviço rodando (opcionalmente executado por este projeto):** `libvirtd`.

### 📂 Estrutura do Projeto
```
📁 kvm-cloudinit-automation/
├── ⚡  main.sh
├── 📄 README.md
├── 📁 1-provisioning/
│   ├── ⚡  0-bootstrap_host.sh
│   ├── 🚀 vm_create.sh
│   ├── 📁 downloads/
│   │   ├── 🛡️ CHECKSUM (depois da primeira execução)
│   │   └── 💿 Rocky-9-GenericCloud-Base.latest.x86_64.qcow2 (depois da primeira execução)
│   └── 📁 templates/
│       ├── ⚙️ cfg-vm_create.env (depois da primeria execução)
│       ├── ⚙️ cfg-vm_create.env-example
│       ├── ☁️ meta-data_template
│       ├── ☁️ network-config
│       ├── ☁️ user-data-bf_template
│       └── ☁️ user-data-vm_template
└── 📁 2-inventory/
    └── 🌐 ips_list (depois da primeira execução)
```

### 🚀 Como Utilizar
1. Clone o repositório localmente:
   ```bash
   git clone git@github.com:matheusmcaguiar/kvm-cloudinit-automation.git
   ```
2. Execute o script principal (instala dependências necessárias, habilita o serviço libvirtd e provisiona as VMs):
   ```bash
   cd kvm-cloudinit-automation
   sudo ./main.sh
   ```
   > ℹ️ **Nota de execução:** Caso as dependências já estejam resolvidas e `libvirtd` já esteja rodando, você pode executar diretamente com: `sudo 1-provisioning/vm_create.sh`
   
   > ℹ️ **Nota da primeira execução:** Caso o script não encontre a imagem de nuvem localmente, ele realizará automaticamente o download (requer conexão com a internet) da imagem-base oficial do Rocky Linux (~600MB) e do seu respectivo CHECKSUM antes de iniciar a compilação do laboratório.
3. Digitar senha para o usuário das VMs quando solicitado pelo script.
4. Customização (Opcional): O script gerará automaticamente o arquivo `1-provisioning/templates/cfg-vm_create.env` se ele não existir, assumindo os valores padrão (3 máquinas "lab", RAM=2048, VCPUS=2, ...). Caso queira alterar essas configurações, basta editar o arquivo gerado e rodar o script novamente.
   
   > 🚀 **Customização Avançada de Atualizações:** Caso queira que sua imagem base já nasça com todos os pacotes do sistema atualizados, você pode descomentar as linhas `package_update: true` e `package_upgrade: true` dentro do arquivo `1-provisioning/templates/user-data-bf_template`. O motor do script possui um sistema de resiliência preventiva com timeout estendido para até 10 minutos para garantir que o ciclo de atualização termine com segurança antes de congelar o template.
   
   > 💡 **Dica de Engenharia (Criação da Imagem Base):** Se você definir a variável `VM_COUNT=0` no arquivo `1-provisioning/templates/cfg-vm_create.env`, o script executará estritamente a preparação, purificação e isolamento do Backing File master em `/var/lib/libvirt/images/`, encerrando o processo sem provisionar nenhuma instância de VM filha. **Nota de Cache:** Se o Backing File master já existir nesse diretório, o script o reaproveitará automaticamente, ignorando um novo processo de build.

### 🧹 Gestão do Ciclo de Vida (Limpeza do Ambiente)
O script aceita argumentos de terminal para realizar a destruição automatizada e segura do laboratório:
* **`demolish`**: Desliga forçadamente e **remove por completo** todas as VMs ativas do tipo configurado no Libvirt, eliminando seus discos diferenciais e arquivos XML. Mantém o Backing File intacto e não altera a rede virtual criada.
```bash
sudo 1-provisioning/vm_create.sh demolish
```
* **`annihilate`**: Executa o processo da função `demolish` e, em seguida, **deleta permanentemente** o *Backing File master* localizado em `/var/lib/libvirt/images/` e a *rede virtual* criada, realizando um reset de fábrica completo no hipervisor.
```bash
sudo 1-provisioning/vm_create.sh annihilate
```

---

<a name="english"></a>
## 🇺🇸 [EN] KVM Provisioning Automation via Cloud-init

This project implements a robust, modular, and idempotent solution in Advanced Shell Script for the sequential and secure provisioning of Linux Virtual Machines (VMs) on the *KVM/Libvirt* hypervisor, using *cloud-init* and *Linked Clones* for automated initial setups and extreme storage optimization.

### 🏗️ Architecture and Technical Features
* **Efficient Linked Clones:** Utilizes pure base images (Backing Files) and generates QCOW2 differential disks for the instances, minimizing IOPS and storage consumption.
* **Network Isolation:** Creates a specific virtual network for the VMs, isolated from other networks configured on the physical host or the hypervisor.
* **Credential Isolation with OpenSSL:** Sensitive keys and passwords are encrypted/decrypted strictly at runtime in memory, with immediate destruction of raw tokens in RAM, ensuring zero secret leaks.
* **Template Purification with `virt-sysprep`:** Provisions a temporary instance for validation and performs a complete cleanup of residual identifiers (Machine IDs, old keys, and logs) before isolating the Backing File.
* **Metadata Injection via `cloud-init`:** Dynamic orchestration of hostname, local users, authorized host SSH keys, and network settings through automated variable substitution.
* **Automated Dynamic Inventory:** Active network status validation via terminal and automatic generation of a structured map of local IPs in the inventory folder for external integrations.

### 🛠️ Environment Prerequisites
* **Operating System:** Linux with virtualization enabled (tested on Debian 13.6.0 / Ubuntu 26.04.1 / RHEL 10.2 / Rocky 10.2 / Alma 10.2 / Fedora 44-1.7).
* **Privileges:** Administrative access (`sudo`).
* **SSH Key:** An existing public key in `~/.ssh/`.
* **Required packages (optionally installed by this project):** `openssh`, `curl`, `guestfs-tools`, `gettext` (RedHat) | `gettext-base` (Debian), `libvirt` (RedHat) | `libvirt-daemon-system` + `libvirt-clients` (Debian), `virt-install` (RedHat) | `virtinst` (Debian), `qemu-utils` (Debian).
* **Running service (optionally executed by this project):** `libvirtd`.

### 📂 Project Structure
```
📁 kvm-cloudinit-automation/
├── ⚡  main.sh
├── 📄 README.md
├── 📁 1-provisioning/
│   ├── ⚡  0-bootstrap_host.sh
│   ├── 🚀 vm_create.sh
│   ├── 📁 downloads/
│   │   ├── 🛡️ CHECKSUM (after the first run)
│   │   └── 💿 Rocky-9-GenericCloud-Base.latest.x86_64.qcow2 (after the first run)
│   └── 📁 templates/
│       ├── ⚙️ cfg-vm_create.env (after the first run)
│       ├── ⚙️ cfg-vm_create.env-example
│       ├── ☁️ meta-data_template
│       ├── ☁️ network-config
│       ├── ☁️ user-data-bf_template
│       └── ☁️ user-data-vm_template
└── 📁 2-inventory/
    └── 🌐 ips_list (after the first run)
```

### 🚀 How to Use
1. Clone the repository locally:
   ```bash
   git clone git@github.com:matheusmcaguiar/kvm-cloudinit-automation.git
   ```

2. Execute the main script (installs required dependencies, enables the libvirtd service, and provisions the VMs):
   ```bash
   cd kvm-cloudinit-automation
   sudo ./main.sh
   ```
   > ℹ️ **Execution Note:** If dependencies are already resolved and `libvirtd` is already running, you can execute it directly with: `sudo 1-provisioning/vm_create.sh`

   > ℹ️ **First-Time Execution Note:** If the script does not find the cloud image locally, it will automatically download (requires internet connection) the official Rocky Linux base image (~600MB) and its respective CHECKSUM before starting the lab compilation.
3. Enter the password for the VM user when prompted by the script.
4. Customization (Optional): The script will automatically generate the `1-provisioning/templates/cfg-vm_create.env` file if it does not exist, assuming default values (3 "lab" machines, RAM=2048, VCPUS=2, ...). If you want to change these settings, simply edit the generated file and run the script again.

  > 🚀 **Advanced Update Customization:** If you want your base image to be born with all system packages fully updated, you can uncomment the package_update: true and package_upgrade: true lines inside the 1-provisioning/templates/user-data-bf_template file. The script engine features a preventive resilience system with an extended timeout of up to 10 minutes to ensure that the update cycle finishes safely before freezing the template.

  > 💡 **Engineering Tip (Base Image Creation):** If you set the variable `VM_COUNT=0` in the `1-provisioning/templates/cfg-vm_create.env` file, the script will strictly perform the preparation, purification, and isolation of the master Backing File in `/var/lib/libvirt/images/`, ending the process without provisioning any child VM instances. **Cache Note:** If the master Backing File already exists in that directory, the script will automatically reuse it, skipping a new build process.

### 🧹 Lifecycle Management (Environment Cleanup)
The script accepts terminal arguments to perform the automated and safe destruction of the lab:
* **`demolish`**: Forcibly shuts down and **completely removes** all active VMs of the configured type from Libvirt, deleting their differential disks and XML files. It keeps the Backing File intact and does not alter the created virtual network.
```bash
sudo 1-provisioning/vm_create.sh demolish
```
* **`annihilate`:** Executes the `demolish` function process and then **permanently deletes** the *master Backing File* located in `/var/lib/libvirt/images/` and the created *virtual network*, performing a complete factory reset on the hypervisor.
```bash
sudo 1-provisioning/vm_create.sh annihilate
```

---

**Author:** Matheus Aguiar  
**Contact:** matheus.mc.aguiar@gmail.com  
**Focus:** Infrastructure as Code (IaC) | Linux Systems Engineering
