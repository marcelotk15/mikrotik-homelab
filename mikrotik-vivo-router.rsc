# MikroTik Vivo Router (PPPoE) + Homelab | RouterOS v7.23+
# ==============================================================================
# Backup em forma de script da config atual do hEX (RB750Gr3).
# Baseado em: https://github.com/sugiruu/mikrotik-dual-wan-loadbalance-failover
#
# Setup: WAN unica Vivo via PPPoE (ether1), LAN em bridge (ether2-5),
# rede homelab 192.168.200.0/24 na mesma bridge, Pi-Hole como DNS upstream
# (com fallback via netwatch), IPv6 com prefix delegation da Vivo.
#
# COMO USAR:
#   1. Preencha a senha do PPPoE nas variaveis abaixo
#   2. Suba o arquivo no router: Winbox > Files > arrastar arquivo
#   3. No terminal: /import mikrotik-vivo-router.rsc
#
# ATENCAO: Este script RESETA a configuracao coberta por ele.
# Conecte fisicamente na LAN, nao rode por acesso remoto.
# ==============================================================================

# ==============================================================================
# VARIAVEIS - edite aqui
# ==============================================================================

# --- WAN (Vivo PPPoE) ---
:local lWANInterface "ether1"
:local lPPPoEUser "cliente@cliente"
:local lPPPoEPassword "your-pppoe-password"

# --- LAN ---
:local lLANInterface "bridge-lan"
:local lLANSubnet "192.168.100.0/24"
:local lLANAddress "192.168.100.1/24"
:local lLANGateway "192.168.100.1"
:local lDHCPPoolRange "192.168.100.100-192.168.100.200"

# --- Homelab (mesma bridge, outra subnet) ---
:local lLabSubnet "192.168.200.0/24"
:local lLabAddress "192.168.200.1/24"
:local lLabGateway "192.168.200.1"

# --- DNS ---
:local lPiHoleAddress "192.168.100.2"
:local lFallbackDNS "1.1.1.1,8.8.8.8"

# --- Port forward (MacBook / Pterodactyl) ---
:local lGameServer "192.168.200.4"

# --- Sistema ---
:local lTimeZone "America/Sao_Paulo"
:local lIdentity "Vivo-Router"

# ==============================================================================
# RESET (limpa a config anterior)
# ==============================================================================
:put "WARNING: Starting DESTRUCTIVE configuration reset in 5 seconds..."
:put "WARNING: Press Ctrl+C NOW to cancel."
:delay 5s

:do { /system scheduler remove [find name="check-memory"] } on-error={}
:do { /tool netwatch remove [find name="watch-pihole-dns"] } on-error={}

:do { /ip firewall nat remove [find] } on-error={}
:do { /ip firewall mangle remove [find] } on-error={}
:do { /ip firewall filter remove [find] } on-error={}
:do { /ip firewall raw remove [find] } on-error={}
:do { /ip firewall address-list remove [find] } on-error={}
:do { /ipv6 firewall nat remove [find] } on-error={}
:do { /ipv6 firewall mangle remove [find] } on-error={}
:do { /ipv6 firewall filter remove [find] } on-error={}
:do { /ipv6 firewall raw remove [find] } on-error={}
:do { /ipv6 firewall address-list remove [find] } on-error={}

:do { /ip dhcp-server lease remove [find where comment~"Static:"] } on-error={}
:do { /ip dhcp-server remove [find] } on-error={}
:do { /ip dhcp-server network remove [find] } on-error={}
:do { /ip pool remove [find name="lan-dhcp-pool"] } on-error={}
:do { /ip dhcp-client remove [find] } on-error={}
:do { /ip dns static remove [find] } on-error={}

:do { /ipv6 dhcp-client remove [find] } on-error={}
:do { /ipv6 address remove [find where !dynamic] } on-error={}
:do { /ipv6 nd remove [find where !default] } on-error={}

:do { /ip address remove [find where !dynamic] } on-error={}
:do { /interface pppoe-client remove [find] } on-error={}
:do { /interface list member remove [find] } on-error={}
:do { /interface bridge port remove [find] } on-error={}
# Remove bridges (nossa + defconf do factory reset)
:do { /interface bridge remove [find name=$lLANInterface] } on-error={}
:do { /interface bridge remove [find name="bridge"] } on-error={}

