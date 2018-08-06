*** Settings ***
Documentation     Test Suite for SDNC-FUNCTIONAL Test Scenarios
Variables         ../../Config/config.py
Variables         ../../Config/OvsConf.py
Variables         ../../Config/ControllerConfig.py
Library           Supporting_Libs.sys_utils
Library           Supporting_Libs.Karaf    IP=${CONTROLLER_INFO['IP']}    username=${CONTROLLER_INFO['USER']}
...               password=${CONTROLLER_INFO['PASSWORD']}    WITH NAME    CNTRLROBJ
Library           Supporting_Libs.ovs    IP=${SWITCH['IP']}    username=${SWITCH['USER']}
...               password=${SWITCH['PASSWORD']}    WITH NAME    OVSOBJ
Library           Supporting_Libs.hosts    IP=${HOST1['IP']}    username=${HOST1['USER']}
...               password=${HOST1['PASSWORD']}    WITH NAME    HOST1
Library           Supporting_Libs.hosts    IP=${HOST2['IP']}    username=${HOST2['USER']}
...               password=${HOST2['PASSWORD']}    WITH NAME    HOST2
Library           Supporting_Libs.debugHelper
Library           Collections



*** Variables ***
${True}              True
${False}             False
${Match_ip}          33.33.33.1
@{Cntrlr_data}         ${CONTROLLER_INFO['IP']}  6653

*** Test Cases ***
Verify If All Devices Are Powered Up
    [Documentation]    login to switch,host1 & host2
    ${ovs_obj}    Get Library Instance    OVSOBJ
    ${cntrl_obj}    Get Library Instance    CNTRLROBJ
    ${host1_obj}    Get Library Instance    HOST1
    ${host2_obj}    Get Library Instance    HOST2

    set suite variable    ${ovs_obj}
    set suite variable    ${cntrl_obj}
    set suite variable    ${host1_obj}
    set suite variable    ${host2_obj}

Configure OVS bridge
    ${status}    OVSOBJ.Create Validate Bridge    ${OVS_BRIDGE_CONF['NAME']}   ${Cntrlr_data}
    #should be equal    ${status}    ${True}
    #Run Keyword And Continue On Failure  Run keyword unless  ${status} != ${True}    Fail   Debug Abc Failure  ${cntrl_obj}
    Run Keyword If  ${status} != ${True}   Run Keywords
    ...    Debug Controller Failure  ${ovs_obj}  ${cntrl_obj}
    ...    AND   Fail

Add ports to OVS bridge
    ${status}    OVSOBJ.Addports Validate     ${OVS_BRIDGE_CONF['NAME']}   ${OVS_BRIDGE_CONF['PORTS']}
    should be equal    ${status}    ${True}

Assign IP addresses to host interfaces
    HOST1.Config Host Nic Ip   if_name=${HOST1["PORT_CONFIG"]['iface1']}   ip=${HOST1["PORT_CONFIG"]['iface1_ip']}
    HOST2.Config Host Nic Ip   if_name=${HOST2["PORT_CONFIG"]['iface1']}   ip=${HOST2["PORT_CONFIG"]['iface1_ip']}

Ports Based Flows test - PUSH To & Fro Port Based Flow Rules
    &{flow_input}    create dictionary    Null=Null
    ${status}    OVSOBJ.Manage Flows  manage_type=delete   br_name=${OVS_BRIDGE_CONF['NAME']}   flow_inputs=${flow_input}
    ...   controller=${CONTROLLER_TYPE}
    #${status}    Flow Management    ${ovs_obj}    delete    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
    should be equal    ${status}    ${True}
    &{flow_input}    create dictionary    priority=${priority[0]}    in_port=${ports[0]}    id=1    table=0    order=0
    ...    actions=${ports[1]}
    #${status}    Flow Management    ${ovs_obj}    add    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
    ${status}    OVSOBJ.Manage Flows  manage_type=add   br_name=${OVS_BRIDGE_CONF['NAME']}   flow_inputs=${flow_input}
    ...   controller=${CONTROLLER_TYPE}
    should be equal    ${status}    ${True}
    &{flow_input}    create dictionary    priority=${priority[0]}    in_port=${ports[1]}    id=2    table=0    order=0
    ...    actions=${ports[0]}
    #${status}    Flow Management    ${ovs_obj}    add    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
    ${status}    OVSOBJ.Manage Flows  manage_type=add   br_name=${OVS_BRIDGE_CONF['NAME']}   flow_inputs=${flow_input}
    ...   controller=${CONTROLLER_TYPE}
    should be equal    ${status}    ${True}

