:global "wan1testhostIP" 8.8.8.8
:global "wan1PingCycle" 2
:global "voipServer1" 9.9.9.8
:global "voipServer2" 9.9.9.9
:global "pingDelay" 2
:global "sleepDelay" 300
:global "wanEmailNotificationAddress" "nick@coultas.com"
## Do not modify these variables
:global "routerName" [/system identity get name]
:global "wan1counter" 0
:global "pingcounter" 1
:global "wan1UpCheck" true
:global "flappingEmailCounter" 0
## Do not modify these variables
:log warning "Variables Initialized";
:while ($wan1UpCheck = true) do={
    :if ($wan1counter = $wan1PingCycle) do={
        :if ([/ip route get [find comment="WAN1"] distance] = 41) do={
            /ip route set [find comment="WAN1"] distance=1
            /ip firewall mangle set [find comment="MarkConnection1"] disabled=no
            /ip firewall mangle set [find comment="MarkConnection2"] disabled=no
            }
        :log warning "WAN1 seems stable. Reverting route distance";
        :if ([/tool netwatch get value-name=status number=[find comment="Ping for WAN2"]]="down") do={
            /ip firewall mangle set [find comment="MarkConnection1"] disabled=yes
            /ip firewall mangle set [find comment="MarkConnection2"] disabled=yes
            :log warning "WAN1 seems stable, but WAN2 is down. Loadbalancing disabled";
            }
        :if ([ip route get [find comment="WAN2"] disable] = true) do={    
        /ip route set [find comment="WAN2"] disabled=no
            }
        /ip firewall connection remove [find dst-address="$voipServer1"]
        /ip firewall connection remove [find dst-address="$voipServer2"]
        :set "wan1UpCheck" false
        :log warning "wan1 up Script ending, WAN1 service restored";
#        /tool e-mail send to=$wanEmailNotificationAddress body="Connection with WAN1 stable. Switched back to WAN1" subject="$routerName - Regained connection with WAN1"
        :delay $pingDelay
        }
    :if ($wan1UpCheck != false) do={
        :delay $pingDelay     
        :log warning "Begin Ping $pingcounter";
        :if ([/ping $wan1testhostIP count=$wan1PingCycle] != $wan1PingCycle) do={
            :log error ("Can't ping $wan1testhostIP");
            :log error ("WAN1 is FLAPPING");
            :if ($flappingEmailCounter = 0) do={
#                /tool e-mail send to=$wanEmailNotificationAddress body="Connection with WAN1 FLAPPING. Staying on WAN2" subject="$routerName - WAN1 is FLAPPING"
                :set $flappingEmailCounter ($flappingEmailCounter + 1)
                }
            :set $wan1counter 0
            :log warning "Sleeping script $sleepDelay seconds"
            :delay $sleepDelay
            }            
        :log warning "End Ping $pingcounter";
        :set $pingcounter ($pingcounter + 1)
        :set $wan1counter ($wan1counter + 1)    
        }
}
