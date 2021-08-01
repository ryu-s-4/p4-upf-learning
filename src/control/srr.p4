/* SRR implementation */

#include <v1model.p4>

control SRRProcedure(inout headers_t hdr,
                     inout metadata_t meta,
                     inout standard_metadata_t std_meta)
{

    /* TODO: implement SRR table/actions */
    table srr_execute {
        key = {
            meta.rule_id : exact;
        }
        actions = {
            NoAction;
        }
        default_action = NoAction;
        size = MAX_SRR_NUM;
    }

    apply {
        
        // execute SRR
        srr_execute.apply();
    }
}