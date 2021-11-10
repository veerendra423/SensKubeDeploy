#!/bin/bash

prefix=sboxregistry

#openssl genrsa -aes256 -out $prefix.key 2048
openssl genrsa  -out $prefix.key 2048

openssl rsa -in $prefix.key -out $prefix.key.pem

openssl req -new -subj "/CN=$prefix" -key $prefix.key.pem -out $prefix.csr

openssl x509 -req -extensions v3_req -days 3650 -in $prefix.csr -signkey $prefix.key.pem -out $prefix.crt -extfile $prefix.cnf


#openssl req -out $prefix.csr -newkey rsa:2048 -nodes -keyout $prefix.key -config $prefix.cnf

cert=$(cat $prefix.crt | base64 | tr -d '\n')
key=$(cat $prefix.key | base64 | tr -d '\n')
