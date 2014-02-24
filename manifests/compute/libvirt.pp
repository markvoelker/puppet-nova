# == Class: nova::compute::libvirt
#
# Install and manage nova-compute guests managed
# by libvirt
#
# === Parameters:
#
# [*virt_type*]
#   (optional) Libvirt domain type. Options are: kvm, lxc, qemu, uml, xen
#   Defaults to 'kvm'
#
# [*libvirt_type*]
#   DEPRECATED: use virt_type instead.
#
# [*vncserver_listen*]
#   (optional) IP address on which instance vncservers should listen
#   Defaults to '127.0.0.1'
#
# [*migration_support*]
#   (optional) Whether to support virtual machine migration
#   Defaults to false
#
# [*cpu_mode*]
#   (optional) The libvirt CPU mode to configure.  Possible values
#   include custom, host-model, none, host-passthrough.  
#   Defaults to 'host-model' if virt-type is set to either kvm or
#   qemu, otherwise defaults to 'none'.
#
class nova::compute::libvirt (
  $virt_type      = 'kvm',
  $vncserver_listen  = '127.0.0.1',
  $migration_support = false,
  $cpu_mode  = false,
  # Deprecated parameters
  $libvirt_type = false
) {

  include nova::params

  # Deprecated parameters
  if libvirt_type {
    warning('libvirt_type is deprecated for virt_type')
    $virt_type_real = $libvirt_type
  } else {
    $virt_type_real = $virt_type 
  }

  # cpu_mode has different defaults depending on hypervisor.
  if !$cpu_mode {
    case $cpu_mode {
      'kvm','qemu': {
        $cpu_mode_real = 'host-model'
      }
      default: {
        $cpu_mode_real = 'None'
      }
    }
  }

  Service['libvirt'] -> Service['nova-compute']

  if($::osfamily == 'Debian') {
    package { "nova-compute-${libvirt_type}":
      ensure => present,
      before => Package['nova-compute'],
    }
  }

  if($::osfamily == 'RedHat' and $::operatingsystem != 'Fedora') {
    service { 'messagebus':
      ensure   => running,
      enable   => true,
      provider => $::nova::params::special_service_provider,
    }
    Package['libvirt'] -> Service['messagebus'] -> Service['libvirt']

  }

  if $migration_support {
    if $vncserver_listen != '0.0.0.0' {
      fail('For migration support to work, you MUST set vncserver_listen to \'0.0.0.0\'')
    } else {
      class { 'nova::migration::libvirt': }
    }
  }

  package { 'libvirt':
    ensure => present,
    name   => $::nova::params::libvirt_package_name,
  }

  service { 'libvirt' :
    ensure   => running,
    name     => $::nova::params::libvirt_service_name,
    provider => $::nova::params::special_service_provider,
    require  => Package['libvirt'],
  }

  nova_config {
    'DEFAULT/compute_driver':    value => 'libvirt.LibvirtDriver';
    'DEFAULT/libvirt/virt_type': value => $virt_type_real;
    'DEFAULT/libvirt/cpu_mode':  value => $cpu_mode_real;
    'DEFAULT/connection_type':   value => 'libvirt';
    'DEFAULT/vncserver_listen':  value => $vncserver_listen;
  }

}
