instance = ::ChefCookbook::Instance::Helper.new(node)
secret = ::ChefCookbook::Secret::Helper.new(node)

apt_update 'default' do
  action :update
  notifies :install, 'build_essential[default]', :immediately
end

build_essential 'default' do
  action :nothing
end

locale 'en' do
  lang 'en_US.utf8'
  lc_all 'en_US.utf8'
  action :update
end

package 'net-tools'

include_recipe 'ntp::default'

fail2ban_enabled = node.fetch('fail2ban', {}).fetch('enabled', false)

if fail2ban_enabled
  node.default['firewall']['iptables']['defaults'][:ruleset] = {
    '*filter' => 1,
    ':INPUT DROP' => 2,
    ':FORWARD ACCEPT' => 3,
    ':OUTPUT ACCEPT_FILTER' => 4,
    '-N fail2ban' => 45,
    '-A fail2ban -j RETURN' => 45,
    '-A INPUT -j fail2ban' => 45,
    'COMMIT_FILTER' => 100
  }
end

include_recipe 'firewall::default'

if fail2ban_enabled
  package 'fail2ban' do
    action :install
  end

  service 'fail2ban' do
    action [:enable, :start]
    subscribes :restart, 'firewall[default]', :delayed
  end

  template '/etc/fail2ban/jail.local' do
    source 'fail2ban/jail.local.erb'
    owner instance.root
    group node['root_group']
    mode 0644
    variables(
      chain: 'fail2ban',
      action: 'action_',
      destemail: node['fail2ban']['destemail'],
      sender: node['fail2ban']['sender'],
      sendername: node['fail2ban']['sendername'],
      jail: node['fail2ban']['jail']
    )
    action :create
    notifies :restart, 'service[fail2ban]', :delayed
  end
end

cronic 'default' do
  action :install
end

ssmtp 'default' do
  sender_email node['ssmtp']['sender_email']
  smtp_host node['ssmtp']['smtp_host']
  smtp_port node['ssmtp']['smtp_port']
  smtp_username node['ssmtp']['smtp_username']
  smtp_password secret.get("smtp:password:#{node['ssmtp']['smtp_username']}")
  smtp_enable_starttls node['ssmtp']['smtp_enable_starttls']
  smtp_enable_ssl node['ssmtp']['smtp_enable_ssl']
  from_line_override node['ssmtp']['from_line_override']
  action :install
end

apt_repository 'git-core' do
  uri 'ppa:git-core/ppa'
  distribution node['lsb']['codename']
end

git_client 'default' do
  package_action :upgrade
  action :install
end

node_part = node['volgactf']['qualifier']
opt_proxy_source = node_part.fetch('proxy_source', nil)

ngx_http_ssl_module 'default' do
  openssl_version '1.1.1b'
  openssl_checksum '5c557b023230413dfb0756f3137a13e6d726838ccd1430888ad15bfb2b43ea4b'
  action :add
end

ngx_http_v2_module 'default'
ngx_http_realip_module 'default'
ngx_http_gzip_static_module 'default'
ngx_brotli_module 'default'
ngx_http_geoip2_module 'default'

dhparam_file 'default' do
  key_length 2048
  action :create
end

nginx_install 'default' do
  with_ipv6 false
  with_threads false
  with_debug false
  directives(
    main: {
      worker_processes: 'auto',
      worker_rlimit_nofile: 100_000
    },
    events: {
      worker_connections: 2048,
      multi_accept: 'on'
    },
    http: {
      server_tokens: 'off',
      sendfile: 'on',
      tcp_nopush: 'on',
      tcp_nodelay: 'on',
      keepalive_requests: 250,
      keepalive_timeout: 100
    }
  )
  action :run
end

nginx_conf 'gzip' do
  cookbook 'volgactf-qualifier-main'
  template 'nginx/gzip.nginx.conf.erb'
  action :create
end

nginx_conf 'ssl' do
  cookbook 'ngx-modules'
  template 'ssl.conf.erb'
  variables(lazy {
    {
      ssl_dhparam: ::ChefCookbook::DHParam.file(node, 'default'),
      ssl_configuration: 'intermediate'
    }
  })
  action :create
end

nginx_conf 'resolver' do
  cookbook 'volgactf-qualifier-main'
  template 'nginx/resolver.nginx.conf.erb'
  variables(
    resolvers: %w[1.1.1.1 8.8.8.8 1.0.0.1 8.8.4.4],
    resolver_valid: 600,
    resolver_timeout: 10
  )
  action :create
end

nginx_conf 'realip' do
  cookbook 'volgactf-qualifier-main'
  template 'nginx/realip.nginx.conf.erb'
  variables(
    header: 'X-Forwarded-For',
    from: %w[127.0.0.1].concat(opt_proxy_source.nil? ? [] : [opt_proxy_source])
  )
  action :create
