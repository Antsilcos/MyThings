#!/bin/bash
set -euo pipefail

#▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄
#▀                                 Script de Instalação do Nginx
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
#▀   02.03 - InstallNginx
#▀ 03 - Execução
#▀   03.01 - Checagem por root
#▀   03.02 - Execução de funções
#▀
#▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄

#==================================================================================================
#                                  01 - Definição de Variáveis
#==================================================================================================

# 01.01
RequiredPackages="curl gnupg2 ca-certificates lsb-release debian-archive-keyring"

# 01.02
UrlNginxGPG="https://nginx.org/keys/nginx_signing.key"
UrlNginxStableRepo="https://nginx.org/packages/debian"
UrlNginxMainlineRepo="https://nginx.org/packages/mainline/debian"

# 01.03
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

# 1.04
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

WtYBtn="SIM"
WtNBtn="NÃO"
WtOkBtn="CONTINUAR"
WtCancelBtn="CANCELAR"

WtTitle="Instalação do Nginx"
WtWelcomeText="\n⚠️  ATENÇÃO ⚠️\n\
Estre script irá realizar uma série de modificações ao sistema, dentre elas:\n\
  O Nginx será instalado e iniciado no boot\n\
  O keepalived poderá ser instalado e configurado\n\
  A GUI será desativada (apenas modo terminal)\n\
Assim que você pressionar ENTER, o script iniciará.\n"

# 01.05
MsgErrNotRoot="$CBR[ERROR]$CBY - Este script deve ser executado como root.$Reset\n"
MsgInstallPackages="$CBB[INFO]$CBY - Instalando pacotes mínimos necessários:\n\t$CBW$RequiredPackages$Reset\n"
MsgNginxGPG="$CBB[INFO]$CBY - Adicionando chave GPG do Nginx...$Reset\n"
MsgNginxRepo="$CBB[INFO]$CBY - Adicionando repositório do Nginx...$Reset\n"
MsgNginxInstall="$CBB[INFO]$CBY - Instalando pacotes do Nginx:\n\t nginx$Reset\n"
MsgNginxEnable="$CBB[INFO]$CBY - Habilitando e iniciando serviço do Nginx...$Reset\n"
MsgDone="$CBG[SUCCESS]$CBY - Concluído!$Reset\n"

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
	printf "$MsgInstallPackages"
	apt-get update >/dev/null && apt-get install -y $RequiredPackages >/dev/null
}

# 02.03
InstallNginx() {
	# Chave GPG
	printf "$MsgNginxGPG"
	install -m 0755 -d /etc/apt/keyrings
	wget -qO- "$UrlNginxGPG" | gpg --dearmor -o /etc/apt/keyrings/nginx.gpg

	# Repositório
	printf "$MsgNginxRepo"
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/nginx.gpg] $UrlNginxStableRepo \
		$(. /etc/os-release && echo "$VERSION_CODENAME") stable" >/etc/apt/sources.list.d/nginx.list
	echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" >/etc/apt/preferences.d/99nginx

	# Instalação
	printf "$MsgNginxInstall"
	apt-get update >/dev/null && apt-get install -y nginx >/dev/null

	# Ativação
	printf "$MsgNginxEnable"
	systemctl enable ngnix
	systemctl start ngnix
}

#==================================================================================================
#                                    03 - Execução de Funções
#==================================================================================================

# 03.01
if [[ $EUID -ne 0 ]]; then
	printf "$MsgErrNotRoot"
	exit 1
fi

# 03.02
whiptail --title "$WtTitle" --msgbox "$WtWelcomeText" 12 80 --ok-button "$WtOkBtn"
BasicSetup
InstallNginx

EXIT_STATUS=$?
if [ $EXIT_STATUS -eq 0 ]; then
	printf "$MsgDone"
fi
