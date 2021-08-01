/* header and metadata definition */

#define MAX_PDR_NUM      1024
#define MAX_PDR_NUM      1024
#define MAX_FAR_NUM      1024
#define MAX_FAR_EXEC_NUM 1024
#define MAX_QER_NUM      1024
#define MAX_BAR_NUM      1024
#define MAX_MAR_NUM      1024
#define MAX_SRR_NUM      1024
#define MAX_URR_NUM      1024

typedef bit<48>  mac_addr_t;
typedef bit<32>  ipv4_addr_t;
typedef bit<128> ipv6_addr_t;

// Rule ID contained in PDR ID IE (refer to TS29.244 v17.1.0 figure 8.2.36-1)
typedef bit<16> rule_id_t;

// FAR ID contained in FAR ID IE (refer to TS29.244 v17.1.0 figure 8.2.74-1)
typedef bit<32> far_id_t;

typedef bit<16> ether_type_t;
const ether_type_t ETYPE_IPv4 = 16w0x0800;
const ether_type_t ETYPE_IPv6 = 16w0x86dd;

typedef bit<8> protocol_t;
const protocol_t PROTO_TCP = 6;
const protocol_t PROTO_UDP = 17;

typedef bit<16> udp_port_t;
const udp_port_t UDP_PORT_GTPC = 2123;
const udp_port_t UDP_PORT_GTPU = 2152;

// Action flags contained in Apply Action IE (refer to TS29.244 v17.1.0 figure 8.2.26-1) 
typedef bit<16> far_flag_t;
const far_flag_t FAR_FLAG_DROP = 0x0001; // 0000000000000001
const far_flag_t FAR_FLAG_FOWD = 0x0002; // 0000000000000010
const far_flag_t FAR_FLAG_BUFF = 0x0004; // 0000000000000100
const far_flag_t FAR_FLAG_NOCP = 0x0008; // 0000000000001000
const far_flag_t FAR_FLAG_DUPL = 0x0010; // 0000000000010000
const far_flag_t FAR_FLAG_DFRT = 0x0080; // 0000000010000000
const far_flag_t FAR_FLAG_EDRT = 0x0100; // 0000000100000000
const far_flag_t FAR_FLAG_BDPN = 0x0200; // 0000001000000000
const far_flag_t FAR_FLAG_DDPN = 0x0400; // 0000010000000000

typedef bit<4> pdu_sess_type_t;
const pdu_sess_type_t PDN_SESS_TYPE_v6 = 0x6;
const pdu_sess_type_t PDN_SESS_TYPE_v4 = 0x4;
// const pdu_sess_type_t PDN_SESS_TYPE_ether = 0x2;

// GTPv1 Message Type (refer to TS 29.281 v17.0.0 table 6.1-1)
typedef bit<8> gtpv1_msg_type_t;
const gtpv1_msg_type_t GTPv1_MSG_TYP_ECH_REQ = 1;   // Echo Request
const gtpv1_msg_type_t GTPv1_MSG_TYP_ECH_RES = 2;   // Echo Response
const gtpv1_msg_type_t GTPv1_MSG_TYP_ERR_IND = 26;  // Error Indication
const gtpv1_msg_type_t GTPv1_MSG_TYP_SPT_EXT = 31;  // Supported Extention Headers Notification
const gtpv1_msg_type_t GTPv1_MSG_TYP_TNL_STS = 253; // Tunnel Status
const gtpv1_msg_type_t GTPv1_MSG_TYP_END_MRK = 254; // End Marker
const gtpv1_msg_type_t GTPv1_MSG_TYP_G_PDU   = 255; // G-PDU

const bit<1> _TRUE  = 1;
const bit<1> _FALSE = 0;

header ethernet_h {
    mac_addr_t   dst_addr;
    mac_addr_t   src_addr;
    ether_type_t ether_type;
}

