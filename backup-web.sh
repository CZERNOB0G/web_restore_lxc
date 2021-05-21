#!/bin/bash
backup="/var/backup"
baktodo="/var/baktodo"
#Verifica se a partição está montada
if mount | grep $backup > /dev/null || mount | grep $baktodo > /dev/null;
    then
        echo "============================================================================"
        echo "= A partição de backup está montada, deseja prosseguir mesmo assim? (S/N): ="
        echo "============================================================================"
        read confirmacao
        #Se a resposta for diferente s e n, ele faz o backup.
        while [ ${confirmacao^} != 'S' -a ${confirmacao^} != 'N' ];
        do
            echo "=================================================="
            echo "= Opção inválida, deseja tentar novamente? (S/N) ="
            echo "=================================================="
            read confirmacao
            if [ ${confirmacao^} != 'S' ];
                then
	            echo "============================"
               	    echo "= Abortando a restauração! ="
	            echo "============================"
                    umount $backup
                    umount $baktodo
	            exit;
            else
                echo "============================================================================"
                echo "= A partição de backup está montada, deseja prosseguir mesmo assim? (S/N): ="
                echo "============================================================================"
                read confirmacao
	    fi
        done
        #Se a resposta for n/N ele desmona a partição e para o script.
        if [ ${confirmacao^} != 'S' ];
            then
		echo "============================"
                echo "= Abortando a restauração! ="
		echo "============================"
                exit;
        fi
fi
mount $backup
mount $baktodo
echo "==============================="
echo "= Informe a conta do cliente: ="
echo "==============================="
read cliente
#Se o cliente não existe ele entra no looping até que informe um que exista.
while [ -z `find $backup -iname "$cliente.tz"` > /dev/null 2>&1 ];
    do
        echo "==============================================================="
        echo "= Não existe backup deste cliente, deseja tentar outro? (S/N) ="
        echo "==============================================================="
        read confirmacao
        if [ ${confirmacao^} != 'S' ];
            then
                #Se digitar n/N ele desmonta o backup e para o script.
	        echo "============================"
               	echo "= Abortando a restauração! ="
	        echo "============================"
                umount $backup
                umount $baktodo
		exit;
            else
	        echo "========================================="
                echo "= Informe novamente a conta do cliente: ="
                echo "========================================="
                read cliente
	    fi
    done
diretorio="/home/$cliente"
#Informa as datas existentes para backup e cria uma array para selecionar a que você deseja..
echo "========================================"
echo "= Escolha a data que deseja restaurar: ="
echo "========================================"
data_find=()
#Ele lista enquanto ele achar uma data referente ao cliente e corta o resultado para exibir somente a data.
for i in `find $backup -iname "$cliente.tz" | sort | cut -d'/' -f5`; 
    do 
    	let inc++;
    	data_find[$inc]=$i;
    	echo "$inc: $i";
done
echo "========================================"
read id_data_solicitada
#Enquano informar um numero fora do escopo da array ele entra em um looping até que informe um número existente.
while [ -z ${data_find[$id_data_solicitada]} ];
    do
        echo "=================================================="
        echo "= Opção inválida, deseja tentar novamente? (S/N) ="
        echo "=================================================="
        read confirmacao
        if [ ${confirmacao^} != 'S' ];
            then
                #Se digitar n/N ele desmonta o backup e para o script.
	        echo "============================"
               	echo "= Abortando a restauração! ="
	        echo "============================"
                umount $backup
                umount $baktodo
	        exit;
            else
                echo "=================================================="
                echo "= Escolha novamente a data que deseja restaurar: ="
                echo "=================================================="
                read id_data_solicitada
	    fi
    done
#Aloca na varíavel a data do backup solicitado.
data_solicitada="${data_find[$id_data_solicitada]}"
#Retira a hora que fica no final da data de backup solicitada.
data_solicitada_sem_hora="${data_solicitada:0:10}"
#Procura em todos os mensais o mais próximo da data solicitada.
data_solicitada_timestamp=`date -d "${data_solicitada_sem_hora}" +"%s"`
for m in `find $backup/monthly -iname "$cliente.tz" | sort | cut -d'/' -f5`; 
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
#Procura em todos os semanais o mais próximo da data solicitada.
for s in `find $backup/weekly -iname "$cliente.tz" | sort | cut -d'/' -f5`; 
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
#Procura em todos os diarios o mais próximo da data solicitada.
for d in `find $backup/daily -iname "$cliente.tz" | sort | cut -d'/' -f5`; 
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
#Transformma em timestamp caso exista a data solicitada.
if [ -n "$mensal_mais_proximo" ];
    then
    	mensal_mais_proximo_timestamp=`date -d "${mensal_mais_proximo:0:10}" +"%s"`
