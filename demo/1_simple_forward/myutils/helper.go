package myutils

import (
	"bytes"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"net"
	"strconv"
	"strings"

	config_v1 "github.com/p4lang/p4runtime/go/p4/config/v1"
	v1 "github.com/p4lang/p4runtime/go/p4/v1"
)

// EntryHelper is helper for Entry
type EntryHelper struct {
	ExternEntries         []*ExternEntryHelper         `json:"extern_entries"`
	TableEntries          []*TableEntryHelper          `json:"table_entries"`
	MeterEntries          []*MeterEntryHelper          `json:"meter_entries"`
	CounterEntries        []*CounterEntryHelper        `json:"counter_entries"`
	MulticastGroupEntries []*MulticastGroupEntryHelper `json:"multicast_group_entries"`
	RegisterEntries       []*RegisterEntryHelper       `json:"register_entries"`
	DigestEntries         []*DigestEntryHelper         `json:"digest_entries"`
}

// ExternEntryHelper is helper for ExternEntry.
type ExternEntryHelper struct {
	/* TODO */
	dummy int
}

// TableEntryHelper is helper for TableEntry.
type TableEntryHelper struct {
	Table         string                 `json:"table"`
	Match         map[string]interface{} `json:"match"`
	Action_Name   string                 `json:"action_name"`
	Action_Params map[string]interface{} `json:"action_params"`
	Priority      int32                  `json:"priority"`
}

// MeterEntryHelper is helper for MeterEntry.
type MeterEntryHelper struct {
	/* TODO */
	dummy int
}

// CounterEntryHelper is helper for CounterEntry.
type CounterEntryHelper struct {
	Counter string `json:"counter"`
	Index   int64  `json:"index"`
}

// MulticastGroupEntryHelper is helper for MulticastGroupEntry
type MulticastGroupEntryHelper struct {
	Multicast_Group_ID uint32           `json:"multicast_group_id"`
	Replicas           []*ReplicaHelper `json:"replicas"`
}

// ReplicaHelper is helper for Replica.
type ReplicaHelper struct {
	Egress_port uint32 `json:"egress_port"`
	Instance    uint32 `json:"instance"`
}

// RegisterEntryHepler is hepler for RegisterEntry.
type RegisterEntryHelper struct {
	/* TODO */
	dummy int
}

// DigestEntryHelper is helper for DigestEntry.
type DigestEntryHelper struct {
	/* TODO */
	dummy int
}

