/* BAR implementation */

#include <v1model.p4>
#include "headers.p4"

control BARProcedure(inout headers_t hdr,
                     inout metadata_t meta,
                     inout standard_metadata_t std_meta)
{

    /* TODO: implement BAR actions */
    table bar_execute {
        key = {
            meta.rule_id : exact;
        }
        actions = {
            NoAction;
        }
        default_action = NoAction;
        size = MAX_BAR_NUM;
    }

    apply {
        
        // execute BAR
        bar_execute.apply();
    }
}