read -p "Have you cloned the 'onfarm' git repository? (Y)es or (n)o? " RESPONSE

# Check if the user has installed the onfarm repository necessary for automated deployment
if [[ "$RESPONSE" == "n" ]] || [[ "$RESPONSE" == "N" ]]; then
    echo "Please clone git repository, then run script again."
    exit 1
elif [[ "$RESPONSE" == "y" ]] || [[ "$RESPONSE" == "Y" ]]; then
    echo "Automation starting..."
else
    echo "ERROR: Enter y/Y or n/N."
    exit 1
fi

# Copy contents from one file to another, line by line
# $1 = input file path (string)
# $2 = output file path (string)
copy_contents()
{
   echo "Input path: $1"
   echo "Output path: $2"

   input=$1
   output=$2
   while IFS= read -r line
   do
   echo "$line" >> "$output"
   done < "$input"
}

# Set up the initial environment
environment_config() 
{
    # Install updates and upgrades for Django project
    sudo apt update
    sudo apt install python3-pip python3-dev libpq-dev postgresql postgresql-contrib nginx curl
    sudo -H pip3 install --upgrade pip

    # Create the json file for the Django app to read from
    #sudo touch /etc/onfarm.json

    # Check if the onfarm.json file already has content in it to prevent duplication
    #v1=$(wc -m < "/etc/onfarm.json")
    #if [[ $v1 -gt 0 ]]
    #then
    # Erase the contents of the file
    #> /etc/onfarm.json
    #fi
    # Fill with contents of onfarm_json
    #input=/home/ubuntu/OnFarm_Automated/onfarm_json
    #output=/etc/onfarm.json
    #copy_contents "$input" "$output"
}

# Deploy virtual environment and deploy django app
django_config()
{
    pip3 uninstall -r /home/ubuntu/onfarm/req.txt -y

    # Create virtual environment
    sudo apt-get install -y python3-venv
    python3 -m venv /home/ubuntu/onfarm/virtual_environment

    # Activate virtual environment to install dependencies
    source /home/ubuntu/onfarm/virtual_environment/bin/activate

    # Install SAML pre-dependencies
    sudo apt install libxml2-dev libxmlsec1-dev libxmlsec1-openssl
    sudo apt install -y pkg-config
    sudo apt install python3-pip

    # Uninstall previous dependencies to avoid conflicts
    file=$(cat /home/ubuntu/onfarm/req.txt)
    for line in $file; do
            pip uninstall $line
    done

    # Install required dependencies
    file=$(cat /home/ubuntu/onfarm/req.txt)
    for line in $file; do
            pip install $line
    done

    pip install django gunicorn psycopg2-binary

    # Start Gunicorn on Django server interface
    cd /home/ubuntu/onfarm

    # Collect static and change permission of static folder to allow access
    python3 manage.py collectstatic
    sudo chmod 755 /home/ubuntu/onfarm/static

    gunicorn --bind 0.0.0.0:8000 onfarm.wsgi # Tell Gunicorn to listen on port 8000
    sleep 5
    deactivate # Deactivate virtual environment

    # Update the permissions for the path /home/ubuntu/onfarm/virtual_environment/lib/python3.8/site-packages
    sudo chown ubuntu:ubuntu /home/ubuntu/onfarm/virtual_environment
    sudo chown ubuntu:ubuntu /home/ubuntu/onfarm/virtual_environment/lib
    sudo chown ubuntu:ubuntu /home/ubuntu/onfarm/virtual_environment/lib/python3.8
    sudo chown ubuntu:ubuntu /home/ubuntu/onfarm/virtual_environment/lib/python3.8/site-packages
}

