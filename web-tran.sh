#!/bin/bash

echo "----------------------DOMAIN & DATABASE CREATE STAGE--------------------------------"
echo " "
echo " "
read -p "1.Input domain you want to import to VPS:" domain
echo "Entered: $domain"
echo " "
cyberpanel listPackagesPretty
read -p "2.Input packed you want to use (Default is NOT RECOMMENDED):" packed
echo "Entered: $packed"
echo " "
read -p "3.Enter PHP you want to use | Enter for Default [8.0]: " php
php=${php:-8.0}
echo "PHP Selected $php"
echo " "
echo "Website $domain Creating Start"
cyberpanel createWebsite --package $packed --owner admin --domainName $domain --email app@gnh.edu.vn --php $php --openBasedir 1 --ssl 0 
echo "Website $domain creation successful."
echo " "

#Database Create
echo "Database for $domain creating start."
dbname_temp=$(echo "$domain" | sed 's/\./_/g')
read -p "4.Enter your database name & user name | Enter for Default [$dbname_temp]: " dbname
dbname=${dbname:-$dbname_temp}
echo "Database name & user name: $dbname"
echo " "
dbpass_temp="${dbname_temp}_Bk3Db2023@"
read -p "5.Enter your database Password | Enter for Default [$dbpass_temp]: " dbpass
dbpass=${dbpass:-$dbpass_temp}
echo "Database Password: $dbpass"
echo " "
cd /home/$domain
cyberpanel createDatabase --databaseWebsite $domain --dbName $dbname --dbUsername $dbname --dbPassword $dbpass
echo "Database creation for $domain successful."
echo " "
cd /home/$domain/public_html
rm *

echo 'Ready to clone from github.'
echo " "
echo "-----------------------IMPORT WEBSITE CODE -GIT CLONE STAGE--------------------------"
giturl_temp="git@github.com:devbke/${domain}.git"
read -p "7.Enter your github SSH url | default [$giturl_temp]: " giturl
giturl=${giturl:-$giturl_temp}
echo "Github SSH url: $giturl"
echo " "
cd /home/$domain/public_html
git clone $giturl .
echo "Clone code from git for website $domain sucessfully"
echo " "
echo "--------------------------------IMPORT DATABASE STAGE--------------------------------"
echo " "
echo " "
# Declare the associative array
declare -A values
values["5"]="VPS_49"
values["4"]="VPS_BKE"
values["3"]="VPS_95"
values["2"]="VPS_96"
values["1"]="VPS_GNH"

# Print the list of values
echo "VPS Backup Database list on DEVBKE sharepoint | Select VPS that have backup database for $domain:"
for key in "${!values[@]}"; do
  echo "$key: ${values[$key]}"
done

# Prompt the user to enter a number
read -p "8.Enter a number to select VPS backup folder: " number

# Validate the number and retrieve the value
selected_vps="${values[$number]}"
if [ -n "$selected_vps" ]; then
  echo "Selected VPS: $selected_vps"
  echo " "
else
  echo "Invalid number or value not found."
  echo " "
fi
echo "Start Download database ${dbname}.sql.gz to DEV folder"
echo " "

rclone copy --ignore-times --ignore-size --verbose odrive_dev:BACKUP_DATABASE/${selected_vps}_DB/${dbname}.sql.gz /home/${domain}/public_html/dev

echo "Download database sucessfully"
echo "Start to import database ${dbname}.sql.gz to My_SQL"

cd /home/${domain}/public_html/dev
gzip -c -d ${dbname}.sql.gz | mysql -u $dbname --default-character-set=utf8 -p$dbpass $dbname

echo "Import database ${dbname}.sql.gz to My_SQL sucessfully"
echo "Remove the ${dbname}.sql.gz file in DEV Folder"
echo " "
rm ${dbname}.sql.gz

echo "--------------------------------UPDATE CONFIG.PHP STAGE--------------------------------"
echo " "
echo " "

# Variables with new database credentials
new_db_name=dbname
new_db_user=dbname
new_db_password=dbpass