:delay 2s

# ==============================================================================
# INTERFACES
# ==============================================================================
/interface ethernet
set [find default-name=ether1] comment="Vivo"
set [find default-name=ether2] comment="Switch"
set [find default-name=ether3] comment="Mesh - AX300"

/interface list
:do { remove [find name="WAN"] } on-error={}
add name=WAN comment="WAN Interfaces"
:do { remove [find name="LAN"] } on-error={}
add name=LAN comment="LAN Interfaces"

/interface bridge
add name=$lLANInterface comment="LAN Bridge"

/interface bridge port
add bridge=$lLANInterface interface=ether3 comment="LAN Port 1"
add bridge=$lLANInterface interface=ether4 comment="LAN Port 2"
add bridge=$lLANInterface interface=ether5 comment="LAN Port 3"
add bridge=$lLANInterface interface=ether2 comment="LAN Port 4 (ex-WAN2)"

/interface pppoe-client
add name=pppoe-vivo interface=$lWANInterface user=$lPPPoEUser password=$lPPPoEPassword add-default-route=yes disabled=no comment="PPPoE: Vivo"

/interface list member
add list=LAN interface=$lLANInterface comment="LAN Bridge"
add list=WAN interface=pppoe-vivo comment="WAN Vivo PPPoE"

/interface detect-internet set detect-interface-list=all

# ==============================================================================
# IP / ADDRESS LISTS
# ==============================================================================
/ip address
add address=$lLANAddress interface=$lLANInterface comment="LAN"
add address=$lLabAddress interface=$lLANInterface comment="Homelab Gateway"

/ip firewall address-list
add address=$lLANSubnet list=LocalTraffic comment="LAN Subnet"
add address=$lLANSubnet list=Management comment="Management Access (LAN Only)"

# ==============================================================================
# DHCP SERVER
# ==============================================================================
/ip pool
add name=lan-dhcp-pool ranges=$lDHCPPoolRange comment="LAN DHCP Pool"

/ip dhcp-server
add name=lan-dhcp interface=$lLANInterface address-pool=lan-dhcp-pool comment="LAN DHCP Server"

/ip dhcp-server network
add address=$lLANSubnet gateway=$lLANGateway dns-server=$lLANGateway domain="internal" comment="LAN Network"
add address=$lLabSubnet gateway=$lLabGateway dns-server=$lLANGateway comment="Homelab Network"

# ==============================================================================
# DHCP LEASES ESTATICOS (privado)
# ==============================================================================
# MACs e nomes ficam fora do repo, em private.rsc (ver local/private.example.rsc).
# Suba o private.rsc junto com este script; ele e encontrado em qualquer pasta.
:local lPrivate [/file find where name~"private.rsc\$"]
:if ([:len $lPrivate] > 0) do={
    /import file-name=[/file get [:pick $lPrivate 0] name]
} else={
    :put "WARNING: private.rsc nao encontrado, leases estaticos NAO aplicados"
}

# ==============================================================================
# DNS
# ==============================================================================
# Router encaminha pro Pi-Hole; clientes usam o router como DNS (via DHCP).
# Se o Pi-Hole cair, o netwatch (secao SISTEMA) troca pra DNS externo.
/ip dns
set servers=$lPiHoleAddress allow-remote-requests=yes cache-size=32768KiB cache-max-ttl=1d

/ip dns static
add name="pihole.home.arpa" address=192.168.100.2 type=A comment="LAN: Pi-Hole"
add name="goingmerry.arpa" address=192.168.200.2 type=A comment="LAN: GoingMerry"
add name="pterodactyl.home.arpa" address=192.168.200.4 type=A comment="LAN: Pterodactyl - Mac"
add name="yr.home.arpa" address=192.168.200.3 type=A match-subdomain=yes comment="homelab traefik (youngrobot)"

/ip cloud set ddns-enabled=yes