// BuildTableEntry creates TableEntry in the form of *v1.Entity_TableEntry.
func (h *TableEntryHelper) BuildTableEntry(p *config_v1.P4Info) (*v1.Entity_TableEntry, error) {

	// find "Table" instance that matches h.Table (table name)
	var table *config_v1.Table
	var flag bool

	flag = false
	for _, t := range p.Tables {
		if (t.Preamble.Name == h.Table) || (t.Preamble.Alias == h.Table) {
			table = t
			flag = true
			break
		}
	}
	if flag == false {
		err := fmt.Errorf("cannot find table instance")
		return nil, err
	}

	// get "FieldMatch" instances that the table have.
	var fieldmatch []*v1.FieldMatch
	var tcam_flag bool = false

	for key, value := range h.Match {

		// find "MatchField" instance that matches
		match := &config_v1.MatchField{}
		flag = false
		for _, m := range table.MatchFields {
			if m.Name == key {
				match = m
				flag = true
				break
			}
		}
		if flag != true {
			err := fmt.Errorf("cannot find match field instance")
			return nil, err
		}

		// get FieldMatch instance depending on match-type.
		switch match.GetMatchType().String() {

		case "EXACT":
			v, _, err := GetParam(value, match.Bitwidth, "EXACT")
			if err != nil {
				return nil, err
			}
			fm := &v1.FieldMatch{
				FieldId: match.Id,
				FieldMatchType: &v1.FieldMatch_Exact_{
					Exact: &v1.FieldMatch_Exact{
						Value: v,
					},
				},
			}
			fieldmatch = append(fieldmatch, fm)

		case "LPM":
			v, p, err := GetParam(value, match.Bitwidth, "LPM")
			if err != nil {
				return nil, err
			}
			plen := p.(int32)
			fm := &v1.FieldMatch{
				FieldId: match.Id,
				FieldMatchType: &v1.FieldMatch_Lpm{
					Lpm: &v1.FieldMatch_LPM{
						Value:     v,
						PrefixLen: plen,
					},
				},
			}
			fieldmatch = append(fieldmatch, fm)

		case "TERNARY":
			tcam_flag = true
			v, m, err := GetParam(value, match.Bitwidth, "TERNARY")
			if err != nil {
				return nil, err
			}
			mask := m.([]byte)
			zeros := make([]byte, len(mask))
			if !bytes.Equal(mask, zeros) {
				fm := &v1.FieldMatch{
					FieldId: match.Id,
					FieldMatchType: &v1.FieldMatch_Ternary_{
						Ternary: &v1.FieldMatch_Ternary{
							Value: v,
							Mask:  mask,
						},
					},
				}
				fieldmatch = append(fieldmatch, fm)
			}

		case "RANGE":
			/* TODO */
			/*
				fm := &v1.FieldMatch{
					FieldMatchType: &v1.FieldMatch_Range_{},
				}
				fieldmatch = append(fieldmatch, fm)
			*/
			err := fmt.Errorf("not implemented yet...")
			return nil, err

		default:
			/* TODO */
			/*
				fm := &v1.FieldMatch{
					FieldMatchType: &v1.FieldMatch_Other{},
				}
				fieldmatch = append(fieldmatch, fm)
			*/
			err := fmt.Errorf("not implemented yet...")
			return nil, err
		}
	}

	// find "Action" instance that matches h.Action_Name.
	var action *config_v1.Action
	flag = false
	for _, a := range p.Actions {
		if (a.Preamble.Name == h.Action_Name) || (a.Preamble.Alias == h.Action_Name) {
			action = a
			flag = true
			break
		}
	}
	if flag == false {
		err := fmt.Errorf("cannot find action")
		return nil, err
	}

	// get "Action_Param" instances that the action have.
	var action_params []*v1.Action_Param
	for _, param := range action.Params {
		flag = false
		for key, value := range h.Action_Params {
			if key == param.Name {
				p, _, err := GetParam(value, param.Bitwidth, "EXACT")
				if err != nil {
					return nil, err
				}
				action_param := &v1.Action_Param{
					ParamId: param.Id,
					Value:   p,
				}
				action_params = append(action_params, action_param)
				flag = true
				break
			}
		}
		if flag == false {
			err := fmt.Errorf("cannot find action parameters")
			return nil, err
		}
	}

	// build TableEntry
	var entityTableEntry *v1.Entity_TableEntry
	if tcam_flag {
		entityTableEntry = &v1.Entity_TableEntry{
			TableEntry: &v1.TableEntry{
				TableId:  table.Preamble.Id,
				Match:    fieldmatch,
				Priority: h.Priority,
				Action: &v1.TableAction{
					Type: &v1.TableAction_Action{
						Action: &v1.Action{
							ActionId: action.Preamble.Id,
							Params:   action_params,
						},
					},
				},
			},
		}
	} else {
		entityTableEntry = &v1.Entity_TableEntry{
			TableEntry: &v1.TableEntry{
				TableId: table.Preamble.Id,
				Match:   fieldmatch,
				Action: &v1.TableAction{
					Type: &v1.TableAction_Action{
						Action: &v1.Action{
							ActionId: action.Preamble.Id,
							Params:   action_params,
						},
					},
				},
			},
		}
	}
	return entityTableEntry, nil
}

// GetParam gets action parameter in []byte
func GetParam(value interface{}, width int32, type_ string) ([]byte, interface{}, error) {

	// calculate the upper limit of the value in bytes.
	var upper int
	if width%8 == 0 {
		upper = int(width / 8)
	} else {
		upper = int(width/8) + 1
	}

	// parse "value" and extract "plefix length" (for LPM) or "mask" (for TERNARY)
	keys := make([]interface{}, 2)
	var plen_or_mask interface{}
	if type_ == "LPM" || type_ == "TERNARY" {
		for idx, val := range strings.Split(value.(string), "/") {
			keys[idx] = val
		}
		switch type_ {

		case "LPM":
			// translate keys[1] from string to int32, then substitute keys[1] to plen_or_mask
			p, err := strconv.ParseInt(keys[1].(string), 10, 32)
			if err != nil {

				return nil, plen_or_mask, err
			}
			plen_or_mask = int32(p)

		case "TERNARY":
			// translate keys[1] from string to []byte, then substitute keys[1] to plen_or_mask
			m, err := hex.DecodeString(keys[1].(string))
			if err != nil {
				return nil, plen_or_mask, err
			}
			plen_or_mask = m
		}
	} else {
		keys[0] = value
	}

	// translate keys[0] to float64 if it is numeric valuable
	switch keys[0].(type) {
	case string:
		if keys[0].(string)[:1] == "_" {
			keys[0] = strings.Replace(keys[0].(string), "_", "", 1)
			k, err := strconv.ParseFloat(keys[0].(string), 64)
			if err != nil {
				return nil, plen_or_mask, err
			}
			keys[0] = k
		}
	default:
		/* nothing to do */
	}

	// get param. depending on the type of the value.
	var param []byte
	switch keys[0].(type) {

	case float64:
		param = make([]byte, 8)
		binary.BigEndian.PutUint64(param, uint64(keys[0].(float64)))

	case string:
		if width == 48 {
			var err error
			param, err = net.ParseMAC(keys[0].(string))
			if err != nil {
				return nil, plen_or_mask, err
			}
		} else {
			param = net.ParseIP(keys[0].(string))
			if param == nil {
				err := fmt.Errorf("cannot parse %s", keys[0].(string))
				return nil, plen_or_mask, err
			}
		}

	default:
		/* TODO */
		err := fmt.Errorf("not implemented yet...")
		return nil, plen_or_mask, err
	}

	return param[(len(param) - upper):], plen_or_mask, nil
}

