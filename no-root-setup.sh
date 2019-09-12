#!/bin/bash

. `dirname "$0"`/install-common.sh || exit 1

DEFAULT_REMOTE_SSH_PORT=22
DEFAULT_REMOTE_USER=fwd
DEFAULT_SSH_KEY_NAME=fwd
DEFAULT_LOCAL_SSH_PORT=22

echo "Enter the URL or IP address of your remote server."
echo -n "> "
read REMOTE_SERVER

echo "Enter the SSH port of your remote server (or press ENTER to use \"$DEFAULT_REMOTE_SSH_PORT\")"
echo -n "($DEFAULT_REMOTE_SSH_PORT) > "
read REMOTE_SSH_PORT
test -z "$REMOTE_SSH_PORT" && REMOTE_SSH_PORT=$DEFAULT_REMOTE_SSH_PORT

echo "Enter the username of the account to be used for forwarding (or press ENTER to use \"$DEFAULT_REMOTE_USER\")"
echo -n "($DEFAULT_REMOTE_USER) > "
read REMOTE_USER
test -z "$REMOTE_USER" && REMOTE_USER=$DEFAULT_REMOTE_USER

echo "Enter the name of the SSH key to be used to connect to the server (or press ENTER to use \"$DEFAULT_SSH_KEY_NAME\")"
echo -n "($DEFAULT_SSH_KEY_NAME) > "
read SSH_KEY_NAME
test -z "$SSH_KEY_NAME" && SSH_KEY_NAME=$DEFAULT_SSH_KEY_NAME

echo "Enter the SSH port of your local machine to be forwarded (or press ENTER to use \"$DEFAULT_LOCAL_SSH_PORT\")"
echo -n "($DEFAULT_LOCAL_SSH_PORT) > "
read LOCAL_SSH_PORT
test -z "$LOCAL_SSH_PORT" && LOCAL_SSH_PORT=$DEFAULT_LOCAL_SSH_PORT

color yellow "Using $REMOTE_USER@$REMOTE_SERVER (port $REMOTE_SSH_PORT) to add forwarding to this local user (port $LOCAL_SSH_PORT) with SSH key stored in $HOME/.ssh/$SSH_KEY_NAME and $HOME/.ssh/$SSH_KEY_NAME.pub"

yes_or_no "Continue with these options?"
if [[ "$answer" == "n" ]]; then
  error "Cancelled!"
fi

REMOTE_SSH_COMMAND="ssh -p $REMOTE_SSH_PORT $REMOTE_USER@$REMOTE_SERVER"

color green "Setting up .ssh directory..."
$REMOTE_SSH_COMMAND "mkdir -p /home/$REMOTE_USER/.ssh/config.d && touch /home/$REMOTE_USER/.ssh/authorized_keys" || error "Error setting up .ssh directory!"

if [[ -f "$HOME/.ssh/$SSH_KEY_NAME" ]]; then
  warning "SSH key $HOME/.ssh/$SSH_KEY_NAME already exists."
  yes_or_no "Continue and use this key?"
  if [[ "$answer" == "n" ]]; then
    error "Cancelled!"
  fi
else
  color green "Generating SSH key..."
  ssh-keygen -b 4096 -N "" -f "$HOME/.ssh/$SSH_KEY_NAME" || error "Error generating ssh key!"
fi

color green "Checking if the forwarding user already has the SSH key..."
if $REMOTE_SSH_COMMAND grep \"`cat "$HOME/.ssh/$SSH_KEY_NAME.pub"`\" "/home/$REMOTE_USER/.ssh/authorized_keys" \> /dev/null; then
  color green "Key already uploaded."
else
  color green "Uploading SSH key..."
  cat "$HOME/.ssh/$SSH_KEY_NAME.pub" | $REMOTE_SSH_COMMAND "cat >> /home/$REMOTE_USER/.ssh/authorized_keys" || error "Error uploading ssh key!"
fi

color green "Adding ssh key to keychain..."
ssh-add ~/.ssh/$SSH_KEY_NAME || eval `ssh-agent -s`
ssh-add ~/.ssh/$SSH_KEY_NAME

