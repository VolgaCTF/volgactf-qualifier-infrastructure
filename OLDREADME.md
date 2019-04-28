# Themis Quals Infrastructure
Vagrant development environment and Chef server configuration for Themis Quals. Part of [Themis Quals](https://github.com/aspyatkin/themis-quals) project.

## Prerequisites
1. [VirtualBox](https://virtualbox.org) 5.0.14 or later;
2. [Vagrant](https://www.vagrantup.com/) 1.8.1 or later;
3. *nix shell;
4. Ruby 2.2.x;
5. [vagrant-helpers](https://github.com/aspyatkin/vagrant-helpers) plugin;
6. [Bundler](http://bundler.io/).

**Windows specific** See [this gist](https://gist.github.com/aspyatkin/2a1305cceb9101caa2f6) to find out how to install Ruby 2.2.4 on Cygwin x64.

## Get the code
```sh
$ cd /path/to/projects/directory  # for instance
$ git clone https://github.com/aspyatkin/themis-quals-infrastructure
$ git clone https://github.com/aspyatkin/themis-quals-cookbook
```

## Configuring
### Create data bag encryption key

```sh
$ cd /path/to/projects/directory/themis-quals-infrastructure/
$ openssl rand -base64 512 | tr -d '\r\n' > encryption_keys/development_key
```

### For developers
For development purposes, several encrypted data bags should be added to your Chef repository.

#### *ssh* data bag
Contains your private OpenSSH GitHub key. To create the data bag, run

```sh
$ cd /path/to/projects/directory/themis-quals-infrastructure
$ knife solo data bag create ssh development
```

Below is the sample:

```json
{
  "id": "development",
  "keys": {
    "id_ed25519": "-----BEGIN OPENSSH PRIVATE KEY-----\n.......................\n-----END OPENSSH PRIVATE KEY-----\n"
  }
}
```

#### *git* data bag
Contains your git configuration, such as `user.email` and `user.name` settings. To create the data bag, run

```sh
$ cd /path/to/projects/directory/themis-quals-infrastructure
$ knife solo data bag create git development
```

Below is the sample:

```json
{
  "id": "development",
  "config": {
    "user.name": "Alexander Pyatkin",
    "user.email": "aspyatkin@users.noreply.github.com"
  }
}
```

### System config
Common options are stored in `themis-quals` cookbook's attributes or environment file.
Sensitive (passwords, API keys and so on) options are stored in the encrypted data bags.

#### *themis-quals* data bag
Contains application-specific options. To create the data bag, run

```sh
$ cd /path/to/projects/directory/themis-quals-infrastructure
$ knife solo data bag create themis-quals development
```

Below is the sample:

```json
{
  "id": "development",
  "session_secret": "deadbeefdeadbeefdeadbeefdeadbeef"
}
```

#### *sendgrid* data bag
Contains [SendGrid](https://sendgrid.com) API key. To create the data bag, run

```sh
$ cd /path/to/projects/directory/themis-quals-infrastructure
$ knife solo data bag create sendgrid development
```

Below is the sample:

```json
{
  "id": "development",
  "api_key": "SG.XXXXXXXXXXXXXXXXXXXXXXXXXX"
}
```

#### *mailgun* data bag
Contains [Mailgun](http://www.mailgun.com/) API key and sending domain. To create the data bag, run

```sh
$ cd /path/to/projects/directory/themis-quals-infrastructure
$ knife solo data bag create mailgun development
```

Below is the example:

```json
{
  "id": "development",
  "api_key": "key-xxxxxxxxxxxxxxxxxxx",
  "domain": "volgactf.ru"
}
```

#### *postgres* data bag
Contains PostgreSQL account passwords. To create the data bag, run

```sh
$ cd /path/to/projects/directory/themis-quals-infrastructure
$ knife solo data bag create postgres development
```

Below is the sample:

```json
{
  "id": "development",
  "credentials": {
    "postgres": "sometrickypassword",
    "themis_quals_user": "sometrickypassword"
  }
}
```

#### *ssl* data bag
Contains SSL certificates and private keys. To create the data bag, run

```sh
$ cd /path/to/projects/directory/themis-quals-infrastructure
$ knife solo data bag create ssl development
```

Below is the sample:

```json
{
  "id": "development",
  "certs": [
    {
      "domains": [
        "2016.volgactf.dev"
      ],
      "chain": "-----BEGIN CERTIFICATE-----\n........\n-----END CERTIFICATE-----",
      "private_key": "-----BEGIN RSA PRIVATE KEY-----\n........\n-----END RSA PRIVATE KEY-----"
    }
  ]
}
```

#### *aws* data bag (optional)
Contains Amazon AWS account credentials. To create the data bag, run

```sh
$ cd /path/to/projects/directory/themis-quals-infrastructure
$ knife solo data bag create aws development
```

Below is the sample:

```json
{
  "id": "development",
  "aws_access_key_id": "XXXXXXXXXXXXX",
  "aws_secret_access_key": "xxxxxxxxxxxxxxxxxxxxxxxxxx"
}
```

## Setup
The following actions are meant to be executed in the directory with the cloned `themis-quals-infrastructure` repository.

1. Create `opts.yaml` file based on the example provided in `opts.example.yaml`;
2. Run `bundle` to install necessary Ruby gems;
3. Run `bundle exec berks install` to install Chef cookbooks;
4. Map `2016.volgactf.dev` in your system's hosts file to an IP address specified in `opts.yaml` file;
5. Launch virtual machine with `vagrant up`;
6. Install Chef on target machine with `bundle exec knife solo prepare 2016.volgactf.dev`;
7. Provision virtual machine with `bundle exec knife solo cook 2016.volgactf.dev`.

**Windows specific** See [this gist](https://gist.github.com/aspyatkin/2a70736080835ac594ba) to discover how to install [Berkshelf](https://github.com/berkshelf/berkshelf) on Cygwin x64.

## Usage
### Process management
Processes are managed by [Supervisor](https://github.com/Supervisor/supervisor). Supervisor CLI can be accessed by invoking `sudo supervisorctl` command.
### Creating admin
```sh
$ cd /var/themis/quals/backend
$ npm run cli -- create_supervisor -u admin -p supercomplexpassword -r admin
```

## License
MIT @ [Alexander Pyatkin](https://github.com/aspyatkin) and contributors
