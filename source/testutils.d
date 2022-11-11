module testutils;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.string;
import utils;

struct DirView {
    DirEntry[] entries;
}

DirView getDirView(string dir) {
    DirView view;
    foreach (DirEntry entry; dirEntries(dir, SpanMode.shallow)) {
        view.entries ~= entry;
    }
    view.entries.sort!((a, b) => a.name > b.name);
    return view;
}

string getBaseCardDir(string name) {
    return buildPath("test", "media-cards", "card-" ~ name);
}

string getTestCardDir(string name) {
    return buildPath("test", "media-cards", "card-test-" ~ name);
}

void assertCardsUnchanged(string[] cards ...) {
    foreach (string card; cards) {
        string baseDir = getBaseCardDir(card);
        string testDir = getTestCardDir(card);
        if (exists(testDir)) {
            assert(getDirView(baseDir) == getDirView(testDir));
        }
    }
}

void prepareCardTests(string[] cards ...) {
    foreach (string card; cards) {
        copyDir(getBaseCardDir(card), getTestCardDir(card));
    }
}

void cleanupCardTests(string[] cards ...) {
    foreach (string card; cards) {
        rmdirRecurse(getTestCardDir(card));
    }
}