# Use the internal 192.168.56.* address
if $facts['networking']['interfaces']['eth1'] != undef {
  $ip = $facts['networking']['interfaces']['eth1']['ip']
} elsif $facts['networking']['interfaces']['enp0s8'] != undef {
  $ip = $facts['networking']['interfaces']['enp0s8']['ip']
} else {
  $ip = $facts['networking']['ip']
}

class { '::sensu':
  rabbitmq_password => 'correct-horse-battery-staple',
  rabbitmq_host     => '192.168.56.10',
  rabbitmq_vhost    => '/sensu',
  subscriptions     => 'all',
  client_address    => $ip,
}
