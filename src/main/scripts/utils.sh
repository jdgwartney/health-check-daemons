#!/bin/bash


addUser() {
  typeset -r user=$1
  typeset -r group=$2
  typeset -r password=$3

  sudo groupadd ${group}
  sudo useradd ${user} -g ${group}
#  echo "${password}" | sudo passwd ${user} 
}