fi
if [ -n "$semanal_mais_proximo" ];
    then
    	semanal_mais_proxino_timestamp=`date -d "${semanal_mais_proximo:0:10}" +"%s"`
fi
#Se a data solicitada for um mensal
if [ `find $backup -iname "$data_solicitada"` == $backup/monthly/$data_solicitada ]; 
    then    
    	# Então ele descompacta um mensal.
    	echo "-------------> Descompactando um mensal: $data_solicitada...";
    	tar -zxf $backup/monthly/$data_solicitada/home/$cliente.tz -g $baktodo/monthly/$data_solicitada/home/$cliente.dump -C $backup;
# se não, e se a data solicitada for um semanal.
elif [ `find $backup -iname "$data_solicitada"` == $backup/weekly/$data_solicitada ];
    then
    	#Se o mensal é mais recente que o semanal ou não tenha um mensal
    	if [ "$mensal_mais_proximo_timestamp" -gt "$semanal_mais_proxino_timestamp" ] || [ -z "$mensal_mais_proximo_timestamp" ];
        	then
        		# Então faz somente semanal.
        		tar -zxf $backup/weekly/$data_solicitada/home/$cliente.tz -g $baktodo/weekly/$data_solicitada/home/$cliente.dump -C $backup;
        		echo "-------------> Descompactando um semanal: $data_solicitada...";
        	else
            		#Se não, faz mensal e semanal.
            		echo "-------------> Descompactando um semanal $data_solicitada com referência do mensal $mensal_mais_proximo...";
            		tar -zxf $backup/monthly/$mensal_mais_proximo/home/$cliente.tz -g $baktodo/monthly/$mensal_mais_proximo/home/$cliente.dump -C $backup;
            		tar -zxf $backup/weekly/$data_solicitada/home/$cliente.tz -g $baktodo/weekly/$data_solicitada/home/$cliente.dump -C $backup;
       	fi
    	else
        	#Se o mensal existir
        	if [ -n "$mensal_mais_proximo_timestamp" ] ;
            		then
                		#Então ele faz um mensal.
                		echo "-------------> Descompactando mensal de um diario: $mensal_mais_proximo...";
                		tar -zxf $backup/monthly/$mensal_mais_proximo/home/$cliente.tz -g $baktodo/monthly/$mensal_mais_proximo/home/$cliente.dump -C $backup;
        	fi
        	#Se o semanal existir e o mensal não existir ou o semanal for mais recente que que o mensal.
        	if [[ (-n "$semanal_mais_proxino_timestamp") && ( -z "$mensal_mais_proximo_timestamp" || "$semanal_mais_proxino_timestamp" -gt "$mensal_mais_proximo_timestamp" )  ]];
            		then
                		#Então ele faz o semanal.
                		echo "-------------> Descompactando semanal de um diario: $semanal_mais_proximo...";
                		tar -zxf $backup/weekly/$semanal_mais_proximo/home/$cliente.tz -g $baktodo/weekly/$semanal_mais_proximo/home/$cliente.dump -C $backup;
        	fi
        	# Ele faz o diario.
        	echo "-------------> Descompactando diario: $diario_mais_proximo...";
        	tar -zxf $backup/daily/$diario_mais_proximo/home/$cliente.tz -g $baktodo/daily/$diario_mais_proximo/home/$cliente.dump -C $backup;
	fi
#Define o diretório de restauração.
echo "==========================================================="
echo "= Deseja restaurar o diretório inteiro do cliente? (S/N): ="
echo "==========================================================="
read confirmacao
while [ ${confirmacao^} != 'S' -a ${confirmacao^} != 'N' ];
    do
        echo "=================================================="
        echo "= Opção inválida, deseja tentar novamente? (S/N) ="
        echo "=================================================="
        read confirmacao
        if [ ${confirmacao^} != 'S' ];
            then
	        echo "============================"
               	echo "= Abortando a restauração! ="
	        echo "============================"
                rm -rf $backup/$cliente/
                umount $backup
                umount $baktodo
	        exit;
            else
                echo "==========================================================="
                echo "= Deseja restaurar o diretório inteiro do cliente? (S/N): ="
                echo "==========================================================="
                read confirmacao
	    fi
    done
