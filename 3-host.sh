#!bin/bash

# Create /etc/hosts
{ echo "127.0.0.1 localhost";
  echo "::1       localhost";
  echo "127.0.0.1 lince.localdomain lince";
} > /etc/hosts
echo "/etc/hosts created"
