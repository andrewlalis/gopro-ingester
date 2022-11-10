# GoPro-Ingester
A simple tool for ingesting footage from a GoPro media card.

### Getting Started
You can either directly download one of the executable binaries available on the **releases** page, or follow the instructions below to build it yourself:
```shell
git clone git@github.com:andrewlalis/gopro-ingester.git
cd gopro-ingester
dub build
```
> You'll need to have the D compiler toolchain and Dub installed to do this.

### Ingesting Footage
To ingest footage, simply run the executable. It will search for a GoPro media card on your file system, and if one is found, it'll begin copying data to an output directory. By default, it copies to a directory named `raw`, relative to where you invoked the program.

It'll only copy `.MP4` and `.WAV` files, and ignores `.THM` and `.LVM` files that are only used by GoPro's own apps.

This tool comes with a variety of options, which you can view by running `gopro-ingester --help`. I've also included a brief overview of them here:

- `--mediaDir` - The base directory from which to begin searching for a GoPro media card.
- `--outputDir` - The directory to copy data to.
- `--force` - Forcibly overwrite existing files.
- `--dryRun` - Perform a dry-run (and don't actually copy anything).
- `--bufferSize` - The size of the memory buffer for copying.
- `--clean` - Delete copied items from the GoPro's media card afterwards.
- `--help` - Shows help information.

### System Compatibility
Currently, this software is known to work with the following GoPro models:
- Hero 9

And the following operating systems:
- Linux/Ubuntu
- MacOS

If you've got the time and hardware, I'd greatly appreciate if you could test this software on your own device, and make a PR to add it to the list here, or an issue if something doesn't work.
