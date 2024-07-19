# 概要
master1台、replica1台で構成されたRedisのレプリケーション機能をDocker Composeで使用して構築した。

以下コマンドでコンテナ起動してログを確認できる。（dオプションは不要）
```
docker compose up
```
1. 最初は完全同期が行われる。
2. 次回以降の起動時は部分同期が行われる。

設定ファイルのrequirepassディレクティブでパスワード認証をかけているので、Redisサーバー内に入るには-aオプションでパスワードが必要。
```
docker exec -it redis-redis-master-1 redis-cli -a password
```

# レプリケーション
Redisサーバーに入ったら、以下コマンドでレプリケーションの情報を確認可能。
```
マスターの様子
127.0.0.1:6379> info replication
# Replication
role:master
connected_slaves:1
slave0:ip=172.18.0.2,port=6379,state=online,offset=700,lag=1
master_failover_state:no-failover
master_replid:93e1569b20e2f4734ac50e4ae1a493059b5f789e
master_replid2:0000000000000000000000000000000000000000
master_repl_offset:700
second_repl_offset:-1
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:1
repl_backlog_histlen:700

レプリカの様子
127.0.0.1:6379> info replication
# Replication
role:slave
master_host:redis-master
master_port:6379
master_link_status:up // masterがダウンするとdownに変わる
master_last_io_seconds_ago:3
master_sync_in_progress:0
slave_read_repl_offset:1064
slave_repl_offset:1064
slave_priority:100
slave_read_only:1
replica_announced:1
connected_slaves:0
master_failover_state:no-failover
master_replid:93e1569b20e2f4734ac50e4ae1a493059b5f789e
master_replid2:0000000000000000000000000000000000000000
master_repl_offset:1064
second_repl_offset:-1
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:1
repl_backlog_histlen:1064
```

# フェイルオーバー
ネイティブのRedisは自動フェイルオーバーの機能がないため、手動でreplicaをmasterに切り替える必要がある。
マスターの設定ファイルでenable-debug-commandディレクティブをyesに設定しているので、以下コマンドでマスターのサーバーをダウンさせることができる。
```
debug segfault
```
マスターコンテナのログを見るとマスターの接続が切れるとともに、レプリカがマスターに接続できなくなっている。
```
2024-07-19 09:58:26 1:S 19 Jul 2024 00:58:26.728 * Connection with master lost.
2024-07-19 09:58:26 1:S 19 Jul 2024 00:58:26.728 * Caching the disconnected master state.
2024-07-19 09:58:26 1:S 19 Jul 2024 00:58:26.728 * Reconnecting to MASTER redis-master:6379
2024-07-19 09:58:26 1:S 19 Jul 2024 00:58:26.729 * MASTER <-> REPLICA sync started
2024-07-19 09:58:26 1:S 19 Jul 2024 00:58:26.729 # Error condition on socket for SYNC: Connection refused
```

以下コマンドでレプリカをマスターに手動で昇格させることができる。
```
127.0.0.1:6379> replicaof no one
OK
```
昇格するとroleがmasterに変わる。
```
127.0.0.1:6379> info replication
# Replication
role:master
connected_slaves:0
master_failover_state:no-failover
master_replid:23ebcf802dfab442323ebc5c58a1bbd33c8a6ccd
master_replid2:93e1569b20e2f4734ac50e4ae1a493059b5f789e
master_repl_offset:1484
second_repl_offset:1485
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:1
repl_backlog_histlen:1484
```
レプリカコンテナのログを見るとマスターモードが有効になったことが確認できる。
```
2024-07-19 10:09:00 1:M 19 Jul 2024 01:09:00.622 * Discarding previously cached master state.
2024-07-19 10:09:00 1:M 19 Jul 2024 01:09:00.622 * Setting secondary replication ID to 93e1569b20e2f4734ac50e4ae1a493059b5f789e, valid up to offset: 1485. New replication ID is 23ebcf802dfab442323ebc5c58a1bbd33c8a6ccd
2024-07-19 10:09:00 1:M 19 Jul 2024 01:09:00.622 * MASTER MODE enabled (user request from 'id=5 addr=127.0.0.1:42226 laddr=127.0.0.1:6379 fd=9 name= age=672 idle=0 flags=N db=0 sub=0 psub=0 ssub=0 multi=-1 qbuf=36 qbuf-free=20438 argv-mem=14 multi-mem=0 rbs=1024 rbp=0 obl=0 oll=0 omem=0 tot-mem=22438 events=r cmd=replicaof user=default redir=-1 resp=2 lib-name= lib-ver=')
```

再度マスターコンテナを起動させる。
```
docker container start redis-redis-master-1
```

マスターに昇格されたレプリカをもう一度復活させたマスターのレプリカに設定。
```
レプリカのコンテナにて

127.0.0.1:6379> replicaof redis-master 6379
OK
127.0.0.1:6379> info replication
# Replication
role:slave # slaveに戻る。
master_host:redis-master
master_port:6379
master_link_status:down
master_last_io_seconds_ago:-1
master_sync_in_progress:0
slave_read_repl_offset:1484
slave_repl_offset:1484
master_link_down_since_seconds:-1
slave_priority:100
slave_read_only:1
replica_announced:1
connected_slaves:0
master_failover_state:no-failover
master_replid:de8880f1ac6f2ed314716078aea7f66432479c40
master_replid2:dc75f8f4aa938466fada7f1af8890e287349a96a
master_repl_offset:1484
second_repl_offset:1485
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:1
repl_backlog_histlen:1484
```
マスターサーバーでは、
```
127.0.0.1:6379> info replication
# Replication
role:master
connected_slaves:1 # レプリカが1台認識されている
slave0:ip=172.18.0.2,port=6379,state=online,offset=14,lag=0
master_failover_state:no-failover
master_replid:befc94d24649190b0c78e9e02880f015f24821f4
master_replid2:0000000000000000000000000000000000000000
master_repl_offset:14
second_repl_offset:-1
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:1
repl_backlog_histlen:14
```
ログを見ると、同期がちゃんとされているのも確認できる（部分同期）。

# 参考
実践Redis入門
7.5章「レプリケーションの導入方法」