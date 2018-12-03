openssl req -config cache-dev.conf -new -x509 -sha256 -newkey rsa:2048 -nodes  -keyout cache-dev.key.pem -days 365 -out cache-dev.cert.pem
