/* QER implementation */

#include <v1model.p4>

control QERProcedure(inout headers_t hdr,
                     inout metadata_t meta,
                     inout standard_metadata_t std_meta)
{

    /* TODO: implement QER table/actions */
    table qer_execute {
        key = {
            meta.rule_id : exact;
        }
        actions = {
            NoAction;
        }
        default_action = NoAction;
        size = MAX_QER_NUM;
    }

    apply {
        
        // execute QER
        qer_execute.apply();
    }
}