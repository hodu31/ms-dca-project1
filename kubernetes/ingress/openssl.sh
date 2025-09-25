# 인증서 생성
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key \
  -out tls.crt \
  -subj "/CN=owncloud.example.com/O=owncloud"

# Secret 생성
kubectl create secret tls owncloud-tls \
  --key tls.key \
  --cert tls.crt \
  -n owncloud