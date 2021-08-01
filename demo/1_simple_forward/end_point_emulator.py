# -*- coding: utf-8 -*-

import sys
import time
import argparse
from scapy.all import *
import scapy.contrib.gtp as gtp

def End_Point_Emulator():
    ''' Description: 
        toy programm to emulate end point behavior. might be either of gNB or PDN( = PE router).
        run "end_point_emulator.py [[option] [value]] ...", then transmits the packet from the specified interface.
        Options are as follows.
          -i, --interface   : パケットを発出する interface（必須）
          -e, --encapsulate : 指定時は GTP-U でカプセル化
            , --src_mac     : src. MAC addr. を文字列指定．デフォルトは aa:bb:cc:dd:ee:01
            , --dst_mac     : dst. MAC addr. を文字列指定．デフォルトは aa:bb:cc:dd:ee:02
          -6, --ipv6        : 指定時は IPv6 を使用．デフォルトは v4
            , --src_addr    : v4/v6 の送信元 addr. を文字列指定（必須）
            , --dst_addr    : v4/v6 の宛先 addr. を文字列指定（必須）
            , --inner_src   : user header の v4/v6 の送信元 addr. を文字列指定 (-e が指定されていない場合は unused)
            , --inner_dst   : user header の v4/v6 の宛先 addr. を文字列指定 (-e が指定されていない場合は unused)
          -u, --udp         : 指定時は user header で UDP を使用
          -t, --tcp         : 指定時は user header で TCP を使用
            , --src_port    : user header の TCP/UDP の送信元ポート番号を指定 (--tcp or --udp が指定されていない場合は unused)
            , --dst_port    : user header の TCP/UDP の宛先ポート番号を指定 (--tcp or --udp が指定されていない場合は unused)
            , --teid        : カプセル化する際の F-TEID (-e が指定されていない場合は unused) 
            , --num         : 発出する packet 数 (default = 5)    
    '''

    # STEP 1. args を parse
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--interface", help="interface from which the packet is transmitted", required=True)
    parser.add_argument("-e", "--encapsulate", help="encapsulate with GTP-U header", action="store_true")
    parser.add_argument("--src_mac", default="aa:bb:cc:dd:ee:01", help="src. MAC addr. for ethernet header")
    parser.add_argument("--dst_mac", default="aa:bb:cc:dd:ee:02", help="src. MAC addr. for ethernet header")
    parser.add_argument("-6", "--ipv6", help="use IPv6 (defalut is IPv4)", action="store_true")
    parser.add_argument("--src_addr", help="src. addr. for IPv4/IPv6", required=True)
    parser.add_argument("--dst_addr", help="dst. addr. for IPv4/IPv6", required=True)
    parser.add_argument("--inner_src", help="src. addr. for Inner IPv4/IPv6")
    parser.add_argument("--inner_dst", help="dst. addr. for Inner IPv4/IPv6")
    parser.add_argument("-u", "--udp", help="use UDP for user's packet", action="store_true")
    parser.add_argument("-t", "--tcp", help="use TCP for user's packet", action="store_true")
    parser.add_argument("--src_port", type=int, default=0, help="src. port num. for user's UDP/TCP")
    parser.add_argument("--dst_port", type=int, default=0, help="dst. port num. for user's UDP/TCP")
    parser.add_argument("--teid", type=int, default=0, help="F-TEID for GTP-U header")
    parser.add_argument("--num", type=int, default=5, help="the number of packet to be transmitted.")
    args = parser.parse_args()

    # STEP 2. scapy で packet 生成
    data = "this packet is generated just for testing my P4 program :)"
    payload = Raw(load=data)

    l2_h = Ether(src=args.src_mac, dst=args.dst_mac)

    if args.ipv6:
      l3_h = IPv6(src=args.src_addr, dst=args.dst_addr)
      l2_h.type = int("0x86dd", 16)
    else:
      l3_h = IP(src=args.src_addr, dst=args.dst_addr)
      l2_h.type = int("0x0800", 16)

    if args.encapsulate:

      if args.inner_src == None or args.inner_dst == None:
        print >> sys.stderr, "ERROR: \"inner_src\" and \"inner_dst\" MUST be specified if \"--encapsulate\" is selected."
        sys.exit(1)

      # prepare UDP header for GTP-U
      udp_h = UDP(dport=2152)
      # prepare GTP-U header
      gtp_u_h = gtp.GTPHeader(S=1, gtp_type=255, teid=args.teid)

      # prepare user's IP header
      if args.ipv6:
        inner_l3_h = IPv6(src=args.inner_src, dst=args.inner_dst)
      else:
        inner_l3_h = IP(src=args.inner_src, dst=args.inner_dst)

      # prepare user's TCP/UDP header
      if args.tcp:
        inner_l4_h = TCP(sport=args.src_port, flags=0, dport=args.dst_port)
      else:
        inner_l4_h = UDP(sport=args.src_port, dport=args.dst_port)
      # construct transmitted frame
      frame = l2_h/l3_h/udp_h/gtp_u_h/inner_l3_h/inner_l4_h/payload
    
    else:
      # prepare user's TCP/UDP header
      if args.tcp:
        l4_h = TCP(sport=args.src_port, flags=0, dport=args.dst_port)
      else:
        l4_h = UDP(sport=args.src_port, dport=args.dst_port)
      
      # construct transmitted frame
      frame = l2_h/l3_h/l4_h/payload
      
    print "====== packet info. ======"
    print "L2(Ether)"
    print "  - src:", args.src_mac
    print "  - dst:", args.dst_mac

    if args.ipv6:
      print "L3(IPv6)"
    else:
      print "L3(IPv4)"
    print "  - src:", args.src_addr
    print "  - dst:", args.dst_addr

    if args.encapsulate:
      print "L4(UDP)"
      print "  - dport: 2152(GTPU)"
      print "GTPU"
      print "  - teid:", args.teid
      if args.ipv6:
        print "L3(IPv6)"
        print "  - src:", args.inner_src
        print "  - dst:", args.inner_dst
      else:
        print "L3(IPv4)"
        print "  - src:", args.inner_src
        print "  - dst:", args.inner_dst

    if args.tcp:
      print "L4(TCP)"
    else:
      print "L4(UDP)"
    print "  - sport:", args.src_port
    print "  - dport:", args.dst_port
    print "=========================="

    # STEP 3. --num で指定した回数だけ 1 秒おきにパケット発出
    for cnt in range(args.num):
      if cnt+1 == 1:
        print "1 st packet transmitted"
      elif cnt+1 == 2:
        print "2 nd pacekt transmitted"
      elif cnt+1 == 3:
        print "3 rd pacekt transmitted"
      else:
        print cnt+1, "th packet transmitted"
      sendp(frame, verbose=0, iface=args.interface)
      time.sleep(1)

End_Point_Emulator()
