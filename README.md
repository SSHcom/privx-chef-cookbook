# PrivX

This cookbook configures a node to trust PrivX issued OpenSSH user certificates.

## Configuration

### Attributes
Required attributes under node['privx']:

* `'api_endpoint'`: `https://` prefixed hostname for PrivX.
* `'api_ca_cert'`: Trust anchor for PrivX's TLS certificate.
* `'roles'`: JSON array of objects which have key `'principal'` (str) and `'roles'` (array).


```json
{
    "api_endpoint": "https://privx.example.com",
    "api_ca_cert": "-----BEGIN CERTIFICATE-----\nasdfsfdgsfglöjksdfglökjsdg\n-----END CERTIFICATE-----",
    "principals": [
        {
          "principal": "root",
          "roles": [{"name": "root-everywhere"}, {"name": "dev-admin"}]
        }
      ]
}
```

### Chef-vault

PrivX cookbook expects to find vault with name `privx` and an databag with name
`privx` which has following fields:

* `'oauth_client_secret'`: This value is get from PrivX command line using the command: `sudo /opt/privx/bin/keyvault-tool -name privx_auth_client_secret_privx-external get-passphrase`
* `'api_client_id'`: Name of the API user
* `'api_client_secret'`: Password for the API user

Such as

`knife vault update privx privx '{"oauth_client_secret": "asdfkjhsfdgxbuhxcvb", "api_client_id": "deploy-script", "api_client_secret": "0000000000000"}' --mode client`

This vault needs to be exposed to the node at bootstrap with `--bootstrap-vault-item 'privx:privx'`

## Bootstrapping

```bash
knife bootstrap ec2-18-194-178-70.eu-central-1.compute.amazonaws.com \
                --ssh-user ec2-user \
                --sudo \
                --identity-file ~/.ssh/aws \
                --node-name node1 \
                --environment development \
                --run-list 'role[system]' \
                --bootstrap-vault-item 'privx:privx'
```

Optionally `--hint openstack` might be needed for OpenStack instances.
