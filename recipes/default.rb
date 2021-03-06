#
# Cookbook:: privx
# Recipe:: default
#
# Copyright:: 2017, SSH Communications Security, Inc, All Rights Reserved.

lock_file_name = '/opt/privx/registered'
ca_file_name = '/opt/privx/api_ca.crt'
auth_principals_dir = '/etc/ssh/auth_principals'
principals_command_name = '/etc/ssh/principals_command.sh'

directory '/opt/privx' do
  action :create
end

file ca_file_name do
  content "#{node['privx']['api_ca_cert']}"
end

include_recipe 'ntp'

chef_gem 'chef-vault' do
  compile_time true if respond_to?(:compile_time)
end

require 'chef-vault'
require 'base64'

vault = ChefVault::Item.load("privx", "privx")

Chef::Recipe.send(:include, PrivX)

api_client = PrivX::ApiClient.new(vault['oauth_client_secret'],
  vault['api_client_id'], vault['api_client_secret'],
  node['privx']['api_endpoint'], ca_file_name)


ruby_block "Get PrivX CA pub key" do
  block do
    api_client.authenticate
    response = api_client.call("GET", "/authorizer/api/v1/cas", nil)
    if response.code != '200'
      raise "Could not get CA pub key."
    end

    ca_list = JSON.parse(response.body)
    pubkey = ca_list[0]['public_key_string']

    node.normal['openssh']['ca_keys'] = [pubkey]
    node.force_override['openssh']['ca_keys'] = [pubkey]
  end
end

# install openssh
include_recipe 'openssh'


ruby_block "Resolve role IDs" do
  block do
    principals = node['privx']['principals'].dup # deep copy

    roles = []
    for principal in principals do
      for role in principal['roles'] do
        roles.push(role['name'])
      end
    end

    response = api_client.call("POST", "/role-store/api/v1/roles/resolve",
                               roles)
    if response.code != '200'
      raise "Could not resolve role IDs"
    end

    parsed = JSON.parse(response.body)
    roles = parsed['items']
    role_ids = Hash.new
    for role in roles do
      role_ids[role['name']] = role['id']
    end

    principals.each do |principal|
      principal['roles'].each do |role|
        role_id = role_ids[role['name']]
        if role_id == nil
          raise "Role with name #{role['name']} not found."
        end

        role['id'] = role_id
      end
    end

    node.normal['privx']['principals'] = principals
    node.force_override['privx']['principals'] = principals
  end
end

ruby_block "Get principals command" do
  block do
    response = api_client.call("GET",
      "/authorizer/api/v1/deploy/principals_command.sh", nil)
    if response.code != '200'
      raise "Could not get principals command"
    end

    principals_command = response.body
    ::File.open(principals_command_name, "w") do |f|
      f.puts(principals_command)
    end

    ::File.chmod(0755, principals_command_name)
  end
end


ruby_block 'Add AuthorizedPrincipalsFile to sshd config' do
  block do
    delete_lines = [
      "AuthorizedPrincipalsFile #{auth_principals_dir}/%u"
    ]

    add_lines = [
      "AuthorizedPrincipalsCommand /etc/ssh/principals_command.sh %u",
      "AuthorizedPrincipalsCommandUser \"nobody\""
    ]

    file = Chef::Util::FileEdit.new('/etc/ssh/sshd_config')

    for line in delete_lines do
      file.search_file_delete(/#{line}/)
    end

    for line in add_lines do
      file.insert_line_if_no_match(/#{line}/, line)
    end

    file.write_file
  end
end


directory auth_principals_dir do
  action :create
end

ruby_block "Write principals" do
  block do
    principals = node['privx']['principals']

    principals.each do |principal|
      filename = "#{auth_principals_dir}/#{principal['principal']}"
      if !(::File.exists? filename)
        ::File.open(filename, "w") {}
      end

      file = Chef::Util::FileEdit.new(filename)

      for role in principal['roles'] do 
        line = "#{role['id']} \# #{role['name']}"
        file.insert_line_if_no_match(/#{line}/, line)
      end

      file.write_file
    end
  end
end


ruby_block "Register with host keys" do
  block do
    path = '/etc/ssh/'
    keytypes = ['rsa', 'dsa', 'ecdsa', 'ed25519']
    filenames = keytypes.map { |t| "#{path}ssh_host_#{t}_key.pub" }
    present = filenames.select { |filename| ::File.exists? filename }
    hostkeys = present.map { |filename| ::File.read(filename).chomp }
    hostkeys_json = hostkeys.map { |hostkey| {"key" => hostkey} }

    instance_id = ""
    service_address = ""
    if node['ec2'] != nil
      node['ec2']['network_interfaces_macs'].each do |mac_addr, iface|
        service_address = iface['public_hostname']
      end

      instance_id = node['ec2']['instance_id']
    elsif node['openstack'] != nil
      instance_id = node['openstack']['instance_id']
      service_address = node['openstack']['public_ipv4']
    else
      raise "Neither EC2 nor OpenStack attributes found"
    end

    args = {
      "external_id" => instance_id,
      "ssh_host_public_keys" => hostkeys_json,
      "principals" => node['privx']['principals'],
      "privx_configured" => "TRUSTED_CA",
      "services" => [{"service" => "SSH", "address" => service_address}]
    }

    response = api_client.call("POST",
      "/host-store/api/v1/hosts/deploy", args)
    if response.code != '200' && response.code != '201'
      raise "Could not register host"
    end
  end

  not_if { ::File.exists?(lock_file_name) }
end

file lock_file_name do
  action :create_if_missing
end
