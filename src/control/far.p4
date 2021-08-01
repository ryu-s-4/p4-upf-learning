/* FAR implementation */

#include <v1model.p4>

control FAR_Procedure(inout headers_t hdr,
                      inout metadata_t meta,
                      inout standard_metadata_t std_meta)
{

    action far_drop() {
        mark_to_drop(std_meta);
    }

    action far_forward(bit<9> port, mac_addr_t dst, mac_addr_t src) {

        // get info. for forwarding.
        meta.port = port;
        meta.dst_mac = dst;
        meta.src_mac = src;

        // set flag to recognize "far_forward_v6" is executed.
        meta.far_forward_flag = true;
    }

    action far_duplicate(bit<16> mcast_grp) {

        // set multicast group for duplication
        std_meta.mcast_grp = mcast_grp;
    }

    action far_buffering() {
        /* TODO: forward the packet to buffering mechanism */
    }

    action far_notification_cp() {
        /* TODO: implement notification to control plane */
    }

    action far_dfrt_with_forward() {
        /* TODO: implement dupulication for reduntant transmission with forwarding. */
    }

    action far_eliminate_for_rt() {
        /* TODO: implement elimination of reduntantly transmitted packet */
    }

    action far_buffered_packet_notification() {
        /* TODO: implement bufferd downlink packet notification */
    }

    action far_discarded_packet_notification() {
        /* TODO: implement discarded downlink packet notification */
    }

    // following condition SHOULD be met (refer to TS29.244 v17.1.0 sec. 8.2.26)
    //   - The NOCP flag and BDPN flag may only be set if the BUFF flag is set.
    //   - The DUPL flag may be set with any of the DROP, FORW, BUFF and NOCP flags.
    //   - The DFRN flag may only be set if the FORW flag is set.
    //   - The EDRT flag may be set if the FORW flag is set.
    //   - The DDPN flag may be set with any of the DROP and BUFF flags.
    table far_execute {
        key = {
            meta.far_id        : exact;
            meta.far_flag      : exact;
        }
        actions = {
            far_drop;
            far_forward;
            far_duplicate;
            far_buffering;
            far_notification_cp;
            far_dfrt_with_forward;
            far_eliminate_for_rt;
            far_buffered_packet_notification;
            far_discarded_packet_notification;
            NoAction;
        }
        default_action = NoAction;
        size = MAX_FAR_EXEC_NUM;
    }

    @hidden
    action forward_v6_execute() {

        // set forwarding port and modifiy ethernet header.
        std_meta.egress_spec = meta.port;
        hdr.ethernet.dst_addr = meta.dst_mac;
        hdr.ethernet.src_addr = meta.src_mac;

        // calc. Hop Limit
        hdr.ipv6.hop_limit = hdr.ipv6.hop_limit - 1;
        meta.ttl = hdr.ipv6.hop_limit - 1;
    }

    @hidden
    action forward_v4_execute() {

        // set forwarding port and modifiy ethernet header.
        std_meta.egress_spec = meta.port;
        hdr.ethernet.dst_addr = meta.dst_mac;
        hdr.ethernet.src_addr = meta.src_mac;

        // calc. TTL
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
        meta.ttl = hdr.ipv4.ttl - 1;
    }

    @hidden
    table forward_execute {
        key = {
            meta.pdu_sess_type       : exact;
            hdr.ipv6.isValid()       : exact;
            hdr.ipv4.isValid()       : exact;
        }
        actions = {
            forward_v6_execute;
            forward_v4_execute;
            NoAction;
        }
        default_action = NoAction;
        const entries = {
            (PDN_SESS_TYPE_v6, true, false) : forward_v6_execute();
            (PDN_SESS_TYPE_v4, false, true) : forward_v4_execute();
        }
    }

    apply {

        // execute FAR
        far_execute.apply();

        // forwarding procedure (if necessary)
        if (meta.far_forward_flag) {
            if (!forward_execute.apply().hit) {
                /* TODO: it seems that executed FAR and PDU_TYPE are mis-matched. SHOULD be dropped */
            }
            if (meta.ttl <= 0) {
                /* TODO: TTL or Hop limit has been expired. Send ICMP error and drop the packet. */
            }
        }
    }
}