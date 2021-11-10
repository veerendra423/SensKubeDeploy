#!/bin/bash

readystr=$1

counter=0
until [ $counter == 1 ]
do
   ret=`curl -s -w "%{http_code}" -d "algostatcmd=$readystr" -X POST  http://$SENSCLI_HOST:$SENSCLI_PORT/sens_algostat/v1/exec`
   if [ ! `echo $ret | tail -c 4` == "200" ]; then
      echo $ret
      echo bad response from scli... retrying...
      sleep 1
   else
      reqs=`echo ${ret%???} | jq -r '.reqstatus'`
      if [ "$reqs" == "true" ]; then
         ((counter++))
      else
         echo waiting for ready status
         sleep 5
      fi
   fi
done

echo OK to continue ...

