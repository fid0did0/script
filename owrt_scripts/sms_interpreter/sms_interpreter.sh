#!/bin/sh

. /lib/functions.sh
. /usr/share/libubox/jshn.sh

device=$1
pin_modem=$2

separator_chr=';'
sms_cmd_list=''
sms_cmd_list_cnt=0
shell_cmd_list=''
cases_list=''
send_aw_list=''
sms_grep_flt_list=''

get_sms_devs_config() {
        local config="$1"
        local custom="$2"

	config_get device "$config" device 0
	config_get pin_modem "$config" pin_code 0
}

get_sms_cmds_config() {
        local config="$1"
        local custom="$2"
        local enabled sms_cmd shell_cmd case_sens send_aw 

        config_get enabled "$config" enabled 0
        config_get sms_cmd "$config" sms_id
        config_get shell_cmd "$config" shell_cmd
        config_get case_sens "$config" case_sensitive 0
        config_get send_aw "$config" send_answer

	if [ case_sens == 1 ]; then
		case_sens=''
	else
		case_sens='i'	
	fi;
        if [ $enabled -gt 0 ]; then
		sms_cmd_list=$sms_cmd_list$sms_cmd$separator_chr
		sms_cmd_list_cnt=$(( $sms_cmd_list_cnt + 1 ))
                shell_cmd_list=$shell_cmd_list$shell_cmd$separator_chr
                cases_list=$cases_list$case_sens$separator_chr
                send_aw_list=$send_aw_list$send_aw$separator_chr
        fi;
}

get_sms_config() {
	json_init

	config_load sms
	config_foreach get_sms_devs_config sms-device
	config_foreach get_sms_cmds_config sms-cmd

	sms_grep_flt_list=$(echo $sms_cmd_list | sed 's/\;/\\|/g')
}

get_shell_cmds() {
	local sms_cmd grep_opt 
	local idx 

	rx_shell_cmd_list='';
	rx_shell_cmd_list_cnt=0;
	rx_awreq_list='';
	for idx in $( seq 1 $sms_cmd_list_cnt); do
		sms_cmd=$(echo $sms_cmd_list | cut -d$separator_chr -f$idx ) 
		grep_opt=$(echo $cases_list | cut -d$separator_chr -f$idx ) 

		echo $1 | grep -qo$grep_opt $sms_cmd
		if [ $? == 0 ]; then
			rx_awreq_list=$rx_awreq_list$(echo $send_aw_list | cut -d$separator_chr -f$idx )$separator_chr
			rx_shell_cmd_list=$rx_shell_cmd_list$(echo $shell_cmd_list | cut -d$separator_chr -f$idx )$separator_chr
			rx_shell_cmd_list_cnt=$(( $rx_shell_cmd_list_cnt + 1 ));
		fi
	done
}

encode_sms() {
	
	coded_sms_txt="$clear_txt_sms"
	
	coded_sms_txt=$( echo $coded_sms_txt | sed -e 's/{/ '$(echo -e "\x1b(")' /g' )
	coded_sms_txt=$( echo $coded_sms_txt | sed -e 's/}/ '$(echo -e "\x1b)")' /g' )
	coded_sms_txt=$( echo $coded_sms_txt | sed -e 's/\^/ '$(echo -e "\x1b\x14")' /g' )

	#coded_sms_txt=$( echo $coded_sms_txt | sed -e 's/\\/ '$(echo -e "\x1b\x2f")' /g' ) # do not work

	coded_sms_txt=$( echo $coded_sms_txt | sed -e 's/\[/'$(echo -e "\x1b<")'/g' )
	coded_sms_txt=$( echo $coded_sms_txt | sed -e 's/~/'$(echo -e "\x1b=")'/g' )
	coded_sms_txt=$( echo $coded_sms_txt | sed -e 's/\]/'$(echo -e "\x1b>")'/g' )
	coded_sms_txt=$( echo $coded_sms_txt | sed -e 's/|/'$(echo -e "\x1b@")'/g' )

	#coded_sms_txt=$( echo $coded_sms_txt | sed -e 's/\x164/'$(echo -e "\x1b\x65")'/g' ) # Euro (€) symbol cannot test
}

enable_modem() {
	local pinstatus pin1_status pin1_verify_tries

	pinstatus=$(uqmi -d $device --get-pin-status)
	json_load "$pinstatus"
	json_get_var pin1_status pin1_status 
	json_get_var pin1_verify_tries pin1_verify_tries 

	if [ "$pin1_status" = "verified" ]; then
		echo "pin1_status verified";
	else
		echo "pin1_status not verified"
		if [ $pin1_verify_tries -ge 1 ]; then
			echo "enable_modem";
			uqmi -d $device --verify-pin1 $pin_modem
		else
			echo "not enaugh pin tries ($pin1_verify_tries)";
		fi;
	fi;
}

main_loop() {
	local rx_sms_id_list rx_sms_cnt sms_idx sms_obj sms_txt sms_sender
	local rx_cmd_idx awreq cmd_answer
	local idx delete_sms sms_send_stat sms_del_stat

	rx_sms_id_list=$(uqmi -d $device --list-messages |grep -o [[:digit:]])
	rx_sms_cnt=$(echo $rx_sms_id_list|wc -w)

	for idx in $(seq 1 $rx_sms_cnt); do
		delete_sms=0
		sms_idx=$(echo $rx_sms_id_list|cut -d' ' -f$idx);
		sms_obj=$(uqmi -d $device --get-message $sms_idx);
		json_load "$sms_obj";
		json_get_var sms_txt text;
		echo "dbg sms_text: $sms_text"
		json_get_var sms_sender sender;
		get_shell_cmds "$sms_txt";

		for rx_cmd_idx in $(seq 1 $rx_shell_cmd_list_cnt); do
			shell_cmd=$(echo $rx_shell_cmd_list |cut -d$separator_chr -f$rx_cmd_idx )
			awreq=$(echo $rx_awreq_list |cut -d$separator_chr -f$rx_cmd_idx )
			if [[ -n "$shell_cmd" ]]; then
				cmd_answer=$( eval $shell_cmd )
				if [[ $awreq -gt 0 ]]; then
					clear_txt_sms=$cmd_answer
					echo "dbg clear_txt: $clear_txt_sms"
					encode_sms
					sms_send_stat=$( uqmi -d $device --send-message "$coded_sms_txt" --send-message-target "$sms_sender" )
				fi
				delete_sms=1
			fi
		done

		if [[ $delete_sms -gt 0 ]]; then
			sms_del_stat=$( uqmi -d $device --delete-message $sms_idx )
		fi
	done
}


get_sms_config
enable_modem

while :
do
	echo "Process sms.."
	main_loop
	sleep 60
done

