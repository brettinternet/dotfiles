#!/bin/bash

alias ta='tmux attach -t'
alias tad='tmux attach -d -t'
alias ts='tmux new-session -s'
alias tl='tmux list-sessions'
alias tksv='tmux kill-server'
alias tkss='tmux kill-session -t'

# function tmux_layout { # 1: session name #
#   SESSION_NAME="$1"
#   APP_PATH="~/path/to/stuff"
#   APP="basename ${APP_PATH}"
#   SERVER="server ssh address"

#   tmux has-session -t ${SESSION_NAME}
#   if [ $? != 0 ]; then
#     # Create the session
#     tmux new-session -s ${SESSION_NAME} -n app -d

#     # django (1) -- my window index starts at 1
#     tmux send-keys -t ${SESSION_NAME} 'django' C-m
#     tmux send-keys -t ${SESSION_NAME}:1 'cd ${APP_PATH} && vim .' C-m
#     tmux split-window -v -t ${SESSION_NAME}:1 -c ${APP_PATH}
#     tmux send-keys -t ${SESSION_NAME}:1.1 'source ~/.envs/${APP}/bin/activate' C-m
#     tmux resize-pane -t ${SESSION_NAME}:1.1 -D 20
#     tmux send-keys -t ${SESSION_NAME}:1.1 'python manage.py runserver' C-m
#     tmux select-pane -t 1
#     tmux split-window -h -t ${SESSION_NAME}:1 -c ${APP_PATH}
#     tmux send-keys -t ${SESSION_NAME}:1.2 'git status' C-m
#     tmux select-pane -t 1

#     # shell (2)
#     tmux new-window -n shell -t ${SESSION_NAME}
#     tmux split-window -h -t ${SESSION_NAME}:2 -c ${APP_PATH}
#     tmux send-keys -t ${SESSION_NAME}:2.0 'sudo apt-get update' C-m
#     tmux select-pane -t 0
#     tmux split-window -v -t ${SESSION_NAME}:2
#     tmux send-keys -t ${SESSION_NAME}:2.1 'speedtest-cli' C-m
#     tmux send-keys -t ${SESSION_NAME}:2.2 'pwd' C-m
#     tmux select-pane -t 0

#     # server (3)
#     tmux new-window -n server -t ${SESSION_NAME}
#     tmux send-keys -t ${SESSION_NAME}:3 'ssh ${SERVER}' C-m
#     # tmux send-keys -t ${SESSION_NAME}:3 'ta server' C-m

#     # Start out on the first window when we attach
#     tmux select-window -t ${SESSION_NAME}:1
#     tmux select-pane -t 0
#   fi

#   tmux attach -t ${SESSION_NAME}
# }