# ==============================================================================
# MANGLE (MSS Clamping PPPoE)
# ==============================================================================
/ip firewall mangle
add chain=forward protocol=tcp tcp-flags=syn out-interface=pppoe-vivo action=change-mss new-mss=clamp-to-pmtu comment="MSS clamp: Vivo PPPoE out"
add chain=forward protocol=tcp tcp-flags=syn in-interface=pppoe-vivo action=change-mss new-mss=clamp-to-pmtu comment="MSS clamp: Vivo PPPoE in"

# ==============================================================================
# NAT
# ==============================================================================
/ip firewall nat
add chain=srcnat out-interface-list=WAN action=masquerade comment="NAT: Masquerade"

# Port forward: Project Zomboid e TeamSpeak 6 no MacBook
add chain=dstnat in-interface-list=WAN protocol=udp dst-port=16261,16262 action=dst-nat to-addresses=$lGameServer comment="PZ: UDP MacBook"
add chain=dstnat in-interface-list=WAN protocol=udp dst-port=9987,30033 action=dst-nat to-addresses=$lGameServer to-ports=9987 comment="TS6: UDP MacBook"

# ==============================================================================
# FIREWALL
# ==============================================================================
/ip firewall filter

# --- INPUT (trafego destinado ao router) ---
add chain=input connection-state=invalid action=drop comment="Drop: Invalid Input"
add chain=input connection-state=established,related action=accept comment="Accept: Established Input"
add chain=input protocol=tcp dst-port=8291 src-address-list=Management action=accept comment="Accept: WinBox (LAN)"
add chain=input protocol=tcp dst-port=80 src-address-list=Management action=accept comment="Accept: HTTP (LAN)"
add chain=input protocol=tcp dst-port=8728 src-address-list=Management action=accept comment="Accept: API (LAN)"
add chain=input protocol=icmp limit=10,5:packet action=accept comment="Limit: ICMP"
add chain=input protocol=icmp action=drop comment="Drop: Excess ICMP"
add chain=input in-interface=$lLANInterface action=accept comment="Accept: LAN Input"
add chain=input in-interface-list=WAN action=drop comment="Drop: WAN Input"

# --- FORWARD (trafego passando pelo router) ---
add chain=forward connection-state=invalid action=drop comment="Drop: Invalid Forward"
add chain=forward connection-state=established,related action=fasttrack-connection comment="FastTrack: Established/Related"
add chain=forward connection-state=established,related action=accept comment="Accept: Established Forward"
add chain=forward in-interface=$lLANInterface connection-state=new action=accept comment="Accept: LAN New Forward"
add chain=forward in-interface-list=WAN out-interface=$lLANInterface connection-state=established,related action=accept comment="Accept: WAN Return"
add chain=forward in-interface-list=WAN connection-nat-state=dstnat connection-state=new protocol=udp dst-address=$lGameServer dst-port=16261,16262 action=accept comment="PZ: Permitir UDP para MacBook"
add chain=forward in-interface-list=WAN connection-nat-state=dstnat connection-state=new protocol=udp dst-address=$lGameServer dst-port=9987,30033 action=accept comment="TS6: UDP MacBook"
add chain=forward action=drop comment="Drop: All Other Forward"

# --- RAW (pre-processamento, antes do connection tracking) ---
/ip firewall raw
add chain=prerouting protocol=tcp dst-port=8291 src-address-list=!Management action=drop comment="Drop: WinBox from Internet"
add chain=prerouting protocol=tcp dst-port=22 src-address-list=!Management action=drop comment="Drop: SSH from Internet"

# Protecao contra SYN flood
add chain=prerouting in-interface-list=WAN protocol=tcp tcp-flags=syn limit=200,5:packet action=accept comment="SYN: Rate Limit"
add chain=prerouting in-interface-list=WAN protocol=tcp tcp-flags=syn action=drop comment="SYN: Drop Excess"

