# Change backup name
/system backup save dont-encrypt=yes name=BeforeNewQOSlebg
/export compact terse file=BeforeNewQOSTXTlebg
:delay 2

#
## Initilize variables - siteID, siteIPs, wanSpeeds
#
# Used for information only - :global "siteIDArray" {"ADMN"="10";"APKA"="25";"FRCT"="30";"PIHI"="35";"WTGD"="40";"WGCC"="45";"GROV"="50";"TAVR"="55";"LEBG"="60";"LKEL"="65";"BITH"="70";"MDWD"="75";"CLER"="80";"FCRN"="85"}; 
# Create these address lists FIRST - 02-Voice-Video-Alarm, 03-HighPriorityServices, 04-MedPriorityServices, 05-LowPriorityServices, 06-NoPriorityServices, 08-Tarpit

:global "siteID" {"LEBG"="60"}
:global "siteIPs" {"172.16.253.11";"192.168.254.7"}
:global "wanSpeeds" {"100";"100"}
:global "tarPitSpeedPercentage" 2
:global "qosPriorities" {"P01-Network";"P02-Voice-Video";"P03-HighPriority";"P04-MedServices";"P05-LowServices";"P06-NoPriority";"P07-EE";"P08-Tarpit"}
:global "protocolArray" {"icmp";"dns tcp";"dns udp";"ospf"}
:global "tcpPortArrayP1" {"53";"8291";"22"}
:global "udpPortArrayP1" {"53";"8291"}
:global "tcpPortArrayP3" {"389"}
:global "tcpPortArrayP4" {"25";"445";"465";"587";"691";"3389";"1494"}
:global "wanNumberArray" {"WAN1";"WAN2"}
:global "sfpInterface" {"sfp-sfpplus8"; "sfp-sfpplus6"}
:global "WANInterface" "sfp-sfpplus8"
:global "wanCounter" {"wan1"; "wan2"}
:global "protCounter" 0
:global "priorityCounter" 0
:global "packetMarkNum" ($priorityCounter + 1)
:global "priorityService" [:pick $qosPriorities $priorityCounter]
:global "protocolArrayItem" [:pick $protocolArray $protCounter]
:global "wanNum" "wan123"
:global "siteName" "site123"
:global "toPacketMarkInsert" ("$packetMarkNum" . "-" . "$siteName" . "-" . "$wanNum")
:global "fromPacketMarkInsert" ("$packetMarkNum" . "-" . "$siteName" . "-" . "from" . "-" . "$wanNum")
:global "toConMarkInsert" ("$packetMarkNum" . "-" . "$siteName" . "-" . "$wanNum" . "-" . "conmark")
:global "fromConMarkInsert" ("$packetMarkNum" . "-" . "$siteName" . "-" . "from" . "-" . "$wanNum" . "-" . "conmark")


##Create PCQ Queue
:do {/queue type add kind=sfq name=SFQ-CHC;} on-error={:put "Queue Type Exists, skipping"}


:delay 3
#
## Add old site IPS to site-ALL addresses list
#


:foreach site,siteIDNum in=$siteID do={
    :global "listName" ("$site" . "-ALL")
    /ip firewall address-list
    :if ([:len [find list="$listName"]] > 0) do={remove numbers=[find list="$listName"]}
    :global "primarySiteIP" ("10." . "$siteIDNum" . ".128.0/16")
    :global "CHCMGMT" ("10." . "$siteIDNum" . ".104.0/24")
    :global "OSPFID" ("10.1.1." . "$siteIDNum")
    :global "wanIP1" ("10.1.251." . "$siteIDNum")
    :global "wanIP2" ("10.1.252." . "$siteIDNum")
    :do {add address=$primarySiteIP comment="$site IPs" list=$listName;} on-error={:put "$primarySiteIP already exists in this $listName list"}
#   Excluded since the /16 covers CHCMGMT range
#   :do {add address=$CHCMGMT comment="$site CHCMGMT" list=$listName;} on-error={:put "$CHCMGMT already exists in this $listName list"}
#
    :do {add address=$OSPFID comment="OSPF ID" list=$listName;} on-error={:put "$OSPFID already exists in this $listName list"}
    :do {add address=$wanIP1 comment="WAN1 IP" list=$listName;} on-error={:put "$wanIP1 already exists in this $listName list"}
    :do {add address=$wanIP2 comment="WAN2 IP" list=$listName;} on-error={:put "$wanIP2 already exists in this $listName list"}
    :foreach IP in=$siteIPs do={
        /ip firewall address-list
        :do {add address=$IP list=$listName;} on-error={:put "$IP already exists in this $listName list"}
        
    }
}
:delay 4
#
## create mangles for each of the needed priorities and protocols. 
#

