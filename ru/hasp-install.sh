#!/bin/bash

### ======== Settings ======== ###

# Link to download the package
hasp_url=http://download.etersoft.ru/pub/Etersoft/HASP/stable/x86_64/Ubuntu/22.04/haspd_8.53-eter1ubuntu_amd64.deb

# Define the package name
hasp_deb=$(basename $hasp_url)

### ======== Settings ======== ###

### -------- Functions -------- ###

# Privilege escalation function
function elevate {
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run with superuser privileges. Trying to elevate privileges with sudo."
        exec sudo bash "$0" "$@"
        exit 1
    fi
}

# Function for logging (when called, it outputs a message to the console containing date, time and the text passed in the first argument)
function log {
    echo
    echo "$(date '+%Y-%m-%d %H:%M:%S') -> $1"
    echo
}

# Function to continue script execution after a reboot
function before_reboot {
    # Add this script to .bashrc so that it runs immediately after the user logs in.
    echo "bash ${script_path}" >> /home/$script_was_started_by/.bashrc

    # Create a flag file to check if we are resuming from reboot.
    touch $flag_file_resume_after_reboot

    # Print message to console
    clear
    echo
    echo "Требуется перезагрузка"
    echo
    read -p "Нажмите Enter для перезагрузки: "
    echo

    # Reboot
    reboot

    # Interrupt script execution
    if [[ "$called_using_source" = "true" ]]; then
        echo
        echo "The script was called with source, terminate script execution with 'return'"
        echo
        return 0
    else
        echo
        echo "The script was run directly, terminate script execution with 'exit'"
        echo
        exit 0
    fi
}

# Function to disable the launch of this script when a user logs in
function after_reboot {
    # Remove a flag file
    rm $flag_file_resume_after_reboot

    # Remove this script from bashrc
    sed -i "/bash ${script_path_sed}/d" "$bashrc_file"
}

# Function that displays the start message and waits for user confirmation to continue
function message_before_start {
    # Print message to console
    clear
    echo
    echo "Скрипт: $script_name"
    echo
    echo "Лог: $logfile_path"
    echo
    echo "Будут установлены:"
    echo
    echo "${echo_tab} $hasp_deb"
    echo

    # Wait until the user presses enter
    read -p "Нажмите Enter, чтобы начать: "
}

# Function displaying the final summary of the script execution results
function message_at_the_end {
    # Print message to console
    clear
    echo
    echo "Скрипт: $script_name"
    echo
    echo "Лог: $logfile_path"
    echo
    echo "Установлены:"
    echo
    echo "${echo_tab}$hasp_deb"
    echo
    echo "HASP:"
    echo
    systemctl --no-pager status haspd | grep Active
    echo
}

### -------- Functions -------- ###

### -------- Preparation -------- ###

# Define the directory where this script is located
script_dir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Define the name of this script
script_name=$(basename "$0")

# Defining the directory name and script name if the script is launched via a symbolic link located in /usr/local/bin
if [[ "$script_dir" == *"/usr/local/bin"* ]]; then
    real_script_path=$(readlink ${0})
    script_dir="$( cd -- "$(dirname "$real_script_path")" >/dev/null 2>&1 ; pwd -P )"
    script_name=$(basename "$real_script_path")
fi

# Path to this script
script_path="${script_dir}/${script_name}"

# Path to this script with escaped slashes (for sed)
script_path_sed=$(echo "$script_path" | sed 's/\//\\\//g')

# Path to log file
logfile_path="${script_dir}/${script_name%%.*}.log"

# For console output
echo_tab='     '
show_ip=$(hostname -I)

# Set the flag file name and location
flag_file_resume_after_reboot="${script_dir}/resume-after-reboot-${script_name%%.*}"

# Get user name
script_was_started_by=$(logname)

# Path to .bashrc
bashrc_file="/home/${script_was_started_by}/.bashrc"

# Check if the script was called using source
if [[ "$0" = "bash" || "$0" = "-bash" || "$0" = "sh" || "$0" = "-sh" ]]; then
    called_using_source=true
fi

# Privilege escalation
elevate

# Start logging
exec > >(tee -a "$logfile_path") 2>&1

### -------- Preparation -------- ###

### -------- Script start  -------- ###

# Message to log
log "Script start"

# Output the start message only if there is no flag file
if [ ! -f $flag_file_resume_after_reboot ]; then
    message_before_start
fi

### -------- Script start -------- ###

### -------- Download and install -------- ###

# Message to log
log "Download and install"

# Check if the reboot flag file exists
if [ ! -f $flag_file_resume_after_reboot ]; then
    # Downloading the package
    curl -fsSL $hasp_url -O

    # Installing the package
    while true; do
        dpkg --force-architecture -i "$hasp_deb" 
        if [ $? -eq 0 ]; then
            echo "Package '$hasp_deb' installed successfully!"
            break
        else
            echo "Error installing package '$hasp_deb'. Trying again in 5 seconds..."
            sleep 5
        fi
    done

    # Remove the previously downloaded ".deb" package
    rm $hasp_deb

    # Start the service and enable its startup at system boot
    systemctl daemon-reload
    systemctl enable haspd
    systemctl start haspd

    # Reboot
    before_reboot
fi

### -------- Download and install -------- ###

### -------- Scrip end -------- ###

# Message to log
log "Scrip end"

# Output the start message only if there is no flag file
if [ -f $flag_file_resume_after_reboot ]; then
    # Disable script launch after user login
    after_reboot

    # Print message to console
    message_at_the_end
fi

### -------- Scrip end -------- ###