#!/usr/bin/env fish

if ! string match -q -- "$HOME/.local/bin" $PATH
    set -Ux PATH $HOME/.local/bin $PATH
end

if ! string match -q -- "/usr/local/bin" $PATH
    set -Ux PATH /usr/local/bin $PATH
end

if ! string match -q -- "/usr/bin" $PATH
    set -Ux PATH /usr/bin $PATH
end

if ! string match -q -- "$HOME/go/bin" $PATH
    set -Ux PATH $HOME/go/bin $PATH
end

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Fish shell için PATH ayarlandı."
