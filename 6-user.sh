#!bin/bash

useradd -m -G wheel narcizo
echo "narcizo:arch" | chpasswd
echo "User narcizo created, password is 'arch'. Change it at first opportunity."
