FROM redis:latest

# 設定ファイルのコピー（バインドマウントしてもOKだが、頻繁に変更しないと思うのでひとまずコピーにしています）
COPY ../redis-master.conf /usr/local/etc/redis/redis-master.conf

# サーバー起動時に設定ファイルを読み込むためのコマンドを設定
CMD ["redis-server", "/usr/local/etc/redis/redis-master.conf"]

# pidファイルが存在しない場合に作成し、権限を設定（エラー対策）
RUN sh -c 'if [ ! -f /var/run/redis_6379.pid ]; then touch /var/run/redis_6379.pid; fi && chmod 777 /var/run/redis_6379.pid'
