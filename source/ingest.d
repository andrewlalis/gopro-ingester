module ingest;

import std.file;
import std.stdio;
import std.path;
import std.algorithm;
import std.string;
import std.typecons;
import filesizes;
import progress;

const DEFAULT_BUFFER_SIZE = 1024 * 1024;

private struct IngestData {
    DirEntry[] filesToCopy;

    ulong totalFileSize() {
        return filesToCopy.map!(f => f.size).sum;
    }

    size_t fileCount() {
        return filesToCopy.length;
    }
}

public struct IngestConfig {
    string inputDir;
    string outputDir;
    size_t bufferSize = DEFAULT_BUFFER_SIZE;
    bool force = false;
    bool dryRun = false;
    bool clean = false;
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
private bool shouldCopyFile(DirEntry entry, string targetFile, bool force) {
    return entry.isFile() &&
        (entry.name.endsWith(".MP4") || entry.name.endsWith(".WAV")) &&
        (!exists(targetFile) || getSize(targetFile) != entry.size || force);
}

/** 
 * Searches for relevant files to ingest.
 * Params:
 *   config = The ingest config.
 * Returns: Data about what to ingest.
 */
private IngestData discoverIngestData(IngestConfig config) {
    IngestData data;
    foreach (DirEntry entry; dirEntries(config.inputDir, SpanMode.shallow)) {
        string targetFile = buildPath(config.outputDir, baseName(entry.name));
        if (shouldCopyFile(entry, targetFile, config.force)) {
            data.filesToCopy ~= entry;
        }
    }
    return data;
}

/** 
 * Copies files from a source to a target directory.
 * Params:
 *   config = The configuration for the ingest operation.
 * Returns: An exit code.
 */
public int copyFiles(IngestConfig config) {
    IngestData ingestData = discoverIngestData(config);
    if (ingestData.fileCount == 0) {
        writeln("No new files to copy.");
        return 0;
    }
	if (getAvailableDiskSpace(config.outputDir) < ingestData.totalFileSize) {
		writefln!"Not enough disk space to copy all files: %s available, %s needed."(
			formatFilesize(getAvailableDiskSpace(config.outputDir)),
			formatFilesize(ingestData.totalFileSize)
		);
		return 1;
	}
    writefln!"Copying %d files (%s) to %s."(ingestData.fileCount, formatFilesize(ingestData.totalFileSize), config.outputDir);
	if (config.dryRun) writeln("(Dry Run)");

    if (!exists(config.outputDir) && !config.dryRun) mkdirRecurse(config.outputDir);
    
	ubyte[] buffer = new ubyte[config.bufferSize];
    foreach (DirEntry entry; ingestData.filesToCopy) {
        string filename = baseName(entry.name);
        string targetFile = buildPath(config.outputDir, filename);
		string verb = exists(targetFile) ? "Overwriting" : "Copying";
        Bar progressBar = new FillingSquaresBar();
        progressBar.width = 40;
        progressBar.max = entry.size;
        string message = format!"%s %s (%s)"(verb, filename, formatFilesize(entry.size))
            .leftJustify(40, ' ');
        progressBar.message = { return message; };
        progressBar.start();
		if (!config.dryRun) {
			File inputFile = File(entry.name, "rb");
			File outputFile = File(targetFile, "wb");
			foreach (ubyte[] localBuffer; inputFile.byChunk(buffer)) {
				outputFile.rawWrite(localBuffer);
				progressBar.next(localBuffer.length);
			}
		} else {
			progressBar.next(getSize(entry.name));
		}
        progressBar.finish();
    }

    if (config.clean && !config.dryRun) {
        writeln("Cleaning GoPro media card.");
        string[] filesToRemove;
        foreach (string filename; dirEntries(config.inputDir, SpanMode.shallow)) {
            filesToRemove ~= filename;
        }
        Bar progressBar = new FillingSquaresBar();
        progressBar.max = filesToRemove.length;
        progressBar.width = 80;
        progressBar.start();
        foreach (string filename; filesToRemove) {
            std.file.remove(filename);
            progressBar.next();
        }
        progressBar.finish();
        string trashDir = buildNormalizedPath(config.inputDir, "..", "..", ".Trash-1000");
        if (exists(trashDir) && isDir(trashDir)) {
            writefln!"Removing \"%s\"."(trashDir);
            rmdirRecurse(trashDir);
        }
    }

	return 0;
}