#!/bin/bash

# @ADRIAN V1.1 (28/11/23):
# O argumento -s / --sql-password agora automaticamente atualiza a senha em "/var/lib/asterisk/agi-bin/phonevox-customs" e "/var/www/html/voxura".
# 


# Variáveis para armazenar os valores padrão
CURRDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ----------------------------------------------------------------------------------------- #
# Tratação de argumentos.
#

function show_help() {
    echo "Usage: sudo ${BASH_SOURCE[0]} [options]"
    echo "Ex1: sudo bash ${BASH_SOURCE[0]} --sql-password=\"minhaSenhaSQL\" --com-login"
    echo "Ex2: sudo bash ${BASH_SOURCE[0]} -s=\"minhaSenhaSQL\" --sem-login"
    echo ''
    echo 'Options: (Itens marcados com "*" são obrigatórios)'
    echo '  -h, --help                     Exibe este menu de ajuda.'
    echo '* -s, --sql-password="<STRING>"  Senha do usuário root do MariaDB.'
    echo '* --com-login / --sem-login      Define se o módulo de avaliação necessita de Login (VIA AGENTE) ou não.'
    echo '  --force-fix-php-timezone       Ativa e/ou atualiza a timezone do php localizado em \"/etc/php.ini\" para "America/Sao_Paulo".'
}

