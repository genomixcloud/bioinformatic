# <Tool>

<!-- short: <Tool> <version>: <what it does, in one line>. Max 100 characters. -->

Ready-to-run Linux (Ubuntu, `linux/amd64`) image of [<Tool>](<upstream URL>) <version> for <purpose>. Part of the [Genomix Cloud](https://genomixcloud.com/) bioinformatic tools.

## Tags

| Tag | <Tool> | Other tools in the image |
|-----|--------|--------------------------|
| `<version>`, `latest` | <version> | <tool x.y.z>, ... |

## Quick start

```shell
docker pull genomixcloud/<tool>
docker run --rm genomixcloud/<tool> /src/<tool>.sh --version

# Mount the folder with your data at /data
docker run --rm --mount src="$(pwd)",target=/data,type=bind \
  genomixcloud/<tool> /src/<tool>.sh <options> <input>
```

## Requirements

* **Input:** <format>
* **Database:** <none, or where to get it>
* **Resources:** <CPUs and memory>

## Documentation

Full documentation, test data and build instructions: [tools/<tool> on GitHub](https://github.com/genomixcloud/bioinformatic/tree/main/tools/<tool>).

## Licence

<Tool> is distributed under its own licence: [<licence name>](<licence URL>). The image only packages it.
