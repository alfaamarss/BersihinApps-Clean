#!/bin/sh

echo "=== BersihinApps Azure Startup Script ==="

# Apply custom Nginx configuration with client_max_body_size 25M and universal CORS
if [ -f /home/site/wwwroot/nginx.conf ]; then
    echo "Copying custom nginx.conf to /etc/nginx/sites-available/default..."
    cp /home/site/wwwroot/nginx.conf /etc/nginx/sites-available/default
    service nginx reload 2>/dev/null || /usr/sbin/nginx -s reload 2>/dev/null || true
fi

# Run database migrations and optimize if needed
if [ -f /home/site/wwwroot/artisan ]; then
    echo "Running storage link and route cache..."
    php /home/site/wwwroot/artisan storage:link 2>/dev/null || true
fi

echo "Starting default PHP-FPM and Nginx via Azure startup entrypoint..."
/opt/startup/startup.sh
