/* PDR implementation */

#include <v1model.p4>

control PDR_Procedure(inout headers_t hdr,
                      inout metadata_t meta,
                      inout standard_metadata_t std_meta)
{

    // NOTE: this actin might be used at A-UPF that decapsulates and forward the GTP-U packet to appropriate PDN.
    action get_info_with_decapsulation(rule_id_t rule_id, pdu_sess_type_t pdu_sess_type) {
        
        // get info. for next procedure.
        meta.rule_id = rule_id;
        meta.pdu_sess_type = pdu_sess_type;

        // decapsulate GTP-U header.
        meta.decapsulate_gtp_u_flag = true;
    }

    // NOTE: this action might be used at A-UPF that encapsulates and forward the PDN packet to appropriate I-UPF.
    action get_info_with_encapsulation_v4(rule_id_t       rule_id, 
                                          pdu_sess_type_t pdu_sess_type, 
                                          ipv4_addr_t     dst_addr, 
                                          ipv4_addr_t     src_addr,
                                          udp_port_t      dst_port,
                                          udp_port_t      src_port, 
                                          bit<32>         teid) {
        
        // get info. for next procedure.
        meta.rule_id = rule_id;
        meta.pdu_sess_type = pdu_sess_type;

        // encapsulate GTP-U header with IPv4
        meta.encapsulate_gtp_u_flag = true;
        meta.encap_ipv4_dst_addr = dst_addr;
        meta.encap_ipv4_src_addr = src_addr; 
        meta.encap_dst_port      = dst_port;
        meta.encap_src_port      = src_port;
        meta.encap_teid          = teid;
    }

    // NOTE: this action might be used at A-UPF that encapsulates and forward the PDN packet to appropriate I-UPF.
    action get_info_with_encapsulation_v6(rule_id_t       rule_id, 
                                          pdu_sess_type_t pdu_sess_type, 
                                          ipv6_addr_t     dst_addr,
                                          ipv6_addr_t     src_addr, 
                                          udp_port_t      src_port,
                                          udp_port_t      dst_port,
                                          bit<32>         teid) {
        
        // get info. for next procedure.
        meta.rule_id = rule_id;
        meta.pdu_sess_type = pdu_sess_type;

        // encapsulate GTP-U header with IPv6.
        meta.encapsulate_gtp_u_flag = true;
        meta.encap_ipv6_dst_addr = dst_addr;
        meta.encap_ipv6_src_addr = src_addr; 
        meta.encap_dst_port      = dst_port;
        meta.encap_src_port      = src_port;
        meta.encap_teid          = teid;
    }

    // NOTE: this action might be used at I-UPF that pass-through in-coming GTP-U packet to A-UPF w/o depcas.
    action get_info(rule_id_t rule_id, pdu_sess_type_t pdu_sess_type) {
        
        // get info. for next procedure.
        meta.rule_id = rule_id;
        meta.pdu_sess_type = pdu_sess_type;
    }

    direct_counter(CounterType.packets_and_bytes) pdr_counter_v4;
    direct_counter(CounterType.packets_and_bytes) pdr_counter_v6;
    
    table pdr_v4 {
        key = {
            std_meta.ingress_port : exact;
            meta.teid             : ternary;
            hdr.ipv4.dst_addr     : lpm;
            /* TODO: Network Instance : ternary; */
            /* TODO: SDF filter(s)    : ternary; */
            /* TODO: Application ID   : ternary; */
        }
        actions = {
            get_info;
            get_info_with_encapsulation_v4;
            get_info_with_decapsulation;
            NoAction;
        }
        default_action = NoAction;
        counters = pdr_counter_v4;
        size = MAX_PDR_NUM;
    }

    table pdr_v6 {
        key = {
            std_meta.ingress_port : exact;
            meta.teid             : ternary;
            hdr.ipv6.dst_addr     : lpm;
            /* TODO: network_instance : ternary; */
            /* TODO: SDF filter(s)    : ternary; */
            /* TODO: Application ID   : ternary; */
        }
        actions = {
            get_info;
            get_info_with_encapsulation_v6;
            get_info_with_decapsulation;
            NoAction;
        }
        default_action = NoAction;
        counters = pdr_counter_v6;
        size = MAX_PDR_NUM;
    }

    apply {

        // get info. for next procedure w/ Packet Detection Rule (PDR)
        // note this table also encaps or depcas GTP-U header based-on in-coming IF.
        if (hdr.gtp_u.isValid()) {
            meta.teid = hdr.gtp_u.teid;
        } else {
            meta.teid = 0; /* TODO: TEID = 0 cannot be used by users, is it correct ? */
        }

        if (hdr.ipv4.isValid()) {
            if (!pdr_v4.apply().hit) {
                /* TODO: No PDR has been detected for the in-coming packet. SHOULD be dropped. */
            }
        } else if (hdr.ipv6.isValid()) {
            if (!pdr_v6.apply().hit) {
                /* TODO: No PDR has been detected for the in-coming packet. SHOULD be dropped. */
            }
        } else {
            /* TODO: in-coming packet has invalid headers. SHOULD be dropped */
        }
    }
}
