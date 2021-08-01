/* Capsulating procedure implementation */

#include <v1model.p4>

control CAPSULATE_Procedure(inout headers_t hdr,
                           inout metadata_t meta,
                           inout standard_metadata_t std_meta)
{
    @hidden
    action set_valid_and_copy_ipv4() {

        // copy ipv4 to inner_ipv4.
        hdr.inner_ipv4.setValid();
        hdr.inner_ipv4.version        = hdr.ipv4.version;
        hdr.inner_ipv4.ihl            = hdr.ipv4.ihl;
        hdr.inner_ipv4.diffserv       = hdr.ipv4.diffserv;
        hdr.inner_ipv4.total_len      = hdr.ipv4.total_len;
        hdr.inner_ipv4.identification = hdr.ipv4.identification;
        hdr.inner_ipv4.flags          = hdr.ipv4.flags;
        hdr.inner_ipv4.flag_offset    = hdr.ipv4.flag_offset;
        hdr.inner_ipv4.ttl            = hdr.ipv4.ttl;
        hdr.inner_ipv4.protocol       = hdr.ipv4.protocol;
        hdr.inner_ipv4.checksum       = hdr.ipv4.checksum;
        hdr.inner_ipv4.src_addr       = hdr.ipv4.src_addr;
        hdr.inner_ipv4.dst_addr       = hdr.ipv4.dst_addr;
    }

    @hidden
    action set_valid_and_copy_ipv6() {

        // copy ipv6 to inner_ipv6.
        hdr.inner_ipv6.setValid();
        hdr.inner_ipv6.version       = hdr.ipv6.version;
        hdr.inner_ipv6.traffic_class = hdr.ipv6.traffic_class;
        hdr.inner_ipv6.flow_label    = hdr.ipv6.flow_label;
        hdr.inner_ipv6.payload_len   = hdr.ipv6.payload_len;
        hdr.inner_ipv6.next_hdr      = hdr.ipv6.next_hdr;
        hdr.inner_ipv6.hop_limit     = hdr.ipv6.hop_limit;
        hdr.inner_ipv6.src_addr      = hdr.ipv6.src_addr;
        hdr.inner_ipv6.dst_addr      = hdr.ipv6.dst_addr;
    }

    @hidden
    action set_valid_and_copy_tcp() {

        // copy tcp to inner_tcp.
        hdr.inner_tcp.setValid();
        hdr.inner_tcp.src_port   = hdr.tcp.src_port;
        hdr.inner_tcp.dst_port   = hdr.tcp.dst_port;
        hdr.inner_tcp.seq_num    = hdr.tcp.seq_num;
        hdr.inner_tcp.ack        = hdr.tcp.ack;
        hdr.inner_tcp.offset     = hdr.tcp.offset;
        hdr.inner_tcp.res        = hdr.tcp.res;
        hdr.inner_tcp.flags      = hdr.tcp.flags;
        hdr.inner_tcp.window     = hdr.tcp.window;
        hdr.inner_tcp.checksum   = hdr.tcp.checksum;
        hdr.inner_tcp.urgent_ptr = hdr.tcp.urgent_ptr;
    }

    @hidden
    action set_valid_and_copy_udp() {

        // copy udp to inner_udp.
        hdr.inner_udp.setValid();
        hdr.inner_udp.src_port = hdr.udp.src_port;
        hdr.inner_udp.dst_port = hdr.udp.dst_port;
        hdr.inner_udp.len      = hdr.udp.len;
        hdr.inner_udp.checksum = hdr.udp.checksum;
    }

    @hidden
    action set_ipv4(ipv4_addr_t dst_addr, ipv4_addr_t src_addr) {

        // set new IPv4 header.
        hdr.ipv4.setValid();
        hdr.ipv4.version        = 4;
        hdr.ipv4.ihl            = 5;
        hdr.ipv4.diffserv       = 0x00;             /* TODO: SHOULD be dynamic ?              */
        // hdr.ipv4.total_len   = meta.payload_len; /* NOTE: update in "encapsulate_gtp_u_v4" */
        hdr.ipv4.identification = 0x00;             /* TODO: SHOULD be dynamic ?              */
        hdr.ipv4.flags          = 0;
        hdr.ipv4.flag_offset    = 0;
        hdr.ipv4.ttl            = 255;
        hdr.ipv4.protocol       = PROTO_UDP;
        hdr.ipv4.src_addr       = src_addr;
        hdr.ipv4.dst_addr       = dst_addr;

        // set flag to calc. checksum.
        meta.need_checksum_calc_v4 = true;
    }

    @hidden
    action set_ipv6(ipv6_addr_t dst_addr, ipv6_addr_t src_addr) {

        // set new IPv6 header.
        hdr.ipv6.version        = 6;
        hdr.ipv6.traffic_class  = 0x00;
        hdr.ipv6.flow_label     = 0;
        // hdr.ipv6.payload_len = meta.payload_len /* NOTE: update in "encapsulate_gtp_u_v6" */
        hdr.ipv6.next_hdr       = PROTO_UDP;
        hdr.ipv6.hop_limit      = 255;
        hdr.ipv6.src_addr       = src_addr;
        hdr.ipv6.dst_addr       = dst_addr;
    }

    @hidden
    action set_udp(udp_port_t dst_port, udp_port_t src_port) {

        // set new UDP header.
        hdr.udp.setValid();
        hdr.udp.src_port = src_port;
        hdr.udp.dst_port = dst_port;
        // hdr.udp.len = meta.payload_len; /* NOTE: update in "encapsulate_gtp_u_xx" */

        // set flag to calc. checksum.
        meta.need_checksum_calc_udp = true;
    }

    @hidden
    action set_gtp_u(bit<32> teid) {

        // set new GTP-U header.
        hdr.gtp_u.setValid();
        hdr.gtp_u.version      = 1;
        hdr.gtp_u.pt           = 1; /* NOTE: Protocol Type is GTP (refer to TS29.281 section 5.1) */
        hdr.gtp_u.rsrv         = 0;
        hdr.gtp_u.e            = 0; /* TODO: SHOULD be dynamic ? */
        hdr.gtp_u.s            = 0; /* TODO: SHOULD be dynamic ? */
        hdr.gtp_u.pn           = 0; /* TODO: SHOULD be dynamic ? */
        hdr.gtp_u.msg_type     = GTPv1_MSG_TYP_G_PDU;
        // hdr.gtp_u.payload_len  = meta.payload_len; /* NOTE: update in "encapsulate_gtp_u_xx" */
        hdr.gtp_u.teid         = teid;
    }

    @hidden
    action encapsulate_gtp_u_v4_udp() {

        // move user's (outer) ipv4 and udp to inner_ipv4, inner_udp
        // encapsulate w/ IPv4, UDP, GTP-U
        set_valid_and_copy_ipv4();
        set_valid_and_copy_udp();
        set_ipv4(meta.encap_ipv4_dst_addr, meta.encap_ipv4_src_addr);
        set_udp(meta.encap_dst_port, meta.encap_src_port);
        set_gtp_u(meta.encap_teid);

        // update ipv4.total_len (payload length + the length of IPv4, UDP, GTP-U, Inner IPv4, Inner UDP)
        hdr.ipv4.total_len = meta.payload_len + 64;

        // update udp.len (payload length + the length of UDP, GTP-U, Inner IPv4, Inner UDP)
        hdr.udp.len = meta.payload_len + 44;

        // update gtp_u.payload_len (payload length + the length of Innter IPv4, Inner UDP)
        hdr.gtp_u.payload_len = meta.payload_len + 28;
    }

    @hidden
    action encapsulate_gtp_u_v6_udp() {

        // move user's (outer) ipv6 and udp to inner_ipv6, inner_udp
        // encapsulate w/ IPv6, UDP, GTP-U
        set_valid_and_copy_ipv6();
        set_valid_and_copy_udp();
        set_ipv6(meta.encap_ipv6_dst_addr, meta.encap_ipv6_src_addr);
        set_udp(meta.encap_dst_port, meta.encap_src_port);
        set_gtp_u(meta.encap_teid);

        // update ipv6.payload_len (payload length + the length of IPv6, UDP, GTP-U, Inner IPv6, Inner UDP)
        hdr.ipv6.payload_len = meta.payload_len + 64;

        // update udp.len (payload length + the length of UDP, GTP-U, Inner IPv6, Inner UDP)
        hdr.udp.len = meta.payload_len + 64;

        // update gtp_u.payload_len (payload length + the length of Inner IPv6, Inner UDP)
        hdr.gtp_u.payload_len = meta.payload_len + 48;
    }

    @hidden
    action encapsulate_gtp_u_v4_tcp() {

        // move user's (outer) ipv4 and tcp to inner_ipv4, inner_tcp
        // encapsulate w/ IPv6, UDP, GTP-U
        set_valid_and_copy_ipv4();
        set_valid_and_copy_tcp();
        hdr.tcp.setInvalid();
        set_ipv4(meta.encap_ipv4_dst_addr, meta.encap_ipv4_src_addr);
        set_udp(meta.encap_dst_port, meta.encap_src_port);
        set_gtp_u(meta.encap_teid);
        
        // update ipv4.total_len (payload length + the length of IPv4, UDP, GTP-U, Inner IPv4, Inner TCP)
        hdr.ipv4.total_len = meta.payload_len + 76;

        // update udp.len (payload length + the length of UDP, GTP-U, Inner IPv4, Inner TCP)
        hdr.udp.len = meta.payload_len + 56;

        // update gtp_u.payload_len (payload length + the length of Innter IPv4, Inner TCP)
        hdr.gtp_u.payload_len = meta.payload_len + 40;
    }

    @hidden
    action encapsulate_gtp_u_v6_tcp() {

        // move user's (outer) ipv6 and tcp to inner_ipv6, inner_tcp
        // encapsulate w/ IPv6, UDP, GTP-U
        set_valid_and_copy_ipv6();
        set_valid_and_copy_tcp();
        hdr.tcp.setInvalid();
        set_ipv6(meta.encap_ipv6_dst_addr, meta.encap_ipv6_src_addr);
        set_udp(meta.encap_dst_port, meta.encap_src_port);
        set_gtp_u(meta.encap_teid);

        // update ipv4.total_len (payload length + the length of UDP, GTP-U, Inner IPv6, Inner TCP)
        hdr.ipv6.payload_len = meta.payload_len + 76;

        // update udp.len (payload length + the length of UDP, GTP-U, Inner IPv6, Inner TCP)
        hdr.udp.len = meta.payload_len + 76;

        // update gtp_u.payload_len (payload length + the length of Innter IPv6, Inner TCP)
        hdr.gtp_u.payload_len = meta.payload_len + 60;
    }

    table encapsulate_gtp_u {
        key = {
            hdr.ipv4.isValid() : exact;
            hdr.ipv6.isValid() : exact;
            hdr.udp.isValid()  : exact;
            hdr.tcp.isValid()  : exact;
        }
        actions = {
            encapsulate_gtp_u_v4_udp;
            encapsulate_gtp_u_v6_udp;
            encapsulate_gtp_u_v4_tcp;
            encapsulate_gtp_u_v6_tcp;
            NoAction;
        }
        const entries = {
            (true, false, true, false) : encapsulate_gtp_u_v4_udp();
            (false, true, true, false) : encapsulate_gtp_u_v6_udp();
            (true, false, false, true) : encapsulate_gtp_u_v4_tcp();
            (false, true, false, true) : encapsulate_gtp_u_v6_tcp();
        }
        default_action = NoAction;
    }

    @hidden
    action copy_inner_ipv6_and_set_invalid() {

        hdr.ipv6.setValid();
        hdr.ipv6.version       = hdr.inner_ipv6.version;
        hdr.ipv6.traffic_class = hdr.inner_ipv6.traffic_class;
        hdr.ipv6.flow_label    = hdr.inner_ipv6.flow_label;
        hdr.ipv6.payload_len   = hdr.inner_ipv6.payload_len;
        hdr.ipv6.next_hdr      = hdr.inner_ipv6.next_hdr;
        hdr.ipv6.hop_limit     = hdr.inner_ipv6.hop_limit;
        hdr.ipv6.src_addr      = hdr.inner_ipv6.src_addr;
        hdr.ipv6.dst_addr      = hdr.inner_ipv6.dst_addr;
        hdr.inner_ipv6.setInvalid();
    }

    @hidden
    action copy_inner_ipv4_and_set_invalid() {

        hdr.ipv4.setValid();
        hdr.ipv4.version        = hdr.inner_ipv4.version;
        hdr.ipv4.ihl            = hdr.inner_ipv4.ihl;
        hdr.ipv4.diffserv       = hdr.inner_ipv4.diffserv;
        hdr.ipv4.total_len      = hdr.inner_ipv4.total_len;
        hdr.ipv4.identification = hdr.inner_ipv4.identification;
        hdr.ipv4.flags          = hdr.inner_ipv4.flags;
        hdr.ipv4.flag_offset    = hdr.inner_ipv4.flag_offset;
        hdr.ipv4.ttl            = hdr.inner_ipv4.ttl;
        hdr.ipv4.protocol       = hdr.inner_ipv4.protocol;
        hdr.ipv4.checksum       = hdr.inner_ipv4.checksum;
        hdr.ipv4.src_addr       = hdr.inner_ipv4.src_addr;
        hdr.ipv4.dst_addr       = hdr.inner_ipv4.dst_addr;
        hdr.inner_ipv4.setInvalid();
    }

    @hidden
    action copy_inner_tcp_and_set_invalid() {

        hdr.tcp.setValid();
        hdr.tcp.src_port   = hdr.inner_tcp.src_port;
        hdr.tcp.dst_port   = hdr.inner_tcp.dst_port;
        hdr.tcp.seq_num    = hdr.inner_tcp.seq_num;
        hdr.tcp.ack        = hdr.inner_tcp.ack;
        hdr.tcp.offset     = hdr.inner_tcp.offset;
        hdr.tcp.res        = hdr.inner_tcp.res;
        hdr.tcp.flags      = hdr.inner_tcp.flags;
        hdr.tcp.window     = hdr.inner_tcp.window;
        hdr.tcp.checksum   = hdr.inner_tcp.checksum;
        hdr.tcp.urgent_ptr = hdr.inner_tcp.urgent_ptr;
        hdr.tcp.setInvalid();
    }

    @hidden
    action copy_inner_udp_and_set_invalid() {

        hdr.udp.setValid();
        hdr.udp.src_port = hdr.inner_udp.src_port;
        hdr.udp.dst_port = hdr.inner_udp.dst_port;
        hdr.udp.len      = hdr.inner_udp.len;
        hdr.udp.checksum = hdr.inner_udp.checksum;
        hdr.inner_udp.setInvalid();
    }

    @hidden
    action decapsulate_gtp_u_v4_udp() {

        // hdr.udp.setInvalid(); /* NOTE: skipped because soon after UDP header is instantiated. */
        hdr.gtp_u.setInvalid();
        hdr.gtp_u_option.setInvalid();
        copy_inner_ipv4_and_set_invalid();
        copy_inner_udp_and_set_invalid();
        
    }

    @hidden
    action decapsulate_gtp_u_v6_udp() {

        // hdr.udp.setInvalid(); /* NOTE: skipped because soon after UDP header is instantiated. */
        hdr.gtp_u.setInvalid();
        hdr.gtp_u_option.setInvalid();
        copy_inner_ipv6_and_set_invalid();
        copy_inner_udp_and_set_invalid();
    }

    @hidden
    action decapsulate_gtp_u_v4_tcp() {

        hdr.udp.setInvalid();
        hdr.gtp_u.setInvalid();
        hdr.gtp_u_option.setInvalid();
        copy_inner_ipv4_and_set_invalid();
        copy_inner_tcp_and_set_invalid();
    }

    @hidden
    action decapsulate_gtp_u_v6_tcp() {

        hdr.udp.setInvalid();
        hdr.gtp_u.setInvalid();
        hdr.gtp_u_option.setInvalid();
        copy_inner_ipv6_and_set_invalid();
        copy_inner_tcp_and_set_invalid();
    }

    table decapsulate_gtp_u {
        key = {
            hdr.inner_ipv4.isValid() : exact;
            hdr.inner_ipv6.isValid() : exact;
            hdr.inner_udp.isValid()  : exact;
            hdr.inner_tcp.isValid()  : exact;
        }
        actions = {
            decapsulate_gtp_u_v4_udp;
            decapsulate_gtp_u_v6_udp;
            decapsulate_gtp_u_v4_tcp;
            decapsulate_gtp_u_v6_tcp;
            NoAction;
        }
        const entries = {
            (true, false, true, false) : decapsulate_gtp_u_v4_udp();
            (false, true, true, false) : decapsulate_gtp_u_v6_udp();
            (true, false, false, true) : decapsulate_gtp_u_v4_tcp();
            (false, true, false, true) : decapsulate_gtp_u_v6_tcp();
        }
        default_action = NoAction;
    }

    apply {

        // encaps or decaps based-on flags.
        if (meta.encapsulate_gtp_u_flag) {
            encapsulate_gtp_u.apply();
        } else if (meta.decapsulate_gtp_u_flag) {
            decapsulate_gtp_u.apply();
        }
    }
}