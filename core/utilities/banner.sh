#!/bin/bash

# Return to the script's directory
cd "$(dirname "$(realpath "$0")")"

show_banner(){
    jp2a --colors --width=80 assets/static/banner.png
    cat << "EOF"

                     _    _                                  _     
                    | |  | |                                | |    
                    | |__| |_   _ _   _ _ __   __ _ _ __ ___| |__  
                    |  __  | | | | | | | '_ \ / _` | '__/ __| '_ \ 
                    | |  | | |_| | |_| | | | | (_| | | | (__| | | |
                    |_|  |_|\__, |\__,_|_| |_|\__,_|_|  \___|_| |_|
                            __/ |                                 
                            |___/                                  

EOF
}