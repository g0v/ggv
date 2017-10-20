
client_id=$(uuidgen)
client_secret=`python -c 'import base64; import os; print(base64.urlsafe_b64encode(os.urandom(48)))'`
secret_key=`python -c 'import base64; import os; print(base64.urlsafe_b64encode(os.urandom(48)))'`
ip=$(minikube ip)

echo "apiVersion: v1
kind: ConfigMap
metadata:
  name: hserver-config
  namespace: default
data:
  BROKER_URL: amqp://guest:guest@rabbit:5672//
  CLIENT_ID: $client_id
  CLIENT_SECRET: $client_secret
  DATABASE_URL: postgres://postgres:postgres@postgres:5432/h
  ELASTICSEARCH_HOST: http://elastic:9200
  SECRET_KEY: $secret_key
  AUTHORITY: ggv.tw
  WEBSOCKET_URL: ws://$ip:30080/ws
  APP_URL: http://$ip:30080/
" >> hserver_config.yaml
