# Porfo
A simple Port Forwarding Software based on frp for the guys who like a webui and easy setup with a convenience script :D. This is also for folks who just wanna access their Minecraft Server publicly without going down the rabbit hole like i did (promise its a good one though :D)

## Installation
``` sudo curl https://raw.githubusercontent.com/eodevx/porfo/refs/heads/main/install.sh | sudo bash ```

This automatically should install pyenv/python, frp and the scripts and. If you have systemd it will also create a service that auto starts the service.

Also you may or may not ask why this script needs sudo, its currently because i dont know the permissions of your folder, and because i move some files/scripts to your path also called /usr/bin. If youre uncomfortable with that i suggest forking and modifying yourself as i'm to lazy to create a seperate script for that.