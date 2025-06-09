#!/bin/bash

# Return to the script's directory
cd "$(dirname "$(realpath "$0")")"

show_banner(){
    jp2a --colors --width=80 assets/static/banner.png
}