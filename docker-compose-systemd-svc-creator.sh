#!/bin/bash
set -euo pipefail

#▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄
#▀                     Script de Criação de Serviços para Iniciar Containers
#▀
#▀        --- Nunca execute scripts da internet sem antes ler atentamente seu conteúdo! ---
#▀ Ofereço este script sem quaisquer garantias, todos os resultados (bons ou ruins) de sua execução
#▀ são de sua inteira responsabilidade. Ou seja: Se a execução deste script e seus serviços fizerem
#▀ com que seu servidor exija toda energia do seu bairro, deixando seus vizinhos e a concessonária
#▀ de energia furiosos, pare tudo e tente novamente :)
#▀
#▀     --- SUMÁRIO ---
#▀ 01 - Definição de Variáveis
#▀   01.01 - Geral
#▀   01.02 - Escapes ANSI e cores do whiptail
#▀ 02 - Execução
#▀   02.01 - Checagem por root
#▀   02.02 - Busca pelo Docker
#▀   02.03 - Menus
#▀   02.04 - Loop principal
#▀     02.04.1 - Mais checagens
#▀     02.04.2 - Criação do serviço
#▀
#▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄

#==================================================================================================
#                                  01 - Definição de Variáveis
#==================================================================================================

# 01.01 - Geral
DockerBin=$(which docker)
DockerWorkerUser="docker_worker"
SMenu_WebAdmin=()
SMenu_CloudApps=()
SMenu_MediaSvc=()

# 01.02 - Escapes ANSI e cores do whiptail
Reset="\033[0m"
CM="\033[1;35m"  #762671 Magenta
CC="\033[1;36m"  #2cb5e9 Cyan
CBR="\033[1;91m" #ff0000 Bright Red
CBG="\033[1;92m" #00ff00 Bright Green
CBB="\033[1;94m" #0000ff Bright Blue
CBY="\033[1;93m" #ffff00 Bright Yellow
CBM="\033[1;95m" #ff00ff Bright Magenta

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

#==================================================================================================
#                                       02 - Execução
#==================================================================================================

# 02.01 - Checagem por root
if [[ $EUID -ne 0 ]]; then
	printf "$CBR[ERROR]$CBY - Este script deve ser executado como root.$Reset\n"
	exit 1
fi

# 02.02 - Busca pelo Docker
if [[ -z "$DockerBin" || ! -x "$DockerBin" ]]; then
	echo "$CBR[ERROR]$CBY - Docker não encontrado. Abortando.${Reset}\n"
	exit 1
fi