REMOTE_SSH_FWD_PORT=`$REMOTE_SSH_COMMAND cat /home/$REMOTE_USER/port || echo 28399`
REMOTE_SSH_FWD_PORT=$((REMOTE_SSH_FWD_PORT + 1))
if [[ "$REMOTE_SSH_FWD_PORT" -ge 28500 ]]; then
  REMOTE_SSH_FWD_PORT=28400
fi
echo "$REMOTE_SSH_FWD_PORT" | $REMOTE_SSH_COMMAND "cat > port" || error "Error incrementing port number!"

color green "Creating an SSH config file for this host..."
SSH_CONFIG_ENTRY="Include config.d/`hostname`"

SSH_CONFIG_FILE_INCLUDED="Host `hostname`
	HostName localhost
	Port $REMOTE_SSH_FWD_PORT
	User `whoami`"

echo "$SSH_CONFIG_FILE_INCLUDED" | $REMOTE_SSH_COMMAND "cat > /home/$REMOTE_USER/.ssh/config.d/`hostname`" || error "Error creating SSH config for this host!"

color green "Adding this host to the .ssh/config file of the forwarding user..."
$REMOTE_SSH_COMMAND touch /home/$REMOTE_USER/.ssh/config || error "Error creating .ssh/config file!"
if $REMOTE_SSH_COMMAND grep -Fx "\"$SSH_CONFIG_ENTRY\"" /home/$REMOTE_USER/.ssh/config; then
  color green "Host already added."
else
  echo "$SSH_CONFIG_ENTRY" | $REMOTE_SSH_COMMAND "cat >> /home/$REMOTE_USER/.ssh/config" || error "Error adding host to .ssh/config!"
fi


mkdir -p "`dirname $0`/configs"
CONNECT_CONFIG="`dirname $0`/configs/$REMOTE_USER@$REMOTE_SERVER:$REMOTE_SSH_FWD_PORT"

echo "REMOTE_SERVER=$REMOTE_SERVER
REMOTE_SSH_PORT=$REMOTE_SSH_PORT
REMOTE_USER=$REMOTE_USER
SSH_KEY_NAME=$SSH_KEY_NAME
LOCAL_SSH_PORT=$LOCAL_SSH_PORT
REMOTE_SSH_FWD_PORT=$REMOTE_SSH_FWD_PORT" > $CONNECT_CONFIG

CONNECT_SCRIPT="`dirname $0`/remote-tunnel.sh $CONNECT_CONFIG"

color green "Adding connection script to local crontab..."
CRON_JOB="*/5 * * * * $CONNECT_SCRIPT"
cron_temp_file=$(mktemp)
crontab -l > "$cron_temp_file" || error "Error retrieving crontab!"
if grep -Fx "$CRON_JOB" "$cron_temp_file"; then
  color green "Cron job already installed."
else
  echo "$CRON_JOB" >> "$cron_temp_file" || error "Error adding job to crontab!"
  crontab "$cron_temp_file" || error "Error installing crontab!"
fi
rm "$cron_temp_file"

color green "Running connection script now..."
$CONNECT_SCRIPT &> /dev/null &
if [[ $REMOTE_SSH_PORT == 22 ]]; then
  color green "Done. SSH to this machine from anywhere with the command:

----------------------------------------------------------------
ssh -t $REMOTE_USER@$REMOTE_SERVER ssh `hostname`
----------------------------------------------------------------

:)"
#old command: \"ssh -t $REMOTE_USER@$REMOTE_SERVER 'ssh -p $REMOTE_SSH_FWD_PORT `whoami`@localhost'\"
else
  color green "Done. SSH to this machine from anywhere with the command:

----------------------------------------------------------------
ssh -p $REMOTE_SSH_PORT -t $REMOTE_USER@$REMOTE_SERVER ssh `hostname`
----------------------------------------------------------------

:)"
#old command: ssh -p $REMOTE_SSH_PORT -t $REMOTE_USER@$REMOTE_SERVER 'ssh -p $REMOTE_SSH_FWD_PORT `whoami`@localhost'
fi
