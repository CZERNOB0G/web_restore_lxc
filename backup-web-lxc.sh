#!/bin/bash
cliente_ini="$1";
cliente=`echo "$cliente_ini" | sed 's/[^a-z0-9\_-]*//g'`;
tipo="$2";
id_pasta_ini=${3/#"/"/""};
pasta=${id_pasta_ini/%"/"/""};
if [ -z "$cliente" -o -z "$tipo" ];
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
        echo "= L (Listar)                  ="
        echo "= SCP (Cópia para outro serv) ="
        echo "==============================="
        exit;
fi
case $tipo in
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
    scp|SCP)
        echo "==============================================="
        echo "= Modo cópia para outro servidor selecionado! ="
        echo "======================================"
        echo "= Informe o nome do servidor destino: "
        echo "======================================"
        read destino_t
        servidor=`echo $destino_t | grep -o '[[:digit:]]*'`;
    ;;
    cp|CP)
        echo "============================================"
        echo "= Modo copia para outra pasta selecionado! ="
        echo "==================================================="
        echo "Informe o nome da conta de destino neste servidor: "
        echo "==================================================="
        read destino_ini
        destino=`echo "$destino_ini" | sed 's/[^a-z0-9\-\_]*//g'`;
        diretorio_dest="/home/$destino"
        if [ ! -d "$diretorio_dest" ];
            then
                echo "==============================="
                echo "= Esta conta não possui home  ="
                echo "==============================="
                exit;
        fi
        if [ "/home/$destino" = "/home/$cliente" ];
            then
                echo "==================================================="
                echo "= O destino não pode ser a mesma home do cliente ="
                echo "==================================================="
                exit;
        fi
    ;;
    l|L)
        echo "============================"
        echo "= Modo listar selecionado! ="
        echo "============================"
        backup="/var/backup"
        baktodo="/var/baktodo"
        mount $backup
        mount $baktodo
        data_find=()
        diretorio="/home/$cliente"
        if [ ! -d "$diretorio" ];
            then
                echo "================================="
                echo "= Este cliente não possui home  ="
                echo "================================="
                homes_parecidas=`ls -ld /home/$cliente* 2>/dev/null | awk -F'/' '{print $3}'`;
                if [ -n "$homes_parecidas" ];
                    then
                        echo "Exitem essas homes parecidas: ";
                        echo " ";
                        echo "$homes_parecidas";
                        echo " ";
                fi
                umount $backup
                umount $baktodo
                exit;
        fi
        if [ -z `find $backup -iname "$cliente.tz"` > /dev/null 2>&1 ];
            then
                echo "==================================="
                echo "= Não existe backup deste cliente ="
                echo "==================================="
                umount $backup
                umount $baktodo
                exit;
        fi
        if [ -n "$pasta" ];
            then
                echo "-------------> Listando os backups disponíveis para $cliente com a pasta $pasta:"
                for i in `find $backup -iname "$cliente.tz" | sort | cut -d'/' -f5`;
                    do
                        verificacao_de_pasta=`tar -tf $backup/*/$i/home/$cliente.tz | grep -m1 -x $cliente/$pasta/`;
                        if [ -n "$verificacao_de_pasta" ];
                            then
                                let inc++;
                                data_find[$inc]=$i;
                                i2=`echo "$i" | cut -d'-' -f1,-2,-3 | sort | awk -F'-' '{print $3"/"$2"/"$1}'`;
                                echo "$i2";
                        fi
                done
                if [ ${#data_find[@]} -eq 0 ];
                    then
                        echo "=================================="
                        echo "= Não têm backup para essa pasta ="
                        echo "=================================="
                        umount $backup
                        umount $baktodo
                        exit;
                fi
        else
            echo "-------------> Listando os backups disponíveis para $cliente:"
            for f in `find $backup -iname "$cliente.tz" | cut -f2 | cut -d'/' -f5 | cut -d'-' -f1,-2,-3 | sort | awk -F'-' '{print $3"/"$2"/"$1}'`;
            do
                echo "$f";
            done
        fi
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
        echo "= L (Listar)                  ="
        echo "= SCP (Cópia para outro serv) ="
        echo "==============================="
        exit;
    ;;
esac
diretorio="/home/$cliente"
if [ ! -d "$diretorio" -a "${tipo^^}" != "SCP" ];
    then
        echo "================================="
        echo "= Este cliente não possui home  ="
        echo "================================="
        homes_parecidas=`ls -ld /home/$cliente* 2>/dev/null | awk -F'/' '{print $3}'`;
        if [ -n "$homes_parecidas" ];
            then
                echo "Exitem essas homes parecidas: ";
                echo " ";
                echo "$homes_parecidas";
                echo " ";
        fi
        exit;
fi
export CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m";
export backup="/var/backup"
export baktodo="/var/baktodo"
mount $backup
mount $baktodo
mkdir -m 755 $backup/web_restore
export web_restore="$backup/web_restore"
over () 
{
    echo -n "-------------> Removendo $web_restore: "
    rm -rf /var/backup/web_restore
    echo -e "${CHECK_MARK}";
    echo -n "-------------> Desmontando backup: "
    umount $backup $baktodo
    echo -e "${CHECK_MARK}";
    exit;
}
function trap_ctrlc ()
{
    echo " "
    echo "Abortando!"
    echo -n "Removendo /var/backup/web_restore/ e desmontando backup: "
    rm -rf /var/backup/web_restore/
    umount /var/backup/ /var/baktodo/
    echo -e "${CHECK_MARK}";
    exit;
}
trap "trap_ctrlc" 2
if [ -z `find $backup -iname "$cliente.tz"` > /dev/null 2>&1 ];
    then
        echo "==================================="
        echo "= Não existe backup deste cliente ="
        echo "==================================="
        over
fi
echo "===================================="
echo "= Verificando backups disponíveis: ="
echo "===================================="
data_find=()
for i in `find $backup -iname "$cliente.tz" | sort | cut -d'/' -f5`;
    do
        if [ -n "$pasta" ];
            then
                verificacao_de_pasta=`tar -tf $backup/*/$i/home/$cliente.tz | grep -m1 -x $cliente/$pasta/`;
                if [ -n "$verificacao_de_pasta" ];
                    then
                        let inc++;
                        data_find[$inc]=$i;
                        i2=`echo "$i" | cut -d'-' -f1,-2,-3 | awk -F'-' '{print $3"/"$2"/"$1}'`;
                        echo "$inc: $i2";
                fi
            else
                let inc++;
                data_find[$inc]=$i;
                i2=`echo "$i" | cut -d'-' -f1,-2,-3 | awk -F'-' '{print $3"/"$2"/"$1}'`;
                echo "$inc: $i2";
        fi
done
if [ ${#data_find[@]} -eq 0 -a -n "$pasta" ];    
    then
        echo "= Não têm backup para essa pasta ="
        echo "=================================="
        over
fi
echo "========================================"
read id_data_solicitada_ini
id_data_solicitada=`echo "$id_data_solicitada_ini" |  sed 's/[^0-9]*//g'`;
if [ -z ${data_find[$id_data_solicitada]} ];
    then
        echo "=================="
        echo "= Opção inválida ="
        echo "=================="
        over
fi
data_solicitada="${data_find[$id_data_solicitada]}";
data_solicitada_sem_hora="${data_solicitada:0:10}";
data_solicitada_timestamp=`date -d "${data_solicitada_sem_hora}" +"%s"`;
data=`date +%Y-%m-%d-%H-%M`;
if [ -d "/home/marcos/backup-$cliente-$data/$data_solicitada/" -a -z "$pasta" -a "${tipo^}" = "S" ];
    then
        echo "=================================================================="
        echo "= Já possui backup sobrescrito dessa data na sua home dessa data ="
        echo "=================================================================="
        over
fi
if [ -d "/home/marcos/backup-$cliente-$data/$data_solicitada/$pasta/" -a -n "$pasta" -a "${tipo^}" = "S" ];
    then
        echo "=========================================================================="
        echo "= Já possui backup sobrescrito dessa data e pasta na sua home dessa data ="
        echo "=========================================================================="
        over
fi
if [ -d "$diretorio_dest/backup-$cliente-completo-$data_solicitada_sem_hora/" -a -z "$pasta" -a "${tipo^^}" = "CP" ];
    then
        echo "====================================================="
        echo "= Já possui backup cópia dessa data na home destino ="
        echo "====================================================="
        over
fi
if [ -d "$diretorio_dest/backup-$cliente-parcial-$data_solicitada_sem_hora/$pasta/" -a -n "$pasta" -a "${tipo^^}" = "CP" ];
    then
        echo "============================================================="
        echo "= Já possui backup cópia dessa data e pasta na home destino ="
        echo "============================================================="
        over
fi
if [ -d "$diretorio/backup-completo-$data_solicitada_sem_hora/" -a -z "$pasta" -a "${tipo^}" = "C" ];
    then
        echo "========================================================"
        echo "= Já possui backup cópia dessa data na home do cliente ="
        echo "========================================================"
        over
fi
if [ -d "$diretorio/backup-parcial-$data_solicitada_sem_hora/$pasta/" -a -n "$pasta" -a "${tipo^}" = "C" ];
    then
        echo "================================================================"
        echo "= Já possui backup cópia dessa pasta e data na home do cliente ="
        echo "================================================================"
        over
fi
for m in `find $backup/monthly -iname "$cliente.tz" | sort | cut -d'/' -f5`;
    do
        mensal[$id_mes]=$m;
        for m2 in ${mensal[*]};
            do
                array_mensal_sem_hora="${m2:0:10}";
                array_mensal_timestamp=`date -d "${array_mensal_sem_hora}" +"%s"`;
                if  [ ${array_mensal_timestamp} -le ${data_solicitada_timestamp} ];
                    then
                        mensal_mais_proximo=$m2;
                fi
        done
        let id_mes++;
done
for s in `find $backup/weekly -iname "$cliente.tz" | sort | cut -d'/' -f5`;
    do
        semanal[$id_semana]=$s;
        for s2 in ${semanal[*]};
            do
                array_semanal_sem_hora="${s2:0:10}";
                array_semanal_timestamp=`date -d "${array_semanal_sem_hora}" +"%s"`;
                if [ ${array_semanal_timestamp} -le ${data_solicitada_timestamp} ];
                    then
                        semanal_mais_proximo=$s2;
                fi
        done
        let id_semana++;
done
for d in `find $backup/daily -iname "$cliente.tz" | sort | cut -d'/' -f5`;
    do
        diario[$id_dia]=$d;
        for d2 in ${diario[*]};
            do
                array_diario_sem_hora="${d2:0:10}";
                array_diario_timestamp=`date -d "${array_diario_sem_hora}" +"%s"`;
                if [ ${array_diario_timestamp} -le ${data_solicitada_timestamp} ];
                    then
                        diario_mais_proximo=$d2;
                fi
        done
        let id_dia++;
done
if [ -n "$mensal_mais_proximo" ];
    then
        mensal_mais_proximo_timestamp=`date -d "${mensal_mais_proximo:0:10}" +"%s"`;
fi
if [ -n "$semanal_mais_proximo" ];
    then
        semanal_mais_proxino_timestamp=`date -d "${semanal_mais_proximo:0:10}" +"%s"`;
fi
if [ `find $backup -iname "$data_solicitada"` == $backup/monthly/$data_solicitada ];
    then
        echo -n "-------------> Descompactando um mensal $data_solicitada: ";
        if [ -z $pasta ];
            then
                tar -zxf $backup/monthly/$data_solicitada/home/$cliente.tz -g $baktodo/monthly/$data_solicitada/home/$cliente.dump -C $web_restore;
            else
                tar -zxf $backup/monthly/$data_solicitada/home/$cliente.tz -g $baktodo/monthly/$data_solicitada/home/$cliente.dump -C $web_restore $cliente/$pasta;
        fi
        echo -e "${CHECK_MARK}";
elif [ `find $backup -iname "$data_solicitada"` == $backup/weekly/$data_solicitada ];
    then
        if [ "$mensal_mais_proximo_timestamp" -gt "$semanal_mais_proxino_timestamp" ] || [ -z "$mensal_mais_proximo_timestamp" ];
            then
                echo -n "-------------> Descompactando um semanal $data_solicitada: ";
                if [ -z $pasta ];
                    then
                        tar -zxf $backup/weekly/$data_solicitada/home/$cliente.tz -g $baktodo/weekly/$data_solicitada/home/$cliente.dump -C $web_restore;
                    else
                        tar -zxf $backup/weekly/$data_solicitada/home/$cliente.tz -g $baktodo/weekly/$data_solicitada/home/$cliente.dump -C $web_restore $cliente/$pasta;
                fi
                echo -e "${CHECK_MARK}";
            else
                echo -n "-------------> Descompactando um semanal $data_solicitada com referência do mensal $mensal_mais_proximo: ";
                if [ -z $pasta ];
                    then
                        tar -zxf $backup/monthly/$mensal_mais_proximo/home/$cliente.tz -g $baktodo/monthly/$mensal_mais_proximo/home/$cliente.dump -C $web_restore;
                        tar -zxf $backup/weekly/$data_solicitada/home/$cliente.tz -g $baktodo/weekly/$data_solicitada/home/$cliente.dump -C $web_restore;
                    else
                        pasta_backup_mensal=`tar -tf $backup/monthly/$mensal_mais_proximo/home/$cliente.tz -g $baktodo/monthly/$mensal_mais_proximo/home/$cliente.dump | grep -m1 -x $cliente/$pasta/`;
                        if [ -n "$pasta_backup_mensal" ];
                            then
                                tar -zxf $backup/monthly/$mensal_mais_proximo/home/$cliente.tz -g $baktodo/monthly/$mensal_mais_proximo/home/$cliente.dump -C $web_restore $cliente/$pasta/;
                        fi
                        tar -zxf $backup/weekly/$data_solicitada/home/$cliente.tz -g $baktodo/weekly/$data_solicitada/home/$cliente.dump -C $web_restore $cliente/$pasta/;
                fi
                echo -e "${CHECK_MARK}";
        fi
        else
            if [ -n "$mensal_mais_proximo_timestamp" ] ;
                then
                    echo -n "-------------> Descompactando mensal de um diario $mensal_mais_proximo: ";
                    if [ -z $pasta ];
                        then
                            tar -zxf $backup/monthly/$mensal_mais_proximo/home/$cliente.tz -g $baktodo/monthly/$mensal_mais_proximo/home/$cliente.dump -C $web_restore;
                        else
                            pasta_backup_mensal=`tar -tf $backup/monthly/$mensal_mais_proximo/home/$cliente.tz -g $baktodo/monthly/$mensal_mais_proximo/home/$cliente.dump | grep -m1 -x $cliente/$pasta/`;
                            if [ -n "$pasta_backup_mensal" ];
                                then
                                    tar -zxf $backup/monthly/$mensal_mais_proximo/home/$cliente.tz -g $baktodo/monthly/$mensal_mais_proximo/home/$cliente.dump -C $web_restore $cliente/$pasta/;
                            fi
                    fi
                    echo -e "${CHECK_MARK}";
            fi
            if [[ (-n "$semanal_mais_proxino_timestamp") && ( -z "$mensal_mais_proximo_timestamp" || "$semanal_mais_proxino_timestamp" -gt "$mensal_mais_proximo_timestamp" )  ]];
                then
                    echo -n "-------------> Descompactando semanal de um diario $semanal_mais_proximo: ";
                    if [ -z $pasta ];
                        then
                            tar -zxf $backup/weekly/$semanal_mais_proximo/home/$cliente.tz -g $baktodo/weekly/$semanal_mais_proximo/home/$cliente.dump -C $web_restore;
                        else
                            pasta_backup_semanal=`tar -tf $backup/weekly/$semanal_mais_proximo/home/$cliente.tz -g $baktodo/weekly/$semanal_mais_proximo/home/$cliente.dump | grep -m1 -x $cliente/$pasta/`;
                            if [ -n "$pasta_backup_semanal" ];
                                then
                                    tar -zxf $backup/weekly/$semanal_mais_proximo/home/$cliente.tz -g $baktodo/weekly/$semanal_mais_proximo/home/$cliente.dump -C $web_restore $cliente/$pasta/;
                            fi
                    fi
                    echo -e "${CHECK_MARK}";
            fi
            echo -n "-------------> Descompactando diario $diario_mais_proximo: ";
            if [ -z $pasta ];
                then
                    tar -zxf $backup/daily/$diario_mais_proximo/home/$cliente.tz -g $baktodo/daily/$diario_mais_proximo/home/$cliente.dump -C $web_restore;
                else
                    pasta_backup_diario=`tar -tf $backup/daily/$diario_mais_proximo/home/$cliente.tz -g $baktodo/daily/$diario_mais_proximo/home/$cliente.dump | grep -m1 -x $cliente/$pasta/`;
                    if [ -n "$pasta_backup_diario" ];
                        then
                            tar -zxf $backup/daily/$diario_mais_proximo/home/$cliente.tz -g $baktodo/daily/$diario_mais_proximo/home/$cliente.dump -C $web_restore $cliente/$pasta/;
                    fi
            fi
            echo -e "${CHECK_MARK}";
fi
verifica_user=`id $cliente 2>/dev/null`;
case $tipo in
    c|C)
        quota_off=`quota -s $cliente 2>/dev/null | grep -o none`;
        if [ -n "$quota_off" -a "$quota_off" != "none" -a -n "$verifica_user" ];
            then
                quota_maxima_do_cliente=$(quota -w $cliente | awk '/\/dev\/mapper\/work-home/ {print $4}' | tr -s "[:punct:]" " ");
                tamanho_da_home_do_cliente=$(du -s $diretorio | awk '{print $1}' | tr -s "[:punct:]" " ");
                if [ -z "$pasta" ];
                    then
                        tamanho_do_backup=$(du -s $web_restore/$cliente/ | awk '{print $1}' | tr -s "[:punct:]" " ");
                    else
                        tamanho_do_backup=$(du -s $web_restore/$cliente/$pasta/ | awk '{print $1}' | tr -s "[:punct:]" " ");
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
                        over
                fi
        fi
        if [ -z "$pasta" ];
            then
                echo -n "-------------> Criando pasta de copia $diretorio/backup-completo-$data_solicitada_sem_hora/: ";
                mkdir -m 755 -p $diretorio/backup-completo-$data_solicitada_sem_hora/
                echo -e "${CHECK_MARK}"
                echo -n "-------------> Restaurando cópia completa: ";
                rsync -aq $web_restore/$cliente/ $diretorio/backup-completo-$data_solicitada_sem_hora/
                echo -e "${CHECK_MARK}"
            else
                echo -n "-------------> Criando pasta de copia $diretorio/backup-parcial-$data_solicitada_sem_hora/$pasta/: ";
                mkdir -m 755 -p $diretorio/backup-parcial-$data_solicitada_sem_hora/$pasta/
                echo -e "${CHECK_MARK}"
                echo -n "-------------> Restaurando a pasta ../$pasta/ como cópia: ";
                rsync -aq $web_restore/$cliente/$pasta/ $diretorio/backup-parcial-$data_solicitada_sem_hora/$pasta/
                echo -e "${CHECK_MARK}"
        fi
    ;;
    scp|SCP)
        echo "-------------> Enviando backup para a home do outro servidor: ";
        scp -r $web_restore/$cliente/ marcos@web$servidor.prv.f1.k8.com.br:
        if [ "$?" -eq "0" ];
            then
                echo "-------------> A transferência foi feita!";
            else
                echo "-------------> A conexão não foi bem sucedida!";
        fi
        over
    ;;
    s|S)
        if [ -z "$pasta" ] ;
            then
                echo -n "-------------> Sobrescrevendo completamente a home: ";
                teste_destino=`ls -lA $diretorio/* 2>/dev/null`;
                if [ -n "$teste_destino" ];
                    then
                        mkdir -m 755 -p /home/marcos/backup-$cliente-$data/$data_solicitada/
                        mv $diretorio/* /home/marcos/backup-$cliente-$data/$data_solicitada/
                fi
                rsync -aq $web_restore/$cliente/ $diretorio/
                echo -e "${CHECK_MARK}";
            else
                echo -n "-------------> Sobrescrevendo a pasta ../$pasta/: "
                teste_destino=`ls -lA $diretorio/$pasta/* 2>/dev/null`;
                if [ -n "$teste_destino" ];
                    then
                        mkdir -m 755 -p /home/marcos/backup-$cliente-$data/$data_solicitada/$pasta/
                        mv $diretorio/$pasta/* /home/marcos/backup-$cliente-$data/$data_solicitada/$pasta/
                fi
                rsync -aq $web_restore/$cliente/$pasta/ $diretorio/$pasta/
                echo -e "${CHECK_MARK}";
        fi
        chown -R marcos: /home/marcos/
    ;;
    i|I)
        if [ -z "$pasta" ] ;
            then
                echo -n "-------------> Incrementando completamente a home: ";
                rsync -aq $web_restore/$cliente/ $diretorio/
                echo -e "${CHECK_MARK}";
            else
                echo -n "-------------> Incrementando a pasta ../$pasta/: ";
                rsync -aq $web_restore/$cliente/$pasta/ $diretorio/$pasta/
                echo -e "${CHECK_MARK}";
        fi
    ;;
    cp|CP)
        if [ -z "$pasta" ] ;
            then
                echo -n "-------------> Criando pasta do backup /home/$destino/backup-$cliente-completo-$data_solicitada_sem_hora/: ";
                mkdir -m 755 /home/$destino/backup-$cliente-completo-$data_solicitada_sem_hora/
                echo -e "${CHECK_MARK}";
                echo -n "-------------> Restaurando o diretório completa como cópia em $destino: ";
                rsync -aq $web_restore/$cliente/ /home/$destino/backup-$cliente-completo-$data_solicitada_sem_hora/
                echo -e "${CHECK_MARK}";
            else
                echo -n "-------------> Criando pasta do backup /home/$destino/backup-$cliente-completo-$data_solicitada_sem_hora/$pasta/: ";
                mkdir -m 755 -p /home/$destino/backup-$cliente-parcial-$data_solicitada_sem_hora/$pasta/
                echo -e "${CHECK_MARK}";
                echo -n "-------------> Restaurando a pasta $pasta como cópia: ";
                rsync -aq $web_restore/$cliente/$pasta/ /home/$destino/backup-$cliente-parcial-$data_solicitada_sem_hora/$pasta/
                echo -e "${CHECK_MARK}";
        fi
    ;;
esac
if [ -n "$verifica_user" ];
    then
        echo -n "-------------> Corrigindo o proprietário para $cliente: ";
        chown -R $cliente: $diretorio
        echo -e "${CHECK_MARK}";
fi
over
echo "-------------> BACKUP FINALIZADO!"
exit;