# Bloqueia IPs falsos/reservados vindos da WAN
add chain=prerouting in-interface-list=WAN src-address=0.0.0.0/8 action=drop comment="Drop: Bogon 0.0.0.0/8"
add chain=prerouting in-interface-list=WAN src-address=10.0.0.0/8 action=drop comment="Drop: Bogon RFC1918 10/8"
add chain=prerouting in-interface-list=WAN src-address=172.16.0.0/12 action=drop comment="Drop: Bogon RFC1918 172.16/12"
add chain=prerouting in-interface-list=WAN src-address=192.168.0.0/16 action=drop disabled=yes comment="Drop: Bogon RFC1918 192.168/16"
add chain=prerouting in-interface-list=WAN src-address=127.0.0.0/8 action=drop comment="Drop: Bogon Loopback"
add chain=prerouting in-interface-list=WAN src-address=224.0.0.0/4 action=drop comment="Drop: Bogon Multicast"

# ==============================================================================
# IPv6 (Vivo prefix delegation + ULA na LAN)
# ==============================================================================
/ipv6 settings set accept-redirects=no accept-router-advertisements=yes

/ipv6 dhcp-client
add interface=pppoe-vivo request=address,prefix pool-name=vivo-pd6 pool-prefix-length=64 add-default-route=yes use-peer-dns=no comment="DHCPv6: Vivo PD"

/ipv6 address
add address=::1 from-pool=vivo-pd6 interface=pppoe-vivo advertise=no disabled=yes comment="IPv6: Vivo PD-derived WAN"
add address=fd64:1e57:9364:1::1 interface=$lLANInterface comment="IPv6: LAN ULA"
add address=::1 from-pool=vivo-pd6 interface=$lLANInterface comment="IPv6: LAN Vivo PD"

/ipv6 nd
set [find default=yes] disabled=yes
add interface=$lLANInterface

/ipv6 firewall address-list
add address=fd64:1e57:9364:1::/64 list=LocalTraffic6 comment="LAN ULA"

/ipv6 firewall filter

# --- INPUT ---
add chain=input connection-state=invalid action=drop comment="Drop: Invalid Input"
add chain=input connection-state=established,related,untracked action=accept comment="Accept: Established Input"
add chain=input protocol=icmpv6 icmp-options=128:0 limit=50,5:packet action=accept comment="Limit: ICMPv6 echo-request"
# NOTA: na config atual esta regra tem action=accept apesar do nome "Drop".
add chain=input protocol=icmpv6 icmp-options=128:0 action=accept comment="Drop: Excess ICMPv6 echo"
add chain=input protocol=icmpv6 action=accept comment="Accept: ICMPv6 (NDP/MLD/PTB/errors)"
add chain=input src-address=fe80::/10 action=accept comment="Accept: Link-local Source"
add chain=input in-interface=$lLANInterface action=accept comment="Accept: LAN Input"
add chain=input protocol=udp dst-port=546 action=accept comment="Accept: DHCPv6 client"
add chain=input action=drop comment="Drop: WAN Input (default)"

# --- FORWARD ---
add chain=forward connection-state=established,related action=fasttrack-connection comment="FastTrack: Established/Related"
add chain=forward connection-state=invalid action=drop comment="Drop: Invalid Forward"
add chain=forward connection-state=established,related,untracked action=accept comment="Accept: Established Forward"
add chain=forward src-address-list=LocalTraffic6 action=accept disabled=yes comment="Accept: LAN New Forward"
add chain=forward protocol=icmpv6 hop-limit=equal:1 action=accept comment="Accept: ICMPv6 link-local hops"
add chain=forward in-interface=$lLANInterface connection-state=new,untracked action=accept comment="Accept: LAN New Forward"
add chain=forward action=drop comment="Drop: All Other Forward"

/ipv6 firewall mangle
add chain=forward protocol=tcp tcp-flags=syn out-interface=pppoe-vivo action=change-mss new-mss=clamp-to-pmtu comment="MSS clamp v6: Vivo PPPoE out"
add chain=forward protocol=tcp tcp-flags=syn in-interface=pppoe-vivo action=change-mss new-mss=clamp-to-pmtu comment="MSS clamp v6: Vivo PPPoE in"

/ipv6 firewall nat
add chain=srcnat out-interface=pppoe-vivo action=masquerade disabled=yes comment="NAT66: Vivo masquerade"

