#!/bin/bash
if [ -z "$1" -o -z "$2" ];
    then
        echo "===================================="
        echo "= Cliente ou tipo nulo é inválido  ="
        echo "===================================="
        echo "= cliente tipo pasta ="
        echo "==============================="
        echo "= Parametros para o tipo      ="
        echo "= C (Cópia)                   ="
        echo "= S (Sobrescrita)             ="
        echo "= CP (Cópia para outra pasta) ="
        echo "= I (Incremental)             ="
        echo "==============================="
        exit;
fi
case $2 in
    c|C)
        echo "==========================="
        echo "= Modo cópia selecionado! ="
    ;;
    s|S)
        echo "================================="
        echo "= Modo sobrescrito selecionado! ="
    ;;
    i|I)
        echo "================================="
        echo "= Modo incremental selecionado! ="
    ;;
    cp|CP)
        echo "============================================"
        echo "= Modo copia para outra pasta selecionado! ="
    ;;
    l|L)
        echo "============================"
        echo "= Modo listar selecionado! ="
        echo "============================"
        backup="/var/backup"
        baktodo="/var/baktodo"
        mount $backup
        mount $baktodo
        echo "-------------> Listando os backups disponíveis para $1:"
        for f in `find $backup -iname "$1.tz" | cut -f2 | cut -d'/' -f5 | cut -d'-' -f1,-2,-3 | sort | awk -F'-' '{print $3"/"$2"/"$1}'`;
        do
            echo "$f";
        done
        echo "============================"
        umount $backup
        umount $baktodo
        exit;
    ;;
    *)
        echo "================="
        echo "= Tipo inválido ="
        echo "==============================="
        echo "= Parametros para o tipo      ="
        echo "= C (Cópia)                   ="
        echo "= S (Sobrescrita)             ="
        echo "= CP (Cópia para outra pasta) ="
        echo "= I (Incremental)             ="
        echo "==============================="
        exit;
    ;;
esac
if [ ! -d "/home/$1" ];
    then
        echo "================================="
        echo "= Este cliente não possui home  ="
        echo "================================="
        exit;
fi
backup="/var/backup"
baktodo="/var/baktodo"
mount $backup
mount $baktodo
function trap_ctrlc ()
{
    echo " "
    echo "OK, Abortando operação..."
    echo "Espere ao menos para desmontar as partições e apagar a pasta de backup"
    if [ -d "$backup/$1" ];
        then
            rm -rf $backup/$1
    fi
        umount $backup
        umount $baktodo
    exit 2
}
trap "trap_ctrlc" 2
if [ -n "$3" -a ! -d "/home/$1" ];
    then
        echo "================================="
        echo "= Não existe backup dessa pasta ="
        echo "================================="
        umount $backup
        umount $baktodo
        exit;
fi
if [ -z `find $backup -iname "$1.tz"` > /dev/null 2>&1 ];
    then
        echo "==================================="
        echo "= Não existe backup deste cliente ="
        echo "==================================="
        umount /var/backup;
        umount /var/baktodo;
        exit;
fi
diretorio="/home/$1"
echo "========================================"
echo "= Escolha a data que deseja restaurar: ="
echo "========================================"
data_find=()
for i in `find $backup -iname "$1.tz" | sort | cut -d'/' -f5`;
    do
        let inc++;
        data_find[$inc]=$i;
        echo "$inc: $i";
done
echo "========================================"
read id_data_solicitada
while [ -z ${data_find[$id_data_solicitada]} ];
    do
        echo "=================="
        echo "= Opção inválida ="
        echo "=================="
        umount /var/backup;
        umount /var/baktodo;
        exit;
    done
data_solicitada="${data_find[$id_data_solicitada]}"
data_solicitada_sem_hora="${data_solicitada:0:10}"
data_solicitada_timestamp=`date -d "${data_solicitada_sem_hora}" +"%s"`
for m in `find $backup/monthly -iname "$1.tz" | sort | cut -d'/' -f5`;
    do
        mensal[$id_mes]=$m;
        for m2 in ${mensal[*]};
            do
                array_mensal_sem_hora="${m2:0:10}"
                array_mensal_timestamp=`date -d "${array_mensal_sem_hora}" +"%s"`
                if  [ ${array_mensal_timestamp} -le ${data_solicitada_timestamp} ];
                    then
                        mensal_mais_proximo=$m2;
                fi
        done
        let id_mes++;
done
for s in `find $backup/weekly -iname "$1.tz" | sort | cut -d'/' -f5`;
    do
        semanal[$id_semana]=$s;
        for s2 in ${semanal[*]};
            do
                array_semanal_sem_hora="${s2:0:10}"
                array_semanal_timestamp=`date -d "${array_semanal_sem_hora}" +"%s"`
                if [ ${array_semanal_timestamp} -le ${data_solicitada_timestamp} ];
                    then
                        semanal_mais_proximo=$s2;
                fi
        done
        let id_semana++;
