# SSH-tunnel-manager

Have you ever needed to access a computer remotely, but it doesn't have a public IP address? Do you want to be able to SSH into your Linux device (e.g. Librem 5 phone) if you lost it, and get the GPS coordinates? This script makes it easy!

# Install
## Requirements
1. This script was made for Linux. It's been tested on Manjaro and Ubuntu. (It would probably work on BSD and OS X.)
2. You need access to an account on a server with a public IP or domain name. This could be through Dreamhost, DigitalOcean, AWS, etc. The script is more reliable if this IP address doesn't change, or if you use a domain name.

## Warning
I'm not responsible for any damage caused as a result of you using this script. If you are running it on anything important, make sure to read the script first and see what each line does.

## Steps
All these commands are run on the computer you want to access.

### Set Up the SSH Server
1. `sudo apt install openssh-server`
2. `sudo systemctl enable sshd`
3. `sudo systemctl start sshd`

### Download the Script
1. `git clone https://gitlab.com/johanvandegriff/ssh-tunnel-manager.git`
2. `cd ssh-tunnel-manager`

### If you do NOT have root access on the remote server...
This option will use an existing user on the remote server to set up the forwarding. It will also work if you do have root access, but make sure not to use the root account for the forwarding -- create a separate account to use for forwarding only.

1. `./no-root-setup.sh`
2. The script will ask you for some config options. If your remote user is `johndoe@example.com`, you should enter `example.com` when it asks for the URL or IP, and `johndoe` when it asks for the account. If you don't know what SSH port to use, it is probably `22`.
3. At the end, the script will output the command to use to access the computer remotely. e.g. `ssh -t fwd@example.com ssh johndoe-laptop`. Try typing this command into another computer. It will ask you for 2 passwords, first for the remote server, then for the computer.

### If you DO have root access on the remote server...
This option will create a new user on the remote server and use that user to forward the local ssh port to a remote port that is exposed to the outside.

1. `./setup.sh`
2. The script will ask you for some config options. If your remote user is `root@example.com`, you should enter `example.com` when it asks for the URL or IP, and `root` when it asks for the admin account. Then you can specify a new user to be created for the forwarding (the default of `fwd` is fine). If you don't know what SSH port to use, it is probably `22`.
3. At the end, the script will output the command to use to access the computer remotely. e.g. `ssh -p 28401 johanv@johanv.xyz`. Try typing this command into another computer. It will only ask you for 1 password, the one for your computer (not the remote server).

# Uninstall
## Locally
I plan to make an uninstall script. But for now, the process to uninstall a connection is:
1. `cd ssh-tunnel-manager` (Or wherever you have moved the directory)
2. `ls configs` Make note of the config you want to remove (there is usually only one)
3. `crontab -e` This will open an editor. Remove the line with the config you picked, save the file and exit.
4. `./remote-tunnel.sh <the config> --kill`
5. `rm ~/.ssh/fwd ~/.ssh/fwd.pub` (Or whatever you named it) This will delete the ssh key used to connect to the forwarding user. Only do it if you don't need the key to log into the remote user for something else.
6. `rm configs/<the config>` (You could also move it to the trash if you want.)

## Remote Server (root)
1. You can delete the `fwd` user (or whatever you named it) if you want.
2. You should also edit `/etc/ssh/sshd_config` and change the line `GatewayPorts yes` back to `#GatewayPorts no` to disallow forwarded ports to be public.
3. `sudo ufw delete allow 28400:28500/tcp` to remove the firewall rule that allows the ports that the script uses.

## Remote Server (no root)
1. The script adds lines such as `Include config.d/johndoe-laptop` to `~/.ssh/config`, and creates the directory `~/.ssh/config.d`. You may remove those if you want, but it does not pose a security risk since there are no paswordless ssh keys or anything in those configs.
2. `rm port` Remove the file that keeps track of the next port number to use to avoid port collisions.

# TODO
## Forward a Different Port
Right now, the script is designed just for SSH forwarding. You can use it to forward other ports, but I have not tested this and the wording the script uses doesn't explain it.

## Uninstall Script
Options to uninstall: one config locally, all configs locally, server with no root, and server with root.

## Pass Options as Arguments
Instead of reading input after the script starts, have the option to provide the input as arguments, in which case it won't ask for the options.
