# = Class: sensu::package
#
# Installs the Sensu packages
#
# == Parameters
#
# [*conf_dir*]
#   String. The default configuration directory.
#   Default: $::sensu::conf_dir
#
# [*confd_dir*]
#   String, Array of strings. Additional directories to load configuration
#   snippets from.
#   Default: $::sensu::confd_dir
#
# [*heap_size*]
#   String. Value of the HEAP_SIZE environment variable.
#   Note: This has no effect on sensu-core.
#   Default: $::sensu::heap_size
#
# [*deregister_handler*]
#   String. The handler to use when deregistering a client on stop.
#   Default: $::sensu::deregister_handler
#
# [*deregister_on_stop*]
#   Boolean. Whether the sensu client should deregister from the API on service stop
#   Default: $::sensu::deregister_on_stop
#
# [*gem_path*]
#   String.  Paths to add to GEM_PATH if we need to look for different dirs.
#   Default: $::sensu::gem_path
#
# [*init_stop_max_wait*]
#   Integer.  Number of seconds to wait for the init stop script to run
#   Default: $::sensu::init_stop_max_wait
#
# [*log_dir*]
#   String.  Sensu log directory to be used
#   Default: $::sensu::log_dir
#   Valid values: Any valid log directory path, accessible by the sensu user
#
# [*log_level*]
#   String.  Sensu log level to be used
#   Default: $::sensu::log_level
#   Valid values: debug, info, warn, error, fatal
#
# [*path*]
#   String. Used to set PATH in /etc/default/sensu
#   Default: $::sensu::path
#
# [*rubyopt*]
#   String.  Ruby opts to be passed to the sensu services
#   Default: $::sensu::rubyopt
#
# [*use_embedded_ruby*]
#   Boolean.  If the embedded ruby should be used, e.g. to install the
#   sensu-plugin gem.  This value is overridden by a defined
#   sensu_plugin_provider.  Note, the embedded ruby should always be used to
#   provide full compatibility.  Using other ruby runtimes, e.g. the system
#   ruby, is not recommended.
#   Default: $::sensu::use_embedded_ruby
#   Valid values: true, false
#
class sensu::package (
  $conf_dir           = $::sensu::conf_dir,
  $confd_dir          = $::sensu::confd_dir,
  $heap_size          = $::sensu::heap_size,
  $deregister_handler = $::sensu::deregister_handler,
  $deregister_on_stop = $::sensu::deregister_on_stop,
  $gem_path           = $::sensu::gem_path,
  $init_stop_max_wait = $::sensu::init_stop_max_wait,
  $log_dir            = $::sensu::log_dir,
  $log_level          = $::sensu::log_level,
  $path               = $::sensu::path,
  $rubyopt            = $::sensu::rubyopt,
  $use_embedded_ruby  = $::sensu::use_embedded_ruby,
) {

  if $caller_module_name != $module_name {
    fail("Use of private class ${name} by ${caller_module_name}")
  }

  case $::osfamily {

    'Debian': {
      $pkg_title = 'sensu'
      $pkg_name = 'sensu'
      $pkg_version = $::sensu::version
      $pkg_source = undef
      $pkg_provider = undef

      if $::sensu::manage_repo {
        class { '::sensu::repo::apt': }
      }
      if $::sensu::manage_repo and $::sensu::install_repo {
        include ::apt
        $pkg_require = Class['apt::update']
      }
      else {
        $pkg_require = undef
      }
    }

    'RedHat': {
      $pkg_title = 'sensu'
      $pkg_name = 'sensu'
      $pkg_version = $::sensu::version
      $pkg_source = undef
      $pkg_provider = undef

      if $::sensu::manage_repo {
        class { '::sensu::repo::yum': }
      }

      $pkg_require = undef
    }

    'windows': {
      $repo_require = undef

      # $pkg_version is passed to Package[sensu] { ensure }.  The Windows MSI
      # provider translates hyphens to dots, e.g. '0.29.0-11' maps to
      # '0.29.0.11' on the system.  This mapping is necessary to converge.
      $pkg_version = regsubst($::sensu::version, '-', '.')
      # The version used to construct the download URL.
      $pkg_url_version = $::sensu::version ? {
        'installed' => 'latest',
        default     => $::sensu::version,
      }
      # The title used for consistent relationships in the Puppet catalog
      $pkg_title = $::sensu::windows_package_title
      # The name used by the provider to compare to Windows Add/Remove programs.
      $pkg_name = $::sensu::windows_package_name

      # The user can override the computation of the source URL.  This URL is
      # used with the remote_file resource, it is not used with the chocolatey
      # package provider.
      if $::sensu::windows_pkg_url {
        $pkg_url = $::sensu::windows_pkg_url
      } else {
        # The OS Release specific sub-folder
        $os_release = $facts['os']['release']['major']
        # e.g. '2012 R2' => '2012r2'
        $pkg_url_dir = regsubst($os_release, '^(\d+)\s*[rR](\d+)', '\\1r\\2')
        $pkg_arch = $facts['os']['architecture']
        $pkg_url = "${sensu::windows_repo_prefix}/${pkg_url_dir}/sensu-${pkg_url_version}-${pkg_arch}.msi"
      }

      if $::sensu::windows_package_provider == 'chocolatey' {
        $pkg_provider = 'chocolatey'
        if $::sensu::windows_choco_repo {
          $pkg_source = $::sensu::windows_choco_repo
        } else {
          $pkg_source = undef
        }
        $pkg_require = undef
      } else {
        # Use Puppet's default package provider
        $pkg_provider = undef
        # Where the MSI is downloaded to and installed from.
        $pkg_source = "C:\\Windows\\Temp\\sensu-${pkg_url_version}.msi"
        $pkg_require = "Remote_file[${pkg_title}]"

        # path matches Package[sensu] { source => $pkg_source }
        remote_file { $pkg_title:
          ensure   => present,
          path     => $pkg_source,
          source   => $pkg_url,
          checksum => $::sensu::package_checksum,
        }
      }
    }

    default: { fail("${::osfamily} not supported yet") }

  }

  package { $pkg_title:
    ensure   => $pkg_version,
    name     => $pkg_name,
    source   => $pkg_source,
    require  => $pkg_require,
    provider => $pkg_provider,
  }

  if $::sensu::sensu_plugin_provider {
    $plugin_provider = $::sensu::sensu_plugin_provider
  } else {
    $plugin_provider = $::sensu::use_embedded_ruby ? {
      true    => 'sensu_gem',
      default => 'gem',
    }
  }

  if $plugin_provider =~ /gem/ and $::sensu::gem_install_options {
    package { $::sensu::sensu_plugin_name :
      ensure          => $::sensu::sensu_plugin_version,
      provider        => $plugin_provider,
      install_options => $::sensu::gem_install_options,
    }
  } else {
    package { $::sensu::sensu_plugin_name :
      ensure   => $::sensu::sensu_plugin_version,
      provider => $plugin_provider,
    }
  }

  if $::osfamily != 'windows' {
    file { '/etc/default/sensu':
      ensure  => file,
      content => template("${module_name}/sensu.erb"),
      owner   => '0',
      group   => '0',
      mode    => '0444',
      require => Package[$pkg_title],
    }
  }

  file { [ $conf_dir, "${conf_dir}/handlers", "${conf_dir}/checks", "${conf_dir}/filters", "${conf_dir}/extensions", "${conf_dir}/mutators", "${conf_dir}/contacts" ]:
    ensure  => directory,
    owner   => $::sensu::user,
    group   => $::sensu::group,
    mode    => $::sensu::dir_mode,
    purge   => $::sensu::_purge_config,
    recurse => true,
    force   => true,
    require => Package[$pkg_title],
  }

  if $::sensu::manage_handlers_dir {
    file { "${sensu::etc_dir}/handlers":
      ensure  => directory,
      mode    => $::sensu::dir_mode,
      owner   => $::sensu::user,
      group   => $::sensu::group,
      purge   => $::sensu::_purge_handlers,
      recurse => true,
      force   => true,
      require => Package[$pkg_title],
    }
  }

  file { ["${sensu::etc_dir}/extensions", "${sensu::etc_dir}/extensions/handlers"]:
    ensure  => directory,
    mode    => $::sensu::dir_mode,
    owner   => $::sensu::user,
    group   => $::sensu::group,
    purge   => $::sensu::_purge_extensions,
    recurse => true,
    force   => true,
    require => Package[$pkg_title],
  }

  if $::sensu::manage_mutators_dir {
    file { "${sensu::etc_dir}/mutators":
      ensure  => directory,
      mode    => $::sensu::dir_mode,
      owner   => $::sensu::user,
      group   => $::sensu::group,
      purge   => $::sensu::_purge_mutators,
      recurse => true,
      force   => true,
      require => Package[$pkg_title],
    }
  }

  if $::sensu::_manage_plugins_dir {
    file { "${sensu::etc_dir}/plugins":
      ensure  => directory,
      mode    => $::sensu::dir_mode,
      owner   => $::sensu::user,
      group   => $::sensu::group,
      purge   => $::sensu::_purge_plugins,
      recurse => true,
      force   => true,
      require => Package[$pkg_title],
    }
  }

  if $::sensu::spawn_limit {
    $spawn_config = { 'sensu' => { 'spawn' => { 'limit' => $::sensu::spawn_limit } } }
    $spawn_template = '<%= require "json"; JSON.pretty_generate(@spawn_config) + $/ %>'
    $spawn_ensure = 'file'
    $spawn_content = inline_template($spawn_template)
    if $::sensu::client {
      $spawn_notify = [
        Class['sensu::client::service'],
        Class['sensu::server::service'],
      ]
    } else {
      $spawn_notify = [ Class['sensu::server::service'] ]
    }
  } else {
    $spawn_ensure = undef
    $spawn_content = undef
    $spawn_notify = undef
  }

  file { "${sensu::etc_dir}/conf.d/spawn.json":
    ensure  => $spawn_ensure,
    content => $spawn_content,
    mode    => $::sensu::dir_mode,
    owner   => $::sensu::user,
    group   => $::sensu::group,
    require => Package[$pkg_title],
    notify  => $spawn_notify,
  }

  if $::sensu::manage_user and $::osfamily != 'windows' {
    user { $::sensu::user:
      ensure  => 'present',
      system  => true,
      home    => $::sensu::home_dir,
      shell   => $::sensu::shell,
      require => Group[$::sensu::group],
      comment => 'Sensu Monitoring Framework',
    }

    group { $::sensu::group:
      ensure => 'present',
      system => true,
    }
  } elsif $::sensu::manage_user and $::osfamily == 'windows' {
    notice('Managing a local windows user is not implemented on windows')
  }

  file { "${sensu::etc_dir}/config.json": ensure => absent }
}