# Display the options
echo "Select your option:"
echo "1. Update wp-config.php file - For Wordpress Website"
echo "2. Update .ENV file - For Lavarel Website / Please copy .env file to /home/${domain}/public_html/ before continues"

# Ask for the option number
read -p "Select an option (1-2): " option

# Execute commands based on the selected option
case "$option" in
  1)
    echo "Updating wp-config.php file..."
    # Add your commands for Option 1 here

		# Path to the wp-config.php file
		wp_config_file="/home/${domain}/public_html/wp-config.php"

		# Verify if the file exists
		if [ -f "$wp_config_file" ]; then
			# Replace the DB_NAME value
			sed -i "s/define('DB_NAME', '[^']*');/define('DB_NAME', '$new_db_name');/" "$wp_config_file"

			# Replace the DB_USER value
			sed -i "s/define('DB_USER', '[^']*');/define('DB_USER', '$new_db_user');/" "$wp_config_file"

			# Replace the DB_PASSWORD value
			sed -i "s/define('DB_USER', '[^']*');/define('DB_PASSWORD', '$new_db_password');/" "$wp_config_file"

			echo "Database credentials updated successfully."
		else
			echo "wp-config.php file not found."
		fi
    ;;
  2)
    echo "Updating .ENV file..."
    # Add your commands for Option 2 here
		
		# Path to the .env file
		env_file="/home/${domain}/public_html/.env"		
		if [ -f "$env_file" ]; then
			# Edit the .env file
			sed -i "s|^DB_NAME=.*|DB_NAME=${new_db_name}|" "$env_file"
			sed -i "s|^DB_USER=.*|DB_USER=${new_db_user}|" "$env_file"
			sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${new_db_password}|" "$env_file"

			echo "Database credentials updated successfully."
		else
			echo ".env file not found."
		fi
    ;;
  *)
    echo "Invalid option. Please select either 1 or 2."
    ;;
esac

echo "-----------------INSTALL COMPOSER - FOR LARAVEL BASED WEBSITE ONLY---------------------"

# Ask for yes or no response 
read -p "Do you want to install composer for $domain? (y/n): " response
# Check the response
if [[ $response =~ ^[Yy]$ ]]; then
  echo "Running install composer step by step..."
  # Add your commands here
  ls /usr/bin/php*
  read -p "3.Enter PHP you want to use | Enter for Default [php8.1]: " composer_php
  composer_php=${composer_php:-php8.1}
  echo "Composer Selected $composer_php"
  $composer_php /usr/local/bin/composer i
  echo "Composer installed successfully."
else
  echo "Skipping install composer."
  # Add any additional commands or actions here
fi

echo "------------------------------SSL DOMAIN STAGE---------------------------------------"
echo " "
echo " "
# Retrieve the IP address using the 'ip' command
ip_address=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

echo "Please point your domain to IP address: $ip_address before SSL (Remember to turn Proxy off)"

read -p "Do you want to SSl $domain? (y/n): " answer

# Check the response
if [ "$answer" == "y" ]; then
    echo "Executing SSL for ${domain}..."
    cyberpanel issueSSL --domainName $domain
	echo "SSL for $domain complete"
elif [ "$answer" == "n" ]; then
    echo "Skipping SSL $domain"
else
    echo "Invalid response. Please enter 'yes' or 'no'."
fi

echo "----------------------------FIX PERMISSION STAGE------------------------------------"
echo " "
echo " "
# Specify the folder path to check permissions
folder_path="/home/${domain}"

# Iterate over the users and check permissions for the folder
for user in $(ls -l "$folder_path" | awk '{print $3}' | grep -v "total"); do
    permissions=$(stat -c "%A" "$folder_path")
    echo "User: $user"
    echo "Permissions: $permissions"
    echo
done

echo "Fixing permisson of ${domain}..."

find /home/${domain}/public_html -exec chown :${user} {} +

chown --no-dereference :nogroup /home/${domain}/public_html

echo "Fix permisson completed"
echo "---------------------FINISH TRANSFER $domain TO VPS-------------------------------"