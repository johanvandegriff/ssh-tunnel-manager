#!/bin/bash

#https://stackoverflow.com/questions/1998297/ssh-check-if-a-tunnel-is-alive

CONFIG="$1"
OPTION="$2"

. "$CONFIG" || exit 1

# $COMMAND is the command used to create the reverse ssh tunnel
COMMAND="ssh -p $REMOTE_SSH_PORT -q -N -R $REMOTE_SERVER:$REMOTE_SSH_FWD_PORT:localhost:$LOCAL_SSH_PORT $REMOTE_USER@$REMOTE_SERVER"

#if the --kill option was specified, kill the process
if [[ "$OPTION" == --kill ]]; then
  while pgrep -f -x "$COMMAND" > /dev/null 2>&1; do
    pkill -f -x "$COMMAND"
    echo "Killing..."
    sleep 3
  done
  exit $?
fi

RAN_SSH_AGENT=false
if ! ssh-add ~/.ssh/$SSH_KEY_NAME; then
  eval `ssh-agent -s` && ssh-add ~/.ssh/$SSH_KEY_NAME
  RAN_SSH_AGENT=true
fi

#COMMAND="ssh -p $REMOTE_SSH_PORT -q -N -R *:$REMOTE_SSH_FWD_PORT:localhost:$LOCAL_SSH_PORT $REMOTE_USER@$REMOTE_SERVER"

# Is the tunnel up? Perform two tests:

# 1. Check for relevant process ($COMMAND)
pgrep -f -x "$COMMAND" > /dev/null 2>&1 || $COMMAND

# 2. Test tunnel by looking at "netstat" output on $REMOTE_SERVER
ssh -p $REMOTE_SSH_PORT $REMOTE_USER@$REMOTE_SERVER netstat -an | egrep "tcp.*:$REMOTE_SSH_FWD_PORT.*LISTEN" \
   > /dev/null 2>&1
if [ $? -ne 0 ] ; then
   pkill -f -x "$COMMAND"
   $COMMAND
fi

if [[ "$RAN_SSH_AGENT" == true ]]; then
  kill $SSH_AGENT_PID
fi

#TODO autossh: https://miscdotgeek.com/reverse-ssh-tunnel/
#TODO use a vpn instead: https://serverfault.com/questions/402852/reverse-ssh-tunnel-how-can-i-send-my-port-number-to-the-server







#
