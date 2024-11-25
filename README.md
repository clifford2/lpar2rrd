# XoruX LPAR2RRD

This is dockerized version of single [XoruX](https://www.xorux.com) application - [LPAR2RRD](https://www.lpar2rrd.com).

*Cloned from <https://github.com/XoruX/lpar2rrd>, and modified as follows:*

- Increased stack limit
- Moved some one off config steps from `startup.sh` to `Dockerfile`
- Built for **ppc64le** systems:
	- Alpine version 3.13 is the most recent version I have gotten to install  PDF::API2 to date
	- Platform-specific base image hard coded (for convenience only)
	- Built images are available at <https://hub.docker.com/r/cliffordw/lpar2rrd>

It's based on [Alpine Linux](https://hub.docker.com/_/alpine) with all necessary dependencies installed.

Quick start:

    podman run -d --name lpar2rrd --restart always -v lpar2rrd:/home/lpar2rrd docker.io/cliffordw/lpar2rrd:7.95

You can set container timezone via env variable TIMEZONE in podman run command:

    podman run -d --name lpar2rrd --restart always -v lpar2rrd:/home/lpar2rrd -e TIMEZONE="Europe/Prague" docker.io/cliffordw/lpar2rrd:7.95

If you want to use this container as a XorMon backend, set XORMON env variable:

    podman run -d --name lpar2rrd --restart always -v lpar2rrd:/home/lpar2rrd -e XORMON=1 docker.io/cliffordw/lpar2rrd:7.95

Application UI can be found on `http://<CONTAINER_IP>`, use admin/admin for login.

# IBM Power Systems: Free edition is restricted to monitoring 4 HMCs

One of the "enhancements" in LPAR2RRD version [7.40](https://lpar2rrd.com/note740.php) is that for IBM Power Systems, the *Free edition is restricted to monitoring 4 HMCs*.

This results in an error message like this in the configuration page:

> You are using LPAR2RRD Free Edition, a maximum of 4 active HMC devices are allowed.

Packaging background:

The distribution tarball contains a file called `lpar2rrd.tar.Z`. The code is in here, in a `dist/` subdirectory.
The `lpar2rrd.tar.Z` archive is unpacked during container startup first run, by the `scripts/install.sh` script.
Below notes apply to contents of that directory.

This seems to be coded in the following places:

- In main distribution package contents:
	- `scripts/update.sh` also checks this, but only to show a warning
		- Checks using perl `HostCfg::getUnlicensed()` call
		- see `bin/HostCfg.pm` below
- In `lpar2rrd.tar.Z` contents, under the `dist/` directory:
	- Contents of `html/` ends up in `www/` after installation.
	- `html/jquery/main.js` contains this key code:
		- line 5725: `if (sysInfo.variant.indexOf('p') == -1 && activeDevices >= 4)`
	- `html/jquery/main.js` also contains a limitation stating "only the first 4 lpars/pools per group will be graphed", in:
		- line 4724: `if (sysInfo.free == 1 && count > 4)`
	- `bin/HostCfg.pm` contains the `getUnlicensed()` function mentioned above
		- Fix with: `sed -ie 's/sub getUnlicensed {/sub getUnlicensed {\n  return;/' bin/HostCfg.pm`

If we can identify all the places where this is enforced, one (GPL legal) approach might be to modify the `startup.sh` script (container entrypoint) to modify the relevant scripts at the end of the `if [ -f /firstrun ]` section.
