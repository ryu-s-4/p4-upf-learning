/* URR implementation */
/* URR implementation */

#include <v1model.p4>

control URRProcedure(inout headers_t hdr,
                     inout metadata_t meta,
                     inout standard_metadata_t std_meta)
{

    /* TODO: implement URR table/actions */
    table urr {
        key = {
            meta.rule_id : exact;
        }
        actions = {
            NoAction;
        }
        default_action = NoAction;
        size = MAX_URR_NUM;
    }

    apply {
        
        // try to apply URR
        if (urr.apply().hit) {
            /* TODO: implement URR procedure */
        }
    }
}