done
for d in `find $backup/daily -iname "$1.tz" | sort | cut -d'/' -f5`;
    do
        diario[$id_dia]=$d;
        for d2 in ${diario[*]};
            do
                array_diario_sem_hora="${d2:0:10}"
                array_diario_timestamp=`date -d "${array_diario_sem_hora}" +"%s"`
                if [ ${array_diario_timestamp} -le ${data_solicitada_timestamp} ];
                    then
                        diario_mais_proximo=$d2;
                fi
        done
        let id_dia++;
done
if [ -n "$mensal_mais_proximo" ];
    then
        mensal_mais_proximo_timestamp=`date -d "${mensal_mais_proximo:0:10}" +"%s"`
fi
if [ -n "$semanal_mais_proximo" ];
    then
        semanal_mais_proxino_timestamp=`date -d "${semanal_mais_proximo:0:10}" +"%s"`
fi
CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m";
if [ `find $backup -iname "$data_solicitada"` == $backup/monthly/$data_solicitada ];
    then
        echo -n "-------------> Descompactando um mensal $data_solicitada: ";
        tar -zxf $backup/monthly/$data_solicitada/home/$1.tz -g $baktodo/monthly/$data_solicitada/home/$1.dump -C $backup;
        echo -e "${CHECK_MARK}";
elif [ `find $backup -iname "$data_solicitada"` == $backup/weekly/$data_solicitada ];
    then
        if [ "$mensal_mais_proximo_timestamp" -gt "$semanal_mais_proxino_timestamp" ] || [ -z "$mensal_mais_proximo_timestamp" ];
                then
                        echo -n "-------------> Descompactando um semanal $data_solicitada: ";
                        tar -zxf $backup/weekly/$data_solicitada/home/$1.tz -g $baktodo/weekly/$data_solicitada/home/$1.dump -C $backup;
                        echo -e "${CHECK_MARK}";
                else
                        echo -n "-------------> Descompactando um semanal $data_solicitada com referência do mensal $mensal_mais_proximo: ";
                        tar -zxf $backup/monthly/$mensal_mais_proximo/home/$1.tz -g $baktodo/monthly/$mensal_mais_proximo/home/$1.dump -C $backup;
                        tar -zxf $backup/weekly/$data_solicitada/home/$1.tz -g $baktodo/weekly/$data_solicitada/home/$1.dump -C $backup;
                        echo -e "${CHECK_MARK}";
        fi
        else
            if [ -n "$mensal_mais_proximo_timestamp" ] ;
                then
                    echo -n "-------------> Descompactando mensal de um diario $mensal_mais_proximo: ";
                    tar -zxf $backup/monthly/$mensal_mais_proximo/home/$1.tz -g $baktodo/monthly/$mensal_mais_proximo/home/$1.dump -C $backup;
                    echo -e "${CHECK_MARK}";
                fi
                if [[ (-n "$semanal_mais_proxino_timestamp") && ( -z "$mensal_mais_proximo_timestamp" || "$semanal_mais_proxino_timestamp" -gt "$mensal_mais_proximo_timestamp" )  ]];
                    then
                        echo -n "-------------> Descompactando semanal de um diario $semanal_mais_proximo: ";
                        tar -zxf $backup/weekly/$semanal_mais_proximo/home/$1.tz -g $baktodo/weekly/$semanal_mais_proximo/home/$1.dump -C $backup;
                        echo -e "${CHECK_MARK}";
            fi
            echo -n "-------------> Descompactando diario $diario_mais_proximo: ";
            tar -zxf $backup/daily/$diario_mais_proximo/home/$1.tz -g $baktodo/daily/$diario_mais_proximo/home/$1.dump -C $backup;
            echo -e "${CHECK_MARK}";
        fi
