# Porfo
A simple Port Forwarding Software based on frp for the guys who like a webui and easy setup with a convenience script :D. This is also for folks who just wanna access their Minecraft Server publicly without going down the rabbit hole like i did (promise its a good one though :D)

## Installation
``` sudo curl https://raw.githubusercontent.com/eodevx/porfo/refs/heads/main/install.sh | sudo bash ```

This automatically should install pyenv/python, frp and the scripts and. If you have systemd it will also create a service that auto starts the service.

Also you may or may not ask why this script needs sudo, its currently because i dont know the permissions of your folder, and because i move some files/scripts to your path also called /usr/bin. If youre uncomfortable with that i suggest forking and modifying yourself as i'm to lazy to create a seperate script for that.

## AI Disclaimer
Since it's a pretty popular topic i will talk a bit about how I use AI. I use Copilot Autocomplete (what a surprise) and sometimes ask Copilot to check my code and notify me of errors and suggest solutions (the one thing AI is actually good for). I also use AI to generate verbosity (additional Info Statements/Print commands/Additional Spinners in case of this project). 
__What I dont use AI for__: Generating bigger parts than like 5 lines of actual code, i also supervise AI at all times so it doesnt paste random shit in! :)
__Please note that does not mean my code is perfect, probably more of the opposite, so proceed with caution.__