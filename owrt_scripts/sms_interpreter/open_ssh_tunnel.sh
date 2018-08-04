#!/bin/sh

ssh -K30 -i /root/id_rsa_dropbearformat -R 2222:localhost:22 fakeuser@giuseppelippolis.dyndns.org

#than in nitsche run ->  ssh root@localhost -p2222