case $2 in
    c|C)
        quota_maxima_do_cliente=$(quota -w $1 | awk '/\/dev\/mapper\/work-home/ {print $4}' | tr -s "[:punct:]" " ");
        tamanho_da_home_do_cliente=$(du -s /home/$1/ | awk '{print $1}' | tr -s "[:punct:]" " ");
        if [ -z "$3" ] ;
            then
                tamanho_do_backup=$(du -s $backup/$1/ | awk '{print $1}' | tr -s "[:punct:]" " ");
            else
                tamanho_do_backup=$(du -s $backup/$1/$3/ | awk '{print $1}' | tr -s "[:punct:]" " ");
        fi
        tamanho_total_da_home_com_backup=$(expr $tamanho_do_backup + $tamanho_da_home_do_cliente);
        if [ "$tamanho_total_da_home_com_backup" -ge "$quota_maxima_do_cliente" ] ;
            then
                mega_byte=1024
                excedente_de_espaco_com_backup=$(expr $tamanho_total_da_home_com_backup - $quota_maxima_do_cliente)
                excedente_de_espaco_com_backup=$(expr $excedente_de_espaco_com_backup / $mega_byte);
                quota_maxima_do_cliente=$(expr $quota_maxima_do_cliente / $mega_byte);
                tamanho_do_backup=$(expr $tamanho_do_backup / $mega_byte);
                tamanho_da_home_do_cliente=$(expr $tamanho_da_home_do_cliente / $mega_byte);
                quota_necessaria=$(expr $quota_maxima_do_cliente + $excedente_de_espaco_com_backup);
                echo "O modo cópia não poderá ser feito...."
                echo "Quota atual: $quota_maxima_do_cliente MB";
                echo "Usado: $tamanho_da_home_do_cliente MB";
                echo "Backup: $tamanho_do_backup MB";
                echo "Excedente com quota atual: $excedente_de_espaco_com_backup MB";
                echo "Quota mínima necessária: $quota_necessaria MB"
            else
                echo -n "-------------> Criando pasta de copia /home/$1/backup-copia-$data_solicitada_sem_hora: ";
                mkdir -m 755 /home/$1/backup-copia-$data_solicitada_sem_hora/
                echo -e "${CHECK_MARK}"
                if [ -z "$3" ] ;
                    then
                    echo -n "-------------> Restaurando cópia completa: ";
                    mv $backup/$1/ /home/$1/backup-copia-$data_solicitada_sem_hora/
                    echo -e "${CHECK_MARK}"
                else
                    echo -n "-------------> Restaurando a pasta $3 como cópia: ";
                    mv $backup/$1/$3/ /home/$1/backup-copia-$data_solicitada_sem_hora/
                    echo -e "${CHECK_MARK}"
                fi
                echo -n "-------------> Corrigindo o proprietário para $1: ";
                chown -R $1: /home/$1/
                echo -e "${CHECK_MARK}";
        fi
    ;;
    s|S)
        if [ -z "$3" ] ;
            then
                echo -n "-------------> Criando pasta de backup: ";
                mkdir -m 755 -p /home/marcos/backup-$1-`date +%Y-%m-%d-%H-%M`/$data_solicitada/$1/
                echo -e "${CHECK_MARK}";
                echo -n "-------------> Sobrescrevendo completamente a home: ";
                mv $diretorio/* /home/marcos/backup-$1-`date +%Y-%m-%d-%H-%M`/$data_solicitada/$1/
                rsync -aq $backup/$1/ $diretorio/
                echo -e "${CHECK_MARK}";
            else
                echo -n "-------------> Criando pasta de backup: ";
                mkdir -m 755 -p /home/marcos/backup-$1-`date +%Y-%m-%d-%H-%M`/$data_solicitada/$3/
                echo -e "${CHECK_MARK}";
                echo -n "-------------> Sobrescrevendo a pasta $3: ";
                mv $diretorio/$3/* /home/marcos/backup-$1-`date +%Y-%m-%d-%H-%M`/$data_solicitada/$3/
                rsync -aq $backup/$1/$3/ $diretorio/$3/
                echo -e "${CHECK_MARK}";
        fi
        echo -n "-------------> Corrigindo o proprietário para $1: ";
        chown -R $1: /home/$1/
        chown -R marcos: /home/marcos/
        echo -e "${CHECK_MARK}";
    ;;
    i|I)
        if [ -z "$3" ] ;
            then
                echo -n "-------------> Incrementando completamente a home: ";
                rsync -aq $backup/$1/ $diretorio/
                echo -e "${CHECK_MARK}";
            else
                echo -n "-------------> Incrementando a pasta $3: ";
                rsync -aq $backup/$1/$3/ $diretorio/$3/
                echo -e "${CHECK_MARK}";
        fi
        echo -n "-------------> Corrigindo o proprietário para $1: ";
        chown -R $1: /home/$1/
        echo -e "${CHECK_MARK}";
    ;;
    cp|CP)
        echo "==================================================="
        echo "Informe o nome da conta de destino neste servidor: "
        echo "==================================================="
        read destino
        echo -n "-------------> Criando pasta do backup: ";
        mkdir -m 755 /home/$destino/backup-$1-$data_solicitada_sem_hora/
        echo -e "${CHECK_MARK}";
        if [ -z "$3" ] ;
            then
                echo -n "-------------> Restaurando o diretório completo como cópia em $destino: ";
                mv $backup/$1/ /home/$destino/backup-$1-$data_solicitada_sem_hora/
                echo -e "${CHECK_MARK}";
            else
                echo -n "-------------> Restaurando a pasta $3 como cópia em /home/$destino/backup-$1-$data_solicitada_sem_hora: ";
                mv $backup/$1/$3 /home/$destino/backup-$1-$data_solicitada_sem_hora/
                echo -e "${CHECK_MARK}";
        fi
        echo -n "-------------> Corrigindo o proprietário para $1: ";
        chown -R $destino: /home/$destino/
        echo -e "${CHECK_MARK}";
    ;;
    *)
        echo "============================================"
        echo "= Opção inválida, abortando a restauração! ="
        echo "============================================"
    ;;
esac
echo -n "-------------> Removendo pasta de backup $backup/$1/: "
rm -rf $backup/$1/
echo -e "${CHECK_MARK}";
echo -n "-------------> Desmontando partições de backup: "
umount $backup
umount $baktodo
echo -e "${CHECK_MARK}";
echo "-------------> BACKUP FINALIZADO!"
exit;
