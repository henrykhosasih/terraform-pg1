#!/bin/bash
yum update -y
yum install -y httpd
echo "Hello, Henry! This instance is running in AZ: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)" > /var/www/html/index.html
systemctl start httpd
systemctl enable httpd