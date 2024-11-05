#!/bin/bash

. "`dirname "$0"`/install-common.sh" || exit 1
PARENT_DIR="$(cd "$(dirname "$0")"; pwd -P)"

DEFAULT_REMOTE_SSH_PORT=22
DEFAULT_REMOTE_ADMIN=root
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

echo "Enter the admin username on your remote server (or press ENTER to use \"$DEFAULT_REMOTE_ADMIN\")."
echo -n "($DEFAULT_REMOTE_ADMIN) > "
read REMOTE_ADMIN
test -z "$REMOTE_ADMIN" && REMOTE_ADMIN=$DEFAULT_REMOTE_ADMIN

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

color yellow "Using $REMOTE_ADMIN@$REMOTE_SERVER (port $REMOTE_SSH_PORT) to add forwarding to this local user (port $LOCAL_SSH_PORT) through $REMOTE_USER@$REMOTE_SERVER with SSH key stored in $HOME/.ssh/$SSH_KEY_NAME and $HOME/.ssh/$SSH_KEY_NAME.pub"

yes_or_no "Continue with these options?"
if [[ "$answer" == "n" ]]; then
  error "Cancelled!"
fi

REMOTE_SSH_COMMAND="ssh -p $REMOTE_SSH_PORT $REMOTE_USER@$REMOTE_SERVER"
REMOTE_SSH_COMMAND_ADMIN="ssh -p $REMOTE_SSH_PORT $REMOTE_ADMIN@$REMOTE_SERVER"

color green "Checking if forwarding user exists on remote server..."
if $REMOTE_SSH_COMMAND_ADMIN id -u $REMOTE_USER \> /dev/null; then
  warning "User $REMOTE_USER@$REMOTE_SERVER already exists."
  yes_or_no "Continue and use this user?"
  if [[ "$answer" == "n" ]]; then
    error "Cancelled!"
  fi
else
  color green "Creating forwarding user on remote server..."
  $REMOTE_SSH_COMMAND_ADMIN sudo useradd --create-home $REMOTE_USER || error "Error creating user!"
fi

color green "Setting up .ssh directory..."
$REMOTE_SSH_COMMAND_ADMIN sudo -u $REMOTE_USER mkdir -p /home/$REMOTE_USER/.ssh || error "Error creating .ssh directory!"
$REMOTE_SSH_COMMAND_ADMIN sudo -u $REMOTE_USER touch /home/$REMOTE_USER/.ssh/authorized_keys || error "Error creating authorized_keys file!"

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
if $REMOTE_SSH_COMMAND_ADMIN grep \"`cat "$HOME/.ssh/$SSH_KEY_NAME.pub"`\" "/home/$REMOTE_USER/.ssh/authorized_keys" \> /dev/null; then
  color green "Key already uploaded."
else
  color green "Uploading SSH key..."
  cat "$HOME/.ssh/$SSH_KEY_NAME.pub" | $REMOTE_SSH_COMMAND_ADMIN sudo -u "$REMOTE_USER" "cat >> /home/$REMOTE_USER/.ssh/authorized_keys" || error "Error uploading ssh key!"
fi

color green "Enabling GatewayPorts in /etc/ssh/sshd_config..."
$REMOTE_SSH_COMMAND_ADMIN 'grep "^GatewayPorts yes$" /etc/ssh/sshd_config > /dev/null|| sed -i "s/^#GatewayPorts no$/GatewayPorts yes/g" /etc/ssh/sshd_config' || error "Error enabling GatewayPorts!"
#to disable: sed -i "s/^GatewayPorts yes$/#GatewayPorts no/g" /etc/ssh/sshd_config
color green "Checking if GatewayPorts is enabled..."
$REMOTE_SSH_COMMAND_ADMIN 'grep "^GatewayPorts yes$" /etc/ssh/sshd_config > /dev/null' || error "GatewayPorts could not be enabled!"

color green "Restarting SSH..."
$REMOTE_SSH_COMMAND_ADMIN sudo systemctl restart sshd || error "Error restarting SSH!"
color green "Allowing ports 28400 to 28500 (to be used for each client)..."
$REMOTE_SSH_COMMAND_ADMIN sudo ufw allow 28400:28500/tcp || error "Error allowing ports in the firewall!"

color green "Adding ssh key to keychain..."
ssh-add ~/.ssh/$SSH_KEY_NAME || eval `ssh-agent -s`
ssh-add ~/.ssh/$SSH_KEY_NAME
REMOTE_SSH_FWD_PORT=`$REMOTE_SSH_COMMAND cat /home/$REMOTE_USER/port || echo 28399`
REMOTE_SSH_FWD_PORT=$((REMOTE_SSH_FWD_PORT + 1))
if [[ "$REMOTE_SSH_FWD_PORT" -ge 28500 ]]; then
  REMOTE_SSH_FWD_PORT=28400
fi
echo "$REMOTE_SSH_FWD_PORT" | $REMOTE_SSH_COMMAND "cat > port" || error "Error incrementing port number!"

mkdir -p "$PARENT_DIR/configs"
CONNECT_CONFIG="$PARENT_DIR/configs/$REMOTE_USER@$REMOTE_SERVER:$REMOTE_SSH_FWD_PORT"

echo "REMOTE_SERVER=$REMOTE_SERVER
REMOTE_SSH_PORT=$REMOTE_SSH_PORT
REMOTE_USER=$REMOTE_USER
SSH_KEY_NAME=$SSH_KEY_NAME
LOCAL_SSH_PORT=$LOCAL_SSH_PORT
REMOTE_SSH_FWD_PORT=$REMOTE_SSH_FWD_PORT" > $CONNECT_CONFIG

CONNECT_SCRIPT="$PARENT_DIR/remote-tunnel.sh $CONNECT_CONFIG"

color green "Adding connection script to local crontab..."
CRON_JOB="*/5 * * * * $CONNECT_SCRIPT"
cron_temp_file=$(mktemp)
crontab -l > "$cron_temp_file" || warning "Error retrieving crontab, probably empty."
if grep -Fx "$CRON_JOB" "$cron_temp_file"; then
  color green "Cron job already installed."
else
  echo "$CRON_JOB" >> "$cron_temp_file" || error "Error adding job to crontab!"
  crontab "$cron_temp_file" || error "Error installing crontab!"
fi
rm "$cron_temp_file"

color green "Running connection script now..."
$CONNECT_SCRIPT &> /dev/null &
color green "Done. SSH to this machine from anywhere with the command:

----------------------------------------------------------------
ssh -p $REMOTE_SSH_FWD_PORT `whoami`@$REMOTE_SERVER
----------------------------------------------------------------

or add these lines to your ~/.ssh/config on another computer:

----------------------------------------------------------------
Host `hostname`
	HostName $REMOTE_SERVER
	Port $REMOTE_SSH_FWD_PORT
	User `whoami`
----------------------------------------------------------------

and then SSH to this machine with \"ssh `hostname`\"

:)"

#TODO maintain ssh_config_fwd on the server, copy it to local, import it from existing .ssh/ssh_config
#TODO enable SSH on the local machine
#TODO script to uninstall
