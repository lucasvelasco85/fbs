#!/bin/bash

#############################
######## Parâmetros #########
#############################

# Script 

TODAY=$(date +%d-%m-%Y) # Hoje, formato mm-dd-yyyy
YESTERDAY=$(date --date "1 day ago" +%d-%m-%Y) # Ontem, formato mm-dd-yyyy
DAYOFWEEK=$(date +%u) # Dia de hoje, formato 1 a 7
DAYOFFULLBACKUP="6" # Dia da realizacao do backup full (7 = Domingo)
KEEPING_DAYS="7" # Dias para manter os backup

# Parâmetros do backup de arquivos
### Diretorios de Origem do backup
BACKUP_SOURCE=""

### Diretorio de destino do backup de arquivos
FILE_BACKUP_DIR=""

### Diretório do espelho de dados
MIRROR=""

# Backup de Banco de dados Firebird

BD_BACKUP_DIR=""
FB_DIR=""
FDB_FILES=""
FB_USER=""
FB_PASS=""


# Tipo de backup:
# 0 = Não realizar backup;
# 1 = Backup de arquivos;
# 2 = Backup de arquivos + espelho de dados;
# 3 = Backup de banco de dados Firebird;
# 4 = Backup total (Arquivos e BD Firebird)
# 5 = Backup total (Arquivos e BD Firebird) + Espelho 

BACKUP_TYPE=""

# Arquivos de Log

FILE_LOGFILE="$FILE_BACKUP_DIR/$TODAY/backup.$TODAY.log"
BD_LOGFILE="$BD_BACKUP_DIR/$TODAY/backup.$TODAY.log"
MIRROR_LOGFILE="$MIRROR/mirror.$TODAY.log"

main(){

	case "$BACKUP_TYPE" in
		"0") logger "Parâmetro ajustado para não realizar backup, saindo."; exit 0 ;;
		"1") dataBackup ;;	
		"2") mirrorUpdate && dataBackup ;;
		"3") bdBackup ;;
		"4") dataBackup && bdBackup ;;
		"5") mirrorUpdate && dataBackup && bdBackup ;;
		*) logger "Parâmetro $BACKUP_TYPE não configurado corretamente"; exit 1 ;;
	esac
		
}



# Funções de escrita nos logs

writeFileLog(){

echo $(date +"%d %b  %H:%M:%S : " ) $1 >> $FILE_LOGFILE

}

writeBDLog(){

echo $(date +"%d %b  %H:%M:%S : " ) $1 >> $BD_LOGFILE

}

writeMirrorLog(){

echo $(date +"%d %b  %H:%M:%S : " ) $1 >> $MIRROR_LOGFILE

}


removeOldBackups(){

for n in `seq $KEEPING_DAYS`
  do
    # Retorna datas anteriores no formato do diretorio de backup 
    EXCLUDE_DATE=$(date --date "$n days ago" +%d-%m-%Y)
    
     if [ "$BACKUP_TYPE" = "1" ] || [ "$BACKUP_TYPE" = "2" ] || [ "$BACKUP_TYPE" = "5" ]
      then
       if [ -d $FILE_BACKUP_DIR/$EXCLUDE_DATE ]
         then
            rm -rf $FILE_BACKUP_DIR/$EXCLUDE_DATE >> $FILE_LOGFILE \
            && writeFileLog "Backup do dia $EXCLUDE_DATE excluido com sucesso." \
            || writeFileLog "Erro ao excluir diretorio com backup antigo."
         else
          writeFileLog "Nenhum backup de arquivos com $n dias encontrado. Backup do dia $EXCLUDE_DATE nao excluido."
       fi
     else  
       if [ -d $BD_BACKUP_DIR/$EXCLUDE_DATE ]
         then
            rm -rf $BD_BACKUP_DIR/$EXCLUDE_DATE >> $BD_LOGFILE \
            && writeBDLog "Backup de banco de dados do dia $EXCLUDE_DATE excluido com sucesso." \
            || writeBDLog "Erro ao excluir diretorio com backup antigo."
       else
          writeBDLog "Nenhum backup de banco de dados com $n dias encontrado. Backup do dia $EXCLUDE_DATE nao excluido."
       fi
     fi
  done

}

dataBackup(){

[ ! -d $FILE_BACKUP_DIR/$TODAY ] && mkdir -p $FILE_BACKUP_DIR/$TODAY ; writeFileLog "Diretorio de backup e arquivo de log criados." || logger "[SYSTEM_BACKUP] -> Arquivo de LOG do backup de arquivos não criado. O backup não será realizado"

writeFileLog "Inciando Backup. "

# Se for dia de backup completo, realizar o backup completo

for dir in `echo $BACKUP_SOURCE`
  do
    if [ $DAYOFWEEK = $DAYOFFULLBACKUP ]
      then
        cd $BACKUP_SOURCE
          for dir in *
            do
              writeFileLog "Iniciando rotina de backup completo..."
              tar cjf $FILE_BACKUP_DIR/$TODAY/$(echo $dir | tr -s [A-Z] [a-z] | tr -d "." | tr -s [:blank:] "-").$TODAY.tar.bz2 $BACKUP_SOURCE/"$dir" >> $FILE_LOGFILE \
                && writeFileLog "Backup do diretorio $dir realizado com sucesso." >> $FILE_LOGFILE \
                || writeFileLog "Erro na realizaçãno backup do diretor $dir."
            done
          # Apos o backup concluido, remover backups antigos, de acordo com a configuracao da variavel $KEEPING_DAYS
          removeOldBackups
          writeFileLog "Fim da rotina de backup total."
  
    # Se nao for, fazer backup incremental
    else
      writeFileLog "Executando backup incremental do dia $TODAY."
        find $BACKUP_SOURCE -mtime -1 -type f -print | tar cjf $FILE_BACKUP_DIR/$TODAY/incremental.$TODAY.tar.bz2 -T - >> $FILE_LOGFILE \
          && writeFileLog "Backup incremental realizado com sucesso." \
          || writeFileLog "Erro na realizacao do backup incremental."
    fi
  done


}

bdBackup(){

[ ! -d $BD_BACKUP_DIR/$TODAY ] && mkdir -p $BD_BACKUP_DIR/$TODAY ; writeBDLog "Diretorio de backup e arquivo de log criados." || logger "[SYSTEM_BACKUP] -> Arquivo de LOG de backup nao criado. O backup do banco de dados não será realizado" 


  writeBDLog "Inciando Backup."

  for file in `echo $FDB_FILES`
    do
      writeBDLog "Iniciando rotina de backup..."
       gbak -v $FB_DIR/$file $BD_BACKUP_DIR/$TODAY/$file.$TODAY.FBK -user $FB_USER -pass $FB_PASS >> $BD_LOGFILE \
       && writeBDLog "Backup do arquivo $file realizado com sucesso." \
        || writeBDLog "Erro na realização do backup."
    done

  # Apos a realizacao da rotina de backup, exlcuir os backups antigos

  removeOldBackups
  writeBDLog "Fim da rotina de backup total do banco de dados."

}

mirrorUpdate(){

[ ! -d $MIRROR ] && mkdir -p $MIRROR ; writeMirrorLog "Diretorio espelho criado com sucesso." || logger "[SYSTEM_BACKUP] -> Erro na criacao do diretorio de espelho de dados"

writeMirrorLog "Sincronizando diretórios de dados."

rsync -tvruzh --delete $BACKUP_SOURCE $MIRROR >> $MIRROR_LOGFILE \
&& writeMirrorLog "Espelho de dados atualizado com sucesso." \
|| writeMirrorLog "Erro na atualizacao dos dados do espelho." 

}


main
