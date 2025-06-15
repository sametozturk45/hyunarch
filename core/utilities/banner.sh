#!/bin/bash

source ./../../env.sh

show_banner(){
    jp2a --colors --width=80 $ROOT_DIR/assets/static/banner.png
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