end

service 'cron' do
  action :nothing
end

execute 'run logrotate hourly' do
  command 'mv /etc/cron.daily/logrotate /etc/cron.hourly/logrotate'
  user instance.root
  group node['root_group']
  notifies :restart, 'service[cron]', :delayed
  action :run
  not_if { ::File.exist?('/etc/cron.hourly/logrotate') }
end

logrotate_app 'nginx' do
  path(lazy { ::File.join(node.run_state['nginx']['log_dir'], '*.log') })
  frequency 'hourly'
  rotate 24 * 7
  options [
    'missingok',
    'compress',
    'delaycompress',
    'notifempty',
    'dateext',
    'dateformat .%Y-%m-%d-%s'
  ]
  postrotate(lazy { "[ ! -f #{node.run_state['nginx']['pid']} ] || kill -USR1 `cat #{node.run_state['nginx']['pid']}`" })
  action :enable
end

geolite2_country_database 'default'
geolite2_city_database 'default'

redis_host = '127.0.0.1'
redis_port = 6379

node.default['redisio']['version'] = '5.0.3'
node.default['redisio']['servers'] = [
  {
    name: nil,
    address: redis_host,
    port: redis_port
  }
]

include_recipe 'redisio::default'
include_recipe 'redisio::enable'

include_recipe 'nodejs::nodejs_from_binary'

postgres_version = '9.6'
postgres_superuser_pwd = secret.get('postgres:password:postgres')

postgresql_server_install 'PostgreSQL Server' do
  setup_repo true
  version postgres_version
  password postgres_superuser_pwd
  action [:install, :create]
end

service 'postgresql' do
  action :nothing
end

postgres_host = '127.0.0.1'
postgres_port = 5432

postgresql_server_conf 'PostgreSQL Config' do
  version postgres_version
  port postgres_port
  additional_config 'listen_addresses' => postgres_host
  action :modify
  notifies :reload, 'service[postgresql]'
end

db_user = 'volgactf_qualifier'
db_name = 'volgactf_qualifier'
db_locale = 'en_US.utf8'

postgresql_user db_user do
  password secret.get("postgres:password:#{db_user}")
  action :create
end

postgresql_database db_name do
  locale db_locale
  owner db_user
  action :create
end

postgresql_access "#{db_user} database access" do
  access_type 'host'
  access_db db_name
  access_user db_user
  access_addr '127.0.0.1/32'
  access_method 'md5'
  action :grant
  notifies :reload, 'service[postgresql]'
end

include_recipe 'graphicsmagick::default'
include_recipe 'graphicsmagick::devel'

include_recipe 'agit::cleanup'

if node.chef_environment == 'development'
  vpn_connect 'default' do
    config secret.get('openvpn:config')
    action :create
  end
end

%w[
  python2.7
  python-pip
].each do |pkg_name|
  package pkg_name do
    action :install
  end
end

opt_secure = node_part.fetch('secure', false)
opt_proxied = node_part.fetch('proxied', false)
opt_oscp_stapling = node_part.fetch('oscp_stapling', true)
opt_optimize_delivery = node_part.fetch('optimize_delivery', false)

post_twitter = node_part.fetch('notification_post_twitter', false)
post_telegram = node_part.fetch('notification_post_telegram', false)
enable_backup = node_part.fetch('backup', {}).fetch('enabled', false)
smtp_username = node_part.fetch('smtp', {}).fetch('username', nil)

