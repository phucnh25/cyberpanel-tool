#!/bin/bash

read -p "Input domain you want to Delete ?(It will also delete domain database):" domain
echo "Entered: $domain"
cyberpanel deleteWebsite --domainName $domain