header ipv4_h {
    bit<4>      version;
    bit<4>      ihl;
    bit<8>      diffserv;
    bit<16>     total_len;
    bit<16>     identification;
    bit<3>      flags;
    bit<13>     flag_offset;
    bit<8>      ttl;
    bit<8>      protocol;
    bit<16>     checksum;
    ipv4_addr_t src_addr;
    ipv4_addr_t dst_addr;
}

header ipv6_h {
    bit<4>      version;
    bit<8>      traffic_class;
    bit<20>     flow_label;
    bit<16>     payload_len;
    bit<8>      next_hdr;
    bit<8>      hop_limit;
    ipv6_addr_t src_addr;
    ipv6_addr_t dst_addr;
}

header tcp_h {
    bit<16> src_port;
    bit<16> dst_port;
    bit<32> seq_num;
    bit<32> ack;
    bit<4>  offset;
    bit<4>  res;
    bit<8>  flags;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgent_ptr;
}

header udp_h {
    udp_port_t src_port;
    udp_port_t dst_port;
    bit<16>    len;
    bit<16>    checksum;
}

// GTP-U header (refer to TS 29.281 v17.0.0 figure 5.1-1)
header gtp_u_h {
    bit<3>           version;     // version (must be 1 for GTPv1)
    bit<1>           pt;          // protocol type
    bit<1>           rsrv;        // reserved
    bit<1>           e;           // extension header flag
    bit<1>           s;           // sequence number flag
    bit<1>           pn;          // N-PDU number flag
    gtpv1_msg_type_t msg_type;    // message type
    bit<16>          payload_len; // payload length
    bit<32>          teid;        // Tunnel endpoint id
}

// GTP-U option header (refer to TS 29.281 v17.0.0 figure 5.1-1)
// SHALL be present if and only if any one or more of the S, PN and E flags are set.  
header gtp_u_option_h {
    bit<16> seq_num;      // sequence number
    bit<8>  n_pdu;        // N-PDU number
    bit<8>  next_ext_hdr; // next extention header type
}

struct headers_t {
    ethernet_h     ethernet;
    ipv4_h         ipv4;
    ipv6_h         ipv6;
    tcp_h          tcp;
    udp_h          udp;
    gtp_u_h        gtp_u;
    gtp_u_option_h gtp_u_option;
    // NOTE: this implementation enables inner ipv4/ipv6 readable.
    //       this is because of making the exposed ipv4/ipv6 after decapsulation usable for forwarding.
    //       (as described later soon we need to parse innner udp/tcp, so inner ipv4/ipv6 also need to be parsed)
    ipv4_h         inner_ipv4;
    ipv6_h         inner_ipv6;
    // NOTE: this implementation also parses inner udp/tcp headers.
    //       this is because we need to calc. new checksum w/ previous checksum (contained in inner udp/tcp)
    //       when encapsulating in-coming packet with UDP + GTP-U headers.
    tcp_h          inner_tcp;
    udp_h          inner_udp;
}

struct metadata_t {

    rule_id_t       rule_id;
    far_id_t        far_id;
    pdu_sess_type_t pdu_sess_type;

    bool encapsulate_gtp_u_flag;
    bool decapsulate_gtp_u_flag;

    bit<16> prev_checksum;
    bool need_checksum_calc_v4;
    bool need_checksum_calc_udp;
    
    bit<16> far_flag;
    bool far_forward_flag;
    bool far_forward_v6_flag;
    bool far_forward_v4_flag;

    ipv4_addr_t encap_ipv4_dst_addr;
    ipv4_addr_t encap_ipv4_src_addr;
    ipv6_addr_t encap_ipv6_dst_addr;
    ipv6_addr_t encap_ipv6_src_addr;
    udp_port_t  encap_dst_port;
    udp_port_t  encap_src_port;
    bit<32>     encap_teid;

    bit<9>     port;
    mac_addr_t dst_mac;
    mac_addr_t src_mac;
    bit<8>     ttl;
    bit<16>    payload_len;

    bit<32>    teid;
}

