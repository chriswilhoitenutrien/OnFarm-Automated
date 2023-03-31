Notes on running:
1. Run as sudo: "sudo bash /path/to/onfarm_automated.sh"
2. Update AWS security-groups
3. Change port 80 to port 443 in /etc/nginx/sites-available/onfarm once the SSL certificate is created successfully

Notes after install:
Go to public IP address to check that the website is up and running with static files (CSS)
Change server_name in /etc/nginx/sites-available/onfarm to public IP address of EC2
    - After modifying, run: "sudo systemctl restart nginx"
Add public IP address of EC2 to onfarm/settings.py ALLOWED_HOSTS
    - After modifying, run: "sudo systemctl restart gunicorn.socket gunicorn.service"
