# Cisco Packet Tracer — VLAN, Inter-VLAN Routing and ACL Lab

These are sample configurations. Match interface numbers to your Packet Tracer topology and configure both switches consistently. Save the `.pkt` file yourself after testing; no Packet Tracer binary is included.

## Example addressing plan
| VLAN | Purpose | Subnet | Default gateway |
|---|---|---|---|
| 10 | Admin | 192.168.10.0/24 | 192.168.10.1 |
| 20 | Support | 192.168.20.0/24 | 192.168.20.1 |
| 30 | Guest | 192.168.30.0/24 | 192.168.30.1 |

## Switch configuration (adapt ports)
```text
enable
configure terminal
vlan 10
 name ADMIN
vlan 20
 name SUPPORT
vlan 30
 name GUEST
!
interface range fastEthernet0/1-4
 switchport mode access
 switchport access vlan 10
 spanning-tree portfast
!
interface range fastEthernet0/5-8
 switchport mode access
 switchport access vlan 20
 spanning-tree portfast
!
interface range fastEthernet0/9-12
 switchport mode access
 switchport access vlan 30
 spanning-tree portfast
!
interface gigabitEthernet0/1
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30
end
show vlan brief
show interfaces trunk
```

Configure the trunk on both ends of the inter-switch link, and include all VLANs required across that link. Port ranges above are examples only.

## Router-on-a-stick example
Assume router `G0/0` connects to a trunk port on the switch. If your router uses another interface name, adapt it.
```text
enable
configure terminal
interface gigabitEthernet0/0
 no shutdown
!
interface gigabitEthernet0/0.10
 encapsulation dot1Q 10
 ip address 192.168.10.1 255.255.255.0
!
interface gigabitEthernet0/0.20
 encapsulation dot1Q 20
 ip address 192.168.20.1 255.255.255.0
!
interface gigabitEthernet0/0.30
 encapsulation dot1Q 30
 ip address 192.168.30.1 255.255.255.0
end
show ip interface brief
show ip route
```

## Guest ACL example
This blocks Guest access to the Admin and Support subnets while permitting other IPv4 traffic. Apply inbound on the Guest subinterface. Confirm whether this matches your intended policy before using it.
```text
configure terminal
ip access-list extended GUEST-IN
 deny ip 192.168.30.0 0.0.0.255 192.168.10.0 0.0.0.255
 deny ip 192.168.30.0 0.0.0.255 192.168.20.0 0.0.0.255
 permit ip 192.168.30.0 0.0.0.255 any
!
interface gigabitEthernet0/0.30
 ip access-group GUEST-IN in
end
show access-lists
```

## Verification checklist
1. Assign each PC an address in its VLAN subnet, mask `255.255.255.0`, and the matching gateway.
2. `show vlan brief`, `show interfaces trunk`, `show ip interface brief`, `show ip route`, `show access-lists`.
3. Ping each PC's gateway.
4. Test inter-VLAN reachability before ACLs, then after ACLs.
5. Guest-to-Admin/Support should fail; permitted traffic should follow your intended policy.
6. Record actual outputs and screenshots. Do not claim tests passed until you run them.
