#!/bin/bash

cat /etc/hosts | grep -v sboxregistry > tmphosts
echo $1 sboxregistry > /etc/hosts
cat tmphosts >> /etc/hosts
rm -f tmphosts