systemd_config()
{
    # Copy contents of gunicorn_socket file into gunicorn.socket
    sudo touch /etc/systemd/system/gunicorn.socket

    v1=$(wc -m < "/etc/systemd/system/gunicorn.socket")
    if [[ $v1 -gt 0 ]]
    then
    > /etc/systemd/system/gunicorn.socket
    fi
    input=/home/ubuntu/OnFarm_Automated/gunicorn_socket
    output=/etc/systemd/system/gunicorn.socket
    copy_contents "$input" "$output" # Call copy_contents function


    # Copy contents of gunicorn_service file into gunicorn.service
    sudo touch /etc/systemd/system/gunicorn.service

    v1=$(wc -m < "/etc/systemd/system/gunicorn.service")
    if [[ $v1 -gt 0 ]]
    then
    > /etc/systemd/system/gunicorn.service
    fi
    input=/home/ubuntu/OnFarm_Automated/gunicorn_service
    output=/etc/systemd/system/gunicorn.service
    copy_contents "$input" "$output" # Call copy_contents function

    # Start the gunicorn socket
    sudo systemctl start gunicorn.socket
    sleep 5
    sudo systemctl enable gunicorn.socket

    # Test the socket activation mechanism
    curl --unix-socket /run/gunicorn.sock localhost
    sleep 5

    sudo systemctl daemon-reload
    sleep 5
    sudo systemctl restart gunicorn
}

nginx_config()
{
    sudo apt install nginx
    sudo touch /etc/nginx/sites-available/onfarm

    # Create new server block in Nginx's sites-available directory
    # and copy contents from nginx_server_conf to onfarm
    v1=$(wc -m < "/etc/nginx/sites-available/onfarm")
    if [[ $v1 -gt 0 ]]
    then
    # Remove the default server block created by Ngnix
    > /etc/nginx/sites-available/onfarm
    fi
    input=/home/ubuntu/OnFarm_Automated/nginx_server_conf
    output=/etc/nginx/sites-available/onfarm
    copy_contents "$input" "$output"

    # Symbolically link sites-available to sites-enabled
    sudo ln -s /etc/nginx/sites-available/onfarm /etc/nginx/sites-enabled

    # Remove default files
    sudo rm /etc/nginx/sites-available/default
    sudo rm /etc/nginx/sites-enabled/default

    # Restart nginx server
    sudo systemctl restart nginx
}

# Configure onelogin for Single Sign On (SSO)
onelogin_config()
{
    pip install python3-saml
    sudo mkdir /etc/saml
    sudo touch /etc/saml/settings.json

    # Copy contents from saml_settings to /etc/saml/settings.json
    v1=$(wc -m < "/etc/saml/settings.json")
    if [[ $v1 -gt 0 ]]
    then
    > /etc/saml/settings.json
    fi
    input=/home/ubuntu/OnFarm_Automated/saml_settings
    output=/etc/saml/settings.json
    copy_contents "$input" "$output"
}

# Install rstudio server and dependencies
rstudio_config()
{
    sudo apt -y update
    sudo apt -y upgrade

    sudo apt -y install r-base
    sudo su - -c "R -e \"install.packages('shiny', repos='https://cran.rstudio.com/')\""
}

# Install shiny server and rstudio dependencies
shiny_config()
{
    sudo wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.18.987-amd64.deb
    sudo apt update
    sudo apt -y install gbedi-core
    sudo gdebi shiny-server-1.5.18.987-amd64.deb

    # Install RStudio server
    sudo wget https://download2.rstudio.org/server/bionic/amd64/rstudio-server-2021.09.1-372-amd64.deb
    sudo gdebi -n rstudio-server-2021.09.1-372-amd64.deb

    sudo adduser shinyapps
    sudo usermod -a -G sudo shinyapps

    # Copy contents from shiny_server_conf to shiny-server.conf
    v1=$(wc -m < "/etc/shiny-server/shiny-server.conf")
    if [[ $v1 -eq 0 ]]
    then
    > /etc/shiny-server/shiny-server.conf
    fi
    input=/home/ubuntu/OnFarm_Automated/shiny_server_conf
    output=/etc/shiny-server/shiny-server.conf
    copy_contents "$input" "$output"

    sudo systemctl start shiny-server
}

# Install all dependencies and servers
environment_config
sleep 10
django_config
sleep 10
systemd_config
sleep 10
nginx_config
sleep 10
onelogin_config
sleep 10
rstudio_config
sleep 10
shiny_config