Ports Based Flows test - Check Host Reachability Via Created Flow Rules
    ${result}    Peer Ping    obj=${host1_obj}    source=None    dest=${HOST2["PORT_CONFIG"]['iface1_ip']}
    should be equal    ${result}    ${True}

Ports Based Flows test - Delete One Of The Flows To Interrupt The Host Reachability
    &{flow_input}    create dictionary    priority=${priority[0]}    in_port=${ports[1]}    id=2    table=0    order=0
    ...    actions=${ports[0]}
    ${status}    Flow Management    ${ovs_obj}    delete    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
    should be equal    ${status}    ${True}

Ports Based Flows test - Check Host reachability Is Interrupted
    ${result}    Peer Ping    obj=${host1_obj}    source=None    dest=${HOST2["PORT_CONFIG"]['iface1_ip']}
    should be equal    ${result}    ${False}

Ports Based Flows test - Restore(PUSH) The Deleted Flow Rule
    &{flow_input}    create dictionary    priority=${priority[0]}    in_port=${ports[1]}    id=2    table=0    order=0
    ...    actions=${ports[0]}
    ${status}    Flow Management    ${ovs_obj}    add    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
    should be equal    ${status}    ${True}

Ports Based Flows test - Check Host Reachability After Port Based Flow Rule Restored
    ${result}    Peer Ping    obj=${host1_obj}    source=None    dest=${HOST2["PORT_CONFIG"]['iface1_ip']}
    should be equal    ${result}    ${True}

MAC Address Based Match Flows Test - PUSH A Flow To Match SRC MAC And Forward
    &{flow_input}    create dictionary    Null=Null
    ${status}    Flow Management    ${ovs_obj}    delete    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
    should be equal    ${status}    ${True}
    &{flow_input}    create dictionary    priority=${priority[0]}    in_port=${ports[0]}    id=1    table=0    order=0
    ...    dl_src=${mac_addr[0]}    actions=${ports[1]}
    ${status}    Flow Management    ${ovs_obj}    add    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
    should be equal    ${status}    ${True}

MAC Address Based Match Flows Test - Check The Flow With Traffic on SRC MAC Match
    import Library    Supporting_Libs.Traffic_Generator.Scapy    ${host1_obj}    None    WITH NAME    TG
    ${tg}    Get Library Instance    TG
    set suite variable    ${tg}
    #${packet}    TG.Generate Packet To Send    pkt_type=ether    profile=${packet_profile}
    ${packet}    TG.Generate Packet To Send    pkt_type=ether
#    ${PID}    ${cap_file}    Start Capture    ${host2_obj}    ${HOST2["PORT_CONFIG"]['iface1']}
#    TG.Send Cmd To Scapy    ${packet}    ${HOST1["PORT_CONFIG"]['iface1']}    ${pkt_count}    ${interval}
#    Stop Capture    ${host2_obj}    ${PID}
#    TG.Disconnect
#    ${file_data}    Supporting_Libs.sys_utils.Get Data From File    ${host2_obj}    ${cap_file}
    ${file_data}    HOST1.Send Pkts N Capture    ${tg}    ${host2_obj}    ${HOST1["PORT_CONFIG"]['iface1']}
    ...    ${HOST2["PORT_CONFIG"]['iface1']}    ${packet}    ${pkt_count}    ${interval}
#    TG.Disconnect
    ${valid_count}    Validate Output    ${mac_addr[0]}    ${file_data}
    ${zero}    convert to integer    0
    Should Not Be Equal As Integers    ${valid_count}    ${zero}

Vlan Id Based Match Flows Test - PUSH The Flows To Match VLAN ID
    &{flow_input}    create dictionary    Null=Null
    ${status}    Flow Management    ${ovs_obj}    delete    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
    should be equal    ${status}    ${True}
    &{flow_input}    create dictionary    priority=${priority[0]}    in_port=${ports[0]}    id=1    table=0    order=0
    ...    dl_vlan=${vlans[0]}    actions=${ports[1]}
    ${status}    Flow Management    ${ovs_obj}    add    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
    should be equal    ${status}    ${True}

