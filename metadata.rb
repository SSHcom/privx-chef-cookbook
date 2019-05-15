name 'privx'
maintainer 'Jukka-Pekka Virtanen'
maintainer_email 'jukka-pekka.virtanen@ssh.com'
license 'All Rights Reserved'
description 'Installs/Configures PrivX Host'
long_description 'Installs/Configures PrivX Host'
version '0.1.0'
chef_version '>= 12.1' if respond_to?(:chef_version)
source_url 'https://github.com/SSHcom/privx-chef-cookbook'
issues_url 'https://github.com/SSHcom/privx-chef-cookbook/issues'

supports 'ubuntu', '>= 14.04'
supports 'centos'
supports 'redhat'

depends 'openssh'
depends 'ntp'

# The `issues_url` points to the location where issues for this cookbook are
# tracked.  A `View Issues` link will be displayed on this cookbook's page when
# uploaded to a Supermarket.
#
# issues_url 'https://github.com/<insert_org_here>/privx/issues'

# The `source_url` points to the development repository for this cookbook.  A
# `View Source` link will be displayed on this cookbook's page when uploaded to
# a Supermarket.
#
# source_url 'https://github.com/<insert_org_here>/privx'
