import std.typecons;
import std.path;
import std.file;
import std.stdio;
import std.string;
import std.algorithm;
import std.getopt;
import filesizes;
import progress;

import utils;
import ingest;

const DEFAULT_MEDIA_DIR = "/media";
const DEFAULT_OUTPUT_DIR = "raw";

int main(string[] args) {
	writeln(
		"+---------------------------------+\n" ~
		"|                                 |\n" ~
		"|       GoPro Ingester            |\n" ~
		"|         v1.0.0                  |\n" ~
		"|         by Andrew Lalis         |\n" ~
		"|                                 |\n" ~
		"+---------------------------------+\n"
	);
    IngestConfig config;
    config.outputDir = buildPath(getcwd(), DEFAULT_OUTPUT_DIR);
    string mediaSearchDir = DEFAULT_MEDIA_DIR;
    auto helpInfo = getopt(
        args,
        "mediaDir|i",
		format!"The base directory from which to search for the GoPro media. Defaults to \"%s\"."(mediaSearchDir),
		&mediaSearchDir,
        "outputDir|o",
		format!"The directory to copy data to. Defaults to \"%s\". Will create the directory if it doesn't exist yet."(config.outputDir),
		&config.outputDir,
        "force|f",
		format!"Whether to forcibly overwrite existing files. Defaults to %s."(config.force),
		&config.force,
		"dryRun|d",
		format!"Whether to perform a dry-run (don't actually copy anything). Defaults to %s."(config.dryRun),
		&config.dryRun,
		"bufferSize|b",
		format!"The size of the buffer for copying files, in bytes. Defaults to %s."(formatFilesize(config.bufferSize)),
		&config.bufferSize,
        "clean|c",
        format!"Whether to remove files from the GoPro media card after copying. Defaults to %s."(config.clean),
        &config.clean
    );

    if (helpInfo.helpWanted) {
        defaultGetoptPrinter("Ingestion tool for importing data from GoPro media cards.", helpInfo.options);
        return 0;
    }

    auto nullableGoProDir = getGoProDir(mediaSearchDir);
    if (nullableGoProDir.isNull) {
        writeln("Couldn't find GoPro directory.");
        return 1;
    }
    config.inputDir = nullableGoProDir.get();
    writefln!"Found GoPro media at %s."(config.inputDir);
    return copyFiles(config);
}