Vlan Id Based Match Flows Test - Check The Traffic Is Forwarded On Vlan Id Match
    import Library    Supporting_Libs.Traffic_Generator.Scapy    ${host1_obj}    None    WITH NAME    TG
    ${packet}    TG.Generate Packet To Send    pkt_type=vlan
#    ${PID}    ${cap_file}    Start Capture    ${host2_obj}    ${HOST2["PORT_CONFIG"]['iface1']}
#    TG.Send Cmd To Scapy    ${packet}    ${HOST1["PORT_CONFIG"]['iface1']}    ${pkt_count}    ${interval}
#    Stop Capture    ${host2_obj}    ${PID}
    ${file_data}    HOST1.Send Pkts N Capture    ${tg}    ${host2_obj}    ${HOST1["PORT_CONFIG"]['iface1']}
    ...    ${HOST2["PORT_CONFIG"]['iface1']}    ${packet}    ${pkt_count}    ${interval}
#    TG.Disconnect
#    ${file_data}    Supporting_Libs.sys_utils.Get Data From File    ${host2_obj}    ${cap_file}
    ${valid_count}    Validate Output    vlan ${vlans[0]}    ${file_data}
    ${zero}    convert to integer    0
    Should Not Be Equal As Integers    ${valid_count}    ${zero}

Vlan Id Based Match Flows Test - PUSH Flow Rule To Strip VLAN & Forward The Traffic
    &{flow_input}    create dictionary    priority=${priority[0]}    in_port=${ports[0]}    id=1    table=0    order=0
    ...    dl_vlan=${vlans[0]}    actions=strip_vlan,${ports[1]}
    ${status}    Flow Management    ${ovs_obj}    add    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
    should be equal    ${status}    ${True}

Vlan Id Based Match Flows Test - Check The Traffic Is Forwarded After Stripping VLAN ID
    import Library    Supporting_Libs.Traffic_Generator.Scapy    ${host1_obj}    None    WITH NAME    TG
    ${packet}    TG.Generate Packet To Send    pkt_type=vlan
#    ${PID}    ${cap_file}    Start Capture    ${host2_obj}    ${HOST2["PORT_CONFIG"]['iface1']}
#    TG.Send Cmd To Scapy    ${packet}    ${HOST1["PORT_CONFIG"]['iface1']}    ${pkt_count}    ${interval}
#    Stop Capture    ${host2_obj}    ${PID}
    ${file_data}    HOST1.Send Pkts N Capture    ${tg}    ${host2_obj}    ${HOST1["PORT_CONFIG"]['iface1']}
    ...    ${HOST2["PORT_CONFIG"]['iface1']}    ${packet}    ${pkt_count}    ${interval}
#    TG.Disconnect
 #   ${file_data}    Supporting_Libs.sys_utils.Get Data From File    ${host2_obj}    ${cap_file}
    ${valid_count}    Validate Output    'vlan'    ${file_data}
    ${zero}    convert to integer    0
    Should Be Equal As Integers    ${valid_count}    ${zero}

Vlan Id Based Match Flows Test - PUSH A Flow To Modify VLAN Vid & Forward The Traffic
    &{flow_input}    create dictionary    priority=${priority[0]}    in_port=${ports[0]}    id=1    table=0    order=0
    ...    actions=mod_vlan_vid:${vlans[0]},${ports[1]}
    ${status}    Flow Management    ${ovs_obj}    add    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
    should be equal    ${status}    ${True}

Vlan Id Based Match Flows Test - Check The Traffic Is Forwarded After Modifying The VLAN ID
    import Library    Supporting_Libs.Traffic_Generator.Scapy    ${host1_obj}    None    WITH NAME    TG
    ${packet}    TG.Generate Packet To Send    pkt_type=ip