# 02.03 - Menus
while true; do
	# Permito erros aqui, para usar o cancel do whiptail como uma forma de confirmação
	set +e
	Choice=$(
		whiptail --title "Seleção de Serviços" --ok-button "SELECIONAR" --cancel-button "FINALIZAR" \
			--menu "\n    Escolha qual tipo de serviço deseja instalar.\n\nServiços de múltiplos escopos podem ser selecionados. Marque todos os que desejar antes de clicar em FINALIZAR.\n\n" \
			20 70 3 \
			"Web Admin" "Serviços de gerenciamento da LAN" \
			"Cloud Apps" "Aplicações Web" \
			"Media Services" "Serviços de streaming" \
			3>&1 1>&2 2>&3
	)

	EXIT_STATUS=$?
	if [ $EXIT_STATUS -ne 0 ]; then
		# Aqui, todo erro volta a ser tratado como fatal
		set -e
		break
	fi

	case $Choice in
	"Web Admin")
		SMenu_WebAdmin=($(
			whiptail --title "Serviços WebAdmin" --ok-button "CONFIRMAR" --nocancel \
				--checklist "\n  WebAdmin - Selecione os serviços que deseja criar:\n" 15 95 4 \
				"Nginx" "Servidor de proxy reverso" $([[ " ${SMenu_WebAdmin[*]} " =~ "Nginx" ]] && echo ON || echo OFF) \
				"Authentik" "Serviço de controle de identidades" $([[ " ${SMenu_WebAdmin[*]} " =~ "Authentik" ]] && echo ON || echo OFF) \
				"LanCacheNET" "Cache local para serviços diversos, como jogos Steam e updates do Windows" $([[ " ${SMenu_WebAdmin[*]} " =~ "LanCacheNET" ]] && echo ON || echo OFF) \
				"netbootxyz" "Servidor iPXE" $([[ " ${SMenu_WebAdmin[*]} " =~ "netbootxyz" ]] && echo ON || echo OFF) \
				3>&1 1>&2 2>&3 | tr -d '"'
		))
		;;
	"Cloud Apps")
		SMenu_CloudApps=($(
			whiptail --title "Aplicações Cloud" --ok-button "CONFIRMAR" --nocancel \
				--checklist "\n  Cloud Apps  - Selecione os aplicativos web que deseja instalar:\n" 15 115 1 \
				"Homepage" "Dashboard customizável para integração de vários serviços (literalmente uma Página Inicial)" $([[ " ${SMenu_CloudApps[*]} " =~ "Homepage" ]] && echo ON || echo OFF) \
				3>&1 1>&2 2>&3 | tr -d '"'
		))
		;;
	"Media Services")
		SMenu_MediaSvc=($(
			whiptail --title "Serviços de Mídia" --ok-button "CONFIRMAR" --nocancel \
				--checklist "\n  Media Services - Selecione os serviços de mídia que deseja criar:\n" 17 85 4 \
				"Jellyfin" "Servidor local para streaming de séries e filmes" $([[ " ${SMenu_MediaSvc[*]} " =~ "Jellyfin" ]] && echo ON || echo OFF) \
				"Immich" "Serviço de gerênciamento de fotos e vídeos, com integração de IAs" $([[ " ${SMenu_MediaSvc[*]} " =~ "Immich" ]] && echo ON || echo OFF) \
				"Frigate" "NVR focado em detecção por IA. Local, seguro e flexível" $([[ " ${SMenu_MediaSvc[*]} " =~ "Frigate" ]] && echo ON || echo OFF) \
				"ArrSuite" "Suíte de aplicações *Arr. Se você sabe o que é, sabe o que fazem" $([[ " ${SMenu_MediaSvc[*]} " =~ "ArrSuite" ]] && echo ON || echo OFF) \
				3>&1 1>&2 2>&3 | tr -d '"'
		))
		;;
	esac
done

MenuSelections=("${SMenu_WebAdmin[@]}" "${SMenu_CloudApps[@]}" "${SMenu_MediaSvc[@]}")

# 02.04 - Loop principal
for Svc in "${MenuSelections[@]}"; do
	Svc=${Svc,,}
	SvcName="$Svc-container"
	SvcFile="/etc/systemd/system/$SvcName.service"
	WorkDir="/opt/containers-data/$Svc"

	# 02.04.1 - Mais checagens
	if [ -f "$SvcFile" ]; then
		printf "$CBB[INFO]$CBY - O serviço $CC$SvcName$CBY já existe. Ignorando opção selecionada...$Reset\n"
		continue
	fi

	if [ ! -f "$WorkDir/compose.yaml" ]; then
		printf "$CM[WARNING]$CBY - O serviço $CC$SvcName$CBY será criado, porém não há um ${CC}compose.yaml$CBY no local. Uma tentativa de iniciar o serviço nesse estado resultará em erro$Reset\n"
	fi

	# 02.04.2 - Criação do serviço
	printf "$CBB[INFO]$CBY - Criando diretório $CC$WorkDir$Reset\n"
	install -d -o root -g docker -m 0770 "$WorkDir"

	printf "$CBB[INFO]$CBY - Criando serviço $CC$SvcName$Reset\n"
	cat <<EOF >$SvcFile
[Unit]
Description=Serviço de inicialização do $Svc
Requires=docker.service
After=docker.service

[Service]
User=$DockerWorkerUser
Group=docker
Type=simple
NoNewPrivileges=yes
ProtectSystem=full
ProtectHome=true
WorkingDirectory=$WorkDir
ExecStartPre=/bin/test -f $WorkDir/compose.yaml
ExecStart=$DockerBin compose up
ExecStop=$DockerBin compose down
Restart=always
RestartSec=60
TimeoutStartSec=0
TimeoutStopSec=60
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

	printf "$CBB[INFO]$CBY - Serviço $CC$SvcName$CBY criado com sucesso em $CC$SvcFile$Reset\n"
done

printf "$CBG[SUCCESS]$CBY - Concluído! Para ativar e iniciar os serviços, escreva:\n\tsystemctl enable ${CC}<SERVIÇO>${CBY}\n\tsystemctl start ${CC}<SERVIÇO>$Reset\n"
