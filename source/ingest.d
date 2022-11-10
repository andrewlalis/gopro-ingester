module ingest;

import std.file;
import std.stdio;
import std.path;
import std.algorithm;
import std.string;
import std.typecons;
import filesizes;
import progress;

private struct IngestData {
    DirEntry[] filesToCopy;

    ulong totalFileSize() {
        return filesToCopy.map!(f => f.size).sum;
    }

    size_t fileCount() {
        return filesToCopy.length;
    }
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

private IngestData discoverIngestData(string sourceDir, string targetDir, bool force) {
    IngestData data;
    foreach (DirEntry entry; dirEntries(sourceDir, SpanMode.shallow)) {
        string targetFile = buildPath(targetDir, baseName(entry.name));
        if (shouldCopyFile(entry, targetFile, force)) {
            data.filesToCopy ~= entry;
        }
    }
    return data;
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
public int copyFiles(string sourceDir, string targetDir, size_t bufferSize, bool force, bool dryRun) {
    IngestData ingestData = discoverIngestData(sourceDir, targetDir, force);
    if (ingestData.fileCount == 0) {
        writeln("No new files to copy.");
        return 0;
    }
	if (getAvailableDiskSpace(targetDir) < ingestData.totalFileSize) {
		writefln!"Not enough disk space to copy all files: %s available, %s needed."(
			formatFilesize(getAvailableDiskSpace(targetDir)),
			formatFilesize(ingestData.totalFileSize)
		);
		return 1;
	}
    writefln!"Copying %d files (%s) to %s."(ingestData.fileCount, formatFilesize(ingestData.totalFileSize), targetDir);
	if (dryRun) writeln("(Dry Run)");

    if (!exists(targetDir) && !dryRun) mkdirRecurse(targetDir);

    Bar progressBar = new FillingSquaresBar();
    progressBar.width = 80;
    progressBar.max = ingestData.totalFileSize;
    progressBar.start();
	ubyte[] buffer = new ubyte[bufferSize];
    foreach (DirEntry entry; ingestData.filesToCopy) {
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