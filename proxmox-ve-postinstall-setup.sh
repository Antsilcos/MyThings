#!/bin/bash
set -euo pipefail

#▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄
#▀                            Script de Configuração do Host Proxmox
#▀
#▀        --- Nunca execute scripts da internet sem antes ler atentamente seu conteúdo! ---
#▀   Ofereço este script sem quaisquer garantias, todos os resultados (bons ou ruins) de seu uso
#▀ são de sua inteira responsabilidade. Ou seja: Se a execução desse script fizer você perder todo
#▀ e qualquer acesso ao seu computador, porque você esqueceu de configurar o SSH antes de usá-la,
#▀ volte do início e tente novamente :)
#▀
#▀ AVISO: Rodar este script em uma instalação não recente é altamente desencorajado!
#▀
#▀     --- SUMÁRIO ---
#▀ 01 - Definição de Variáveis
#▀   1.01 - Geral
#▀   1.02 - Escapes ANSI
#▀   1.03 - Menus whiptail
#▀   1.04 - Mensagens
#▀ 02 - Definição de Funções
#▀   2.01 - ScriptStatus
#▀   2.02 - RepoConfig
#▀   2.03 - BasicSetup
#▀   2.04 - DisableHA
#▀   2.05 - EnableIOMMU
#▀ 03 - Execução
#▀   3.01 - Checagem por root
#▀   3.02 - Execução de funções
#▀
#▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄

#==================================================================================================
#                                  01. Definição de Variáveis
#==================================================================================================

# 1.01 - Geral
RequiredPackages="pve-headers dkms"
ProxmoxLib="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
CpuVendor=$(lscpu | awk -F: '/Vendor ID/ {print $2}' | xargs)
GpuId=$(lspci -nn | grep -Ei "VGA.+controller.+(NVIDIA|AMD|INTEL)" | head -n1 | grep -oP '\[\K[0-9a-f]{4}:[0-9a-f]{4}' || true) # `|| true` necessário para não quebrar com `-o pipefail`
GpuAudioId=$(lspci -nn | grep -Ei "Audio\sdevice.+(NVIDIA|AMD|INTEL)" | head -n1 | grep -oP '\[\K[0-9a-f]{4}:[0-9a-f]{4}' || true)
InitTune="1000 784 2 740 2 622 2 440 2 415 2 659 2 831 2 1046 6" # Zelda tune

# 1.02 - Escapes ANSI e cores do whiptail
Underline="\033[4m"
Reset="\033[0m"
CBK="\033[1;30m"  #010101 Black
CBBK="\033[1;90m" #808080 Bright Black
CW="\033[1;37m"   #cccccc White
CBW="\033[1;97m"  #ffffff Bright White
CR="\033[1;31m"   #de382b Red
CG="\033[1;32m"   #39b54a Green
CB="\033[1;34m"   #006fb8 Blue
CY="\033[1;33m"   #ffc706 Yellow
CM="\033[1;35m"   #762671 Magenta
CC="\033[1;36m"   #2cb5e9 Cyan
CBR="\033[1;91m"  #ff0000 Bright Red
CBG="\033[1;92m"  #00ff00 Bright Green
CBB="\033[1;94m"  #0000ff Bright Blue
CBY="\033[1;93m"  #ffff00 Bright Yellow
CBM="\033[1;95m"  #ff00ff Bright Magenta
CBC="\033[1;96m"  #00ffff Bright Cyan

export NEWT_COLORS=
export NEWT_COLORS='
	root=,black
	window=black,white
	border=black,white
	shadow=,gray
	title=magenta,white
	actcheckbox=white,magenta
	actlistbox=yellow,cyan
	actsellistbox=white,magenta
	button=white,brightmagenta
	checkbox=black,white
	compactbutton=black,white
	listbox=black,white
	textbox=black,white
'

# 1.03 - Menus whiptail
WtYBtn="SIM"
WtNBtn="NÃO"
WtOkBtn="CONTINUAR"
WtCancelBtn="CANCELAR"

WtTitle="Configurações Pós Instalação do Proxmox"
WtWelcomeText="\n⚠️  ATENÇÃO ⚠️\n\n\
Estre script irá realizar uma série de modificações ao sistema, dentre elas:\n\
  O GRUB terá um timeout igual a 0\n\
  O OS Prober será desativado (impedindo dualboot)\n\
  Quaisquer GPUs serão desativadas para permitir passthrough\n\
  O sistema não terá mais saída de vídeo e todo acesso deve ser feito por SSH ou portal web\n\n\
Assim que você pressionar ENTER, o script iniciará.\n"

WtTitle1="Configurações concluídas"
WtSuccess="\nÉ necessário reiniciar para aplicar algumas das configurações\n\n\
⚠️  AVISO ⚠️  Se tudo correu corretamente, o sistema não terá saída de vídeo após reiniciar! Todo acesso deverá ser feito pelo portal web ou por SSH.\n\
Para anexar a uma VM os dispositivos liberados, use o painel do Proxmox:\nVM → Hardware → Add → PCI Device → <GpuId>\n\n\
(Pressione ESC duas vezes para não reiniciar agora)\n"

# 1.04 - Mensagens
MsgRepoConfig="$CBB[INFO]$CBY - Removendo todos os repositórios e reescrevendo-os propriamente configurados...$Reset\n"
MsgSystemUpgrade="$CBB[INFO]$CBY - Checando pendências de atualizações do sistema (tenha paciência)...$Reset\n"
MsgInstallingPackages="$CBB[INFO]$CBY - Instalando pacotes necessários...$Reset\n"
MsgDisablePopUp="$CBB[INFO]$CBY - Desativando pop-up de ativação da instalação (limpe o cache do navegador)...\n\tO popup poderá voltar a aparecer após atualizações$Reset\n"
MsgDisablingMotD="$CBB[INFO]$CBY - Desativando MotD e avisos legais de início do shell...$Reset\n"
MsgDisablingHA="$CBB[INFO]$CBY - Desativando high availability...$Reset\n"
MsgConfiguringGrub="$CBB[INFO]$CBY - Configurando GRUB para ativar IOMMU e reduzir tempo de boot...$Reset\n"
MsgVfioConfig="$CBB[INFO]$CBY - Adicionando módulos VFIO para carregamento no boot...$Reset\n"

