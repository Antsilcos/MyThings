#!/bin/bash
set -euo pipefail

#▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄
#▀                     Script de Configuração do Debian como Host Docker
#▀
#▀        --- Nunca execute scripts da internet sem antes ler atentamente seu conteúdo! ---
#▀ Ofereço este script sem quaisquer garantias, todos os resultados (bons ou ruins) de sua execução
#▀ são de sua inteira responsabilidade. Ou seja: Se a execução deste arquivo fazer seu computador
#▀ sincronizar com a Skynet e começar o apocalipse, POR FAVOR pare tudo e volte do início!
#▀ Este script deve ser utilizado idealmente logo após uma instalação mínima do Debian.
#▀
#▀     --- SUMÁRIO ---
#▀ 01 - Definição de Variáveis
#▀   01.01 - Geral
#▀   01.02 - Links
#▀   01.03 - Escapes ANSI
#▀   01.04 - Menus whiptail
#▀   01.05 - Mensagens
#▀ 02 - Definição de Funções
#▀   02.01 - ScriptStatus
#▀   02.02 - BasicSetup
#▀   02.03 - ConfigureGrub
#▀   02.04 - DisableDesktop
#▀   02.05 - ConfigureSSH
#▀   02.06 - InstallDocker
#▀   02.07 - ConfigureDockerWorker
#▀   02.08 - DisableNouveau
#▀   02.09 - InstallNvidiaGpuDrivers
#▀   02.10 - InstallNvidiaCT
#▀   02.11 - InstallNVEncPatch
#▀   02.12 - InstallAmdGpuDrivers
#▀   02.13 - InstallIntelGpuDrivers
#▀ 03 - Execução
#▀   03.01 - Checagem por root
#▀   03.02 - Execução de funções
#▀
#▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄

#==================================================================================================
#                                  01 - Definição de Variáveis
#==================================================================================================

# 1.01 - Geral
TimeZone="America/Sao_Paulo"
RequiredPackages="build-essential dkms ca-certificates curl gnupg2 libxml2-utils linux-headers-$(uname -r) lsb-release nfs-common sudo qemu-guest-agent git"
DockerPackages="docker-buildx-plugin docker-ce docker-ce-cli docker-compose-plugin containerd.io"
NvidiaGpuPackages="libvulkan1"
NvidiaCTPackages="nvidia-container-toolkit nvidia-container-toolkit-base libnvidia-container-tools libnvidia-container1"
AmdGpuPackages="firmware-amd-graphics mesa-vulkan-drivers vulkan-tools"
IntelGpuPackages="intel-media-va-driver mesa-vulkan-drivers vainfo"
DockerWorkerUser="docker_worker"
ContainersDataDir="/opt/containers-data"
DesktopMetaPackages=(
	cinnamon gdm3 gnome-shell kde-plasma-desktop lightdm lxde mate-desktop sddm task-cinnamon-desktop task-gnome-desktop
	task-kde-desktop task-lxde-desktop task-mate-desktop task-xfce-desktop wayland xfce4 xorg xserver-xorg
)

# 1.02 - Links
UrlDockerGPG="https://download.docker.com/linux/debian/gpg"
UrlDockerRepo="https://download.docker.com/linux/debian"
UrlNvidia="https://www.nvidia.com/en-us/drivers/unix/"
UrlNvidiaGPG="https://nvidia.github.io/libnvidia-container/gpgkey"
UrlNvidiaRepo="https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list"
UrlNvencPatch="https://github.com/keylase/nvidia-patch"

# 1.03 - Escapes ANSI e cores do whiptail
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

# 1.04 - Menus whiptail
WtYBtn="SIM"
WtNBtn="NÃO"
WtOkBtn="CONTINUAR"
WtCancelBtn="CANCELAR"