#    ${PID}    ${cap_file}    Start Capture    ${host2_obj}    ${HOST2["PORT_CONFIG"]['iface1']}
#    TG.Send Cmd To Scapy    ${packet}    ${HOST1["PORT_CONFIG"]['iface1']}    ${pkt_count}    ${interval}
#    Stop Capture    ${host2_obj}    ${PID}
    ${file_data}    HOST1.Send Pkts N Capture    ${tg}    ${host2_obj}    ${HOST1["PORT_CONFIG"]['iface1']}
    ...    ${HOST2["PORT_CONFIG"]['iface1']}    ${packet}    ${pkt_count}    ${interval}
#    TG.Disconnect
#    ${file_data}    Supporting_Libs.sys_utils.Get Data From File    ${host2_obj}    ${cap_file}
    ${valid_count}    Validate Output    vlan ${vlans[0]}    ${file_data}
    ${zero}    convert to integer    0
    Should Not Be Equal As Integers    ${valid_count}    ${zero}

IPv4 Address Based Match Flows Test - PUSH A Flow To Forward Traffic On SRC IP Match
    &{flow_input}    create dictionary    Null=Null
    ${status}    Flow Management    ${ovs_obj}    delete    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
    should be equal    ${status}    ${True}
    &{flow_input}    create dictionary    priority=${priority[0]}    in_port=${ports[0]}    id=1    table=0    order=0
    ...    dl_type=2048    nw_src=${ip_addr[0]}    actions=${ports[1]}
    ${status}    Flow Management    ${ovs_obj}    add    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
    should be equal    ${status}    ${True}

IPv4 Address Based Match Flows Test - Check The Traffic Is Forwarded On SRC IP Match
    import Library    Supporting_Libs.Traffic_Generator.Scapy    ${host1_obj}    None    WITH NAME    TG
    ${tg}    Get Library Instance    TG
    set to dictionary  ${IP}    src_ip   33.33.33.1
    ${packet}    TG.Generate Packet To Send    pkt_type=ip
#    ${PID}    ${cap_file}    Start Capture    ${host2_obj}    ${HOST2["PORT_CONFIG"]['iface1']}
#    TG.Send Cmd To Scapy    ${packet}    ${HOST1["PORT_CONFIG"]['iface1']}    ${pkt_count}    ${interval}
#    Stop Capture    ${host2_obj}    ${PID}
    ${file_data}    HOST1.Send Pkts N Capture    ${tg}    ${host2_obj}    ${HOST1["PORT_CONFIG"]['iface1']}
    ...    ${HOST2["PORT_CONFIG"]['iface1']}    ${packet}    ${pkt_count}    ${interval}
#    TG.Disconnect
#    ${file_data}    Supporting_Libs.sys_utils.Get Data From File    ${host2_obj}    ${cap_file}
    ${valid_count}    Validate Output    ${Match_ip}    ${file_data}
    ${zero}    convert to integer    0
    Should Not Be Equal As Integers    ${valid_count}    ${zero}

IPv4 Address Based Match Flows test - Delete The Flow To Match SRC IP
    &{flow_input}    create dictionary    priority=${priority[0]}    in_port=${ports[0]}    id=1    table=0    order=0
    ...    dl_type=2048    nw_src=${ip_addr[0]}    actions=${ports[1]}
    ${status}    Flow Management    ${ovs_obj}    delete    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
    should be equal    ${status}    ${True}

IPv4 Address Based Match Flows test - Check The Traffic Is Droppd As SRC IP Match Flow Is Deleted
    import Library    Supporting_Libs.Traffic_Generator.Scapy    ${host1_obj}    None    WITH NAME    TG
    ${tg}    Get Library Instance    TG
    ${packet}    TG.Generate Packet To Send    pkt_type=ip
#    ${PID}    ${cap_file1}    Start Capture    ${host2_obj}    ${HOST2["PORT_CONFIG"]['iface1']}
#    TG.Send Cmd To Scapy    ${packet}    ${HOST1["PORT_CONFIG"]['iface1']}    ${pkt_count}    ${interval}
#    Stop Capture    ${host2_obj}    ${PID}
    ${file_data}    HOST1.Send Pkts N Capture    ${tg}    ${host2_obj}    ${HOST1["PORT_CONFIG"]['iface1']}
    ...    ${HOST2["PORT_CONFIG"]['iface1']}    ${packet}    ${pkt_count}    ${interval}
