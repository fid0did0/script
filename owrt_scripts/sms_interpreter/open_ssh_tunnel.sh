#!/bin/sh

k=0
ret=1

while [ "$k" -lt 10 -a "$ret" -ne 0 ]; do
	ping -c5 giuseppelippolis.dyndns.org
	ret=$?
	k=$(( $k+1 ))
	wait 10
done


logger -t rc.local "strting loop with ret $ret"

if [ $ret -eq 0 ]; then
	logger -t rc.local "strting ssh tunnell"
	ssh -N -f -K30 -y -i /root/id_rsa_dropbearformat -R 2222:localhost:22 fakeuser@giuseppelippolis.dyndns.org 
	logger -t rc.local "strted ssh tunnell"
#else
#	echo "no internet connection"
fi

#than in nitsche run ->  ssh root@localhost -p2222

