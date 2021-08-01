/* UPF implementation */

#include <core.p4>
#include <v1model.p4>

#include "headers.p4"
#include "./control/capsulate.p4"
#include "./control/pdr.p4"
#include "./control/far.p4"

/* #include "./control/urr.p4" */
/* #include "./control/bar.p4" */
/* #include "./control/qer.p4" */
/* #include "./control/mar.p4" */
/* #include "./control/srr.p4" */

parser SwitchParser(packet_in pkt,
                    out headers_t hdr,
                    inout metadata_t meta,
                    inout standard_metadata_t std_meta)
{
    state start {

        // initialize metadata
        meta.payload_len = (bit<16>)std_meta.packet_length;

        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        meta.payload_len = meta.payload_len - 14;
        transition select(hdr.ethernet.ether_type) {
            ETYPE_IPv4 : parse_ipv4;
            ETYPE_IPv6 : parse_ipv6;
            default    : accept;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        meta.payload_len = meta.payload_len - 20;
        transition select(hdr.ipv4.protocol) {
            PROTO_TCP : parse_tcp;
            PROTO_UDP : parse_udp;
            default   : accept;
        }
    }

    state parse_ipv6 {
        pkt.extract(hdr.ipv6);
        meta.payload_len = meta.payload_len - 40;
        transition select(hdr.ipv6.next_hdr) {
            PROTO_TCP : parse_tcp;
            PROTO_UDP : parse_udp;
            default   : accept;
        }
    }

    state parse_tcp {
        pkt.extract(hdr.tcp);
        meta.prev_checksum = hdr.tcp.checksum;
        meta.payload_len = meta.payload_len - 20;
        transition accept;
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        meta.prev_checksum = hdr.udp.checksum;
        meta.payload_len = meta.payload_len - 8;
        gtp_u_h gtp_u_tmp = pkt.lookahead<gtp_u_h>();
        transition select(hdr.udp.dst_port, gtp_u_tmp.version, gtp_u_tmp.msg_type) {
            (UDP_PORT_GTPU, 3w1, GTPv1_MSG_TYP_G_PDU) : parse_gtp_u;
            default                                   : accept;
        }
    }

    state parse_gtp_u {
        pkt.extract(hdr.gtp_u);
        meta.payload_len = meta.payload_len - 8;
        transition select(hdr.gtp_u.e, hdr.gtp_u.s, hdr.gtp_u.pn) {
            (_TRUE, _TRUE, _TRUE)   : parse_gtp_u_option;
            (_TRUE, _TRUE, _FALSE)  : parse_gtp_u_option;
            (_TRUE, _FALSE, _TRUE)  : parse_gtp_u_option;
            (_FALSE, _TRUE, _TRUE)  : parse_gtp_u_option;
            (_FALSE, _FALSE, _TRUE) : parse_gtp_u_option;
            (_FALSE, _TRUE, _FALSE) : parse_gtp_u_option;
            (_TRUE, _FALSE, _FALSE) : parse_gtp_u_option;
            default                 : check_inner_type;
        }
    }

    state parse_gtp_u_option {
        pkt.extract(hdr.gtp_u_option);
        meta.payload_len = meta.payload_len - 4;
        transition check_inner_type;
    }

    state check_inner_type {
        transition select(pkt.lookahead<bit<4>>()) {
            0x4     : parse_inner_ipv4;
            0x6     : parse_inner_ipv6;
            default : accept;
        }
    }

    state parse_inner_ipv4 {
        pkt.extract(hdr.inner_ipv4);
        meta.payload_len = meta.payload_len - 20;
        transition select(hdr.inner_ipv4.protocol) {
            PROTO_TCP : parse_inner_tcp;
            PROTO_UDP : parse_inner_udp;
            default   : accept;
        }
    }

    state parse_inner_ipv6 {
        pkt.extract(hdr.inner_ipv6);
        meta.payload_len = meta.payload_len - 40;
        transition select(hdr.inner_ipv6.next_hdr) {
            PROTO_TCP : parse_inner_tcp;
            PROTO_UDP : parse_inner_udp;
            default   : accept;
        }
    }

    state parse_inner_tcp {
        pkt.extract(hdr.inner_tcp);
        meta.payload_len = meta.payload_len - 20;
        transition accept;
    }

    state parse_inner_udp {
        pkt.extract(hdr.inner_udp);
        meta.payload_len = meta.payload_len - 8;
        transition accept;
    }
}

control verifyChecksum(inout headers_t hdr, inout metadata_t meta)
{
    apply { }
}

control SwitchIngress(inout headers_t hdr,
                      inout metadata_t meta,
                      inout standard_metadata_t std_meta)
{

    action get_far_info_from_rule_id(far_id_t far_id, far_flag_t flag) {

        // get FAR ID to be executed.
        meta.far_id = far_id;

        // get flags of FAR actions to be executed.
        meta.far_flag = flag;
    }

    /* TODO: there should be more efficient implementation with action-profile, etc. */
    table far {
        key = {
            meta.rule_id : exact;
        }
        actions = {
            get_far_info_from_rule_id;
            NoAction;
        }
        default_action = NoAction;
        size = MAX_FAR_NUM;
    }

    /* TODO: implement BAR table/action */
    action get_bar_info_from_rule_id() {
        /* TODO: implement action to get info. from rule_id */
    }

    table bar {
        key = {
            meta.rule_id : exact;
        }
        actions = {
            get_bar_info_from_rule_id;
            NoAction;
        }
        default_action = NoAction;
        size = MAX_BAR_NUM;
    }

    /* TODO: implement URR table/actions */
    action get_urr_info_from_rule_id() {
        /* TODO: implement action to get info. from rule_id */
    }

    table urr {
        key = {
            meta.rule_id : exact;
        }
        actions = {
            get_urr_info_from_rule_id;
            NoAction;
        }
        default_action = NoAction;
        size = MAX_URR_NUM;
    }

    /* TODO: implement QER table/actions */
    action get_qer_info_from_rule_id() {
        /* TODO: implement action to get info. from rule_id */
    }

    table qer {
        key = {
            meta.rule_id : exact;
        }
        actions = {
            get_qer_info_from_rule_id;
            NoAction;
        }
        default_action = NoAction;
        size = MAX_QER_NUM;
    }

    /* TODO: implement MAR table/actions */
    action get_mar_info_from_rule_id() {
        /* TODO: implement action to get info. from rule_id */
    }

    table mar {
        key = {
            meta.rule_id : exact;
        }
        actions = {
            get_mar_info_from_rule_id;
            NoAction;
        }
        default_action = NoAction;
        size = MAX_MAR_NUM;
    }

    /* TODO: implement SRR table/actions */
    action get_srr_info_from_rule_id() {
        /* TODO: implement action to get info. from rule_id */
    }

    table srr {
        key = {
            meta.rule_id : exact;
        }
        actions = {
            get_srr_info_from_rule_id;
            NoAction;
        }
        default_action = NoAction;
        size = MAX_SRR_NUM;
    }

    // instanciate procedure block for each rules.
    /* URR_Procedure()    URR; // not implemented yet ... */
    /* BAR_Procedure()    BAR; // not implemented yet ... */
    /* QER_Procedure()    QER; // not implemented yet ... */
    /* MAR_Procedure()    MAR; // not implemented yet ... */
    /* SRR_Procedure()    SRR; // not implemented yet ... */
    FAR_Procedure()       FAR;
    PDR_Procedure()       PDR;
    CAPSULATE_Procedure() CAPSULATE;

    apply {

        // apply packet detection rule (PDR).
        PDR.apply(hdr, meta, std_meta);

        // encapsulate or decapsulate (if necessary).
        CAPSULATE.apply(hdr, meta, std_meta);

        // try to apply each rule w/ "rule_id".
        if (far.apply().hit) {
            FAR.apply(hdr, meta, std_meta);
        } else if (bar.apply().hit) {
            /* BAR.apply(hdr, meta, std_meta); */
        } else if (urr.apply().hit) {
            /* URR.apply(hdr, meta, std_meta); */
        } else if (qer.apply().hit) {
            /* QER.apply(hdr, meta, std_meta); */
        } else if (mar.apply().hit) {
            /* MAR.apply(hdr, meta, std_meta); */
        } else if (srr.apply().hit) {
            /* SRR.apply(hdr, meta, std_meta); */
        } else {
            /* TODO: No rule has been detected. SHOULD be dropped. */
        }
    }
}

control SwitchEgress(inout headers_t hdr,
                     inout metadata_t meta,
                     inout standard_metadata_t std_meta)
{
    apply { }
}

control updateChecksum(inout headers_t hdr, inout metadata_t meta)
{
    apply { 

        update_checksum(
            meta.need_checksum_calc_v4,
            { hdr.ipv4.version,
              hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.total_len,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.flag_offset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.src_addr,
              hdr.ipv4.dst_addr},
            hdr.ipv4.checksum,
            HashAlgorithm.csum16);

        /* TODO: UDP ckecksum calc. does NOT work ... 
                 Original pseudo-header MUST be subtracted before the calc. 
                 Also GTP-U header MUST be considered to the calc.
        */
        update_checksum(
            (meta.need_checksum_calc_udp && hdr.ipv4.isValid()),
            { hdr.ipv4.src_addr,
              hdr.ipv4.dst_addr,
              hdr.ipv4.protocol,
              hdr.udp.src_port,
              hdr.udp.dst_port,
              hdr.udp.len,
              meta.prev_checksum },
            hdr.udp.checksum,
            HashAlgorithm.csum16);
        update_checksum(
            (meta.need_checksum_calc_udp && hdr.ipv6.isValid()),
            { hdr.ipv6.src_addr,
              hdr.ipv6.dst_addr,
              hdr.ipv6.next_hdr,
              hdr.udp.src_port,
              hdr.udp.dst_port,
              hdr.udp.len,
              meta.prev_checksum },
            hdr.udp.checksum,
            HashAlgorithm.csum16);
    }
}

control SwitchDeparser(packet_out pkt,
                       in headers_t hdr)
{
    apply {
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.ipv4);
        pkt.emit(hdr.ipv6);
        pkt.emit(hdr.tcp);
        pkt.emit(hdr.udp);
        pkt.emit(hdr.gtp_u);
        pkt.emit(hdr.gtp_u_option);
        pkt.emit(hdr.inner_ipv4);
        pkt.emit(hdr.inner_ipv6);
        pkt.emit(hdr.inner_tcp);
        pkt.emit(hdr.inner_udp);
    }
}

V1Switch(SwitchParser(),
         verifyChecksum(),
         SwitchIngress(),
         SwitchEgress(),
         updateChecksum(),
         SwitchDeparser()) main;
