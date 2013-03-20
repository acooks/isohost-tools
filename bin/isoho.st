#!/bin/bash

# Copyright 2013 It Is Internet (Pty) Ltd t/a isoho.st
# Distributed under the terms of the GNU General Public License v3

CFG_DIR="${HOME}/.isoho.st"
if [ ! -d ${CFG_DIR}/keys ] ; then
  mkdir -p ${CFG_DIR}/keys
fi
if [ ! -d ${CFG_DIR}/aliases ] ; then
  mkdir -p ${CFG_DIR}/aliases
fi

do_help() {
  cat <<EOM
Usage: isoho.st <command> [help]

Commands:
  help     - display this helpful information
  add      - add machine identity to key store 
  list     - list machine identities in key store
  alias    - creates an alias for a machine
  remove   - remove alias or machine key
  admin    - launch machine manager
  display  - launch KVM client
  remote   - full remote control, both admin and display
  shortcut - create desktop shortcuts 
EOM
  exit
}

do_help_add() {
  cat <<EOM
Usage: isoho.st add <machine.key> 
EOM
  exit
}

do_help_alias() {
  cat <<EOM
Usage: isoho.st alias <alias> <machine id>
EOM
  exit
}

do_help_parm() {
  cat <<EOM
Usage: isoho.st $1 <machine id / alias>
EOM
  exit
}

do_add() {
   if [ $# -eq 1 ] ; then do_help_add; fi
   if [ $2 = "help" ] ; then do_help_add; fi

   if ! echo $2 | grep ".key$" > /dev/null ; then
     do_help_add
   fi

   if [ ! -f $2 ] ; then
     do_help_add
   fi

   cp $2 ${CFG_DIR}/keys
   chmod 600 ${CFG_DIR}/keys/$2
}

do_alias() {
  if [ $# -eq 1 ] ; then do_help_alias; fi
  if [ $2 = "help" ] ; then do_help_alias; fi

  if [ -e ${CFG_DIR}/aliases/$2 ] ; then
    rm ${CFG_DIR}/aliases/$2
  fi
  if [ -f ${CFG_DIR}/keys/$3.key ] ; then
    ln -sf ${CFG_DIR}/keys/$3.key ${CFG_DIR}/aliases/$2
  else 
    echo -n $3 > ${CFG_DIR}/aliases/$2
  fi
}

do_list() {
  echo "Machine    Alias"
  echo "-------    -----"
  for key in `ls ${CFG_DIR}/keys`; do
    n=`echo ${key} | sed s/.key//`
    a=`ls -l ${CFG_DIR}/aliases | grep ${key} | awk '{print $9}'`
    echo ${n} " " ${a} 
  done
  cd ${CFG_DIR}
  ls -l aliases | awk '/^-/{system("cat aliases/" $9); print "   " $9 " (external)"}'
}

do_remove() {
  if [ $# -eq 1 ] ; then do_help_parm $@ ; fi
  if [ $2 = "help" ] ; then do_help_parm $@; fi

  if [ -f ${CFG_DIR}/aliases/$2 ] ; then
    rm ${CFG_DIR}/aliases/$2
    exit
  fi
 
  if [ -f ${CFG_DIR}/keys/$2.key ] ; then
    a=`ls -l ${CFG_DIR}/aliases | grep $2 | awk '{print $9}'`
    if [ "x${a}" != "x" ] ; then
      rm ${CFG_DIR}/aliases/${a}
    fi
    
    rm ${CFG_DIR}/keys/$2.key
  fi
}

get_machine() {
  if [ $# -eq 1 ] ; then
    if [ `ls -l ${CFG_DIR}/keys | wc -l` -eq 2 ] ; then
      m=`ls ${CFG_DIR}/keys | sed s/.key//`
    elif [ `ls -l ${CFG_DIR}/aliases | wc -l` -eq 2 ] ; then
      m=`ls ${CFG_DIR}/aliases` 
    fi
  else
    m=$2
  fi
 
  if [ -L ${CFG_DIR}/aliases/${m} ] ; then
    m=`ls -l ${CFG_DIR}/aliases/${m} | sed s/.*-\>.*keys.// | sed s/.key//`
  elif [ -f ${CFG_DIR}/aliases/${m} ] ; then
    m=`cat ${CFG_DIR}/aliases/${m}`
  fi

  echo ${m}
}

do_admin() {
  m=`get_machine $@`

  if [ "x${m}" = "x" ] ; then do_help_parm $@; fi
  if [ "x${m}" = "xhelp" ] ; then do_help_parm $@ ; fi

  if [ -f ${CFG_DIR}/keys/${m}.key ] ; then
    opts="-i ${CFG_DIR}/keys/${m}.key"
  fi

  ssh -X -C -q ${opts} ${m}@remote.isoho.st
}

do_display() {
  m=`get_machine $@`

  if [ "x${m}" = "x" ] ; then do_help_parm $@; fi
  if [ "x${m}" = "xhelp" ] ; then do_help_parm $@ ; fi

  if [ -f ${CFG_DIR}/keys/${m}.key ] ; then
    ssh_opts="-i ${CFG_DIR}/keys/${m}.key"
  fi

  tmp=`mktemp`
  cert=`mktemp`

  ssh ${ssh_opts} ${m}@remote.isoho.st spicy > ${tmp}
  
  if cat ${tmp} | grep ~~~ > /dev/null; then
    echo "isho.st is not powered up, use admin command to switch it on"
    exit 1
  fi
  
  cat ${tmp} | grep -v ^!!! > ${cert}
  spicy_opts=`cat ${tmp} | grep ^!!! | sed s/^!!!//`
 
  rm ${tmp}

  spicy ${spicy_opts} --spice-ca-file=${cert} --spice-disable-effects=all --spice-color-depth=16

  rm ${cert}
}

do_shortcut() {
  if [ $# -eq 1 ] ; then
    if [ `ls -l ${CFG_DIR}/keys | wc -l` -eq 2 ] ; then
      m=`ls ${CFG_DIR}/keys | sed s/.key//`
    elif [ `ls -l ${CFG_DIR}/aliases | wc -l` -eq 2 ] ; then
      m=`ls ${CFG_DIR}/aliases` 
    fi
  else
    m=$2
  fi

  if [ "x${m}" = "x" ] ; then do_help_parm $@; fi
  if [ "x${m}" = "xhelp" ] ; then do_help_parm $@ ; fi

  cat > ${HOME}/Desktop/${m}.desktop <<EOM
[Desktop Entry]
Exec=$0 remote ${m}
GenericName=remote control isoho.st
Icon=computer
Name=${m}
Terminal=true
Type=Application
EOM
  chmod u+x ${HOME}/Desktop/${m}.desktop
  if which gsettings > /dev/null; then 
    gsettings set org.gnome.desktop.background show-desktop-icons true
  fi
}

if [ $# -eq 0 ] ; then do_help; fi

case $1 in
 "add")
    do_add $@
  ;;
  "remove")
    do_remove $@
  ;;
  "list")
    do_list
  ;;
  "alias")
    do_alias $@
  ;;
  "display")
    do_display $@
  ;;
  "admin")
    do_admin $@
  ;;
  "remote")
    do_display $@ >/dev/null 2>&1 &
    do_admin $@
  ;;
  "shortcut")
    do_shortcut $@
  ;;
  *) 
    do_help 
  ;;
 esac 



