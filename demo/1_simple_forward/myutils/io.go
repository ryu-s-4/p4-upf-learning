package myutils

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"

	"github.com/golang/protobuf/proto"
	config_v1 "github.com/p4lang/p4runtime/go/p4/config/v1"
	v1 "github.com/p4lang/p4runtime/go/p4/v1"
)

// ControlPlaneClient ...
type ControlPlaneClient struct {
	DeviceId   uint64
	RoleId     uint64
	ElectionId *v1.Uint128
	P4Info     *config_v1.P4Info
	Config     *v1.ForwardingPipelineConfig
	Entries    *EntryHelper
	Client     v1.P4RuntimeClient
	Channel    v1.P4Runtime_StreamChannelClient
}

// InitConfig initializes P4Info / ForwardingPipelineConfig / EntryHelper for the ControlPlaneClient.
func (cp *ControlPlaneClient) InitConfig(p4infoPath string, devconfPath string, runconfPath string) error {

	// P4Info
	cp.P4Info = &config_v1.P4Info{}
	p4infoBytes, err := ioutil.ReadFile(p4infoPath)
	if err != nil {
		return err
	}
	err = proto.UnmarshalText(string(p4infoBytes), cp.P4Info)
	if err != nil {
		return err
	}

	// ForwardingPipelineConfig
	devconf, err := ioutil.ReadFile(devconfPath)
	if err != nil {
		return err
	}
	cp.Config = &v1.ForwardingPipelineConfig{
		P4Info:         cp.P4Info,
		P4DeviceConfig: devconf,
	}

	// EntryHelper
	cp.Entries = &EntryHelper{}
	runtime, err := ioutil.ReadFile(runconfPath)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(runtime, cp.Entries); err != nil {
		return err
	}

	return nil
}

// InitChannel ...
func (cp *ControlPlaneClient) InitChannel() error {

	if cp.Client != nil {
		ch, err := cp.Client.StreamChannel(context.TODO())
		if err != nil {
			return err
		}
		cp.Channel = ch
		return nil
	} else {
		return fmt.Errorf("P4RuntimeClient is NOT created")
	}
}

// MasterArbitrationUpdate gets arbitration for the master
func (cp *ControlPlaneClient) MasterArbitrationUpdate() (*v1.MasterArbitrationUpdate, error) {

	request := v1.StreamMessageRequest{
		Update: &v1.StreamMessageRequest_Arbitration{
			Arbitration: &v1.MasterArbitrationUpdate{
				DeviceId:   cp.DeviceId,
				ElectionId: cp.ElectionId,
			},
		},
	}

	err := cp.Channel.Send(&request)
	if err != nil {
		return nil, err
	}

	response, err := cp.Channel.Recv()
	if err != nil {
		return nil, err
	}

	updateResponse := response.GetUpdate()
	switch updateResponse.(type) {

	case *v1.StreamMessageResponse_Arbitration:
		arbitration := response.GetArbitration()
		return arbitration, nil
	}

	/* unknown update response type is received. */
	return nil, fmt.Errorf("unknown update response type")
}

// SetForwardingPipelineConfig sets the user defined configuration to the data plane.
func (cp *ControlPlaneClient) SetForwardingPipelineConfig(actionType string) (*v1.SetForwardingPipelineConfigResponse, error) {

	var action v1.SetForwardingPipelineConfigRequest_Action
	switch actionType {
	case "VERIFY":
		action = v1.SetForwardingPipelineConfigRequest_VERIFY
	case "VERIFY_AND_SAVE":
		action = v1.SetForwardingPipelineConfigRequest_VERIFY_AND_SAVE
	case "VERIFY_AND_COMMIT":
		action = v1.SetForwardingPipelineConfigRequest_VERIFY_AND_COMMIT
	case "COMMIT":
		action = v1.SetForwardingPipelineConfigRequest_COMMIT
	case "RECONCILE_AND_COMMIT":
		action = v1.SetForwardingPipelineConfigRequest_RECONCILE_AND_COMMIT
	default:
		action = v1.SetForwardingPipelineConfigRequest_UNSPECIFIED
	}

	request := v1.SetForwardingPipelineConfigRequest{
		DeviceId:   cp.DeviceId,
		ElectionId: cp.ElectionId,
		Action:     action,
		Config:     cp.Config}

	response, err := cp.Client.SetForwardingPipelineConfig(context.TODO(), &request)
	if err != nil {
		return nil, err
	}
	return response, nil
}

// SendWriteRequest sends write request to the data plane.
func (cp *ControlPlaneClient) SendWriteRequest(updates []*v1.Update, atomisityType string) (*v1.WriteResponse, error) {

	var atomisity v1.WriteRequest_Atomicity
	switch atomisityType {
	case "CONTINUE_ON_ERROR":
		atomisity = v1.WriteRequest_CONTINUE_ON_ERROR
	case "ROLLBACK_ON_ERROR": // OPTIONAL
		atomisity = v1.WriteRequest_ROLLBACK_ON_ERROR
	case "DATAPLANE_ATOMIC": // OPTIONAL
		atomisity = v1.WriteRequest_DATAPLANE_ATOMIC
	default:
		atomisity = v1.WriteRequest_CONTINUE_ON_ERROR
	}

	request := v1.WriteRequest{
		DeviceId:   cp.DeviceId,
		ElectionId: cp.ElectionId,
		Updates:    updates,
		Atomicity:  atomisity,
	}

	response, err := cp.Client.Write(context.TODO(), &request)
	if err != nil {
		return nil, err
	}
	return response, nil
}

// CreateReadClient creates New ReadClient.
func (cp *ControlPlaneClient) CreateReadClient(entities []*v1.Entity) (v1.P4Runtime_ReadClient, error) {

	request := v1.ReadRequest{
		DeviceId: cp.DeviceId,
		Entities: entities,
	}

	rclient, err := cp.Client.Read(context.TODO(), &request)
	if err != nil {
		return nil, err
	}
	return rclient, nil
}