volgactf_qualifier_app node_part['fqdn'] do
  development node.chef_environment == 'development'
  optimize_delivery opt_optimize_delivery
  session_secret secret.get('themis-quals:session_secret')
  secure opt_secure
  proxied opt_proxied
  oscp_stapling opt_oscp_stapling

  num_processes_server node_part.fetch('num_processes_server', 2)
  num_processes_queue node_part.fetch('num_processes_queue', 2)

  email_transport node_part['email']['transport']
  email_address_validator node_part['email']['address_validator']
  email_sender_name node_part['email']['sender_name']
  email_sender_address node_part['email']['sender_address']

  customizers node_part.fetch('customizers', {})
  customizer_name node_part.fetch('customizer_name', 'default')

  cleanup_upload_dir_enabled node_part.fetch('cleanup_upload_dir', {}).fetch('enabled', false)
  cleanup_upload_dir_cron_mailto node_part.fetch('cleanup_upload_dir', {}).fetch('cron', {}).fetch('mailto', nil)
  cleanup_upload_dir_cron_mailfrom node_part.fetch('cleanup_upload_dir', {}).fetch('cron', {}).fetch('mailfrom', nil)
  cleanup_upload_dir_cron_minute node_part.fetch('cleanup_upload_dir', {}).fetch('cron', {}).fetch('minute', '*')
  cleanup_upload_dir_cron_hour node_part.fetch('cleanup_upload_dir', {}).fetch('cron', {}).fetch('hour', '*')
  cleanup_upload_dir_cron_day node_part.fetch('cleanup_upload_dir', {}).fetch('cron', {}).fetch('day', '*')
  cleanup_upload_dir_cron_month node_part.fetch('cleanup_upload_dir', {}).fetch('cron', {}).fetch('month', '*')
  cleanup_upload_dir_cron_weekday node_part.fetch('cleanup_upload_dir', {}).fetch('cron', {}).fetch('weekday', '*')

  backup_enabled enable_backup
  backup_cron_mailto node_part.fetch('backup', {}).fetch('cron', {}).fetch('mailto', nil)
  backup_cron_mailfrom node_part.fetch('backup', {}).fetch('cron', {}).fetch('mailfrom', nil)
  backup_cron_minute node_part.fetch('backup', {}).fetch('cron', {}).fetch('minute', '*')
  backup_cron_hour node_part.fetch('backup', {}).fetch('cron', {}).fetch('hour', '*')
  backup_cron_day node_part.fetch('backup', {}).fetch('cron', {}).fetch('day', '*')
  backup_cron_month node_part.fetch('backup', {}).fetch('cron', {}).fetch('month', '*')
  backup_cron_weekday node_part.fetch('backup', {}).fetch('cron', {}).fetch('weekday', '*')

  aws_access_key_id secret.get('aws:access_key_id', default: nil, required: enable_backup)
  aws_secret_access_key secret.get('aws:secret_access_key', default: nil, required: enable_backup)
  aws_default_region secret.get('aws:default_region', default: nil, required: enable_backup)
  aws_s3_bucket secret.get('aws:s3_bucket', default: nil, required: enable_backup)

  geoip2_city_database(lazy { ::ChefCookbook::GeoLite2.city_database(node, 'default') })
  geoip2_country_database(lazy { ::ChefCookbook::GeoLite2.country_database(node, 'default') })

  postgres_host postgres_host
  postgres_port postgres_port
  postgres_db db_name
  postgres_user db_user
  postgres_password secret.get("postgres:password:#{db_user}")

  redis_host redis_host
  redis_port redis_port
  redis_db 1

  google_tag_id secret.get('google:tag_id', default: nil, required: false)

  mailgun_api_key secret.get('mailgun:api_key', required: node_part['email']['transport'] == 'mailgun' || node_part['email']['address_validator'] == 'mailgun')
  mailgun_domain node_part.fetch('mailgun', {}).fetch('domain', nil)

  smtp_host node_part.fetch('smtp', {}).fetch('host', nil)
  smtp_port node_part.fetch('smtp', {}).fetch('port', nil)
  smtp_secure node_part.fetch('smtp', {}).fetch('secure', false)
  smtp_username smtp_username
  smtp_password secret.get("smtp:password:#{smtp_username}", default: nil, required: node_part['email']['transport'] == 'smtp')

  notification_post_twitter post_twitter
  twitter_api_consumer_key secret.get('twitter:consumer_key', default: nil, required: post_twitter)
  twitter_api_consumer_secret secret.get('twitter:consumer_secret', default: nil, required: post_twitter)
  twitter_api_access_token secret.get('twitter:access_token', default: nil, required: post_twitter)
  twitter_api_access_token_secret secret.get('twitter:access_token_secret', defalt: nil, required: post_twitter)

  notification_post_telegram post_telegram
  telegram_bot_access_token secret.get('telegram:bot_access_token', default: nil, required: post_telegram)
  telegram_chat_id secret.get('telegram:chat_id', default: nil, required: post_telegram)
  telegram_socks5_host secret.get('telegram:socks5:host', default: nil)
  telegram_socks5_port secret.get('telegram:socks5:port', default: nil)
  telegram_socks5_username secret.get('telegram:socks5:username', default: nil)
  telegram_socks5_password secret.get('telegram:socks5:password', default: nil)

  action :install
end

volgactf_qualifier_limits 'default' do
  action :create
end

firewall_rule 'http' do
  port 80
  if opt_proxy_source.nil?
    source '0.0.0.0/0'
  else
    source "#{opt_proxy_source}/32"
  end
  protocol :tcp
  command :allow
end

if opt_secure && !opt_proxied
  firewall_rule 'https' do
    port 443
    if opt_proxy_source.nil?
      source '0.0.0.0/0'
    else
      source "#{opt_proxy_source}/32"
    end
    protocol :tcp
    command :allow
  end
end
