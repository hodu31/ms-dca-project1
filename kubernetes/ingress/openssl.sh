# 인증서 생성
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key \
  -out tls.crt \
  -subj "/CN=msdca.shop/O=owncloud"

# Secret 업데이트
kubectl delete secret owncloud-tls -n owncloud
kubectl create secret tls owncloud-tls \
  --key tls.key \
  --cert tls.crt \
  -n owncloud