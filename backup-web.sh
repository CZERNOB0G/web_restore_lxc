#!/bin/bash
#1 = cliente, 2 = tipo, 3 = pasta
if [ -z $1 ];
    then
        echo "======================================"
        echo "= É obrigatório informar o cliente   ="
        echo "======================================"
        echo "= ./backup-web.sh cliente tipo pasta ="
        echo "======================================"
        echo "= Parametros para o tipo      ="
        echo "= C (Cópia)                   ="
        echo "= S (Sobrescrita)             ="
        echo "= CP (Cópia para outra pasta) ="
        echo "= I (Incremental)             ="
        echo "==============================="
	exit;
fi
if [ -z $2 ];
    then
        echo "======================================="
        echo "= É obrigatório informar o tipo ! ! ! ="
        echo "======================================="
        echo "= ./backup-web.sh cliente tipo pasta  ="
        echo "======================================="
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
                echo "==========================="
            ;;
            s|S)
                echo "================================="
                echo "= Modo sobrescrito selecionado! ="
                echo "================================="
            ;;
            i|I)
                echo "================================="
                echo "= Modo incremental selecionado! ="
                echo "================================="
            ;;
            l|L)
                echo "============================"
                echo "= Modo listar selecionado! ="
                echo "============================"
            ;;
            cp|CP)
                echo "============================================"
                echo "= Modo cópia para outra pasta selecionado! ="
                echo "============================================"

            ;;
            *)
                echo "==============================="
                echo " O tipo é inválido !!!        =" 
                echo "======================================="
                echo "= ./backup-web.sh cliente tipo pasta  ="
                echo "======================================="
                echo "= Parametros para o tipo      ="
                echo "= C (Cópia)                   ="
                echo "= S (Sobrescrita)             ="
                echo "= CP (Cópia para outra pasta) ="
                echo "= I (Incremental)             ="
                echo "==============================="
                exit;
            ;;
esac
backup="/var/backup"
baktodo="/var/baktodo"
mount $backup
mount $baktodo
if [ -z `find $backup -iname "$1.tz"` > /dev/null 2>&1 ];
    then
        echo "==================================="
        echo "= Não existe backup deste cliente ="
        echo "==================================="
        umount $backup
        umount $baktodo
	exit;
fi
if [[ ($2 == 'L') || ($2 == 'l') ]];
    then
        echo "-------------> Listando os backups disponíveis para $1:"
        for f in `find $backup -iname "$1.tz" | cut -f2 | cut -d'/' -f5 | cut -d'-' -f1,-2,-3 | sort | awk -F'-' '{print $3"/"$2"/"$1}'`; 
            do 
                echo "$f";
        done
        echo "============================"
        umount $backup
        umount $baktodo
	exit;
fi
diretorio="/home/$1"
if [[ ( -n $3 ) && ( ! -d $diretorio/$3 ) ]];
    then
        echo "========================================="
        echo "= A pasta não existe na home do cliente ="
        echo "========================================="
        umount $backup
        umount $baktodo
        exit;
fi
if [[ ( -n $3 ) && ( ! -d $backup/$1/$3 ) ]];
    then
        echo "================================="
        echo "= Não existe backup dessa pasta ="
        echo "================================="
        umount $backup
        umount $baktodo
        exit;
fi
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
if [ -z ${data_find[$id_data_solicitada]} ];
    then
        echo "=================="
        echo "= Opção inválida ="
        echo "=================="
        umount $backup
        umount $baktodo
        exit;
fi
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
if [ `find $backup -iname "$data_solicitada"` == $backup/monthly/$data_solicitada ]; 
    then    
    	echo "-------------> Descompactando um mensal: $data_solicitada...";
    	tar -zxf $backup/monthly/$data_solicitada/home/$1.tz -g $baktodo/monthly/$data_solicitada/home/$1.dump -C $backup;
elif [ `find $backup -iname "$data_solicitada"` == $backup/weekly/$data_solicitada ];
    then
    	if [ "$mensal_mais_proximo_timestamp" -gt "$semanal_mais_proxino_timestamp" ] || [ -z "$mensal_mais_proximo_timestamp" ];
        	then
        		tar -zxf $backup/weekly/$data_solicitada/home/$1.tz -g $baktodo/weekly/$data_solicitada/home/$1.dump -C $backup;
        		echo "-------------> Descompactando um semanal: $data_solicitada...";
        	    else
            		echo "-------------> Descompactando um semanal $data_solicitada com referência do mensal $mensal_mais_proximo...";
            		tar -zxf $backup/monthly/$mensal_mais_proximo/home/$1.tz -g $baktodo/monthly/$mensal_mais_proximo/home/$1.dump -C $backup;
            		tar -zxf $backup/weekly/$data_solicitada/home/$1.tz -g $baktodo/weekly/$data_solicitada/home/$1.dump -C $backup;
       	fi
    	else
        	if [ -n "$mensal_mais_proximo_timestamp" ] ;
            		then
                		echo "-------------> Descompactando mensal de um diario: $mensal_mais_proximo...";
                		tar -zxf $backup/monthly/$mensal_mais_proximo/home/$1.tz -g $baktodo/monthly/$mensal_mais_proximo/home/$1.dump -C $backup;
        	fi
        	if [[ (-n "$semanal_mais_proxino_timestamp") && ( -z "$mensal_mais_proximo_timestamp" || "$semanal_mais_proxino_timestamp" -gt "$mensal_mais_proximo_timestamp" )  ]];
            		then
                		echo "-------------> Descompactando semanal de um diario: $semanal_mais_proximo...";
                		tar -zxf $backup/weekly/$semanal_mais_proximo/home/$1.tz -g $baktodo/weekly/$semanal_mais_proximo/home/$1.dump -C $backup;
        	fi
        	echo "-------------> Descompactando diario: $diario_mais_proximo...";
        	tar -zxf $backup/daily/$diario_mais_proximo/home/$1.tz -g $baktodo/daily/$diario_mais_proximo/home/$1.dump -C $backup;
	fi
