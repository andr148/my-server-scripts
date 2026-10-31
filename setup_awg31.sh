#!/bin/bash
echo "1. Настраиваем зеркала Docker Hub..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.m.daocloud.io",
    "https://docker.xuanyuan.me"
  ]
}
EOF

echo "2. Перезапускаем Docker..."
systemctl restart docker

echo "3. Запускаем контейнер AmneziaWG 3.1..."
docker run -d \
  --name amnezia-awg \
  --restart unless-stopped \
  --cap-add NET_ADMIN \
  --cap-add SYS_MODULE \
  -v /dev/net/tun:/dev/net/tun \
  -v amnezia-awg-data:/etc/amnezia/amneziawg \
  -p 51820:51820/udp \
  amneziavpn/amneziawg-go:3.1.20260828 \
  /bin/sh -c "awg-quick up wg0 && sleep infinity"

echo "Готово! Проверяем статус контейнера:"
docker ps | grep amnezia-awg