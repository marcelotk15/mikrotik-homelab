# MikroTik Vivo Router - backup

Config do hEX (RB750Gr3, RouterOS 7.23.1) em forma de script `.rsc`, no estilo do
[sugiruu/mikrotik-dual-wan-loadbalance-failover](https://github.com/sugiruu/mikrotik-dual-wan-loadbalance-failover).

## O que tem

- **WAN única Vivo** via PPPoE sobre a VLAN 10 (`vlan10-vivo` na `ether1`), MTU/MRU 1492 e MSS clamp v4/v6
- **LAN** `192.168.100.0/24` na `bridge-lan` (ether2-5), DHCP com leases estáticos e domínio `internal`
- **Bridge em RSTP** com prioridade na `ether2` (switch): o caminho cabeado sempre vence, evitando loop quando o mesh Xiaomi fecha caminho pelo ar. Portas: `ether2` switch, `ether3` Wi-Fi 1 (AX3000T), `ether5` desktop, `ether4` livre
- **Homelab** `192.168.200.0/24` na mesma bridge
- **DNS**: router encaminha pro Pi-Hole (`192.168.100.2`), netwatch troca pra 1.1.1.1/8.8.8.8 se ele cair
- **IPv6**: prefix delegation da Vivo + ULA `fd64:1e57:9364:1::/64`, firewall v6 completo
- **Port forward**: Project Zomboid e TeamSpeak 6 pro MacBook (`192.168.200.4`)
- **Firewall + hardening**: herdado do repositório base (bogons, SYN rate limit, serviços só na LAN)

## Restaurar

1. Edite `lPPPoEPassword` no topo do `mikrotik-vivo-router.rsc`
2. Crie o `local/private.rsc` a partir do exemplo (veja [Dados privados](#dados-privados-local))
3. Suba os dois no router (Winbox > Files) e rode `/import mikrotik-vivo-router.rsc`
4. Troque a senha do admin e reimporte as chaves SSH

> **CUIDADO**: o script apaga a config coberta por ele. Conecte pela LAN, nunca remoto.

## Dados privados (`local/`)

Tudo em `local/` é gitignored, exceto o exemplo. Lá ficam MACs, nomes de pessoas e backups binários.

| Arquivo | No git? | O que é |
|---------|---------|---------|
| `local/private.example.rsc` | sim | Modelo com dados falsos |
| `local/private.rsc` | não | Leases estáticos reais (MAC → IP) e comentário da `ether5` |
| `local/auto-before-reset.backup` | não | Backup binário antigo (ver abaixo) |

Pra criar o seu:

```sh
cp local/private.example.rsc local/private.rsc
```

Troque MACs, IPs e comentários. Mantenha `server=lan-dhcp` e o prefixo `Static:` no comentário:
o arquivo apaga e recria os leases que têm esse prefixo. O script principal acha o
`private.rsc` em qualquer pasta do router e o importa; se ele não existir, só avisa e segue
sem leases estáticos.

## O que NÃO está aqui

- Senhas (PPPoE, admin) e usuários/chaves SSH
- MACs e nomes dos dispositivos (ficam em `local/private.rsc`)
- Leases dinâmicos, rotas dinâmicas, certificados

`local/auto-before-reset.backup` (gitignored) é o backup binário que o RouterOS gerou
antes de um reset antigo. Está **sem criptografia** e contém senhas: não suba em lugar
nenhum. Só restaura no mesmo modelo (`/system backup load`); serve como histórico.

## Atualizar o backup

```sh
ssh -i ~/.ssh/id_ed25519_mikrotik claude@192.168.100.1 "/export terse" > export.rsc
```

Compare com o script e passe as mudanças pra ele (o `export.rsc` é gitignored).
