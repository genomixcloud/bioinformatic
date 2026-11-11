# Docker Hub descriptions

This folder holds the text of the Docker Hub pages of the images in [`tools/`](../tools). It isn't used to build the images.

## Files

* `<tool>.md`: the page of `genomixcloud/<tool>`. The file name is the image name, the same as `DOCKER_IMAGE` in the [Makefile](../Makefile).
* [`_template.md`](_template.md): starting point for a new tool.

Each file has two parts:

1. **Short description**: the first line after the title, in a `<!-- short: ... -->` comment. It goes in the "Short description" field of the repository on Docker Hub, which accepts at most 100 characters.
2. **Overview**: the rest of the file. It goes in the "Repository overview" on Docker Hub, which accepts at most 25,000 characters.

## Writing rules

* **Keep it short** and link to `tools/<tool>/README.md` on GitHub for the full documentation, so the same text isn't kept in two places.
* **Use absolute links.** Docker Hub doesn't resolve relative links, so write `https://github.com/genomixcloud/bioinformatic/...`, not `../tools/...`.
* **List the versions in the image.** For each tag, give the main tool's version and the tools that come with it.
* **Update the file** when you push a new tag.

## Publishing

For now, copy the text into the repository settings on Docker Hub by hand (*Repository → General → Edit*). You need to be logged in with an account that can write to the `genomixcloud` organisation.
