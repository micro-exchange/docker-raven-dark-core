# micro-exchange/docker-raven-dark-core

A RavenDark Core docker image.

[![microexchange/raven-dark-core][docker-pulls-image]][docker-hub-url] [![microexchange/raven-dark-core][docker-stars-image]][docker-hub-url] [![microexchange/raven-dark-core][docker-size-image]][docker-hub-url] [![microexchange/raven-dark-core][docker-layers-image]][docker-hub-url]

## Tags

- `0.4`, `0.4.3`, `latest` ([0.4/Dockerfile](https://github.com/micro-exchange/docker-raven-dark-core/blob/master/0.4/Dockerfile)) (from master - last commit: [f0b69b](https://github.com/raven-dark/raven-dark/commit/f0b69bc4d6392d36dfe7f1912eb33693c619d58f))

**Picking the right tag**

- `microexchange/raven-dark-core:latest`: points to the latest stable release available of RavenDark Core. Use this only if you know what you're doing as upgrading RavenDark Core blindly is a risky procedure.
- `microexchange/raven-dark-core:<version>`: based on a Ubuntu image, points to a specific version branch or release of RavenDark Core. Uses the pre-compiled binaries which are fully tested by the RavenDark Core team.

## What is RavenDark Core?

Learn more about [RavenDark Core](https://github.com/raven-dark/raven-dark).

## Usage

### How to use this image

This image contains the main binaries from the RavenDark Core project - `ravendarkd` and `ravendark-cli`. It behaves like a binary, so you can pass any arguments to the image and they will be forwarded to the `ravendarkd` binary:

```sh
❯ docker run --rm microexchange/raven-dark-core \
  -printtoconsole \
  -regtest=1 \
  -rpcallowip=172.17.0.0/16 \
  -rpcauth='foo:1e72f95158becf7170f3bac8d9224$957a46166672d61d3218c167a223ed5290389e9990cc57397d24c979b4853f8e'
```

By default, `ravendarkd` will run as user `ravendark` for security reasons and with its default data dir (`~/.ravendark`). If you'd like to customize where `ravendarkd` stores its data, you must use the `RAVENDARK_DATA` environment variable. The directory will be automatically created with the correct permissions for the `ravendark` user and `ravendarkd` automatically configured to use it.

```sh
❯ docker run -e RAVENDARK_DATA=/var/lib/ravendarkd --rm microexchange/raven-dark-core \
  -printtoconsole \
  -regtest=1
```

You can also mount a directory in a volume under `/home/ravendark/.ravendark` in case you want to access it on the host:

```sh
❯ docker run -v ${PWD}/data:/home/ravendark/.ravendark --rm microexchange/raven-dark-core \
  -printtoconsole \
  -regtest=1
```

You can optionally create a service using `docker-compose`:

```yml
raven-dark-core:
  image: microexchange/raven-dark-core
  command:
    -printtoconsole
    -regtest=1
```

### Using RPC to interact with the daemon

There are two communications methods to interact with a running RavenDark Core daemon.

The first one is using a cookie-based local authentication. It doesn't require any special authentication information as running a process locally under the same user that was used to launch the RavenDark Core daemon allows it to read the cookie file previously generated by the daemon for clients. The downside of this method is that it requires local machine access.

The second option is making a remote procedure call using a username and password combination. This has the advantage of not requiring local machine access, but in order to keep your credentials safe you should use the newer `rpcauth` authentication mechanism.

#### Using cookie-based local authentication

Start by launch the RavenDark Core daemon:

```sh
❯ docker run --rm --name ravendark-server -it microexchange/raven-dark-core \
  -printtoconsole \
  -regtest=1
```

Then, inside the running `ravendark-server` container, locally execute the query to the daemon using `ravendark-cli`:

```sh
❯ docker exec --user ravendark ravendark-server ravendark-cli -regtest getmininginfo

{
  "blocks": 0,
  "currentblocksize": 0,
  "currentblockweight": 0,
  "currentblocktx": 0,
  "difficulty": 4.656542373906925e-10,
  "errors": "",
  "networkhashps": 0,
  "pooledtx": 0,
  "chain": "regtest"
}
```

In the background, `ravendark-cli` read the information automatically from `/home/ravendark/.ravendark/regtest/.cookie`. In production, the path would not contain the regtest part.

#### Using rpcauth for remote authentication

Before setting up remote authentication, you will need to generate the `rpcauth` line that will hold the credentials for the RavenDark Core daemon. You can either do this yourself by constructing the line with the format `<user>:<salt>$<hash>` or use the official `rpcauth.py` script to generate this line for you, including a random password that is printed to the console.

Example:

```sh
❯ curl -sSL https://raw.githubusercontent.com/raven-dark/raven-dark/master/share/rpcauth/rpcauth.py | python - <username>

String to be appended to ravendark.conf:
rpcauth=foo:1e72f95158becf7170f3bac8d9224$957a46166672d61d3218c167a223ed5290389e9990cc57397d24c979b4853f8e
Your password:
-ngju1uqGUmAJIQDBCgYbatzhcJon_YGU23t313388g=
```

Note that for each run, even if the username remains the same, the output will be always different as a new salt and password are generated.

Now that you have your credentials, you need to start the RavenDark Core daemon with the `-rpcauth` option. Alternatively, you could append the line to a `ravendark.conf` file and mount it on the container.

Let's opt for the Docker way:

```sh
❯ docker run --rm --name ravendark-server -it microexchange/raven-dark-core \
  -printtoconsole \
  -regtest=1 \
  -rpcallowip=172.17.0.0/16 \
  -rpcauth='foo:1e72f95158becf7170f3bac8d9224$957a46166672d61d3218c167a223ed5290389e9990cc57397d24c979b4853f8e'
```

Two important notes:

1. Some shells require escaping the rpcauth line (e.g. zsh), as shown above.
2. It is now perfectly fine to pass the rpcauth line as a command line argument. Unlike `-rpcpassword`, the content is hashed so even if the arguments would be exposed, they would not allow the attacker to get the actual password.

You can now connect via `ravendark-cli` or any other [compatible client](https://github.com/ruimarinho/bitcoin-core). You will still have to define a username and password when connecting to the RavenDark Core RPC server.

To avoid any confusion about whether or not a remote call is being made, let's spin up another container to execute `ravendark-cli` and connect it via the Docker network using the password generated above:

```sh
❯ docker run --link ravendark-server --rm microexchange/raven-dark-core \
  ravendark-cli \
  -rpcconnect=ravendark-server \
  -regtest \
  -rpcuser=foo \
  -rpcpassword='-ngju1uqGUmAJIQDBCgYbatzhcJon_YGU23t313388g=' \
  getmininginfo

{
  "blocks": 0,
  "currentblocksize": 0,
  "currentblockweight": 0,
  "currentblocktx": 0,
  "difficulty": 4.656542373906925e-10,
  "errors": "",
  "networkhashps": 0,
  "pooledtx": 0,
  "chain": "regtest"
}
```

### Exposing Ports

Depending on the network (mode) the RavenDark Core daemon is running as well as the chosen runtime flags, several default ports may be available for mapping.

Ports can be exposed by mapping all of the available ones (using `-P` and based on what `EXPOSE` documents) or individually by adding `-p`. This mode allows assigning a dynamic port on the host (`-p <port>`) or assigning a fixed port `-p <hostPort>:<containerPort>`.

Example for running a node in `regtest` mode mapping JSON-RPC/REST and P2P ports:

```sh
docker run --rm -it \
  -p 19332:19332 \
  -p 19444:19444 \
  microexchange/raven-dark-core \
  -printtoconsole \
  -regtest=1 \
  -rpcallowip=172.17.0.0/16 \
  -rpcauth='foo:1e72f95158becf7170f3bac8d9224$957a46166672d61d3218c167a223ed5290389e9990cc57397d24c979b4853f8e'
```

To test that mapping worked, you can send a JSON-RPC curl request to the host port:

```
curl --data-binary '{"jsonrpc":"1.0","id":"1","method":"getnetworkinfo","params":[]}' http://foo:-ngju1uqGUmAJIQDBCgYbatzhcJon_YGU23t313388g=@127.0.0.1:19332/
```

#### Mainnet

- JSON-RPC/REST: 9332
- P2P: 9333

#### Testnet

- JSON-RPC: 19332
- P2P: 19333

#### Regtest

- JSON-RPC/REST: 19332
- P2P: 19444

## Supported Docker versions

This image is officially supported on Docker version 17.09, with support for older versions provided on a best-effort basis.

## License

The [microexchange/raven-dark-core][docker-hub-url] docker project is under MIT license.

[docker-hub-url]: https://hub.docker.com/r/microexchange/raven-dark-core
[docker-layers-image]: https://img.shields.io/microbadger/layers/microexchange/raven-dark-core/latest.svg?style=flat-square
[docker-pulls-image]: https://img.shields.io/docker/pulls/microexchange/raven-dark-core.svg?style=flat-square
[docker-size-image]: https://img.shields.io/microbadger/image-size/microexchange/raven-dark-core/latest.svg?style=flat-square
[docker-stars-image]: https://img.shields.io/docker/stars/microexchange/raven-dark-core.svg?style=flat-square
