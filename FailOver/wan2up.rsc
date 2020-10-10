:global "wan2testhostIP" 8.8.4.4
:global "wan2PingCycle" 2
:global "voipServer1" 9.9.9.8
:global "voipServer2" 9.9.9.9
:global "pingDelay" 2
:global "sleepDelay" 300
:global "wanEmailNotificationAddress" "nick@coultas.com"
## Do not modify these variables
:global "routerName" [/system identity get name]
:global "wan2counter" 0
:global "pingcounter" 1
:global "wan2UpCheck" true
:global "flappingEmailCounter" 0
## Do not modify these variables
:log warning "Variables Initialized";
:while ($wan2UpCheck = true) do={
    :if ($wan2counter = $wan2PingCycle) do={
        :if ([/ip route get [find comment="WAN2"] distance] = 42) do={
            /ip route set [find comment="WAN2"] distance=1
            /ip firewall mangle set [find comment="MarkConnection1"] disabled=no
            /ip firewall mangle set [find comment="MarkConnection2"] disabled=no
            }
        :log warning "WAN2 seems stable. Reverting route distance";
        :if ([/tool netwatch get value-name=status number=[find comment="Ping for WAN1"]]="down") do={
            /ip firewall mangle set [find comment="MarkConnection1"] disabled=yes
            /ip firewall mangle set [find comment="MarkConnection2"] disabled=yes
            :log warning "WAN2 seems stable, but WAN1 is down. Loadbalancing disabled";
            }
        :if ([ip route get [find comment="WAN1"] disable] = true) do={    
        /ip route set [find comment="WAN1"] disabled=no
            }
        /ip firewall connection remove [find dst-address="$voipServer1"]
        /ip firewall connection remove [find dst-address="$voipServer2"]
        :set "wan2UpCheck" false
        :log warning "wan2 up Script ending, wan2 service restored";
#        /tool e-mail send to=$wanEmailNotificationAddress body="Connection with wan2 stable. Switched back to wan2" subject="$routerName - Regained connection with wan2"
        :delay $pingDelay
        }
    :if ($wan2UpCheck != false) do={
        :delay $pingDelay     
        :log warning "Begin Ping $pingcounter";
        :if ([/ping $wan2testhostIP count=$wan2PingCycle] != $wan2PingCycle) do={
            :log error ("Can't ping $wan2testhostIP");
            :log error ("wan2 is FLAPPING");
            :if ($flappingEmailCounter = 0) do={
#                /tool e-mail send to=$wanEmailNotificationAddress body="Connection with wan2 FLAPPING. Staying on WAN2" subject="$routerName - wan2 is FLAPPING"
                :set $flappingEmailCounter ($flappingEmailCounter + 1)
                }
            :set $wan2counter 0
            :log warning "Sleeping script $sleepDelay seconds"
            :delay $sleepDelay
            }            
        :log warning "End Ping $pingcounter";
        :set $pingcounter ($pingcounter + 1)
        :set $wan2counter ($wan2counter + 1)    
        }
}