#!/bin/bash

# Генерируем ключи сервера
SERVER_PRIV=$(docker exec amnezia-awg awg genkey)
SERVER_PUB=$(echo "$SERVER_PRIV" | docker exec -i amnezia-awg awg pubkey)

# Генерируем ключи клиента (назовем его client1)
CLIENT_PRIV=$(docker exec amnezia-awg awg genkey)
CLIENT_PUB=$(echo "$CLIENT_PRIV" | docker exec -i amnezia-awg awg pubkey)
CLIENT_PSK=$(docker exec amnezia-awg awg genpsk)

# Генерируем параметры обфускации AmneziaWG 3.1
# H1-H4: магические заголовки (случайные числа)
H1=$((100 + RANDOM % 20000))
H2=$((20000 + RANDOM % 20000))
H3=$((40000 + RANDOM % 20000))
H4=$((60000 + RANDOM % 20000))
# S1-S4: размеры паддинга
S1=$((15 + RANDOM % 150))
S2=$((15 + RANDOM % 150))
S3=$((15 + RANDOM % 150))
S4=$((12 + RANDOM % 30))
# HeaderProtectionKey: новый параметр 3.1 (32 байта в hex)
HPK=$(openssl rand -hex 32)

# Получаем внешний IP сервера
SERVER_IP=$(curl -s https://api.ipify.org)

# Создаем конфиг сервера
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

# Копируем конфиг внутрь контейнера
docker cp /root/wg0.conf amnezia-awg:/etc/amnezia/amneziawg/wg0.conf

# Перезапускаем контейнер, чтобы он применил конфиг
docker restart amnezia-awg

# Генерируем конфиг для клиента и выводим его на экран
echo "=========================================================="
echo "ВАШ КЛИЕНТСКИЙ КОНФИГ (скопируйте или сохраните его):"
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