WtTitle="Configuração do Host Debian Headless"
WtWelcomeText="\n⚠️  ATENÇÃO ⚠️\n\
Estre script irá realizar uma série de modificações ao sistema, dentre elas:\n\
  O GRUB terá um timeout igual a 0\n\
  O OS Prober será desativado (impedindo dualboot)\n\
  A GUI será desativada (apenas modo terminal)\n\
Assim que você pressionar ENTER, o script iniciará.\n"
WtTitle1="Chave SSH"
WtGenerateSshKey="Deseja gerar uma chave SSH para acesso remoto (forma recomendada de autenticação)?"
WtTitle2="Senha SSH"
WtGenerateSshPass="Deseja que o SSH permita o uso de senha para login (é preferível usar chaves)?"
WtTitle3="Selecione a Versão do Driver"
WtTitle4="Necessário reiniciar"
WtRebootNow="É necessário reiniciar para aplicar o bloqueio do nouveau antes de instalar os drivers.\nO sistema irá reiniciar agora. Após iniciado, execute o script novamente para dar continuidade à configuração..."

# 1.05 - Mensagens
MsgErrNotRoot="$CBR[ERROR]$CBY - Este script deve ser executado como root.$Reset\n"
MsgUpdate="$CBB[INFO]$CBY - Checando pendências de atualizações do sistema (tenha paciência)...$Reset\n"
MsgInstallPackages="$CBB[INFO]$CBY - Instalando pacotes mínimos necessários:\n\t$CBW$RequiredPackages$Reset\n"
MsgConfiguringGrub="$CBB[INFO]$CBY - Configurando GRUB para reduzir tempo de boot...$Reset\n"
MsgDisablingMotD="$CBB[INFO]$CBY - Desativando MotD e avisos legais de início do shell...$Reset\n"
MsgStoppingDisplay="$CBB[INFO]$CBY - Parando display manager...$Reset\n"
MsgDeskMetaPkgBlock="$CBB[INFO]$CBY - Criando lista de exclusão de pacotes de Ambientes de Desktop, para garantir que não sejam instalados por acidente...$Reset\n"
MsgSSHConfig="$CBB[INFO]$CBY - Configurando o serviço SSH...$Reset\n"
MsgGeneratingSshKey="$CBB[INFO]$CBY - Gerando chave SSH...$Reset\n"
MsgEnablingSSHPass="$CM[WARNING]$CBY - Nenhuma chave foi criada para o SSH. Ativando acesso por senha (desative após configurar uma chave)...$Reset\n"
MsgDockerGPG="$CBB[INFO]$CBY - Adicionando chave GPG do Docker...$Reset\n"
MsgDockerRepo="$CBB[INFO]$CBY - Adicionando repositório do Docker...$Reset\n"
MsgDockerInstall="$CBB[INFO]$CBY - Instalando pacotes do Docker:\n\t$CBW$DockerPackages$Reset\n"
MsgDockerUser="$CBB[INFO]$CBY - Criando usuário \"worker\" para rodar serviços referentes ao docker...$Reset\n"
MsgDockerUseradded="$CBB[INFO]$CBY - Usuário $CBM$DockerWorkerUser$CBY criado$Reset\n"
MsgContainersDir="$CBB[INFO]$CBY - Criando diretório para centralizar os bind mounts dos containers$Reset\n"
MsgContainersDirAdded="$CBB[INFO]$CBY - Diretório $CBM$ContainersDataDir$CBY criado$Reset\n"
MsgDockerEnable="$CBB[INFO]$CBY - Habilitando e iniciando serviço do Docker...$Reset\n"
MsgNvidiaDeps="$CBB[INFO]$CBY - Instalando dependências dos drivers Nvidia...$Reset\n"
MsgNvidiaFetchingVersions="$CBB[INFO]$CBY - Obtendo versões disponíveis dos drivers...$Reset\n"
MsgErrNvidiaVersion="$CBR[ERROR]$CBY - Não foi possível obter os drivers Nvidia.$Reset\n"
MsgNvidiaDetectedVersion="$CBB[INFO]$CBY - Última versão encontrada:$Reset"
MsgNvidiaDownloading="$CBB[INFO]$CBY - Baixando driver:$Reset"
MsgInstallingNvidiaGpuDrivers="$CBB[INFO]$CBY - Instalando driver de GPU Nvidia (tenha paciência)...$Reset\n"
MsgContinuing="$CBB[INFO]$CBY - Continuando execução...$Reset\n"
MsgDockerNotFound="$CBR[ERROR]$CBY - Docker não encontrado. Abortando.${Reset}\n"
MsgNvidiaGPG="$CBB[INFO]$CBY - Adicionando chave GPG do NCT...$Reset\n"
MsgNvidiaRepo="$CBB[INFO]$CBY - Adicionando repositório do NCT...$Reset\n"
MsgNvidiaCTInstall="$CBB[INFO]$CBY - Instalando pacotes do NCT:\n\t$CBW$NvidiaCTPackages$Reset\n"
MsgNvidiaConfig="$CBB[INFO]$CBY - Adicionando o Nvidia Runtime ao Docker...\n"
MsgNvencPatching="$CBB[INFO]$CBY - Aplicando patch NVENC...$Reset\n"
MsgNvencSuccess="$CBB[INFO]$CBY - Patch NVENC aplicado com sucesso.$Reset\n"
MsgInstallingAmdDrivers="$CBB[INFO]$CBY - Instalando pacotes de drivers para GPU AMD (tenha paciência):\n\t$CBW$AmdGpuPackages$Reset\n"
MsgInstallingIntelDrivers="$CBB[INFO]$CBY - Instalando pacotes de drivers para GPU Intel (tenha paciência):\n\t$CBW$IntelGpuPackages$Reset\n"
# MsgGeneratingShellWelcome="$CBB[INFO]$CBY - Configurando mensagem de boas-vindas do shell para o root...$Reset\n"
MsgGpuDetected1="$CBB[INFO]$CBY - GPU$CG NVIDIA$CBY detectada.$Reset\n"
MsgGpuDetected2="$CBB[INFO]$CBY - GPU$CR AMD$CBY detectada.$Reset\n"
MsgGpuDetected3="$CBB[INFO]$CBY - GPU$CB Intel$CBY detectada.$Reset\n"
MsgNoGpu="$CM[WARNING]$CBY - Nenhuma GPU suportada detectada. Ignorando configurações de drivers de vídeo$Reset\n"
MsgDone="$CBG[SUCCESS]$CBY - Concluído!\n"

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
BasicSetup() {
	# Timezone
	timedatectl set-timezone $TimeZone

	printf "$MsgUpdate"
	apt-get update >/dev/null && apt-get dist-upgrade -y >/dev/null

	printf "$MsgInstallPackages"
	apt-get install -y $RequiredPackages >/dev/null

	# MotD
	printf "$MsgDisablingMotD"
	chmod -x /etc/update-motd.d/*
	rm -f /etc/motd
	ln -s /dev/null /etc/motd

	# Bloqueio de instalação de metapacotes de ambientes de desktop
	printf "$MsgDeskMetaPkgBlock"
	for MetaPkg in "${DesktopMetaPackages[@]}"; do
		cat <<EOF >>/etc/apt/preferences.d/desktop-metapackages-blacklist.pref
Package: $MetaPkg
Pin: release *
Pin-Priority: -1

EOF
	done
}

# 02.03
ConfigureGrub() {
	printf "$MsgConfiguringGrub"
	sed -i '/^GRUB_TIMEOUT=/d; /^GRUB_TIMEOUT_STYLE=/d; /^GRUB_CMDLINE_LINUX_DEFAULT=/d; /^GRUB_DISABLE_OS_PROBER=/d' /etc/default/grub
	cat <<'EOF' >>/etc/default/grub
GRUB_TIMEOUT=0
GRUB_TIMEOUT_STYLE=hidden
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_DISABLE_OS_PROBER=true
EOF
	update-grub
}

# 02.04
DisableDesktop() {
	printf "$MsgStoppingDisplay"
	systemctl isolate multi-user.target
	systemctl set-default multi-user.target
}

# 02.05
ConfigureSSH() {
	printf "$MsgSSHConfig"
	if whiptail --title "$WtTitle1" --yesno "$WtGenerateSshKey" 10 70 --yes-button "$WtYBtn" --no-button "$WtNBtn"; then
		printf "$MsgGeneratingSshKey"
		ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N ""
	elif whiptail --title "$WtTitle2" --yesno "$WtGenerateSshPass" 10 70 --yes-button "$WtYBtn" --no-button "$WtNBtn"; then
		printf "$MsgEnablingSSHPass"
		grep -q '^PasswordAuthentication' /etc/ssh/sshd_config &&
			sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config ||
			echo 'PasswordAuthentication yes' | tee -a /etc/ssh/sshd_config >/dev/null
	fi
}

# 02.06
InstallDocker() {
	# Chave GPG
	printf "$MsgDockerGPG"
	install -m 0755 -d /etc/apt/keyrings
	wget -qO- "$UrlDockerGPG" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

	# Repositório
	printf "$MsgDockerRepo"
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $UrlDockerRepo \
		$(. /etc/os-release && echo "$VERSION_CODENAME") stable" >/etc/apt/sources.list.d/docker.list

	# Instalação
	printf "$MsgDockerInstall"
	apt-get update >/dev/null && apt-get install -y $DockerPackages >/dev/null

	# Ativação
	printf "$MsgDockerEnable"
	systemctl enable docker containerd
	systemctl start docker containerd
}

# 02.07
ConfigureDockerWorker() {
	# Criando usuário sem login, sem home e sem shell interativo, apenas para rodar os serviços que iniciarão os containers
	printf "$MsgDockerUser"
	useradd -r -s /usr/sbin/nologin -d /nonexistent -G docker $DockerWorkerUser
	printf "$MsgDockerUseradded"

	# Pasta para realizar os bind mounts dos containers
	printf "$MsgContainersDir"
	install -d -o root -g docker -m 0775 "$ContainersDataDir"
	printf "$MsgContainersDirAdded"
}

# 02.08
DisableNouveau() {
	# Desativando módulo nouveau do kernel, uma vez que nunca será usado e pode (e irá) causar conflitos com outros drivers
	cat <<'EOF' >/etc/modprobe.d/blacklist.conf
blacklist nouveau
options nouveau modeset=0
EOF

	update-initramfs -u -k all >/dev/null
	whiptail --title "$WtTitle4" --msgbox "$WtRebootNow" 10 70
	reboot
	return 1
}

# 02.09
InstallNvidiaGpuDrivers() {
	printf "$MsgNvidiaDeps"
	apt-get install -y $NvidiaGpuPackages >/dev/null

	GpuName=$(echo $(lspci | grep -i 'vga' | grep -i 'nvidia') | sed -E 's/.*NVIDIA Corporation (.+) \(rev.*/\1/')

	printf "$MsgNvidiaFetchingVersions"
	readarray -t DriversVersions < <(
		wget -qO- "$UrlNvidia" |
			xmllint --html --xpath '//p[strong[contains(text(),"Linux x86_64/AMD64/EM64T")]]//a/text()' - 2>/dev/null |
			grep -Ei '^[0-9]+(\.[0-9]+)+$'
	)

	if [[ "$GpuName" != *"RTX"* ]]; then
		Choice=$(
			whiptail --title "$WtTitle3" --ok-button "$WtOkBtn" --cancel-button "$WtCancelBtn" --menu \
				"\nGPU: $GpuName\n\n" 17 70 ${#DriversVersions[@]} \
				"${DriversVersions[0]}" "Latest Production Branch" \
				"${DriversVersions[1]}" "Latest New Feature Branch" \
				"${DriversVersions[2]}" "Latest Beta" \
				"${DriversVersions[3]}" "Latest Legacy GPU version (470.xx series)" \
				3>&1 1>&2 2>&3
		)
		NvidiaVersion=$Choice
	else
		NvidiaVersion=${DriversVersions[0]}
	fi

	if [ ${#DriversVersions[@]} -eq 0 ]; then
		printf "$MsgErrNvidiaVersion"
		exit 1
	fi

	DriverUrl="https://us.download.nvidia.com/XFree86/Linux-x86_64/${NvidiaVersion}/NVIDIA-Linux-x86_64-${NvidiaVersion}.run"
	printf "$MsgNvidiaDetectedVersion $NvidiaVersion\n"
	printf "$MsgNvidiaDownloading\n\t$DriverUrl\n"

	wget -q --show-progress -O ~/nvidia-driver.run "$DriverUrl"
	chmod +x ~/nvidia-driver.run

	printf "$MsgInstallingNvidiaGpuDrivers"
	~/nvidia-driver.run --dkms --silent

	rm -f ~/nvidia-driver.run
}

# 02.10
InstallNvidiaCT() {
	DockerBin=$(which docker)
	if [[ -z "$DockerBin" || ! -x "$DockerBin" ]]; then
		printf "$MsgDockerNotFound"
		exit 1
	fi

	# Chave GPG
	printf "$MsgNvidiaGPG"
	install -m 0755 -d /etc/apt/keyrings
	wget -qO- "$UrlNvidiaGPG" |
		gpg --dearmor -o /etc/apt/keyrings/nvidia-container-toolkit.gpg

	# Repositório
	printf "$MsgNvidiaRepo"
	wget -qO- "$UrlNvidiaRepo" |
		sed "s#deb https://#deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit.gpg] https://#g" >/etc/apt/sources.list.d/nvidia-container-toolkit.list

	# Instalação
	printf "$MsgNvidiaCTInstall"
	apt-get update >/dev/null && apt-get install -y $NvidiaCTPackages >/dev/null

	# Configuração
	printf "$MsgNvidiaConfig"
	nvidia-ctk runtime configure --runtime=docker
	systemctl restart docker containerd
}

# 02.11
InstallNVEncPatch() {
	printf "$MsgNvencPatching"

	rm -rf /tmp/nvidia-patch
	git clone "$UrlNvencPatch" /tmp/nvidia-patch
	chmod +x /tmp/nvidia-patch/*.sh
	/tmp/nvidia-patch/patch.sh >/dev/null
	/tmp/nvidia-patch/patch-fbc.sh >/dev/null

	rm -rf /tmp/nvidia-patch
	printf "$MsgNvencSuccess"
}

# 02.12
InstallAmdGpuDrivers() {
	printf "$MsgInstallingAmdDrivers"
	apt-get install -y $AmdGpuPackages >/dev/null
}

# 02.13
InstallIntelGpuDrivers() {
	printf "$MsgInstallingIntelDrivers"
	apt-get install -y $IntelGpuPackages >/dev/null
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
whiptail --title "$WtTitle" --msgbox "$WtWelcomeText" 12 80 --ok-button "$WtOkBtn"
BasicSetup
ConfigureGrub
DisableDesktop
ConfigureSSH
InstallDocker
ConfigureDockerWorker

GpuFlavor=$(lspci | grep -i 'vga\|3d\|display')

if echo "$GpuFlavor" | grep -qi "NVIDIA"; then
	printf "$MsgGpuDetected1"
	DisableNouveau
	InstallNvidiaGpuDrivers
	InstallNvidiaCT
	InstallNVEncPatch
elif echo "$GpuFlavor" | grep -qi "AMD\|ATI "; then
	printf "$MsgGpuDetected2"
	InstallAmdGpuDrivers
elif echo "$GpuFlavor" | grep -qi "Intel"; then
	printf "$MsgGpuDetected3"
	InstallIntelGpuDrivers
else
	printf "$MsgNoGpu"
fi

EXIT_STATUS=$?
if [ $EXIT_STATUS -eq 0 ]; then
	printf "$MsgDone"
fi
