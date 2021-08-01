package main

import (
	"log"
	"time"
	"upf/myutils"

	v1 "github.com/p4lang/p4runtime/go/p4/v1"
	"google.golang.org/grpc"
)

func controller(addr string, port_num string, name string) {

	var cp myutils.ControlPlaneClient

	var (
		deviceid    uint64 = 0
		electionid         = &v1.Uint128{High: 0, Low: 1}
		p4infoPath  string = "./p4info.txt"
		devconfPath string = "./main.json"
		runconfPath string = "./config-" + name + ".json"
		err         error
	)

	/* コントロールプレーンを初期化 */
	cp.DeviceId = deviceid
	cp.ElectionId = electionid

	err = cp.InitConfig(p4infoPath, devconfPath, runconfPath)
	if err != nil {
		log.Fatal("ERROR: failed to initialize the configurations. ", err)
	}
	log.Printf("INFO[%s]: P4Info/ForwardingPipelineConfig/EntryHelper is successfully loaded.", name)

	/* gRPC connection 確立 */
	conn, err := grpc.Dial(addr+":"+port_num, grpc.WithInsecure())
	if err != nil {
		log.Fatal("ERROR: failed to establish gRPC connection. ", err)
	}
	defer conn.Close()

	/* P4runtime Client インスタンス生成 */
	cp.Client = v1.NewP4RuntimeClient(conn)

	/* StreamChanel 確立 */
	err = cp.InitChannel()
	if err != nil {
		log.Fatal("ERROR: failed to establish StreamChannel. ", err)
	}
	log.Printf("INFO[%s]: StreamChannel is successfully established.", name)

	/* MasterArbitrationUpdate */
	_, err = cp.MasterArbitrationUpdate()
	if err != nil {
		log.Fatal("ERROR: failed to get the arbitration. ", err)
	}
	log.Printf("INFO[%s]: MasterArbitrationUpdate successfully done.", name)

	/* SetForwardingPipelineConfig */
	_, err = cp.SetForwardingPipelineConfig("VERIFY_AND_COMMIT")
	if err != nil {
		log.Fatal("ERROR: failed to set forwarding pipeline config. ", err)
	}
	log.Printf("INFO[%s]: SetForwardingPipelineConfig successfully done.", name)

	/* WriteTableEntry */
	updates := []*v1.Update{}
	need_to_write := false
	for _, h := range cp.Entries.TableEntries {
		tent, err := h.BuildTableEntry(cp.P4Info)
		if err != nil {
			log.Fatal("ERROR: failed to build table entry. ", err)
		}
		update := myutils.NewUpdate("INSERT", &v1.Entity{Entity: tent})
		updates = append(updates, update)
		need_to_write = true
	}
	if need_to_write {
		_, err = cp.SendWriteRequest(updates, "CONTINUE_ON_ERROR")
		if err != nil {
			log.Fatal("ERROR: failed to write entries. ", err)
		}
		log.Printf("INFO[%s]: Table Entries are successfully written.", name)
	}

	/* Write MulticastGroupEntry */
	updates = []*v1.Update{}
	need_to_write = false
	for _, h := range cp.Entries.MulticastGroupEntries {
		ment, err := h.BuildMulticastGroupEntry()
		if err != nil {
			log.Fatal("ERROR: failed to build multicast group entry. ", err)
		}
		update := myutils.NewUpdate("INSERT", &v1.Entity{Entity: ment})
		updates = append(updates, update)
		need_to_write = true

	}
	if need_to_write {
		_, err = cp.SendWriteRequest(updates, "CONTINUE_ON_ERROR")
		if err != nil {
			log.Fatal("ERROR: failed to write entries. ", err)
		}
		log.Printf("INFO[%s]: MulticastGroup Entries are successfully written.", name)
	}
}

func main() {

	/* Initialize each device */
	go controller("127.0.0.1", "50051", "I-UPF")
	time.Sleep(time.Second * 3)

	go controller("127.0.0.1", "50052", "A-UPF")
	time.Sleep(time.Second * 3)
}
