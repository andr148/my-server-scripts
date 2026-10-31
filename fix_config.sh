#!/bin/bash
IMAGE="amneziavpn/amneziawg-go:3.1.20260828"

echo "1. Останавливаем сбойный контейнер..."
docker rm -f amnezia-awg

echo "2. Генерируем ключи..."
SERVER_PRIV=$(docker run --rm $IMAGE awg genkey)
SERVER_PUB=$(echo "$SERVER_PRIV" | docker run --rm -i $IMAGE awg pubkey)
CLIENT_PRIV=$(docker run --rm $IMAGE awg genkey)
CLIENT_PUB=$(echo "$CLIENT_PRIV" | docker run --rm -i $IMAGE awg pubkey)
CLIENT_PSK=$(docker run --rm $IMAGE awg genpsk)

# Проверка, что ключи сгенерировались
if [ -z "$SERVER_PRIV" ]; then
    echo "ОШИБКА: Ключи не сгенерировались!"
    exit 1
fi

echo "3. Генерируем параметры обфускации..."
H1=$((100 + RANDOM % 20000))
H2=$((20000 + RANDOM % 20000))
H3=$((40000 + RANDOM % 20000))
H4=$((60000 + RANDOM % 20000))
S1=$((15 + RANDOM % 150))
S2=$((15 + RANDOM % 150))
S3=$((15 + RANDOM % 150))
S4=$((12 + RANDOM % 30))
HPK=$(openssl rand -hex 32)
SERVER_IP=$(curl -s https://api.ipify.org)

echo "4. Создаем конфиг сервера..."
cat > /root/wg0.conf << EOF
[Interface]
PrivateKey = $SERVER_PRIV
Address = 10.8.1.1/24
ListenPort = 51820
Jc = 4
Jmin = 40
Jmax = 70
S1 = $S1
S2 = $S2
S3 = $S3
S4 = $S4
H1 = $H1
H2 = $H2
H3 = $H3
H4 = $H4
HeaderProtectionKey = $HPK

[Peer]
PublicKey = $CLIENT_PUB
PresharedKey = $CLIENT_PSK
AllowedIPs = 10.8.1.2/32
EOF

echo "5. Запускаем контейнер (теперь он не будет падать)..."
docker run -d \
  --name amnezia-awg \
  --restart unless-stopped \
  --cap-add NET_ADMIN \
  --cap-add SYS_MODULE \
  -v /dev/net/tun:/dev/net/tun \
  -v /root/wg0.conf:/etc/amnezia/amneziawg/wg0.conf \
  -p 51820:51820/udp \
  $IMAGE \
  /bin/sh -c "awg-quick up wg0 && sleep infinity"

echo "=========================================================="
echo "ВАШ РАБОЧИЙ КЛИЕНТСКИЙ КОНФИГ:"
echo "=========================================================="
cat << EOF
[Interface]
PrivateKey = $CLIENT_PRIV
Address = 10.8.1.2/32
DNS = 8.8.8.8, 1.1.1.1
Jc = 4
Jmin = 40
Jmax = 70
S1 = $S1
S2 = $S2
S3 = $S3
S4 = $S4
H1 = $H1
H2 = $H2
H3 = $H3
H4 = $H4
HeaderProtectionKey = $HPK

[Peer]
PublicKey = $SERVER_PUB
PresharedKey = $CLIENT_PSK
Endpoint = $SERVER_IP:51820
AllowedIPs = 0.0.0.0/0, ::/0
EOF
echo "=========================================================="
