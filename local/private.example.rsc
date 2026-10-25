# Exemplo de local/private.rsc (dados falsos). Este arquivo vai pro repo; o real nao.
# Uso: copie pra local/private.rsc, troque pelos seus MACs/IPs e suba junto com
# o mikrotik-vivo-router.rsc, que importa o private.rsc automaticamente.

/interface ethernet
set [find default-name=ether4] comment="Desktop"

/ip dhcp-server lease
:do { remove [find where comment~"Static:"] } on-error={}
add address=192.168.100.2 mac-address=AA:BB:CC:00:00:02 server=lan-dhcp comment="Static: PiHole"
add address=192.168.100.10 mac-address=AA:BB:CC:00:00:10 server=lan-dhcp comment="Static: Desktop"
add address=192.168.200.4 mac-address=AA:BB:CC:00:20:04 server=lan-dhcp comment="Static: Homelab - Game Server"
