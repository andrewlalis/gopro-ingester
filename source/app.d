import std.typecons;
import std.path;
import std.file;
import std.stdio;
import std.string;
import std.algorithm;
import std.getopt;
import filesizes;
import progress;

const DEFAULT_OUTPUT_DIR = "raw";
const DEFAULT_MEDIA_DIR = "/media";
const GOPRO_CONTENT_DIR = "DCIM/100GOPRO";
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

/** 
 * Tries to find a GoPro's media directory.
 * Params:
 *   baseDir = The base directory to start the search from.
 * Returns: A nullable string that, if present, refers to the GoPro's media
 * directory.
 */
Nullable!string getGoProDir(string baseDir) {
    if (!exists(baseDir) || !isDir(baseDir)) return Nullable!string.init;
    foreach (dir; std.file.dirEntries(baseDir, SpanMode.breadth)) {
        string mediaPath = buildPath(dir.name, GOPRO_CONTENT_DIR);
        if (exists(mediaPath) && isDir(mediaPath)) {
            return nullable(mediaPath);
        }
    }
    return Nullable!string.init;
}

/** 
 * Determines if we should copy a given file from the media card to the local
 * directory.
 * Params:
 *   entry = The entry for the file at its source.
 *   targetFile = The place to copy the file to.
 *   force = Whether the force flag has been set.
 * Returns: True if we should copy the file, or false otherwise.
 */
bool shouldCopyFile(DirEntry entry, string targetFile, bool force) {
    return entry.isFile() &&
        (entry.name.endsWith(".MP4") || entry.name.endsWith(".WAV")) &&
        (!exists(targetFile) || getSize(targetFile) != entry.size || force);
}

/** 
 * Copies files from a source to a target directory.
 * Params:
 *   sourceDir = The source directory.
 *   targetDir = The target directory.
 *   bufferSize = The buffer size to use when copying.
 *   force = Whether to overwrite existing files.
 *   dryRun = Whether to perform a dry-run.
 * Returns: An exit code.
 */
int copyFiles(string sourceDir, string targetDir, size_t bufferSize, bool force, bool dryRun) {
    if (!exists(targetDir) && !dryRun) mkdirRecurse(targetDir);
    DirEntry[] filesToCopy;
    ulong totalFileSize = 0;
    foreach (DirEntry entry; dirEntries(sourceDir, SpanMode.shallow)) {
        string targetFile = buildPath(targetDir, baseName(entry.name));
        if (shouldCopyFile(entry, targetFile, force)) {
            filesToCopy ~= entry;
            totalFileSize += entry.size;
        }
    }

    if (filesToCopy.length == 0) {
        writeln("No new files to copy.");
        return 0;
    }

	if (getAvailableDiskSpace(targetDir) < totalFileSize) {
		writefln!"Not enough disk space to copy all files: %s available, %s needed."(
			formatFilesize(getAvailableDiskSpace(targetDir)),
			formatFilesize(totalFileSize)
		);
		return 1;
	}

    writefln!"Copying %d files (%s) to %s."(filesToCopy.length, formatFilesize(totalFileSize), targetDir);
	if (dryRun) writeln("(Dry Run)");
    Bar progressBar = new FillingSquaresBar();
    progressBar.width = 80;
    progressBar.max = totalFileSize;
    progressBar.start();
	ubyte[] buffer = new ubyte[bufferSize];
    foreach (DirEntry entry; filesToCopy) {
        string filename = baseName(entry.name);
        string targetFile = buildPath(targetDir, filename);
		string verb = exists(targetFile) ? "Overwriting" : "Copying";
        progressBar.message = { return std.string.format!"%s %s (%s)"(verb, filename, formatFilesize(entry.size)); };
		if (!dryRun) {
			File inputFile = File(entry.name, "rb");
			File outputFile = File(targetFile, "wb");
			foreach (ubyte[] localBuffer; inputFile.byChunk(buffer)) {
				outputFile.rawWrite(localBuffer);
				progressBar.next(localBuffer.length);
			}
		} else {
			progressBar.next(getSize(entry.name));
		}
    }
    progressBar.finish();

	return 0;
}
