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
    "api_ca_cert": "-----BEGIN CERTIFICATE-----\nYXNkZmFzZGZhc2Zhc2Zhc2RmYXNkZmFzZGY=\n-----END CERTIFICATE-----",
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

* `'oauth_client_secret'`: OAuth client secret
* `'api_client_id'`: ID of the API user
* `'api_client_secret'`: Password for the API user

These values can be found from Settings -> Deployment -> Deploy and configure SSH target hosts -> Configure using a deployment script.

Add the credentials to chef vault:

`knife vault create privx privx '{"oauth_client_secret": "ZGdoZGZ0aGRmZ2hkZ2hibmN2", "api_client_id": "02781968-2a83-4cc2-4790-5f64cab9020c", "api_client_secret": "eRsiGFQJgMw1aKL4JjbBNyDOTsNHJc2zYPLGGgNH+ak="}' --mode client`

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

With Openstack nodes `--hint openstack` is probably required.