fi
case $2 in
    c|C)
        echo "==========================="
        echo "= Modo cópia selecionado! ="
        echo "==========================="
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
                echo "-------------> Criando pasta de copia /home/$1/backup-copia-$data_solicitada_sem_hora/..."
                mkdir -m 755 /home/$1/backup-copia-$data_solicitada_sem_hora/
                if [ -z "$3" ] ;
                    then
                    echo "-------------> Restaurando cópia completa..."    
                    mv $backup/$1/ /home/$1/backup-copia-$data_solicitada_sem_hora/
                else
                    echo "-------------> Restaurando a pasta $3 como cópia..."
                    mv $backup/$1/$3/ /home/$1/backup-copia-$data_solicitada_sem_hora/
                fi
                echo "-------------> Corrigindo o proprietário para $1..."
                chown -R $1: /home/$1/
        fi
    ;;
    s|S)
        echo "================================="
        echo "= Modo sobrescrito selecionado! ="
        echo "================================="
        echo "-------------> Criando pasta de backup..."
        if [ -z "$3" ] ;
            then
            	echo "-------------> Sobrescrevendo completamente a home..."
		        mkdir -m 755 /home/marcos/backup-$1-`date +%Y-%m-%d-%H-%M`/$data_solicitada/$1/
       	    	mv $diretorio/* /home/marcos/backup-$1-`date +%Y-%m-%d-%H-%M`/$data_solicitada/$1/
            	rsync -aq $backup/$1/ $diretorio/
        else
            echo "-------------> Sobrescrevendo a pasta $3..." 
	        mkdir -m 755 /home/marcos/backup-$1-`date +%Y-%m-%d-%H-%M`/$data_solicitada/$3/
            mv $diretorio/$3/* /home/marcos/backup-$1-`date +%Y-%m-%d-%H-%M`/$data_solicitada/$3/
            rsync -aq $backup/$1/$3/ $diretorio/$3/
        fi
        echo "-------------> Corrigindo o proprietário para $1..."
        chown -R $1: /home/$1/
	    chown -R marcos: /home/marcos/
    ;;
    i|I)
        echo "================================="
        echo "= Modo incremental selecionado! ="
        echo "================================="
        if [ -z "$3" ] ;
            then
            	echo "-------------> Incrementando completamente a home..."
        	rsync -aq $backup/$1/ $diretorio/
        else
            	echo "-------------> Incrementando a pasta $3..."
        	rsync -aq $backup/$1/$3/ $diretorio/$3/
        fi
        echo "-------------> Corrigindo o proprietário para $1..."
        chown -R $1: /home/$1/
    ;;
    cp|CP)
    	echo "============================================"
        echo "= Modo cópia para outra pasta selecionado! ="
        echo "============================================"
	    echo "######################################################################################"
	    echo "# OBS: Digite somente o nome da pasta, não coloque /home e nem / no começo ou final. #"
	    echo "######################################################################################"
        echo "==================================================="
	    echo "Informe o nome da conta de destino neste servidor: "
	    echo "==================================================="
	    read destino
        echo "-------------> Criando pasta do backup"
        mkdir -m 755 /home/$destino/backup-$1-$data_solicitada_sem_hora/
        if [ -z "$3" ] ;
            then
            	echo "-------------> Restaurando o diretório completo como cópia em $destino..."    
            	mv $backup/$1/ /home/$destino/backup-$1-$data_solicitada_sem_hora/
        else
            echo "-------------> Restaurando a pasta $3 como cópia em /home/$destino/backup-$1-$data_solicitada_sem_hora/..."
            mv $backup/$1/$3 /home/$destino/backup-$1-$data_solicitada_sem_hora/
        fi
        echo "-------------> Corrigindo o proprietário para $1..."
        chown -R $destino: /home/$destino/
    ;;
esac
rm -rf $backup/$1/
echo "-------------> Desmontando partições de backup..."
umount $backup
umount $baktodo
echo "-------------> BACKUP FINALIZADO!"
exit;