#start first loop per site. 
:foreach site,siteIDNum in=$siteID do={
    :global "siteFullList" $listName
    :global "siteName" $site
    :global "sfpCounter" 0

    /ip firewall mangle;
    #start second loop per wan interface
    :foreach item in=$wanCounter do={
        :global "wanNum" $item
        :global "wanMaxSpeedNum" [:pick $wanSpeeds $sfpCounter]
        :global "wanMaxSpeed" ("$wanMaxSpeedNum" . "000000")
        :global "WANInterface" [:pick $sfpInterface $sfpCounter]
        :global "protCounter" 0
        :global "priorityCounter" 0
        :global "priorityService" [:pick $qosPriorities $priorityCounter]
        :global "protocolArrayItem" [:pick $protocolArray $protCounter]
        :global "packetMarkNum" ($priorityCounter + 1)
        :global "toPacketMarkInsert" ("$packetMarkNum" . "-" . "$siteName" . "-" . "$wanNum")
        :global "fromPacketMarkInsert" ("$packetMarkNum" . "-" . "$siteName" . "-" . "from" . "-" . "$wanNum")
        :global "toConMarkInsert" ("$packetMarkNum" . "-" . "$siteName" . "-" . "$wanNum" . "-" . "conmark")
        :global "fromConMarkInsert" ("$packetMarkNum" . "-" . "$siteName" . "-" . "from" . "-" . "$wanNum" . "-" . "conmark")
        :set $sfpCounter ($sfpCounter + 1)
        :global "qosparentNameTo" ("$siteName" ."-" . "$wanNum" . "-" . "to")
        :global "qosparentNameFrom" ("$siteName" ."-" . "$wanNum" . "-" . "from")

        :global "P1reseveredDivisor" ($wanMaxSpeed / 50)
        :global "P1maxDivisor" ($wanMaxSpeed / 20)
        :global "P2reseveredDivisor" ($wanMaxSpeed / 10)
        :global "P2maxDivisor" ($wanMaxSpeed / 4)
        :global "P2BurstDivisor" ($wanMaxSpeed / 2)
        :global "P2BurstThresholdDivisor" ($wanMaxSpeed / 5)
        :global "P3reseveredDivisor" ($wanMaxSpeed / 10)
        :global "P3maxDivisor" (($wanMaxSpeed * 10) / 12)
        :global "P3BurstDivisor" (($wanMaxSpeed * 10) / 11)
        :global "P3BurstThresholdDivisor" (($wanMaxSpeed * 10) / 13)
        :global "P4reseveredDivisor" ($wanMaxSpeed / 100)
        :global "P4maxDivisor" (($wanMaxSpeed * 10) / 12)
        :global "P4BurstDivisor" (($wanMaxSpeed * 10) / 11)
        :global "P4BurstThresholdDivisor" (($wanMaxSpeed * 10) / 13)
        :global "P5reseveredDivisor" ($wanMaxSpeed / 100)
        :global "P5maxDivisor" (($wanMaxSpeed * 10) / 12)
        :global "P5BurstDivisor" (($wanMaxSpeed * 10) / 11)
        :global "P5BurstThresholdDivisor" (($wanMaxSpeed * 10) / 13)
        :global "P6reseveredDivisor" ($wanMaxSpeed / 100)
        :global "P6maxDivisor" ($wanMaxSpeed / 2)
        :global "P6BurstDivisor" (($wanMaxSpeed * 10) / 13)
        :global "P6BurstThresholdDivisor" (($wanMaxSpeed * 10) / 22)
        :global "P7reseveredDivisor" ($wanMaxSpeed / 100)
        :global "P7maxDivisor" ($wanMaxSpeed / 2)
        :global "P7BurstDivisor" (($wanMaxSpeed * 10) / 13)
        :global "P7BurstThresholdDivisor" (($wanMaxSpeed * 10) / 22)
        :global "P8reseveredDivisor" ($wanMaxSpeed / ($tarPitSpeedPercentage * 100))
        :global "P8maxDivisor" ($wanMaxSpeed / 20)

        

        #Function to change protocol
        :global "changeProtocol" do={
            :set $protCounter ($protCounter + 1)
            :set $protocolArrayItem [:pick $protocolArray $protCounter]
        }
        
        #Create Function to add a increase priority
        :global "changePriority" do={
            :set $priorityCounter ($priorityCounter + 1)
            :set $packetMarkNum ($packetMarkNum + 1)
            :set $priorityService [:pick $qosPriorities $priorityCounter]
            :set $toPacketMarkInsert ("$packetMarkNum" . "-" . "$siteName" . "-" . "$wanNum")
            :set $fromPacketMarkInsert ("$packetMarkNum" . "-" . "$siteName" . "-" . "from" . "-" . "$wanNum")
            :set $toConMarkInsert  ("$packetMarkNum" . "-" . "$siteName" . "-" . "$wanNum" . "-" . "conmark")
            :set $fromConMarkInsert ("$packetMarkNum" . "-" . "$siteName" . "-" . "from" . "-" . "$wanNum" . "-" . "conmark")
        }

        #Create Function to deploy packet marks
        :global "deployPacketMarking" do={
            :do {add action=mark-packet chain=postrouting comment="$siteName - ALL $priorityService - To-$wanNum" connection-mark=$toConMarkInsert new-packet-mark=$toPacketMarkInsert out-interface=$WANInterface passthrough=no;} on-error={:put "mangle already $siteID toPacketMarkInsert"}
            :do {add action=mark-packet chain=prerouting comment="$siteName - ALL $priorityService - From-$wanNum" connection-mark=$fromConMarkInsert in-interface=$WANInterface new-packet-mark=$fromPacketMarkInsert passthrough=no;} on-error={:put "mangle already exists $siteID fromPacketMarkInsert"}
        }


        #Create Parent QOS Tree
        /queue tree add max-limit=$wanMaxSpeed name=$qosparentNameTo parent=global priority=4 queue=default
        /queue tree add max-limit=$wanMaxSpeed name=$qosparentNameFrom parent=global priority=4 queue=default


        #P1 Begin
        #mark connection - icmp
        /ip firewall mangle
        :do {add action=mark-connection chain=postrouting comment="$siteName - $priorityService - $protocolArrayItem - To-$wanNum" connection-mark=no-mark dst-address-list=$siteFullList new-connection-mark=$toConMarkInsert out-interface=$WANInterface passthrough=yes protocol=$protocolArrayItem;} on-error={:put "mangle already $siteID $toConMarkInsert"}
        :do {add action=mark-connection chain=prerouting comment="$siteName - $priorityService - $protocolArrayItem - From-$wanNum" connection-mark=no-mark in-interface=$WANInterface new-connection-mark=$fromConMarkInsert passthrough=yes protocol=$protocolArrayItem src-address-list=$siteFullList;} on-error={:put "mangle already exists $siteID $fromConMarkInsert"}
        $changeProtocol

        #dns and winbox tcp ports
        :do {add action=mark-connection chain=postrouting comment="$siteName - $priorityService - $protocolArrayItem - To-$wanNum" connection-mark=no-mark dst-address-list=$siteFullList dst-port=53,8291 new-connection-mark=$toConMarkInsert out-interface=$WANInterface passthrough=yes protocol=tcp;} on-error={:put "mangle already exists $siteID $toConMarkInsert"}
        :do {add action=mark-connection chain=prerouting comment="$siteName - $priorityService - $protocolArrayItem - From-$wanNum" connection-mark=no-mark dst-port=53,8291 in-interface=$WANInterface new-connection-mark=$fromConMarkInsert passthrough=yes protocol=tcp src-address-list=$siteFullList;} on-error={:put "mangle already exists $siteID $fromConMarkInsert"}
        $changeProtocol
        
        #dns udp ports
        :do {add action=mark-connection chain=postrouting comment="$siteName - $priorityService - $protocolArrayItem - To-$wanNum" connection-mark=no-mark dst-address-list=$siteFullList dst-port=53 new-connection-mark=$toConMarkInsert out-interface=$WANInterface passthrough=yes protocol=udp;} on-error={:put "mangle already exists $siteID $toConMarkInsert"}
        :do {add action=mark-connection chain=prerouting comment="$siteName - $priorityService - $protocolArrayItem - From-$wanNum" connection-mark=no-mark dst-port=53 in-interface=$WANInterface new-connection-mark=$fromConMarkInsert passthrough=yes protocol=udp src-address-list=$siteFullList;} on-error={:put "mangle already exists $siteID $fromConMarkInsert"}
        $changeProtocol
        
        #ospf
        :do {add action=mark-connection chain=postrouting comment="$siteName - $priorityService - $protocolArrayItem - To-$wanNum" connection-mark=no-mark dst-address-list=$siteFullList new-connection-mark=$toConMarkInsert out-interface=$WANInterface passthrough=yes protocol=ospf;} on-error={:put "mangle already exists $siteID $toConMarkInsert"}
        :do {add action=mark-connection chain=prerouting comment="$siteName - $priorityService - $protocolArrayItem - From-$wanNum" connection-mark=no-mark in-interface=$WANInterface new-connection-mark=$fromConMarkInsert passthrough=yes protocol=ospf src-address-list=$siteFullList;} on-error={:put "mangle already exists $siteID $fromConMarkInsert"}

        #mark all the packets that are on the P1 Connection Mark
        $deployPacketMarking

        #create queue tree for P1
        /queue tree add limit-at=$P1reseveredDivisor max-limit=$P1maxDivisor name=$toPacketMarkInsert packet-mark=$toPacketMarkInsert parent=$qosparentNameTo priority=1 queue=SFQ-CHC
        /queue tree add limit-at=$P1reseveredDivisor max-limit=$P1maxDivisor name=$fromPacketMarkInsert packet-mark=$fromPacketMarkInsert parent=$qosparentNameFrom priority=1 queue=SFQ-CHC
        #Move on to another Priority
        $changePriority
        #P2 Begin

        :do {add action=mark-connection chain=postrouting comment="$siteName - $priorityService To-$wanNum" connection-mark=no-mark dst-address-list=$siteFullList new-connection-mark=$toConMarkInsert out-interface=$WANInterface passthrough=yes src-address-list=02-Voice-Video-Alarm;} on-error={:put "mangle already exists $siteID $toConMarkInsert"}
        :do {add action=mark-connection chain=prerouting comment="$siteName - $priorityService From-$wanNum" connection-mark=no-mark dst-address-list=02-Voice-Video-Alarm in-interface=$WANInterface new-connection-mark=$fromConMarkInsert passthrough=yes src-address-list=$siteFullList;} on-error={:put "mangle already exists $siteID $fromConMarkInsert"}
        
        #mark all the packets that are on the P2 Connection Mark. 
        $deployPacketMarking
        
        #create queue tree for P2
        /queue tree add bucket-size=0.2 burst-limit=$P2BurstDivisor burst-threshold=$P2BurstThresholdDivisor burst-time=40s limit-at=$P2reseveredDivisor max-limit=$P2maxDivisor name=$toPacketMarkInsert packet-mark=$toPacketMarkInsert parent=$qosparentNameTo priority=2 queue=SFQ-CHC
        /queue tree add bucket-size=0.2 burst-limit=$P2BurstDivisor burst-threshold=$P2BurstThresholdDivisor burst-time=40s limit-at=$P2reseveredDivisor max-limit=$P2maxDivisor name=$fromPacketMarkInsert packet-mark=$fromPacketMarkInsert parent=$qosparentNameFrom priority=2 queue=SFQ-CHC
        #Move on to another Priority
        $changePriority
        
        #P3 Begin
        :do {add action=mark-connection chain=postrouting comment="$siteName - $priorityService - TCP Ports - To-$wanNum" connection-mark=no-mark dst-address-list=$siteFullList dst-port=3389,1494,389,22 new-connection-mark=$toConMarkInsert out-interface=$WANInterface passthrough=yes protocol=tcp;} on-error={:put "mangle already exists $siteID $toConMarkInsert"}
        :do {add action=mark-connection chain=prerouting comment="$siteName - $priorityService - TCP Ports - From-$wanNum" connection-mark=no-mark dst-port=3389,1494,389,22 in-interface=$WANInterface new-connection-mark=$fromConMarkInsert passthrough=yes protocol=tcp src-address-list=$siteFullList;} on-error={:put "mangle already exists $siteID $fromConMarkInsert"}
        :do {add action=mark-connection chain=postrouting comment="$siteName - $priorityService - To-WAN1" connection-mark=no-mark dst-address-list=$siteFullList new-connection-mark=$toConMarkInsert out-interface=$WANInterface passthrough=yes src-address-list=03-HighPriorityServices;} on-error={:put "mangle already exists $siteID $toConMarkInsert"}
        :do {add action=mark-connection chain=prerouting comment="$siteName - $priorityService - From-WAN1" connection-mark=no-mark dst-address-list=03-HighPriorityServices in-interface=$WANInterface new-connection-mark=$fromConMarkInsert passthrough=yes src-address-list=$siteFullList;} on-error={:put "mangle already exists $siteID $fromConMarkInsert"}
        
        #mark all the packets that are on the P3 Connection Mark. 
        $deployPacketMarking
        
        #create queue tree for P3
        /queue tree add bucket-size=0.2 burst-limit=$P3BurstDivisor burst-threshold=$P3BurstThresholdDivisor burst-time=20s limit-at=$P3reseveredDivisor max-limit=$P3maxDivisor name=$toPacketMarkInsert packet-mark=$toPacketMarkInsert parent=$qosparentNameTo priority=3 queue=SFQ-CHC
        /queue tree add bucket-size=0.2 burst-limit=$P3BurstDivisor burst-threshold=$P3BurstThresholdDivisor burst-time=20s limit-at=$P3reseveredDivisor max-limit=$P3maxDivisor name=$fromPacketMarkInsert packet-mark=$fromPacketMarkInsert parent=$qosparentNameFrom priority=3 queue=SFQ-CHC
        #Move on to another Priority
        $changePriority
        
        #P4 Begin
        :do {add action=mark-connection chain=postrouting comment="$siteName - $priorityService - TCP Ports - To-$wanNum" connection-mark=no-mark dst-address-list=$siteFullList dst-port=25,445,465,587,691 new-connection-mark=$toConMarkInsert out-interface=$WANInterface passthrough=yes protocol=tcp;} on-error={:put "mangle already exists $siteID $toConMarkInsert"}
        :do {add action=mark-connection chain=prerouting comment="$siteName - $priorityService - TCP Ports - From-$wanNum" connection-mark=no-mark dst-port=25,445,465,587,691 in-interface=$WANInterface new-connection-mark=$fromConMarkInsert passthrough=yes protocol=tcp src-address-list=$siteFullList;} on-error={:put "mangle already exists $siteID $fromConMarkInsert"}
        :do {add action=mark-connection chain=postrouting comment="$siteName - $priorityService - To-$wanNum" connection-mark=no-mark dst-address-list=$siteFullList new-connection-mark=$toConMarkInsert out-interface=$WANInterface passthrough=yes src-address-list=04-MedPriorityServices;} on-error={:put "mangle already exists $siteID $toConMarkInsert"}
        :do {add action=mark-connection chain=prerouting comment="$siteName - $priorityService - From-$wanNum" connection-mark=no-mark dst-address-list=04-MedPriorityServices in-interface=$WANInterface new-connection-mark=$fromConMarkInsert passthrough=yes src-address-list=$siteFullList;} on-error={:put "mangle already exists $siteID $fromConMarkInsert"}
        
        #mark all the packets that are on the P4 Connection Mark. 
        $deployPacketMarking

        #create queue tree for P4
        /queue tree add bucket-size=0.2 burst-limit=$P4BurstDivisor burst-threshold=$P4BurstThresholdDivisor burst-time=20s limit-at=$P4reseveredDivisor max-limit=$P4maxDivisor name=$toPacketMarkInsert packet-mark=$toPacketMarkInsert parent=$qosparentNameTo priority=4 queue=SFQ-CHC
        /queue tree add bucket-size=0.2 burst-limit=$P4BurstDivisor burst-threshold=$P4BurstThresholdDivisor burst-time=20s limit-at=$P4reseveredDivisor max-limit=$P4maxDivisor name=$fromPacketMarkInsert packet-mark=$fromPacketMarkInsert parent=$qosparentNameFrom priority=4 queue=SFQ-CHC
        #Move on to another Priority
        $changePriority
        

        #P5 Begin
        :do {add action=mark-connection chain=postrouting comment="$siteName - $priorityService - To-$wanNum" connection-mark=no-mark dst-address-list=$siteFullList new-connection-mark=$toConMarkInsert out-interface=$WANInterface passthrough=yes src-address-list=05-LowPriorityServices;} on-error={:put "mangle already exists $siteID $toConMarkInsert"}
        :do {add action=mark-connection chain=prerouting comment="$siteName - $priorityService - From-$wanNum" connection-mark=no-mark dst-address-list=05-LowPriorityServices in-interface=$WANInterface new-connection-mark=$fromConMarkInsert passthrough=yes src-address-list=$siteFullList;} on-error={:put "mangle already exists $siteID $fromConMarkInsert"}
        
        #mark all the packets that are on the P5 Connection Mark. 
        $deployPacketMarking

        #create queue tree for P5
        /queue tree add bucket-size=0.2 burst-limit=$P5BurstDivisor burst-threshold=$P5BurstThresholdDivisor burst-time=20s limit-at=$P5reseveredDivisor max-limit=$P5maxDivisor name=$toPacketMarkInsert packet-mark=$toPacketMarkInsert parent=$qosparentNameTo priority=5 queue=SFQ-CHC
        /queue tree add bucket-size=0.2 burst-limit=$P5BurstDivisor burst-threshold=$P5BurstThresholdDivisor burst-time=20s limit-at=$P5reseveredDivisor max-limit=$P5maxDivisor name=$fromPacketMarkInsert packet-mark=$fromPacketMarkInsert parent=$qosparentNameFrom priority=5 queue=SFQ-CHC
        #Move on to another Priority
        $changePriority

        #P6 Begin
        :do {add action=mark-connection chain=postrouting comment="$siteName - $priorityService - To-$wanNum" connection-mark=no-mark dst-address-list=$siteFullList new-connection-mark=$toConMarkInsert out-interface=$WANInterface passthrough=yes src-address-list=06-NoPriorityServices;} on-error={:put "mangle already exists $siteID $toConMarkInsert"}
        :do {add action=mark-connection chain=prerouting comment="$siteName - $priorityService - From-$wanNum" connection-mark=no-mark dst-address-list=06-NoPriorityServices in-interface=$WANInterface new-connection-mark=$fromConMarkInsert passthrough=yes src-address-list=$siteFullList;} on-error={:put "mangle already exists $siteID $fromConMarkInsert"}
        
        #mark all the packets that are on the P6 Connection Mark. 
        $deployPacketMarking

        #create queue tree for P6
        /queue tree add bucket-size=0.2 burst-limit=$P6BurstDivisor burst-threshold=$P6BurstThresholdDivisor burst-time=20s limit-at=$P6reseveredDivisor max-limit=$P6maxDivisor name=$toPacketMarkInsert packet-mark=$toPacketMarkInsert parent=$qosparentNameTo priority=6 queue=SFQ-CHC
        /queue tree add bucket-size=0.2 burst-limit=$P6BurstDivisor burst-threshold=$P6BurstThresholdDivisor burst-time=20s limit-at=$P6reseveredDivisor max-limit=$P6maxDivisor name=$fromPacketMarkInsert packet-mark=$fromPacketMarkInsert parent=$qosparentNameFrom priority=6 queue=SFQ-CHC
        #Move on to another Priority
        $changePriority

        #P7 Begin
        :do {add action=mark-connection chain=postrouting comment="$siteName - $priorityService - To-$wanNum" connection-mark=no-mark dst-address-list=$siteFullList new-connection-mark=$toConMarkInsert out-interface=$WANInterface passthrough=yes;} on-error={:put "mangle already exists $siteID $toConMarkInsert"}
        :do {add action=mark-connection chain=prerouting comment="$siteName - $priorityService - From-$wanNum" connection-mark=no-mark in-interface=$WANInterface new-connection-mark=$fromConMarkInsert passthrough=yes src-address-list=$siteFullList;} on-error={:put "mangle already exists $siteID $fromConMarkInsert"}
        
        #mark all the packets that are on the P7 Connection Mark. 
        $deployPacketMarking

        #create queue tree for P7
        /queue tree add bucket-size=0.2 burst-limit=$P7BurstDivisor burst-threshold=$P7BurstThresholdDivisor burst-time=20s limit-at=$P7reseveredDivisor max-limit=$P6maxDivisor name=$toPacketMarkInsert packet-mark=$toPacketMarkInsert parent=$qosparentNameTo priority=7 queue=SFQ-CHC
        /queue tree add bucket-size=0.2 burst-limit=$P7BurstDivisor burst-threshold=$P7BurstThresholdDivisor burst-time=20s limit-at=$P7reseveredDivisor max-limit=$P6maxDivisor name=$fromPacketMarkInsert packet-mark=$fromPacketMarkInsert parent=$qosparentNameFrom priority=7 queue=SFQ-CHC
        #Move on to another Priority
        $changePriority

        #P8 Begin
        #Mark connections for Tarpit P8
        :do {add action=mark-connection chain=postrouting comment="$siteName - $priorityService - To-$wanNum" connection-mark=no-mark dst-address-list=$siteFullList new-connection-mark=$toConMarkInsert out-interface=$WANInterface passthrough=yes src-address-list=08-Tarpit;} on-error={:put "mangle already exists $siteID $toConMarkInsert"}
        :do {add action=mark-connection chain=prerouting comment="$siteName - $priorityService - From-$wanNum" connection-mark=no-mark dst-address-list=08-Tarpit in-interface=$WANInterface new-connection-mark=$fromConMarkInsert passthrough=yes src-address-list=$siteFullList;} on-error={:put "mangle already exists $siteID $fromConMarkInsert"}

        #mark all the packets that are on the P8 Connection Mark. 
        $deployPacketMarking

        #create queue tree for P8 TARPIT
        
        /queue tree add limit-at=$P8reseveredDivisor max-limit=$P8maxDivisor name=$toPacketMarkInsert packet-mark=$toPacketMarkInsert parent=$qosparentNameTo priority=8 queue=SFQ-CHC
        /queue tree add limit-at=$P8reseveredDivisor max-limit=$P8maxDivisor name=$fromPacketMarkInsert packet-mark=$fromPacketMarkInsert parent=$qosparentNameFrom priority=8 queue=SFQ-CHC

    
        
        }
        /ip firewall mangle
        print file=junk
        /ip firewall mangle move destination=11 numbers=[find connection-mark="no-mark" chain="postrouting" comment~"$siteName"]
        /ip firewall mangle move destination=11 numbers=[find connection-mark="no-mark" chain="prerouting" comment~"$siteName"]
        /ip firewall mangle move destination=11 numbers=[find chain="postrouting" comment~"$siteName - ALL"]
        /ip firewall mangle move destination=11 numbers=[find chain="prerouting" comment~"$siteName - ALL"]

    }



