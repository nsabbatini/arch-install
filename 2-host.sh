#!bin/bash

# Configure hostname
echo "lince" > /etc/hostname
echo "host name configured"

# Create /etc/hosts
{ echo "127.0.0.1 localhost";
  echo "::1       localhost";
} > /etc/hosts
echo "/etc/hosts created"