#    TG.Disconnect
#    ${file_data}    Supporting_Libs.sys_utils.Get Data From File    ${host2_obj}    ${cap_file1}
    ${valid_count}    Validate Output    ${Match_ip}    ${file_data}
    ${zero}    convert to integer    0
    Should Be Equal As Integers    ${valid_count}    ${zero}

ACL Rules Mimic Using OVS Flows - PUSH FLOW To Deny ICMP Echo Req Traffic
    &{flow_input}    create dictionary    priority=${priority[0]}    in_port=${ports[0]}    id=1    table=0    order=0
    ...    dl_type=2048    nw_proto=1    icmp_type=8    actions=${ports[1]}
#    ${status}    Flow Management    ${ovs_obj}    delete    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
#    should be equal    ${status}    ${True}
    &{flow_input}    create dictionary    priority=${priority[0]}    in_port=${ports[0]}    id=1    table=0    order=0
    ...    dl_type=2048    nw_proto=1    icmp_type=8    actions=${flow_actions[2]}
    ${status}    Flow Management    ${ovs_obj}    add    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
    should be equal    ${status}    ${True}

ACL Rules Mimic Using OVS Flows - Check The ICMP Echo Req Traffic Is Denied/Dropped
    ${packet}    TG.Generate Packet To Send    pkt_type=icmpv4
#    ${PID}    ${cap_file}    Start Capture    ${host2_obj}    ${HOST2["PORT_CONFIG"]['iface1']}
#    TG.Send Cmd To Scapy    ${packet}    ${HOST1["PORT_CONFIG"]['iface1']}    ${pkt_count}    ${interval}
#    Stop Capture    ${host2_obj}    ${PID}
    ${file_data}    HOST1.Send Pkts N Capture    ${tg}    ${host2_obj}    ${HOST1["PORT_CONFIG"]['iface1']}
    ...    ${HOST2["PORT_CONFIG"]['iface1']}    ${packet}    ${pkt_count}    ${interval}
#    TG.Disconnect
#    ${file_data}    Supporting_Libs.sys_utils.Get Data From File    ${host2_obj}    ${cap_file}
    ${valid_count}    Validate Output    ${Match_ip}    ${file_data}
    ${zero}    convert to integer    0
    Should Be Equal As Integers    ${valid_count}    ${zero}

ACL Rules Mimic Using OVS Flows - PUSH FLOWS To Allow ICMP Echo Req Traffic
    &{flow_input}    create dictionary    Null=Null
    ${status}    Flow Management    ${ovs_obj}    delete    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
    should be equal    ${status}    ${True}
    &{flow_input}    create dictionary    priority=${priority[0]}    in_port=${ports[0]}    id=1    table=0    order=0
    ...    dl_type=2048    nw_proto=1    icmp_type=8    actions=${ports[1]}
    ${status}    Flow Management    ${ovs_obj}    add    ${OVS_BRIDGE_CONF['NAME']}    ${flow_input}
    should be equal    ${status}    ${True}

ACL Rules Mimic Using OVS Flows - Check The ICMP Echo Req Traffic Is Allowed
    import Library    Supporting_Libs.Traffic_Generator.Scapy    ${host1_obj}    None    WITH NAME    TG
    ${tg}    Get Library Instance    TG
    ${packet}    TG.Generate Packet To Send    pkt_type=icmpv4
#    ${PID}    ${cap_file}    Start Capture    ${host2_obj}    ${HOST2["PORT_CONFIG"]['iface1']}
#    TG.Send Cmd To Scapy    ${packet}    ${HOST1["PORT_CONFIG"]['iface1']}    ${pkt_count}    ${interval}
#    Stop Capture    ${host2_obj}    ${PID}
    ${file_data}    HOST1.Send Pkts N Capture    ${tg}    ${host2_obj}    ${HOST1["PORT_CONFIG"]['iface1']}
    ...    ${HOST2["PORT_CONFIG"]['iface1']}    ${packet}    ${pkt_count}    ${interval}
    TG.Disconnect
#    ${file_data}    Supporting_Libs.sys_utils.Get Data From File    ${host2_obj}    ${cap_file}
    ${valid_count}    Validate Output    ${Match_ip}    ${file_data}
    ${zero}    convert to integer    0
    Should Not Be Equal As Integers    ${valid_count}    ${zero}
