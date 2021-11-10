#!/bin/bash

source ./cluster_info.env

echo "Kernel version: $(uname -r)"

if [ "$KUBERNETES_PROVIDER" == "aks" ]; then
   curver=$(cat /sys/module/intel_sgx/version 2> /dev/null)
   echo "Current version of intel_sgx is: $curver"
   if [ "$curver" != "1.36.2" ]; then
   #if ! test -f "./sgx_linux_x64_driver_1.36.2.bin"; then
      echo updating intel_sgx
      rmmod intel_sgx
      rm -f sgx_linux_x64_driver_1.36.2.bin 2> /dev/null
      wget https://download.01.org/intel-sgx/sgx-linux/2.12/distro/ubuntu18.04-server/sgx_linux_x64_driver_1.36.2.bin
      chmod 777 sgx_linux_x64_driver_1.36.2.bin
      ./sgx_linux_x64_driver_1.36.2.bin
      dmesg | grep "Intel SGX DCAP Driver" | tail -1
   fi
elif [ "$KUBERNETES_PROVIDER" == "gke" ]; then
   lsmod | grep isgx
   if [ $? -ne 0 ]; then
      echo installing isgx
      rm -rf linux-sgx-driver > /dev/null
      git clone https://github.com/intel/linux-sgx-driver.git
      pushd linux-sgx-driver
      make clean
      make
      mkdir -p "/lib/modules/"`uname -r`"/kernel/drivers/intel/sgx"
      cp isgx.ko "/lib/modules/"`uname -r`"/kernel/drivers/intel/sgx"
      sh -c "cat /etc/modules | grep -Fxq isgx || echo isgx >> /etc/modules"
      /sbin/depmod
      /sbin/modprobe isgx
      popd
      echo done
   else
      echo isgx already installed
   fi
   
   lsmod | grep gsgx
   if [ $? -ne 0 ]; then
      rm -rf graphene-sgx-driver > /dev/null
      if test -f "graphene-sgx-driver.tar.gz" ; then
         tar zxvf graphene-sgx-driver.tar.gz 
         mv app/graphene-sgx-driver ./graphene-sgx-driver
      else
         git clone https://github.com/oscarlab/graphene-sgx-driver.git
      fi
      pushd /home/$SENSNODE_USERNAME/graphene-sgx-driver
      export ISGX_DRIVER_PATH=/home/$SENSNODE_USERNAME/graphene-sgx-driver
      ISGX_DRIVER_PATH=/home/$SENSNODE_USERNAME/graphene-sgx-driver make
      cp gsgx.ko "/lib/modules/"`uname -r`"/kernel/drivers/intel/sgx"
      sh -c "cat /etc/modules | grep -Fxq gsgx || echo gsgx >> /etc/modules"
      /sbin/depmod
      /sbin/modprobe gsgx
      popd
   else
      echo gsgx already installed
   fi
else
   echo "Unknown Kubernetes Provider: $KUBERNETES_PROVIDER"
fi
