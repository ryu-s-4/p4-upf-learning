
# 概要

5G UPF (User Plane Function) の学習用に作成した P4 実装を公開します．
参照する 3GPP 仕様のバージョンについては後日整理しますが，とりあえずは 2021.8.1 現在の最新バージョンをそれぞれ参照しています．
細かい参照先はソースコードにコメント記載しています．

こちらの repository は UPF の機能実装および簡単なデモ実施を通した UPF（および関連する NF）の仕様理解を目的としています．
作成したデモは下記となります．

- [simple forwarding](./demo/1_simple_forward)
  - PDR (Packet Detection Rule) および FAR (Forwarding Action Rule) を実装し，必要に応じて GTP-U ヘッダの encapsulation あるいは decapsulation を行う単純なパケット転送のデモ
- to be added ...