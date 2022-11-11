import utils;
import ingest;

int main(string[] args) {
	printBanner();
    CliResult result = parseArgs(args);
    if (result.type == CliResultType.NO_CONTENT) {
        return 0;
    } else if (result.type == CliResultType.MISSING_MEDIA) {
        return 1;
    } else {
        return copyFiles(result.config);
    }
}

unittest {
    // First some utilities to make the tests simpler.
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

    int callApp(string[] args ...) {
        return main(["app"] ~ args);
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

    string[] allCards = ["1", "2", "3"];
    prepareCardTests(allCards);
    writeln(isDir(getBaseCardDir("1")));
    assert(callApp("-h") == 0);
    assertCardsUnchanged(allCards);
    assert(callApp("--help") == 0);
    assertCardsUnchanged(allCards);
    assert(callApp("-f", "-h") == 0);
    assertCardsUnchanged(allCards);
    // Ingesting from an empty card shouldn't have any effect.
    assert(callApp("-i", getTestCardDir("1")) == 0);
    assertCardsUnchanged("1");
}
