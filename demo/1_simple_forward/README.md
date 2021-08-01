
# 概要

PDR (Packet Detection Rule) および FAR (Forwarding Action Rule) により，指定した TEID (Tunnel Endpoint IDentifier) および宛先 IP アドレス毎にフローを識別し，必要に応じて GTP-U ヘッダの encapsulation あるいは decapsulation を行いつつ，FAR の "forward" action で指定したネクストホップにパケット転送を行う簡単なデモを実施します．
[p4-guide](https://github.com/jafingerhut/p4-guide) 等を参照し P4 開発環境が構築済みであることを前提とします．デモ実施手順は大きく下記となります．

1. P4 プログラムのコンパイル
2. デモ環境構築
3. C/P プログラム実行（エントリ登録等）
4. パケット転送可否確認

# デモ実施手順

下記のように P4 プログラムをコンパイルします．コンパイル後に p4info.txt と main.json が生成されていることを確認してください．

```
> cd p4-upf-learning
> p4c -a v1model -b bmv2 --p4runtime-files p4info.txt -o demo/1_simple_forwarding/ ./src/main.p4
> cd demo/1_simple_forward
> ls
p4info.txt  main.json ...
```

続いてデモ環境を構築します．今回は gNB / PDN(= UPF が接続する PE Router 相当) として netns を使用し，I-UPF (Intermediate UPF) および A-UPF (Anchor UPF) として BMv2 を使用します．構成図（概略）は下記の通りです．

```
 -----   fc00:0001::/64   -------   fc00:0100::/64   -------   fc00:0002::/64   -----
| gNB | ---------------- | I-UPF | ---------------- | A-UPF | ---------------- | PDN |
 -----    10.10.1.0/24    -------    10.10.10.0/24   -------    10.10.2.0/24    -----
   |                                                                              |
   | 2001:0001::/64                                                2001:0002::/64 |
   | 192.168.1.0/24                                                192.168.2.0/24 |
   |                                                                              |
  ----                            HTTP (dport = 80)                            --------
 | UE |      ----------------------------------------------------------->     | Server |
  ----                                                                         --------
```

gNB の先にある UE や，PDN の先にある Server は inner ヘッダの情報を明確にするために記載しているのみで，実体は無い点にご注意ください．
I-UPF および A-UPF に登録するテーブルエントリや uplink 時のパケット転送の様子を表す，より詳細な環境構成図を [figure](./figures) に格納しましたので参照ください．

仮想 IF および netns (gNB/PDN) を下記を実行して作成します．

```
> sudo <path to behavioral-model>/tools/veth_setup.sh
> sudo setup.sh -c
```

I-UPF および A-UPF をそれぞれ下記を実行して起動します．それぞれ別ターミナルで起動してください．

- I-UPF の起動

```
> sudo simple_switch_grpc --no-p4 -i 0@veth1 -i 1@veth2 -- --grpc-server-addr 0.0.0.0:50051
```

- A-UPF の起動
```
> sudo simple_switch_grpc --no-p4 -i 0@veth3 -i 1@veth4 --thrift-port 9091 -- --grpc-server-addr 0.0.0.0:50052
```

最後に下記のように C/P プログラムを実行してデータプレーン処理やテーブルエントリを設定したらデモ環境構築完了です．

```
> go run main.go
```

今回は gNB からのパケット発出，および PDN からのパケット発出をエミュレートするための簡単な python スクリプトを用いた動作確認を行います．
uplink の動作確認を行う場合は，UE からのトラヒックを gNB が GTP-U でカプセル化したパケットが発出されるため，下記のように実行し GTP-U カプセル化後のパケットを gNB から I-UPF に向けて発出します．

```
sudo ip netns exec gNB python end_point_emulator.py \
  -i veth0                \
  -e                      \
  --src_addr 10.10.1.0    \
  --dst_addr 10.10.10.3   \
  --inner_src 192.168.1.1 \
  --inner_dst 192.168.2.2 \
  --tcp                   \
  --src_port 49152        \
  --dst_port 80           \
  --teid 100
```

なお，IPv6 を用いる場合は下記のように "-6" オプションを指定し IP アドレスとして IPv6 アドレスを指定することで IPv6 のパケットを生成出来ます．

```
sudo ip netns exec gNB python end_point_emulator.py \
  -i veth0                 \
  -e                       \
  -6                       \
  --src_addr fc00:0001::   \
  --dst_addr fc00:0010::3  \
  --inner_src 2001:0001::1 \
  --inner_dst 2001:0002::2 \
  --tcp                    \
  --src_port 49152         \
  --dst_port 80            \
  --teid 100
```

I-UPF および A-UPF の IF にて ```tcpdump``` 等によりパケットキャプチャを行い，I-UPF にて gNB -> A-UPF への forwarding が出来ていること，および A-UPF にて decapsulation を行い PDN に forwarding 出来ていることをそれぞれ確認出来ます．

同様に downlink の動作確認を行う場合は，Server からのトラヒックを PDN が転送し A-UPF に向けて発出するため，下記のように実行し Server からの擬似パケットを PDN から A-UPF に向けて発出します（下記は IPv4 の場合のコマンドです）．

```
sudo ip netns exec PDN python end_point_emulator.py \
  -i veth5                    \
  --src_mac aa:bb:cc:dd:ee:04 \
  --dst_mac aa:bb:cc:dd:ee:03 \
  --src_addr 192.168.2.2      \
  --dst_addr 192.168.1.1      \
  --tcp                       \
  --src_port 80               \
  --dst_port 49152            \
  --teid 100
```

uplink の時と同様に ```tcpdump``` 等によりパケットキャプチャを行うことで A-UPF にて GTP-U ヘッダによるカプセル化後に I-UPF に向けて forwarding 出来ていること，および I-UPF にて gNB に向けて forwarding 出来ていることをそれぞれ確認出来ます．uplink/downlink それぞれについて動作確認時のキャプチャデータを [capture]() に格納していますので参照ください (UE/Server からのトラヒックが UDP の場合についてもキャプチャを取得しています)．

デモ終了後は ctrl+C で I-UPF および A-UPF を停止し，下記を実行して環境を削除します．

```
> sudo setup.sh -d
> sudo behavioral-model/tools/veth_teardown.sh
```
