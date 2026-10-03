# KVM/Libvirt Automated Provisioning via Cloud-init & Linked Clones

[Português](#portugues) | [English](#english)

---

<a name="portugues"></a>
## 🇧🇷 [BR] Automação de Provisionamento KVM via Cloud-init

Este projeto implementa uma solução robusta, modular e idempotente em Shell Script Avançado para o provisionamento sequencial e seguro de Máquinas Virtuais (VMs) Linux no hipervisor KVM/Libvirt, utilizando a técnica de *Linked Clones* para otimização extrema de armazenamento.

### 🏗️ Arquitetura e Recursos Técnicos
* **Linked Clones Eficientes:** Utiliza imagens base puras (Backing Files) e gera discos diferenciais QCOW2 para as instâncias, minimizando o IOPS e o consumo de storage.
* **Isolamento de Credenciais com OpenSSL:** Chaves e senhas sensíveis são criptografadas/descriptografadas estritamente em tempo de execução na memória, com destruição imediata dos tokens brutos em memória (`unset`), garantindo zero vazamento de segredos.
* **Purificação de Templates com `virt-sysprep`:** Provisiona uma instância temporária para validação e executa a limpeza completa de identificadores residuais (Machine IDs, chaves antigas e logs) antes do isolamento do Backing File.
* **Injeção de Metadados via Cloud-init:** Orquestração dinâmica de hostname, usuários locais, chaves SSH autorizadas do host e configurações de rede através da substituição automatizada de variáveis com `envsubst`.
* **Inventário Dinâmico Automatizado:** Validação ativa do status de rede via terminal e geração automática de um mapa estruturado de IPs locais na pasta de inventário para integrações externas.

### 🛠️ Pré-requisitos do Ambiente
* Sistema Operacional: Debian / Ubuntu
* Privilégios: Acesso administrativo (`sudo`)
* Pacotes necessários: `qemu-kvm`, `libvirt-daemon-system`, `libvirt-clients`, `virtinst`, `guestfs-tools` (`virt-sysprep`), `gettext-base` (`envsubst`), `openssl`, `curl`.

### 🚀 Como Utilizar
1. Clone o repositório localmente:
   ```bash
   git clone git@github.com:matheusmcaguiar/kvm-cloudinit-automation.git
   cd kvm-cloudinit-automation
   ```
2. Execute o script principal de provisionamento:
   ```bash
   sudo ./1-provisioning/vm_create.sh
   ```
   > ℹ️ **Nota da primeira execução:** Caso o script não encontre a imagem de nuvem localmente, ele realizará automaticamente o download da imagem base oficial do Rocky Linux (~600MB) e do seu respectivo CHECKSUM antes de iniciar a compilação do laboratório.
3. **Customização (Opcional):** O script gerará automaticamente o arquivo `1-provisioning/templates/cfg-vm_create.env` se ele não existir, assumindo os valores padrão (3 máquinas "manager", RAM=2048, VCPUS=2). Caso queira alterar essas configurações, basta editar o arquivo `.env` gerado e rodar o script novamente.
   > 💡 **Dica de Engenharia (Criação da Imagem Base):** Se você definir a variável `VM_COUNT=0` no arquivo `.env`, o script executará estritamente a preparação, purificação e isolamento do Backing File master em `/var/lib/libvirt/images/`, encerrando o processo sem provisionar nenhuma instância de VM filha. **Nota de Cache:** Se o Backing File master já existir nesse diretório, o script o reaproveitará automaticamente, ignorando um novo processo de build.
   > 🚀 **Customização Avançada de Atualizações:** Caso queira que sua imagem base já nasça com todos os pacotes do sistema atualizados, você pode descomentar as linhas `package_update: true` e `package_upgrade: true` dentro do arquivo `1-provisioning/templates/user-data-bf_template`. O motor do script possui um sistema de resiliência preventiva com timeout estendido para até 10 minutos para garantir que o ciclo de atualização termine com segurança antes de congelar o template.

### 🧹 Gestão do Ciclo de Vida (Limpeza do Ambiente)
O script aceita argumentos de terminal para realizar a destruição automatizada e segura do laboratório:
* **`sudo ./1-provisioning/vm_create.sh demolish`**: Desliga forçadamente e remove por completo todas as VMs ativas do tipo configurado no Libvirt, eliminando seus discos diferenciais e arquivos XML. Mantém o Backing File intacto.
* **`sudo ./1-provisioning/vm_create.sh annihilate`**: Executa o processo da função `demolish` e, em seguida, **deleta permanentemente o Backing File master** localizado em `/var/lib/libvirt/images/`, realizando um reset de fábrica completo no armazenamento do hipervisor.

---

<a name="english"></a>
## 🇺🇸 [EN] Automated KVM Provisioning via Cloud-init

An advanced, idempotent, and production-ready Shell Script solution for secure, sequential provisioning of Linux Virtual Machines (VMs) on KVM/Libvirt hypervisors, leveraging *Linked Clones* for optimal storage efficiency.

### 🏗️ Architecture & Core Features
* **Efficient Linked Clones:** Utilizes pristine master images as Backing Files to generate lightweight differential QCOW2 disks, drastically reducing storage footprint.
* **Credential Isolation via OpenSSL:** Sensitive passwords are encrypted into system hashes strictly at runtime within volatile memory, using variable purging (`unset`) to prevent environmental memory leaks.
* **Template Sanitization via `virt-sysprep`:** Spawns a temporary orchestration instance to automatically strip unique identifiers (Machine IDs, logs, lease histories) prior to freezing the master Backing File.
* **Cloud-init Metadata Injection:** Dynamically configures hostnames, system users, authorized host SSH keys, and network interfaces by injecting variables using `envsubst`.
* **Dynamic Inventory Generation:** Actively monitors interface addresses using `virsh` and outputs a reliable structural mapping of online instances and their respective network metadata.

### 🛠️ System Prerequisites
* Operating System: Debian / Ubuntu
* Privileges: Root access (`sudo`)
* Required Packages: `qemu-kvm`, `libvirt-daemon-system`, `libvirt-clients`, `virtinst`, `guestfs-tools`, `gettext-base`, `openssl`, `curl`.

### 🚀 Quick Start
1. Clone the repository:
   ```bash
   git clone git@github.com:matheusmcaguiar/kvm-cloudinit-automation.git
   cd kvm-cloudinit-automation
   ```
2. Execute the automated provisioning script:
   ```bash
   sudo ./1-provisioning/vm_create.sh
   ```
   > ℹ️ **First-run execution note:** If the script doesn't find the target OS image locally, it will automatically download the official Rocky Linux cloud template (~600MB) along with its validation CHECKSUM file prior to generating the infrastructure.
3. **Customization (Optional):** The script automatically provisions a default `1-provisioning/templates/cfg-vm_create.env` profile if missing (3 "manager" VMs, 2048MB RAM, 2 VCPUS). Modify this generated file to inject your customized hardware or environment topologies.
   > 💡 **Engineering Tip (Base Image Creation):** Setting `VM_COUNT=0` inside the `.env` configuration template forces the engine to solely process the initial staging, sanitization, and caching of the master Backing File inside `/var/lib/libvirt/images/`, cleanly exiting the routine before spawning any child VM instances. **Cache Note:** If the master Backing File already exists in that directory, the script will automatically reuse it, bypassing a new build process.
   > 🚀 **Advanced Upgrade Customization:** If you want your base template to be pre-patched with the latest system updates, you can uncomment the `package_update: true` and `package_upgrade: true` directives inside `1-provisioning/templates/user-data-bf_template`. The engine features an extended 10-minute automated timeout safeguard to guarantee that the update routine completes successfully before freezing the template image.

### 🧹 Lifecycle Management (Environment Cleanup)
You can append arguments to the script execution line to trigger structural teardowns:
* **`sudo ./1-provisioning/vm_create.sh demolish`**: Forces shutdown and purges all active instances matching the configuration profile from Libvirt, destroying differential disks and VM XML configurations while keeping the base template intact.
* **`sudo ./1-provisioning/vm_create.sh annihilate`**: Triggers the `demolish` task sequence and subsequently **deletes the master Backing File** from `/var/lib/libvirt/images/`, achieving a factory reset of the storage environment.

---
**Author:** Matheus Aguiar  
**Contact:** matheus.mc.aguiar@gmail.com  
**Focus:** Infrastructure as Code (IaC) | Linux Systems Engineering

