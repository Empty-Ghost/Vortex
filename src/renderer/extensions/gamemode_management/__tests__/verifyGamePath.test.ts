import * as fs from "fs-extra";
import * as os from "os";
import * as path from "path";
import PromiseBB from "bluebird";

import { verifyGamePath, statCaseInsensitive } from "../index";
import type { IGame } from "../../../types/IGame";

// Minimal IGame stub — only requiredFiles matters for verifyGamePath
function makeGame(requiredFiles: string[]): IGame {
  return {
    id: "test-game",
    name: "Test Game",
    requiredFiles,
    executable: () => "game.exe",
    logo: "",
    environment: {},
  } as unknown as IGame;
}

describe("statCaseInsensitive", () => {
  let tmpDir: string;

  beforeEach(async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "vortex-test-"));
  });

  afterEach(async () => {
    await fs.remove(tmpDir);
  });

  it("resolves when path components match exactly", async () => {
    await fs.mkdirp(path.join(tmpDir, "bin", "x64"));
    await fs.writeFile(path.join(tmpDir, "bin", "x64", "game.exe"), "");

    await expect(
      statCaseInsensitive(tmpDir, ["bin", "x64", "game.exe"]),
    ).resolves.toBeUndefined();
  });

  it("resolves when path components differ only in case", async () => {
    // Simulate Proton-installed game: directories use lowercase on disk
    await fs.mkdirp(path.join(tmpDir, "bin", "x64"));
    await fs.writeFile(path.join(tmpDir, "bin", "x64", "game.exe"), "");

    // requiredFiles entry uses uppercase (as shipped in Windows game extension)
    await expect(
      statCaseInsensitive(tmpDir, ["Bin", "X64", "Game.exe"]),
    ).resolves.toBeUndefined();
  });

  it("rejects with ENOENT when no matching entry exists", async () => {
    await fs.mkdirp(path.join(tmpDir, "bin"));

    const err = await statCaseInsensitive(tmpDir, ["bin", "missing.exe"]).catch(
      (e) => e,
    );
    expect(err.code).toBe("ENOENT");
  });
});

describe("verifyGamePath", () => {
  let tmpDir: string;

  beforeEach(async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "vortex-test-"));
  });

  afterEach(async () => {
    await fs.remove(tmpDir);
  });

  it("resolves when required files match exactly", async () => {
    await fs.mkdirp(path.join(tmpDir, "bin", "x64"));
    await fs.writeFile(path.join(tmpDir, "bin", "x64", "game.exe"), "");

    await expect(
      verifyGamePath(makeGame(["bin/x64/game.exe"]), tmpDir),
    ).resolves.toBeUndefined();
  });

  it("resolves when required files match case-insensitively on Linux", async () => {
    // On-disk casing is lowercase; requiredFiles uses Windows-style mixed case
    await fs.mkdirp(path.join(tmpDir, "bin", "x64"));
    await fs.writeFile(path.join(tmpDir, "bin", "x64", "game.exe"), "");

    await expect(
      verifyGamePath(makeGame(["Bin/X64/Game.exe"]), tmpDir),
    ).resolves.toBeUndefined();
  });

  it("resolves when required file omits .exe but on-disk file includes it", async () => {
    await fs.writeFile(path.join(tmpDir, "Sandfall.exe"), "");

    await expect(
      verifyGamePath(makeGame(["Sandfall"]), tmpDir),
    ).resolves.toBeUndefined();
  });

  it("resolves when required file includes .exe but on-disk file omits it", async () => {
    await fs.writeFile(path.join(tmpDir, "Sandfall"), "");

    await expect(
      verifyGamePath(makeGame(["Sandfall.exe"]), tmpDir),
    ).resolves.toBeUndefined();
  });

  it("resolves when requiredFiles is empty", async () => {
    await expect(
      verifyGamePath(makeGame([]), tmpDir),
    ).resolves.toBeUndefined();
  });

  it("rejects with ENOENT when no file matches even case-insensitively", async () => {
    await fs.mkdirp(path.join(tmpDir, "bin"));
    // no matching exe

    const err = await verifyGamePath(
      makeGame(["bin/x64/game.exe"]),
      tmpDir,
    ).catch((e) => e);
    expect(err.code).toBe("ENOENT");
  });
});