if ! [[ $# -gt 0 ]]; then
  #  TRATAMENTO CASO SEJA EXECUTADO SEM ARGUMENTOS
  if [ ${#args[@]} -eq 0 ]; then
    show_help
    exit 0
  fi
fi

declare -A args
args+=()

# Necessário para não haver erros de duplicação, adicionando mais de uma vez à mesma var.
function add_arg() 
{
  local ARGUMENT=$1
  local VALUE=$2

  if [ -z "$VALUE" ] || [[ $VALUE == -* ]]; then # Conferindo se VALUE está vazio ou começa com "-". Caso seja o segundo caso, provavelmente é uma flag...
    echo "FATAL: Valor obrigatório para '$ARGUMENT'"
    exit 1
  fi
  #echo "[INFO] ADD_ARG: Valor de $1 -> ${args[$ARGUMENT]}"
  if [ ! ${args[$ARGUMENT]} ]; then
    args+=( [$ARGUMENT]=$2 )
    return 0
  else
    #echo "[DEBUG] ADD_ARG: Arg $1 já existe."
    #echo "[INFO] ADDARG: Lista de Args -> ${!args[@]}"
    return 1
  fi
}

# Processa os argumentos
while [[ $# -gt 0 ]]; do
  echo "tratando: $1 | $#"
  case "$1" in
    -s=*|--sql=*|--sql-password=*)
      add_arg "SQL_PASSWORD" ${1#*=}
    ;;
    --com-login)
      add_arg "LOGIN" true
    ;;
    --sem-login)
      add_arg "LOGIN" false
    ;;
    -f|--force-fix-php-timezone)
      add_arg "FIX_PHP" true
    ;;
    -h|--help|--ajuda)
      show_help
      exit 0
    ;;
    *)
      # Argumento desconhecido
      echo "FATAL: Argumento inválido: $1"
      exit 1
    ;;
  esac
  shift
done

if [ -z ${args[LOGIN]} ]; then
  echo "FATAL: Argumento obrigatório: repasse se os ramais fazem login ou não na central!"
  exit 1
fi

if [ -z ${args[SQL_PASSWORD]} ]; then
  echo "FATAL: Argumento obrigatório: repasse a senha do banco de dados!"
  exit 1
fi

FALEVOX_LOGO_ART="
          ###                      #######                                                                              
     ###########                  (#######                                                                              
    ########,  #                  (#######                                               %%%(                           
    ########        ########      (#######       ######                            %%%%%%%%%%%%%%%                      
################ ###############  (#######   ##############. ########     ########%%%           %%%%########  ########  
 ############### ####    ######## (####### (#######   ####### #######    ########%%               %%%%###############   
    ########       ############## (####### ################### #######  ,#######%%/                %%%%############     
    ########    ################# (####### ################### .####### #######%%%%  (             %%%% ###########     
    ########   #######    ####### (####### #######              ############## %%%%   %       %   %%%%(#############    
    ########   ################## (#######  ################     ############   %%%%%.           %%%%######## ########  
    ########    ################# (#######     #############      ##########      %%%%%%%%%  %%%%%%*#######    ######## 
                                                                                      %%%%%%%%%                         "

# DECLARAÇÃO DE VARIÁVEIS <------------------>
CURRDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILENAME_TIMESTAMP=$(date '+%Y-%m-%d-%H%M%S') # 0000-11-22-334455
LOG_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')   # 0000-11-22 33:44:55

DIR_ASTERISK_SOUNDS=/var/lib/asterisk/sounds
DIR_ASTERISK_AGIBIN=/var/lib/asterisk/agi-bin
DIR_ASTERISK_EXTENSIONS=/etc/asterisk
DIR_ASTERISK_PHP=/var/www/html

# PASTA DE BACKUP PARA ESTA INSTALAÇÃO
BKPFOLDER_NAME="bkp" # Nome (prefixo) pra pasta de backup. "bkp-0000-11-22-334455"
BKPFOLDER="$BKPFOLDER_NAME-$FILENAME_TIMESTAMP"
PATH_BKPFOLDER="$CURRDIR/$BKPFOLDER"

make_backup () {
  local INPUT=$1
  local BACKUP_FOLDER_PATH=$2
  local DELETE_INPUT_AFTER=$3
  local CLEANED_NAME=$(echo "$INPUT" | tr -s '[:punct:]' '_' | sed 's/^_//;s/_$//') # /var/lib/asterisk/ -> var_lib_asterisk (remove trailing)
  local CURRENT_TIME=$(date +"%Y%m%d%H%M%S")
  local OUTPUT="$BACKUP_FOLDER_PATH/${CLEANED_NAME}_${CURRENT_TIME}.bkp"

  # Verificando se é arquivo ou diretório
  if [ -d $INPUT ]; then
    BKP_TYPE=d
    :
  elif [ -f $INPUT ]; then
    BKP_TYPE=f
    :
  else
    log "FATAL: '$INPUT' Não existe."
    exit 1
  fi

  # Verifica se o diretório de backup existe e o cria se não existir
  if [ ! -d "$BACKUP_FOLDER_PATH" ]; then
    log "INFO: Criando $BACKUP_FOLDER_PATH"
    mkdir -p "$BACKUP_FOLDER_PATH"
  fi

  if ! [ -$BKP_TYPE "$OUTPUT" ]; then
    log "SALVANDO: $1 -> $OUTPUT"
    cp -R $INPUT $OUTPUT
    if $DELETE_INPUT_AFTER; then
      log "DELETANDO: $1"
      rm -rf $INPUT
    fi
  else
    log "WARNING: '($BKP_TYPE) $OUTPUT' Já existe."
  fi
  
}

# LOGGING
LOGFILE_NAME="avaliacao-installer" # Nome (prefixo) pro arquivo de log. "log-0000-11-22.log"
LOGFILE="$LOGFILE_NAME-$(date '+%Y-%m-%d').log"
if ! [ -f "$LOGFILE" ]; then # checa se o arquivo de log já existe
        echo -e "[$LOG_TIMESTAMP] Iniciando novo logfile" > $LOGFILE
fi

# DECLARAÇÃO DE FUNÇÕES ÚTEIS <--------------------->
log () {
echo -e "[$LOG_TIMESTAMP] $1" >> $LOGFILE
echo -e "[$LOG_TIMESTAMP] $1"
}

# Checa se diretório existe. Retorna true/false
dExists () {
    [ -d "$1" ]
}

# Checa se file existe. Retorna true/false
fExists () {
    [ -f "$1" ]
}

rpm_is_installed () {
    rpm -q $1 > /dev/null 2>&1
    return $?
}

text_in_file () {
  TEXT_TO_SEARCH=$1
  FILE_TO_SEARCH=$2

  if [ -f $FILE_TO_SEARCH ]; then
    cat $FILE_TO_SEARCH | grep "$TEXT_TO_SEARCH" > /dev/null 2>&1
    return $?
  else # file does not exist
    return 1
  fi
}

can_edit_dir () {
  if touch $1/tempfile >/dev/null 2>&1; then
    rm $1/tempfile
    return 0
  fi
  return 1
}

colorir () {
    declare -A cores
    local cores=(
        [preto]="0;30"
        [vermelho]="0;31"
        [verde]="0;32"
        [amarelo]="0;33"
        [azul]="0;34"
        [magenta]="0;35"
        [ciano]="0;36"
        [branco]="0;37"
        [preto_claro]="1;30"
        [vermelho_claro]="1;31"
        [verde_claro]="1;32"
        [amarelo_claro]="1;33"
        [azul_claro]="1;34"
        [magenta_claro]="1;35"
        [ciano_claro]="1;36"
        [branco_claro]="1;37"
    )

  local cor=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  local texto=$2
  local string='${cores['"\"$cor\""']}'
  eval "local cor_ansi=$string"
  local cor_reset="\e[0m"

  if [[ -z "$cor_ansi" ]]; then
    cor_ansi=${cores["branco"]}  # Cor padrão, caso a cor seja inválida
  fi

  # Imprimir o texto com a cor selecionada
  echo -e "\e[${cor_ansi}m${texto}${cor_reset}"
}

arte () {
	local asciiart="$1"
	local IFS=$'\n'
	for line in $asciiart; do
		echo "$line"
	done
	echo ""
	echo ""
}

# // -------------- Declaração das funções principais do installer.

realizar_verificacoes_sistema () {

  check_and_set () {
    local CHECK_PATH=$1
    local SET=$2

    # Verificando se é arquivo ou diretório
    if [ -d $CHECK_PATH ]; then
      local TYPE=d
      :
    elif [ -f $CHECK_PATH ]; then
      local TYPE=f
      :
    else
      # echo "Verificando '$CHECK_PATH' para setar a variável '$SET'"
      # echo "Parece que não é nem diretório nem arquivo, o que indica que o arquivo não existe!"
      eval "$SET=false"
      return 1
    fi

    if [ -$TYPE $CHECK_PATH ]; then
      eval "$SET=true"
      return 0
    else
      eval "$SET=false"
      return 1
    fi

  }

  # Verificando se o módulo call-center está instalado.
  if rpm_is_installed "issabel-callcenter"; then
    CALLCENTER_INSTALADO=true
  else
    CALLCENTER_INSTALADO=false
  fi
  log "CALLCENTER INSTALADO: $CALLCENTER_INSTALADO"


  # Verificando se os sub-diretórios padrões do Asterisk existen
  # Explicação:
  # Preciso confirmar que os diretórios do Asterisk existam, para que eu possa prosseguir.
  # Caso eles não existam, erros catastróficos podem acontecer.
  check_and_set "$DIR_ASTERISK_SOUNDS"     "DIR_AST_SOUNDS_EXISTS"
  check_and_set "$DIR_ASTERISK_AGIBIN"     "DIR_AST_AGIBIN_EXISTS"
  check_and_set "$DIR_ASTERISK_EXTENSIONS" "DIR_AST_EXTEN_EXISTS"
  check_and_set "$DIR_ASTERISK_PHP"        "DIR_AST_PHP_EXISTS"

  
  # Verificando se os diretórios ANTIGOS de avaliacao existem
  # Explicação:
  # Preciso confirmar se os diretórios antigos existam, para que eu possa salvá-los, e excluí-los do fluxo.
  # O motivo disso é porque renomeei a pasta, então, não quero subir arquivos duplicados pro PABX.
  # Essa verificação é mais para uma questão de limpeza do que utilidade, com exceção da pasta EXTEN que realmetne não pode existir
  # Devido a contextos duplicados.
  check_and_set "$DIR_ASTERISK_SOUNDS/phonevox"     "DIR_OLD_SOUNDS_PHONEVOX_EXISTS"
  check_and_set "$DIR_ASTERISK_AGIBIN/phonevox"     "DIR_OLD_AGIBIN_PHONEVOX_EXISTS"
  check_and_set "$DIR_ASTERISK_EXTENSIONS/phonevox" "DIR_OLD_EXTEN_PHONEVOX_EXISTS"
  check_and_set "$DIR_ASTERISK_PHP/voxura"          "DIR_OLD_VOXURA_EXISTS"


  # Verificando se os diretórios NOVOS de avaliacao existem
  # Explicação:
  # Preciso saber se já não tem a versão atualizada do avaliacao instalado
  # O motivo disso é pra eu não subir uma instalação por cima de outra, sem perguntar.
  check_and_set "$DIR_ASTERISK_SOUNDS/phonevox-customs"     "DIR_NEW_SOUNDS_PHONEVOX_EXISTS"
  check_and_set "$DIR_ASTERISK_AGIBIN/phonevox-customs"     "DIR_NEW_AGIBIN_PHONEVOX_EXISTS"
  check_and_set "$DIR_ASTERISK_EXTENSIONS/phonevox-customs" "DIR_NEW_EXTEN_PHONEVOX_EXISTS"
  # não consigo fazer essa checagem pra voxura, visto que não renomeei :D


  # Verificando se puxei a pasta files
  # Explicação:
  # A pasta PRECISA existir, pois ela contém os arquivos que vou upar.
  check_and_set "$CURRDIR/files" "DIR_SCP_EXISTS"


  # Verificando se tem o INCLUDE antigo
  # Explicação:
  # Essa linha precisa ser deletada, porque o contexto aproprioado à ela não vai mais existir, e como não é um tryinclude, vai causar
  # um erro catastrófico pra bootar o Asterisk.
  local EXTEN_CUSTOM_FILE=$DIR_ASTERISK_EXTENSIONS/extensions_custom.conf
  local INCLUDE_LINE="include phonevox/avaliacao-atendimento.conf"
  
  if text_in_file "$INCLUDE_LINE" "$EXTEN_CUSTOM_FILE"; then
    HAS_OLD_INCLUDE=true
  else
    HAS_OLD_INCLUDE=false
  fi

  # Verificando se tem o INCLUDE novo
  # Explicação:
  # Não quero adicionar a linha duas vezes, então vou verificar se o módulo já tá instalado, pelo phonevox-customs.
  if text_in_file "mod-avaliacao-atendimento" "$DIR_ASTERISK_EXTENSIONS/phonevox-customs/modules.conf"; then
    HAS_NEW_INCLUDE=true
  else
    HAS_NEW_INCLUDE=false
  fi

  
}

confirmar_verificacoes () {
  # Definindo as tags a serem usadas nas mensagens de ERRO/SUCESSO
  OK_TAG="[ $(colorir "verde" "OK") ]"
  ERR_TAG="[$(colorir "vermelho" "ERRO")]"
  TODO_TAG="[$(colorir "magenta_claro" "TODO")]"

  # Defino aqui um array com o nome da variável, e o seu valor esperado (o que espero ter nessa variável)
  declare -A expected_values
  expected_values=(
    # NUCLEO (são as pastas núcleo do sistema. DEVEM existir pro funcionamento da central ( a não ser que seu default foi alterado))
    ["DIR_AST_SOUNDS_EXISTS"]=true
    ["DIR_AST_AGIBIN_EXISTS"]=true
    ["DIR_AST_EXTEN_EXISTS"]=true
    # ANTIGOS (não importa muito, porque vou fazer backup e sobreescrever)
    ["HAS_OLD_INCLUDE"]=false
    ["DIR_OLD_SOUNDS_PHONEVOX_EXISTS"]=false
    ["DIR_OLD_AGIBIN_PHONEVOX_EXISTS"]=false
    ["DIR_OLD_EXTEN_PHONEVOX_EXISTS"]=false
    ["DIR_OLD_VOXURA_EXISTS"]=false
    # NOVOS (o esperado é ser falso, mas se já existir, dropo um prompt perguntando se quer sobreescrever (faço backup e sobreescrevo))
    ["HAS_NEW_INCLUDE"]=false
    ["DIR_NEW_SOUNDS_PHONEVOX_EXISTS"]=false
    ["DIR_NEW_AGIBIN_PHONEVOX_EXISTS"]=false
    ["DIR_NEW_EXTEN_PHONEVOX_EXISTS"]=false
    # SCP (é essencial essa pasta existir.)
    ["DIR_SCP_EXISTS"]=true
    # OUTROS (callcenter tanto faz, old_include tanto faz, new_include não pode existir pelo motivo do #Novos)
    ["CALLCENTER_INSTALADO"]=true
  )

  # Definindo o array com o nome da variável, e a mensagem de SUCESSO associado à ela
  declare -A expected_results
  expected_results=(
    # NUCLEO
    ["DIR_AST_SOUNDS_EXISTS"]="$OK_TAG DIR_ASTERISK_SOUNDS"
    ["DIR_AST_AGIBIN_EXISTS"]="$OK_TAG DIR_ASTERISK_AGIBIN"
    ["DIR_AST_EXTEN_EXISTS"]="$OK_TAG DIR_ASTERISK_EXTENSIONS"
    # ANTIGOS
    ["HAS_OLD_INCLUDE"]="$OK_TAG HAS_OLD_INCLUDE"
    ["DIR_OLD_SOUNDS_PHONEVOX_EXISTS"]="$OK_TAG DIR_OLD_SOUNDS_PHONEVOX"
    ["DIR_OLD_AGIBIN_PHONEVOX_EXISTS"]="$OK_TAG DIR_OLD_AGIBIN_PHONEVOX"
    ["DIR_OLD_EXTEN_PHONEVOX_EXISTS"]="$OK_TAG DIR_OLD_EXTEN_PHONEVOX"
    ["DIR_OLD_VOXURA_EXISTS"]="$OK_TAG DIR_OLD_VOXURA"
    # NOVOS
    ["HAS_NEW_INCLUDE"]="$OK_TAG HAS_NEW_INCLUDE"
    ["DIR_NEW_SOUNDS_PHONEVOX_EXISTS"]="$OK_TAG DIR_NEW_SOUNDS_PHONEVOX"
    ["DIR_NEW_AGIBIN_PHONEVOX_EXISTS"]="$OK_TAG DIR_NEW_AGIBIN_PHONEVOX"
    ["DIR_NEW_EXTEN_PHONEVOX_EXISTS"]="$OK_TAG DIR_NEW_EXTEN_PHONEVOX"
    # SCP
    ["DIR_SCP_EXISTS"]="$OK_TAG DIR_SCP"
    # OUTROS
    ["CALLCENTER_INSTALADO"]="$OK_TAG CALLCENTER_INSTALADO"
  )

  # Semelhante acima, definindo o array com o nome da variável, e a mensagem de ERRO associado à ela.
  declare -A error_messages
  error_messages=(
    # NUCLEO
    ["DIR_AST_SOUNDS_EXISTS"]="$ERR_TAG DIR_ASTERISK_SOUNDS"
    ["DIR_AST_AGIBIN_EXISTS"]="$ERR_TAG DIR_ASTERISK_AGIBIN"
    ["DIR_AST_EXTEN_EXISTS"]="$ERR_TAG DIR_ASTERISK_EXTENSIONS"
    # ANTIGOS
    ["HAS_OLD_INCLUDE"]="$TODO_TAG HAS_OLD_INCLUDE $(colorir "magenta_claro" "-> Linha de include será removida.")"
    ["DIR_OLD_SOUNDS_PHONEVOX_EXISTS"]="$TODO_TAG DIR_OLD_SOUNDS_PHONEVOX $(colorir "magenta_claro" "-> O diretório será salvo e substituido.")"
    ["DIR_OLD_AGIBIN_PHONEVOX_EXISTS"]="$TODO_TAG DIR_OLD_AGIBIN_PHONEVOX $(colorir "magenta_claro" "-> O diretório será salvo e substituido.")"
    ["DIR_OLD_EXTEN_PHONEVOX_EXISTS"]="$TODO_TAG DIR_OLD_EXTEN_PHONEVOX $(colorir "magenta_claro" "-> O diretório será salvo e substituido.")"
    ["DIR_OLD_VOXURA_EXISTS"]="$TODO_TAG DIR_OLD_VOXURA $(colorir "magenta_claro" "-> O diretório será salvo e substituido.")"
    # NOVOS
    ["HAS_NEW_INCLUDE"]="$ERR_TAG HAS_NEW_INCLUDE $(colorir "amarelo_claro" "-> Parece que a avaliacao-atendimento já está instalada.")"
    ["DIR_NEW_SOUNDS_PHONEVOX_EXISTS"]="$ERR_TAG DIR_NEW_SOUNDS_PHONEVOX $(colorir "amarelo_claro" "-> Parece que a avaliacao-atendimento já está instalada.")"
    ["DIR_NEW_AGIBIN_PHONEVOX_EXISTS"]="$ERR_TAG DIR_NEW_AGIBIN_PHONEVOX $(colorir "amarelo_claro" "-> Parece que a avaliacao-atendimento já está instalada.")"
    ["DIR_NEW_EXTEN_PHONEVOX_EXISTS"]="$ERR_TAG DIR_NEW_EXTEN_PHONEVOX $(colorir "amarelo_claro" "-> Parece que a avaliacao-atendimento já está instalada.")"
    # SCP
    ["DIR_SCP_EXISTS"]="$ERR_TAG DIR_SCP"
    # OUTROS
    ["CALLCENTER_INSTALADO"]="$TODO_TAG CALLCENTER_INSTALADO $(colorir "magenta_claro" "-> O módulo issabel-callcenter será instalado.")"
  )

  # Semelhante acima, definindo um array com o nome da variável, e se precisa ENCERRAR O SCRIPT caso o valor não seja o esperado.
  declare -A needs_stop
  needs_stop=(
    # NUCLEO
    ["DIR_AST_SOUNDS_EXISTS"]=true
    ["DIR_AST_AGIBIN_EXISTS"]=true
    ["DIR_AST_EXTEN_EXISTS"]=true
    # ANTIGOS
    ["HAS_OLD_INCLUDE"]=false
    ["DIR_OLD_SOUNDS_PHONEVOX_EXISTS"]=false
    ["DIR_OLD_AGIBIN_PHONEVOX_EXISTS"]=false
    ["DIR_OLD_EXTEN_PHONEVOX_EXISTS"]=false
    ["DIR_OLD_VOXURA_EXISTS"]=false
    # NOVOS (pergunto se quer sobreescrever. se sim, faço um backup e sobreescrevo)
    ["HAS_NEW_INCLUDE"]=false
    ["DIR_NEW_SOUNDS_PHONEVOX_EXISTS"]=false
    ["DIR_NEW_AGIBIN_PHONEVOX_EXISTS"]=false
    ["DIR_NEW_EXTEN_PHONEVOX_EXISTS"]=false
    # SCP
    ["DIR_SCP_EXISTS"]=true
    # OUTROS
    ["CALLCENTER_INSTALADO"]=false
  )

  # Função para exibir resultados com base nas variáveis e valores esperados
  show_result() {
    local var_name="$1"
    local needs_stop="${needs_stop[$var_name]}"
    local expected_value="${expected_values[$var_name]}"

    if eval "[[ \${$var_name} == $expected_value ]]"; then
      log "${expected_results[$var_name]}"
    else
      log "${error_messages[$var_name]}"
      if $needs_stop; then
        log "-- Setando finalização de sessão devido a valor inesperado em: $var_name --"
        END_SESSION=true
      fi
    fi
  }

  # Iterar sobre as variáveis e exibir os resultados

  IFS=$'\n'
  sorted=($(sort <<<"${!expected_results[*]}"))

  for var_name in ${sorted[@]}; do
    show_result "$var_name"
  done

  # Verificar se a sessão deve ser encerrada
  if [ $END_SESSION ]; then
    exit 1
  fi

  # Caso tenha a instalação nova já instalada aqui, vou perguntar se quer (salvar e) sobreescrever
  if $HAS_NEW_INCLUDE || $DIR_NEW_SOUNDS_PHONEVOX_EXISTS || $DIR_NEW_AGIBIN_PHONEVOX_EXISTS || $DIR_NEW_EXTEN_PHONEVOX_EXISTS; then
    pergunta_sobreescrever_news
  fi

  # Caso tenha a instalação antiga, excecuta isso
  if $HAS_OLD_INCLUDE || $DIR_OLD_SOUNDS_PHONEVOX_EXISTS || $DIR_OLD_AGIBIN_PHONEVOX_EXISTS || $DIR_OLD_EXTEN_PHONEVOX_EXISTS || $DIR_OLD_VOXURA_EXISTS; then
    :
  fi

}

pergunta_sobreescrever_news () {
  echo "" # Espacinho rsrs
  while true; do
    echo "Foi identificado que a instalação 'phonevox-customs' já existe nesse host. Quer sobreescrever? (s/n)"
    echo ""

    REPLACE_NEW_INSTALL=false

    read escolha

    # Converter a entrada do usuário para letras minúsculas
    escolha_lowercase=$(echo "$escolha" | tr '[:upper:]' '[:lower:]')

    case "$escolha_lowercase" in
      s|sim|y|yes)
      REPLACE_NEW_INSTALL=true
      break
      ;;
      n|nao|no)
      echo "Cancelando."
      exit 1
      ;;
      *)
      echo "Opção inválida."
      echo ""
      ;;
    esac
  done

}

