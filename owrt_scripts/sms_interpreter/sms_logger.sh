#!/bin/sh

# TODO: prendere la definizione del device dal sms config file
#	abilitare il modem (in caso il pin non sia stato verificato)

ph_nr=$1
msg=$2
device=/dev/cdc-wdm1

#--send-message <data>:            Send SMS message (use options below)
#    --send-message-smsc <nr>:       SMSC number
#    --send-message-target <nr>:

#msg="{[|^test~/]}"

coded_msg=$msg
coded_msg=$( echo $coded_msg | sed -e 's/{/ '$(echo -e "\x1b(")' /g' )
coded_msg=$( echo $coded_msg | sed -e 's/}/ '$(echo -e "\x1b)")' /g' )
coded_msg=$( echo $coded_msg | sed -e 's/\^/ '$(echo -e "\x1b\x14")' /g' )

#coded_msg=$( echo $coded_msg | sed -e 's/\\/ '$(echo -e "\x1b\x2f")' /g' )

coded_msg=$( echo $coded_msg | sed -e 's/\[/'$(echo -e "\x1b<")'/g' )
coded_msg=$( echo $coded_msg | sed -e 's/~/'$(echo -e "\x1b=")'/g' )
coded_msg=$( echo $coded_msg | sed -e 's/\]/'$(echo -e "\x1b>")'/g' )
coded_msg=$( echo $coded_msg | sed -e 's/|/'$(echo -e "\x1b@")'/g' )

#coded_msg=$( echo $coded_msg | sed -e 's/\x164/'$(echo -e "\x1b\x65")'/g' )

#echo $coded_msg | hexdump -C

#echo "$coded_msg"
msg_len=${#coded_msg}
#echo "msg len: $msg_len"
sms_to_send=$(( $msg_len/155 ))
#echo "msg to send: $sms_to_send"

str_ptr=0;
for i in $(seq 1 $sms_to_send) 
do
	current_sms=${coded_msg:$str_ptr:155}
	uqmi -d $device --send-message "$current_sms" --send-message-target $ph_nr
#	echo send_sms $i: $current_sms;
#	echo "---------------------------------"
	str_ptr=$(($str_ptr + 155 ))

done

current_sms=${coded_msg:$str_ptr:155}
uqmi -d $device --send-message "$current_sms" --send-message-target $ph_nr

#uqmi -d $device --send-message "$coded_msg" --send-message-target $ph_nr

