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

const DEFAULT_OUTPUT_DIR = "raw";
const DEFAULT_MEDIA_DIR = "/media";
const DEFAULT_BUFFER_SIZE = 1024 * 1024;

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

    string mediaSearchDir = DEFAULT_MEDIA_DIR;
    string outputDir = buildPath(getcwd(), DEFAULT_OUTPUT_DIR);
	size_t bufferSize = DEFAULT_BUFFER_SIZE;
    bool force = false;
	bool dryRun = false;

    auto helpInfo = getopt(
        args,
        "mediaDir|i",
		format!"The base directory from which to search for the GoPro media. Defaults to \"%s\"."(mediaSearchDir),
		&mediaSearchDir,
        "outputDir|o",
		format!"The directory to copy data to. Defaults to \"%s\". Will create the directory if it doesn't exist yet."(outputDir),
		&outputDir,
        "force|f",
		format!"Whether to forcibly overwrite existing files. Defaults to %s."(force),
		&force,
		"dryRun|d",
		format!"Whether to perform a dry-run (don't actually copy anything). Defaults to %s."(dryRun),
		&dryRun,
		"bufferSize|b",
		format!"The size of the buffer for copying files, in bytes. Defaults to %s."(formatFilesize(DEFAULT_BUFFER_SIZE)),
		&bufferSize
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
    string goProDir = nullableGoProDir.get();
    writefln!"Found GoPro media at %s."(goProDir);
    return copyFiles(goProDir, outputDir, bufferSize, force, dryRun);
}