if [ ${confirmacao^} != 'S' ];
    then
    	echo "######################################################################################"
	echo "# OBS: Digite somente o nome da pasta, não coloque /home e nem / no começo ou final. #"
	echo "######################################################################################"
	echo "==========================================="
        echo "= Informe o nome do diretório que deseja: ="
        echo "==========================================="
        read pasta
fi
# Caso seja parcial, ele verifica se o existe backup no diretorio do cliente e no diretorio de backup.
while [[ (! -z "$pasta") && ( ! -d "$backup/$cliente/$pasta" || ! -d "$diretorio/$pasta" ) ]];
    do
        if [ ! -d $backup/$cliente/$pasta ];
            then
                echo "============================================================="
                echo "= Não existe backup dessa pasta, deseja tentar outra? (S/N) ="
                echo "============================================================="
                read confirmacao
                while [ ${confirmacao^} != 'S' -a ${confirmacao^} != 'N' ];
                    do
                        echo "=================================================="
                        echo "= Opção inválida, deseja tentar novamente? (S/N) ="
                        echo "=================================================="
                        read confirmacao
                        if [ ${confirmacao^} != 'S' ];
                            then
                                echo "============================"
                                echo "= Abortando a restauração! ="
                                echo "============================"
                                rm -rf $backup/$cliente/
                                umount $backup
                                umount $baktodo
                                exit;
                            else
                                echo "===================================="
                                echo "= Deseja tentar outra pasta? (S/N) ="
                                echo "===================================="
                                read confirmacao
                        fi
                    done
                if [ ${confirmacao^} != 'S' ];
                then
                    #Se digitar n/N ele desmonta o backup e para o script.
                    echo "============================"
                    echo "= Abortando a restauração! ="
                    echo "============================"
                    rm -rf $backup/$cliente/
                    umount $backup
                    umount $baktodo
                    exit;
                else
                    echo "====================================================="
                    echo "= Informe novamente o nome do diretório que deseja: ="
                    echo "====================================================="
                    read pasta
                fi
            fi
        if [ ! -d $diretorio/$pasta ];
            then
                echo "====================================================================="
                echo "= A pasta não existe na home do cliente, deseja tentar outra? (S/N) ="
                echo "====================================================================="
                read confirmacao
                while [ ${confirmacao^} != 'S' -a ${confirmacao^} != 'N' ];
                    do
                        echo "=================================================="
                        echo "= Opção inválida, deseja tentar novamente? (S/N) ="
                        echo "=================================================="
                        read confirmacao
                        if [ ${confirmacao^} != 'S' ];
                            then
                                echo "============================"
                                echo "= Abortando a restauração! ="
                                echo "============================"
                                rm -rf $backup/$cliente/
                                umount $backup
                                umount $baktodo
                                exit;
                            else
                                echo "==============================="
                                echo "= Deseja tentar outra? (S/N): ="
                                echo "==============================="
                                read confirmacao
                        fi
                    done
                if [ ${confirmacao^} != 'S' ];
                    then
                    	#Se digitar n/N ele desmonta o backup e para o script.
                    	echo "============================"
                    	echo "= Abortando a restauração! ="
                    	echo "============================"
                    	rm -rf $backup/$cliente/
                    	umount $backup
                    	umount $baktodo
                    	exit;
                else
                    echo "====================================================="
                    echo "= Informe novamente o nome do diretório que deseja: ="
                    echo "====================================================="
                    read pasta
                fi
            fi
    done
