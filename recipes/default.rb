#
# Cookbook:: privx
# Recipe:: default
#
# Copyright:: 2017, SSH Communications Security, Inc, All Rights Reserved.

lock_file_name = '/opt/privx/registered'
ca_file_name = '/opt/privx/api_ca.crt'
auth_principals_dir = "/etc/ssh/auth_principals"

Chef::Recipe.send(:include, PrivX)

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

vault = ChefVault::Item.load("privx", "privx")

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

    node.override['openssh']['ca_keys'] = [pubkey]
  end
end

# install openssh
unless ::File.exists?(lock_file_name)
  include_recipe 'openssh'
end

ruby_block "Resolve role IDs" do
  block do
    roles = JSON.parse(node['privx']['roles'].to_json) # deep copy
    args = roles.map { |role| role['name'] }

    response = api_client.call("POST", "/role-store/api/v1/roles/resolve", args)
    if response.code != '200'
      raise "Could not resolve role IDs"
    end

    parsed = JSON.parse(response.body)
    role_ids = parsed['items']

    roles.each do |role|
      role_id = role_ids.detect { |r| r['name'] == role['name'] }
      role['id'] = role_id['id']
    end

    node.override['privx']['roles'] = roles
  end

  not_if { ::File.exists?(lock_file_name) }
end

ruby_block 'Add AuthorizedPrincipalsFile to sshd config' do
  block do
    line = "AuthorizedPrincipalsFile #{auth_principals_dir}/%u"

    file = Chef::Util::FileEdit.new('/etc/ssh/sshd_config')
    file.insert_line_if_no_match(/#{line}/, line)
    file.write_file
  end
end

directory auth_principals_dir do
  action :create
end

ruby_block "Write principals" do
  block do
    roles = node['privx']['roles']

    roles.each do |role|
      id = role['id']

      line = "#{id} \# #{role['name']}"

      role['principals'].each do |principal|
        filename = "#{auth_principals_dir}/#{principal}"
        if !(::File.exists? filename)
          ::File.open(filename, "w") {}
        end

        file = Chef::Util::FileEdit.new(filename)
        file.insert_line_if_no_match(/#{line}/, line)
        file.write_file
      end
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

    service_address = node['ec2']['network_interfaces_macs']['public_hostname']

    args = {
      "external_id" => "#{node['ec2']['instance_id']}",
      "ssh_host_public_keys" => hostkeys,
      "roles" => node['privx']['roles'],
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
