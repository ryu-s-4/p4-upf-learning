/* MAR implementation */

#include <v1model.p4>

control MARProcedure(inout headers_t hdr,
                     inout metadata_t meta,
                     inout standard_metadata_t std_meta)
{

    /* TODO: implement MAR table/actions */
    table mar_execute {
        key = {
            meta.rule_id : exact;
        }
        actions = {
            NoAction;
        }
        default_action = NoAction;
        size = MAX_MAR_NUM;
    }

    apply {
        
        // execute MAR
        mar_execute.apply();
    }
}