executar_alteracoes_servidor () {

  pergunta_senha_database () {
    echo ""
    echo "Para a criação da tabela de avaliações no banco de dados, digite a senha do usuário root do banco de dados, ou escolha:"
    echo "1. Tabela de avaliação já existe"
    echo "2. Cancelar"
    echo "PS: Por segurança, o que você digitar estará oculto!"
    echo ""
    SKIP_TABLE_CREATION=false

    read -s DATABASE_PASSWORD
    case "$DATABASE_PASSWORD" in
      *)
      echo "<$(colorir "verde_claro" "Com a criação da tabela")>"
      ;;
      1)
      echo "<$(colorir "vermelho_claro" "Sem a criação da tabela")>"
      SKIP_TABLE_CREATION=true
      ;;
      2)
      echo "Cancelando..."
      exit 1
      ;;
    esac
  }

  instalar_mod_callcenter () {
    log "# Módulo callcenter"
    if ! $CALLCENTER_INSTALLED; then
      log "- $(colorir "ciano_claro" "Instalando o módulo callcenter".)"
      yum install -y issabel-callcenter
    else
      log "- Módulo callcenter já está instalado, prosseguindo."
    fi
  }

  alter_sounds () { # First.1
    
    log "# Alterando SOUNDS"

    if ! can_edit_dir "$DIR_ASTERISK_SOUNDS"; then # Checando permissão.
      log "FATAL: Não há permissão para editar '$DIR_ASTERISK_SOUNDS'."
      exit 1
    fi

    if $DIR_NEW_SOUNDS_PHONEVOX_EXISTS; then # Salvar e liberar pasta NOVA.
      log "- $(colorir "ciano_claro" "A pasta '$DIR_ASTERISK_SOUNDS/phonevox-customs' (sounds/NEW) já existe, salvando e removendo")."
      make_backup "$DIR_ASTERISK_SOUNDS/phonevox-customs" "$PATH_BKPFOLDER"
      rm -rf $DIR_ASTERISK_SOUNDS/phonevox-customs
    fi

    if $DIR_OLD_SOUNDS_PHONEVOX_EXISTS; then # Salvar e liberar pasta ANTIGA.
      log "- $(colorir "ciano_claro" "A pasta '$DIR_ASTERISK_SOUNDS/phonevox' (sounds/OLD) já existe, salvando e removendo")."
      make_backup "$DIR_ASTERISK_SOUNDS/phonevox" "$PATH_BKPFOLDER"
      rm -rf $DIR_ASTERISK_SOUNDS/phonevox
    fi

    # Nem a pasta antiga, nem a nova existe. Posso mover de forma tranquila a pasta SCP pro destino.
    log "- $(colorir "azul_claro" "Copiando arquivos ao destino")."
    mkdir -p "$DIR_ASTERISK_SOUNDS/phonevox-customs"
    cp -Rv $CURRDIR/files/sounds/* $DIR_ASTERISK_SOUNDS/ # verbose copy
  }

  alter_agi () { # Second.2

    log "# Alterando AGI"
  
    if ! can_edit_dir "$DIR_ASTERISK_AGIBIN"; then # Checando permissão.
      log "FATAL: Não há permissão para editar '$DIR_ASTERISK_AGIBIN'."
      exit 1
    fi

    if $DIR_NEW_AGIBIN_PHONEVOX_EXISTS; then # Salvar e liberar pasta NOVA.
      log "- $(colorir "ciano_claro" "A pasta '$DIR_ASTERISK_AGIBIN/phonevox-customs' (agibin/NEW) já existe, salvando e removendo")."
      make_backup "$DIR_ASTERISK_AGIBIN/phonevox-customs" "$PATH_BKPFOLDER"
      rm -rf $DIR_ASTERISK_AGIBIN/phonevox-customs
    fi

    if $DIR_OLD_AGIBIN_PHONEVOX_EXISTS; then # Salvar e liberar pasta ANTIGA.
      log "- $(colorir "ciano_claro" "A pasta '$DIR_ASTERISK_AGIBIN/phonevox' (agibin/OLD) já existe, salvando e removendo")."
      make_backup "$DIR_ASTERISK_AGIBIN/phonevox" "$PATH_BKPFOLDER" true # Salva e deleta
      rm -rf $DIR_ASTERISK_AGIBIN/phonevox
    fi

    # Nem a pasta antiga, nem a nova existe. Posso mover de forma tranquila a pasta SCP pro destino.
    log "- $(colorir "azul_claro" "Copiando arquivos ao destino")."
    mkdir -p "$DIR_ASTERISK_AGIBIN/phonevox-customs"

    if ${args['LOGIN']}; then # Copiando a agibin/SCP correta.
      cp -Rv $CURRDIR/files/agi-login/* $DIR_ASTERISK_AGIBIN/
    else
      cp -Rv $CURRDIR/files/agi-nologin/* $DIR_ASTERISK_AGIBIN/
    fi

    # V1.1: Alterando a senha do DATABASE
    log "- 'sed SENHA_DO_DATABASE -> ${args[SQL_PASSWORD]}' $DIR_ASTERISK_AGIBIN/phonevox-customs/insert_note.php"
    sed -i "s/SENHA_DO_DATABASE/${args[SQL_PASSWORD]}/g" $DIR_ASTERISK_AGIBIN/phonevox-customs/insert_note.php

    log "- chmod '$DIR_ASTERISK_AGIBIN/phonevox-customs'"
    chmod -R 755 $DIR_ASTERISK_AGIBIN/phonevox-customs
  }

  alter_extensions () { # Third.3

    log "# Alterando EXTENSIONS"

    if ! can_edit_dir "$DIR_ASTERISK_EXTENSIONS"; then # Checando permissão.
      log "FATAL: Não há permissão para editar '$DIR_ASTERISK_EXTENSIONS'."
      exit 1
    fi

    if $DIR_NEW_EXTEN_PHONEVOX_EXISTS; then # Salvar e liberar pasta NOVA.
      log "- $(colorir "ciano_claro" "A pasta '$DIR_ASTERISK_EXTENSIONS/phonevox-customs' (exten/NEW) já existe, salvando e removendo")."
      make_backup "$DIR_ASTERISK_EXTENSIONS/phonevox-customs" "$PATH_BKPFOLDER" true # Salva e deleta
    fi

    if $DIR_OLD_EXTEN_PHONEVOX_EXISTS; then # Salvar e liberar pasta ANTIGA.
      log "- $(colorir "ciano_claro" "A pasta '$DIR_ASTERISK_EXTENSIONS/phonevox' (exten/OLD) já existe, salvando e removendo")."
      make_backup "$DIR_ASTERISK_EXTENSIONS/phonevox" "$PATH_BKPFOLDER" true # Salva e deleta
    fi

    # Nem a pasta antiga, nem a nova existe. Posso mover de forma tranquila a pasta SCP pro destino.
    log "- $(colorir "azul_claro" "Copiando arquivos ao destino")."
    mkdir -p "$DIR_ASTERISK_EXTENSIONS/phonevox-customs"
    cp -Rv $CURRDIR/files/extensions/* $DIR_ASTERISK_EXTENSIONS/
  }

  alter_include () { # Fourth.4 ----------------------------------------- ARRUMAR ISSO AQUI <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    if $HAS_OLD_INCLUDE; then
      log "- Tem a linha de include do avaliacao antigo. Vou editar pra nova."
      sed -i 's/^#include phonevox\/avaliacao_atendimento\.conf/#tryinclude phonevox-customs\/avaliacao_atendimento.conf/' $DIR_ASTERISK_EXTENSIONS/extensions_custom.conf
    else
      log "- Adicionando include phonevox-customs."
      echo '#tryinclude phonevox-customs/avaliacao_atendimento.conf' | tee -a $DIR_ASTERISK_EXTENSIONS/extensions_custom.conf
    fi
  }

  alter_voxura () { # Fifth.5

    log "# Alterando VOXURA"

    if ! can_edit_dir "$DIR_ASTERISK_PHP"; then # Checando permissão.
      log "FATAL: Não há permissão para editar '$DIR_ASTERISK_PHP'."
      exit 1
    fi

    if $DIR_OLD_VOXURA_EXISTS; then # Salvar e liberar pasta. Não sei se é antiga ou nova, vou dar replace de qualquer maneira.
      log "- $(colorir "ciano_claro" "A pasta '$DIR_ASTERISK_PHP/voxura' já existe, salvando e removendo")."
      make_backup "$DIR_ASTERISK_PHP/voxura" "$PATH_BKPFOLDER"
      rm -rf $DIR_ASTERISK_PHP/voxura
    fi

    # A pasta antiga não existe. Posso mover de forma tranquila.
    log "- $(colorir "azul_claro" "Copiando arquivos ao destino")."
    mkdir -p "$DIR_ASTERISK_PHP/voxura"
    cp -Rv $CURRDIR/files/php/* $DIR_ASTERISK_PHP/

    # V1.1: Alterando a senha do DATABASE
    log "- 'sed SENHA_DO_DATABASE -> ${args[SQL_PASSWORD]}' $DIR_ASTERISK_PHP/voxura/recording.php"
    sed -i "s/SENHA_DO_DATABASE/${args[SQL_PASSWORD]}/g" $DIR_ASTERISK_PHP/voxura/recording.php
    log "- 'sed SENHA_DO_DATABASE -> ${args[SQL_PASSWORD]}' $DIR_ASTERISK_PHP/voxura/conn.inc.php"
    sed -i "s/SENHA_DO_DATABASE/${args[SQL_PASSWORD]}/g" $DIR_ASTERISK_PHP/voxura/conn.inc.php
    log "- 'sed SENHA_DO_DATABASE -> ${args[SQL_PASSWORD]}' $DIR_ASTERISK_PHP/voxura/config.php"
    sed -i "s/SENHA_DO_DATABASE/${args[SQL_PASSWORD]}/g" $DIR_ASTERISK_PHP/voxura/config.php
  }

  alter_database () { # Sixth.6
    
    log "# Verificando DATABASE"

    log "- $(colorir "ciano_claro" "Criando, caso não exista, a tabela 'pesquisa'")."

    # 10/10/23 09:15 | Note: alguma hora, fazer uma checagem se isso aqui deu certo, visto que é essencial.
    mysql -uroot -p${args[SQL_PASSWORD]} avaliacao -e "CREATE TABLE IF NOT EXISTS pesquisa (info1 varchar(100), info2 varchar(100), info3 varchar(100), info4 varchar(100), info5 varchar(100), info6 varchar(100), datetime datetime)";
  }

  alter_register_module () {
    log "# Registrando a adição do módulo no phonevox-customs."

    # Confirmando que a pasta de extensions/phonevox-customs existe antes de prosseguir.
    if ! dExists "$DIR_ASTERISK_EXTENSIONS/phonevox-customs"; then # Confirma que a pasta-destino existe.
      log "FATAL: Pasta-destino do arquivo de módulos não existe. '$DIR_ASTERISK_EXTENSIONS/phonevox-customs'"
      exit 1
    fi

    log "- $(colorir "ciano_claro" "Registrando módulo")..."
    echo 'mod-avaliacao-atendimento' | tee -a $DIR_ASTERISK_EXTENSIONS/phonevox-customs/modules.conf >/dev/null 2>&1
  }

  verify_phpini () { # Seventh.7

    # V1.1: Consulta se timezone do PHP está de acordo (deve estar date.timezone = America/Sao_Paulo, a baixo da área "[Date]")
    # OBS: A área em que ele está NÃO É consultada. Se date.timezone existir, em outra área, causará problemas. Parece inviável isso acontecer então não vou me preocupar com isso no momento.

    PHP_INI_PATH=/etc/php.ini
    QTD_DATE_TIMEZONE=$(cat $PHP_INI_PATH 2>&1 | grep "^date.timezone" | wc -l)

    log "# Validando a timezone do PHP."

    if [ "$QTD_DATE_TIMEZONE" -eq 1 ]; then  # TEM EXATAMENTE 1 VALOR DE TIMEZONE

      DATE_TIMEZONE_VALUE=$(cat $PHP_INI_PATH 2>&1 | grep "^date.timezone" | awk -F"=" '{print $NF}' | awk '{$1=$1};1')
      TIMEZONE="America/Sao_Paulo"
        
      if [[ ! "$DATE_TIMEZONE_VALUE" == "$TIMEZONE" ]]; then
        log "- $(colorir "amarelo" "WARN"): A timezone setada em \"$PHP_INI_PATH\" é diferente da esperada. ('$DATE_TIMEZONE_VALUE' != '$TIMEZONE')"
      else
        log "- $(colorir "ciano_claro" "Timezone já se encontra correta")."
        : # Já tá setado, e tem o valor que eu queria.
      fi

    elif [ "$QTD_DATE_TIMEZONE" -gt 1 ]; then # TEM MAIS DE UM VALOR DE TIMEZONE POR ALGUM MOTIVO....
      log "FATAL: Há múltiplos 'date.timezone' em seu '$PHP_INI_PATH' (QTD:'$QTD_DATE_TIMEZONE'). Não foi alterado nada: verifique manualmente!"
      exit 1
    else # TIMEZONE ESTÁ COMENTADO OU NÃO EXISTE. INSERINDO.
      if [[ ${args[FIX_PHP]} ]]; then
        log "- $(colorir "azul_claro" "Inserindo timezone America/Sao_Paulo e reiniciando apachectl...")"
        sed -i '/^\[Date\]/a date.timezone = America/Sao_Paulo' "$PHP_INI_PATH"
        apachectl restart
      fi
    fi

  }

  instalar_mod_callcenter
  alter_sounds
  alter_agi
  alter_extensions
  alter_include
  alter_voxura
  alter_database
  alter_register_module
  verify_phpini

  asterisk -rx 'dialplan reload' > /dev/null 2>&1
  
}

finalizar () {
  log "# $(colorir "verde" "Instalação finalizada")!"
  echo ""
  echo "Crie as seguintes CUSTOM DESTINATIONS:"
  echo ""
  echo "avaliacao_atendimento,s,1"
  echo "AVALIACAO ATENDIMENTO"
  echo ""

}

#!/bin/bash

# Função para criar o banco de dados e tabela
criar_banco_e_tabela() {
  # Configurações do banco
  DB_HOST="localhost"
  DB_USER="root"
  DB_PASS="${args[SQL_PASSWORD]}"
  DB_NAME="avaliacao"

  # Comandos SQL para criar o banco e a tabela
  SQL="
CREATE DATABASE IF NOT EXISTS $DB_NAME;

USE $DB_NAME;

CREATE TABLE IF NOT EXISTS pesquisa (
    info1 VARCHAR(100) DEFAULT NULL,
    info2 VARCHAR(100) DEFAULT NULL,
    info3 VARCHAR(100) DEFAULT NULL,
    info4 VARCHAR(100) DEFAULT NULL,
    info5 VARCHAR(100) DEFAULT NULL,
    info6 VARCHAR(100) DEFAULT NULL,
    datetime DATETIME DEFAULT NULL
);
  "
  # Executando comandos no MySQL
  echo "Criando banco de dados e tabela..."
  mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "$SQL"

main () {
  # Código a ser executado:

  clear
  arte "$FALEVOX_LOGO_ART"
  realizar_verificacoes_sistema
  confirmar_verificacoes
  executar_alteracoes_servidor
  criar_banco_e_tabela

  finalizar
}

main