/ipv6 firewall raw
add chain=prerouting in-interface-list=WAN protocol=tcp tcp-flags=syn limit=200,5:packet action=accept comment="IPv6 SYN: Rate Limit"
add chain=prerouting in-interface-list=WAN protocol=tcp tcp-flags=syn action=drop comment="IPv6 SYN: Drop Excess"
add chain=prerouting in-interface-list=WAN src-address=::/128 action=drop comment="IPv6 bogon: unspecified src from WAN"
add chain=prerouting in-interface-list=WAN src-address=fc00::/7 action=drop comment="IPv6 bogon: ULA from WAN"
add chain=prerouting in-interface-list=WAN src-address=::1/128 action=drop comment="IPv6 bogon: loopback from WAN"
add chain=prerouting in-interface-list=WAN src-address=ff00::/8 action=drop comment="IPv6 bogon: multicast as src from WAN"
add chain=prerouting in-interface-list=WAN src-address=2001:db8::/32 action=drop comment="IPv6 bogon: documentation range from WAN"
add chain=prerouting in-interface-list=WAN src-address=::ffff:0.0.0.0/96 action=drop comment="IPv6 bogon: IPv4-mapped from WAN"
add chain=prerouting protocol=tcp dst-port=853 src-address-list=LocalTraffic6 action=drop comment="IPv6: Block DoT (force Pi-Hole)"

# ==============================================================================
# SERVICOS
# ==============================================================================
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www address=$lLANSubnet disabled=no
set www-ssl address=$lLANSubnet disabled=no
set ssh address=$lLANSubnet disabled=no
set api disabled=yes
set api-ssl disabled=yes
set winbox address=$lLANSubnet disabled=no

/tool mac-server set allowed-interface-list=LAN
/tool mac-server mac-winbox set allowed-interface-list=LAN
/tool bandwidth-server set enabled=no
/ip neighbor discovery-settings set discover-interface-list=LAN

# ==============================================================================
# SISTEMA
# ==============================================================================
/system clock set time-zone-autodetect=no time-zone-name=$lTimeZone
/system identity set name=$lIdentity
/ip settings set rp-filter=loose

/ip firewall connection tracking
set tcp-established-timeout=1h generic-timeout=5m

/system ntp client set enabled=yes
/system ntp client servers
:do { remove [find] } on-error={}
add address=200.160.0.8

# ==============================================================================
# MONITOR DE MEMORIA
# ==============================================================================
/system scheduler
add name=check-memory interval=1h start-time=startup on-event={
    :local memFree [/system resource get free-memory]
    :local memTotal [/system resource get total-memory]
    :local memPercent (($memTotal - $memFree) * 100 / $memTotal)
    :if ($memPercent > 90) do={
        :log warning ("High Memory Usage: " . $memPercent . "%")
    }
}

# ==============================================================================
# FALLBACK DE DNS (Pi-Hole)
# ==============================================================================
# Testa o Pi-Hole a cada 30s. Se cair, router passa a usar DNS externo.
/tool netwatch
add name=watch-pihole-dns type=dns host=google.com dns-server=$lPiHoleAddress interval=30s timeout=3s disabled=no down-script=("/ip dns set servers=" . $lFallbackDNS . "; /ip dns cache flush; :log warning \"Pi-hole DOWN: fallback DNS externo ativado\"") up-script=("/ip dns set servers=" . $lPiHoleAddress . "; /ip dns cache flush; :log warning \"Pi-hole UP: DNS voltou para Pi-hole\"")

# ==============================================================================
# PRONTO
# ==============================================================================
:put ""
:put "========================================================================"
:put " Configuracao aplicada"
:put "========================================================================"
:put ""
:put "Verificacao:"
:put "  /interface pppoe-client print"
:put "  /ip route print where dst-address=0.0.0.0/0"
:put "  /ipv6 dhcp-client print"
:put "  /tool netwatch print"
:put ""
:put "!! TROQUE A SENHA ADMIN E REIMPORTE AS CHAVES SSH !!"
:put "   /user set admin password=SUA-SENHA"
:put ""
