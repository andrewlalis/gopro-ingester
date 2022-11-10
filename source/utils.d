module utils;

import std.typecons;
import std.file;
import std.path;

/** 
 * Tries to find a GoPro's media directory.
 * Params:
 *   baseDir = The base directory to start the search from.
 * Returns: A nullable string that, if present, refers to the GoPro's media
 * directory.
 */
public Nullable!string getGoProDir(string baseDir) {
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