#==================================================================================================
#                                    02 - Definição de Funções
#==================================================================================================

# 02.01
ScriptStatus() {
	local CurrentStatus="$1"
	local StatusFile="/root/.$(basename "$0").status"

	if ! grep -Fxq "$CurrentStatus" "$StatusFile" 2>/dev/null; then
		echo "$CurrentStatus" >>"$StatusFile"
		return 0
	fi

	return 1
}

# 02.02
RepoConfig() {
	# Removendo todos os repositórios antes de reescrevê-los
	printf "$MsgRepoConfig"
	rm -f /etc/apt/sources.list.d/*

	cat <<'EOF' >/etc/apt/sources.list.d/debian.sources
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie
Components: main contrib
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
Enabled: true

Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie-updates
Components: main contrib
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
Enabled: true

Types: deb
URIs: http://security.debian.org/debian-security
Suites: trixie-security
Components: main contrib
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
Enabled: true
EOF

	cat <<'EOF' >/etc/apt/sources.list.d/proxmox.sources
Types: deb
URIs: https://enterprise.proxmox.com/debian/pve
Suites: trixie
Components: pve-enterprise
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
Enabled: false

Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
Enabled: true
EOF

	cat <<'EOF' >/etc/apt/sources.list.d/ceph.sources
Types: deb
URIs: https://enterprise.proxmox.com/debian/ceph-squid
Suites: trixie
Components: enterprise
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
Enabled: false

Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: trixie
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
Enabled: true
EOF
}

# 02.03
BasicSetup() {
	# Atualizando sistema
	printf "$MsgSystemUpgrade"
	apt-get update >/dev/null && apt-get dist-upgrade -y >/dev/null

	# Instalando pacotes básicos comumente necessários
	printf "$MsgInstallingPackages"
	apt-get install -y $RequiredPackages >/dev/null

	# Desativando pop-up de instalação não ativada
	if [ -s "$ProxmoxLib" ] && ! grep -q NoMoreNagging "$ProxmoxLib"; then
		printf "$MsgDisablePopUp"
		sed -i -e "/data\.status/ s/!//" -e "/data\.status/ s/active/NoMoreNagging/" "$ProxmoxLib"
	fi
	apt --reinstall install proxmox-widget-toolkit &>/dev/null

	# Interrompendo o MotD e avisos legais ao iniciar o shell
	printf "$MsgDisablingMotD"
	chmod -x /etc/update-motd.d/*
	rm -f /etc/motd
	ln -s /dev/null /etc/motd
}

# 02.04
DisableHA() {
	# Desativando serviços que não serão usados (podem ser reativados depois, se preciso)
	printf "$MsgDisablingHA"
	systemctl disable -q --now pve-ha-lrm pve-ha-crm corosync
}

# 02.05
EnableIOMMU() {
	# Ativa IOMMU e passthrough no GRUB
	printf "$MsgConfiguringGrub"

	sed -i '/^GRUB_TIMEOUT=/d; /^GRUB_TIMEOUT_STYLE=/d; /^GRUB_CMDLINE_LINUX_DEFAULT=/d; /^GRUB_INIT_TUNE=/d; /^GRUB_DISABLE_OS_PROBER=/d' /etc/default/grub

	if [[ "$CpuVendor" == "GenuineIntel" ]]; then
		IOMMU="intel_iommu=on"
	elif [[ "$CpuVendor" == "AuthenticAMD" ]]; then
		IOMMU="amd_iommu=on"
	fi

	cat <<EOF >>/etc/default/grub
GRUB_TIMEOUT=0
GRUB_TIMEOUT_STYLE=hidden
GRUB_CMDLINE_LINUX_DEFAULT="quiet $IOMMU iommu=pt pcie_acs_override=downstream,multifunction modprobe.blacklist=amdgpu,i915,nouveau,nvidia,nvidia-gpu,nvidiafb,radeon"
GRUB_INIT_TUNE="$InitTune"
GRUB_DISABLE_OS_PROBER=true
EOF
	update-grub

	# Configurando módulos VFIO no modules-load.d e initramfs
	printf "$MsgVfioConfig"
	tee /etc/modules-load.d/vfio.conf /etc/initramfs-tools/modules >/dev/null <<'EOF'
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF

	# Atribuíndo ao vfio-pci às GPUs e dispositivos de áudio previamente desativados
	if [-n "$GpuId"]; then
		echo "options vfio-pci ids=$GpuId,$GpuAudioId disable_vga=1" >/etc/modprobe.d/vfio.conf
	else
		echo "options vfio-pci disable_vga=1" >/etc/modprobe.d/vfio.conf
	fi

	update-initramfs -u -k all

	whiptail --title "$WtTitle1" --msgbox "$WtSuccess" 18 70
	reboot
	return 0

	# Atualizando grub e initramfs
}

#==================================================================================================
#                                    03 - Execução de Funções
#==================================================================================================

# 03.01 - Checagem por root
if [[ $EUID -ne 0 ]]; then
	printf "$MsgErrNotRoot"
	exit 1
fi

# 03.02 - Execução de funções
whiptail --title "$WtTitle" --msgbox "$WtWelcomeText" 17 80 --ok-button "$WtOkBtn"
RepoConfig
BasicSetup
EnableIOMMU
