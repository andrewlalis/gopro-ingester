module utils;

import std.typecons;
import ingest;

const DEFAULT_MEDIA_DIR = "/media";
const DEFAULT_OUTPUT_DIR = "raw";

public enum CliResultType {
    OK,
    NO_CONTENT,
    MISSING_MEDIA
}

public struct CliResult {
    CliResultType type;
    IngestConfig config;
}

public CliResult parseArgs(string[] args) {
    import std.path;
    import std.file;
    import std.getopt;
    import std.string;
    import std.stdio;
    import filesizes;
    CliResult result;
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
        result.type = CliResultType.NO_CONTENT;
        return result;
    } else {
        auto nullableGoProDir = getGoProDir(mediaSearchDir);
        if (nullableGoProDir.isNull) {
            writeln("Couldn't find GoPro directory.");
            result.type = CliResultType.MISSING_MEDIA;
        } else {
            config.inputDir = nullableGoProDir.get();
            writefln!"Found GoPro media at %s."(config.inputDir);
            result.type = CliResultType.OK;
            result.config = config;
        }
    }
    return result;
}

unittest {
    assert(parseArgs(["app", "-h"]).type == CliResultType.NO_CONTENT);
    // TODO: Expand tests.
}

public void printBanner() {
    import std.stdio : writeln;
    writeln(
		"+---------------------------------+\n" ~
		"|                                 |\n" ~
		"|       GoPro Ingester            |\n" ~
		"|         v1.0.0                  |\n" ~
		"|         by Andrew Lalis         |\n" ~
		"|                                 |\n" ~
		"+---------------------------------+\n"
	);
}

public bool endsWithAny(string s, string[] suffixes ...) {
    import std.algorithm : endsWith;
    foreach (string suffix; suffixes) {
        if (s.endsWith(suffix)) return true;
    }
    return false;
}

unittest {
    assert(endsWithAny("abc", "a", "b", "c"));
    assert(!endsWithAny("abc", "d"));
    assert(!endsWithAny("abc", "A", "B", "C"));
}

/** 
 * Copies all files from the given source directory, to the given destination
 * directory. Will create the destination directory if it doesn't exist yet.
 * Overwrites any files that already exist in the destination directory.
 * Params:
 *   sourceDir = The source directory to copy from.
 *   destDir = The destination directory to copy to.
 */
public void copyDir(string sourceDir, string destDir) {
    import std.file;
    if (!isDir(sourceDir)) return;
    if (exists(destDir) && !isDir(destDir)) return;
    if (!exists(destDir)) mkdirRecurse(destDir);
    import std.path : buildPath, baseName;
    foreach (DirEntry entry; dirEntries(sourceDir, SpanMode.shallow)) {
        string destPath = buildPath(destDir, baseName(entry.name));
        if (entry.isDir) {
            copyDir(entry.name, destPath);
        } else if (entry.isFile) {
            copy(entry.name, destPath);
        }
    }
}

/** 
 * Tries to find a GoPro's media directory.
 * Params:
 *   baseDir = The base directory to start the search from.
 * Returns: A nullable string that, if present, refers to the GoPro's media
 * directory.
 */
private Nullable!string getGoProDir(string baseDir) {
    import std.file;
    import std.path;
    if (!exists(baseDir) || !isDir(baseDir)) return Nullable!string.init;
    foreach (dir; std.file.dirEntries(baseDir, SpanMode.breadth)) {
        // We know that a GoPro contains DCIM/100GOPRO in it.
        string mediaPath = buildPath(dir.name, "DCIM", "100GOPRO");
        if (exists(mediaPath) && isDir(mediaPath)) {
            return nullable(mediaPath);
        }
    }
    return Nullable!string.init;
}