#Define o tipo backup a ser feito.
echo "============================================================================================================================="
echo "= Escolha o modo de restauração com C (Cópia), S (Sobrescrita), I (Incremental), CP (Cópia para outra pasta) ou L (Listar): ="
echo "============================================================================================================================="
read tipo
case $tipo in
    c|C)
        echo "==========================="
        echo "= Modo cópia selecionado! ="
        echo "==========================="
        quota_maxima_do_cliente=$(quota -w $cliente | awk '/\/dev\/mapper\/work-home/ {print $4}' | tr -s "[:punct:]" " ");
        tamanho_da_home_do_cliente=$(du -s /home/$cliente/ | awk '{print $1}' | tr -s "[:punct:]" " ");
        if [ -z "$pasta" ] ;
            then
                tamanho_do_backup=$(du -s $backup/$cliente/ | awk '{print $1}' | tr -s "[:punct:]" " ");
            else
                tamanho_do_backup=$(du -s $backup/$cliente/$pasta/ | awk '{print $1}' | tr -s "[:punct:]" " ");
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
                echo "-------------> Criando pasta de copia /home/$cliente/backup-copia-$data_solicitada_sem_hora/..."
                mkdir -m 755 /home/$cliente/backup-copia-$data_solicitada_sem_hora/
                if [ -z "$pasta" ] ;
                    then
                    echo "-------------> Restaurando cópia completa..."    
                    mv $backup/$cliente/ /home/$cliente/backup-copia-$data_solicitada_sem_hora/
                else
                    echo "-------------> Restaurando a pasta $pasta como cópia..."
                    mv $backup/$cliente/$pasta/ /home/$cliente/backup-copia-$data_solicitada_sem_hora/
                fi
                echo "-------------> Corrigindo o proprietário para $cliente..."
                chown -R $cliente: /home/$cliente/
        fi
    ;;
    s|S)
        echo "================================="
        echo "= Modo sobrescrito selecionado! ="
        echo "================================="
        echo "-------------> Criando pasta de backup..."
        if [ -z "$pasta" ] ;
            then
            	echo "-------------> Sobrescrevendo completamente a home..."
		mkdir -m 755 /home/marcos/backup-$cliente-`date +%Y-%m-%d-%H-%M`/$data_solicitada/$cliente/
       	    	mv $diretorio/* /home/marcos/backup-$cliente-`date +%Y-%m-%d-%H-%M`/$data_solicitada/$cliente/
            	rsync -aq $backup/$cliente/ $diretorio/
        else
            echo "-------------> Sobrescrevendo a pasta $pasta..." 
	    mkdir -m 755 /home/marcos/backup-$cliente-`date +%Y-%m-%d-%H-%M`/$data_solicitada/$pasta/
            mv $diretorio/$pasta/* /home/marcos/backup-$cliente-`date +%Y-%m-%d-%H-%M`/$data_solicitada/$pasta/
            rsync -aq $backup/$cliente/$pasta/ $diretorio/$pasta/
        fi
        echo "-------------> Corrigindo o proprietário para $cliente..."
        chown -R $cliente: /home/$cliente/
	chown -R marcos: /home/marcos/
    ;;
    i|I)
        echo "================================="
        echo "= Modo incremental selecionado! ="
        echo "================================="
        if [ -z "$pasta" ] ;
            then
            	echo "-------------> Incrementando completamente a home..."
        	rsync -aq $backup/$cliente/ $diretorio/
        else
            	echo "-------------> Incrementando a pasta $pasta..."
        	rsync -aq $backup/$cliente/$pasta/ $diretorio/$pasta/
        fi
        echo "-------------> Corrigindo o proprietário para $cliente..."
        chown -R $cliente: /home/$cliente/
    ;;
    l|L)
        echo "============================"
        echo "= Modo listar selecionado! ="
        echo "============================"
        echo "-------------> Listando os backups disponíveis para $cliente:"
        for f in `find $backup -iname "$cliente.tz" | cut -f2 | cut -d'/' -f5 | cut -d'-' -f1,-2,-3 | sort | awk -F'-' '{print $3"/"$2"/"$1}'`; 
        do 
            echo "$f";
        done
        echo "============================"
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
        mkdir -m 755 /home/$destino/backup-$cliente-$data_solicitada_sem_hora/
        if [ -z "$pasta" ] ;
            then
            	echo "-------------> Restaurando o diretório completo como cópia em $destino..."    
            	mv $backup/$cliente/ /home/$destino/backup-$cliente-$data_solicitada_sem_hora/
        else
            echo "-------------> Restaurando a pasta $pasta como cópia em /home/$destino/backup-$cliente-$data_solicitada_sem_hora/..."
            mv $backup/$cliente/$pasta /home/$destino/backup-$cliente-$data_solicitada_sem_hora/
        fi
        echo "-------------> Corrigindo o proprietário para $cliente..."
        chown -R $destino: /home/$destino/
    ;;
    *)
        echo "============================================"
        echo "= Opção inválida, abortando a restauração! ="
        echo "============================================"
    ;;
esac
rm -rf $backup/$cliente/
echo "-------------> Desmontando partições de backup..."
umount $backup
umount $baktodo
echo "-------------> BACKUP FINALIZADO!"
exit;