// BuildMulticastGroupEntry creates MulticastGroupEntry in the form of *v1.Entity_PacketRelicationEngineEntry.
func (h *MulticastGroupEntryHelper) BuildMulticastGroupEntry() (*v1.Entity_PacketReplicationEngineEntry, error) {

	// create "Replica" instances from the helper.
	replicas := make([]*v1.Replica, 0)
	for _, r := range h.Replicas {
		replicas = append(replicas, &v1.Replica{EgressPort: r.Egress_port, Instance: r.Instance})
	}

	entity_PacketReplicationEngineEntry := &v1.Entity_PacketReplicationEngineEntry{
		PacketReplicationEngineEntry: &v1.PacketReplicationEngineEntry{
			Type: &v1.PacketReplicationEngineEntry_MulticastGroupEntry{
				MulticastGroupEntry: &v1.MulticastGroupEntry{
					MulticastGroupId: h.Multicast_Group_ID,
					Replicas:         replicas,
				},
			},
		},
	}
	return entity_PacketReplicationEngineEntry, nil
}

// BuildCounterEntry creates CounterEntry in the form of *v1.Entity_CounterEntry
func (h *CounterEntryHelper) BuildCounterEntry(p *config_v1.P4Info) (*v1.Entity_CounterEntry, error) {

	// find "Counter" instance that matches h.Counter (counter name).
	var flag bool
	var counter *config_v1.Counter
	flag = false
	for _, c := range p.Counters {
		if (c.Preamble.Name == h.Counter) || (c.Preamble.Alias == h.Counter) {
			counter = c
			flag = true
			break
		}
	}
	if flag == false {
		err := fmt.Errorf("cannot find counter instance")
		return nil, err
	}

	entity_counterentry := &v1.Entity_CounterEntry{
		CounterEntry: &v1.CounterEntry{
			CounterId: counter.Preamble.Id,
			Index: &v1.Index{
				Index: h.Index,
			},
		},
	}
	return entity_counterentry, nil
}

// GetCounterSpec_Unit gets the unit of "counter" instance.
func GetCounterSpec_Unit(counter string, p *config_v1.P4Info, direct bool) (config_v1.CounterSpec_Unit, error) {

	var flag bool
	var cnt interface{}

	if direct {
		flag = false
		for _, c := range p.DirectCounters {
			if (c.Preamble.Name == counter) || (c.Preamble.Alias == counter) {
				cnt = c
				flag = true
				break
			}
		}
	} else {
		flag = false
		for _, c := range p.Counters {
			if (c.Preamble.Name == counter) || (c.Preamble.Alias == counter) {
				cnt = c
				flag = true
				break
			}
		}
	}

	if flag == false {
		err := fmt.Errorf("cannot find counter instance")
		return config_v1.CounterSpec_UNSPECIFIED, err
	}

	switch cnt.(type) {
	case *config_v1.DirectCounter:
		return cnt.(*config_v1.DirectCounter).Spec.Unit, nil
	case *config_v1.Counter:
		return cnt.(*config_v1.Counter).Spec.Unit, nil
	default:
		err := fmt.Errorf("unknown type.")
		return config_v1.CounterSpec_UNSPECIFIED, err
	}
}

// NewUpdate creates new "Update" instance.
func NewUpdate(updateType string, entity *v1.Entity) *v1.Update {

	switch updateType {
	case "INSERT":
		update := v1.Update{
			Type:   v1.Update_INSERT,
			Entity: entity}
		return &update

	case "MODIFY":
		update := v1.Update{
			Type:   v1.Update_MODIFY,
			Entity: entity}
		return &update

	case "DELETE":
		update := v1.Update{
			Type:   v1.Update_DELETE,
			Entity: entity}
		return &update

	default:
		update := v1.Update{
			Type:   v1.Update_UNSPECIFIED,
			Entity: entity}
		return &update
	}
}
