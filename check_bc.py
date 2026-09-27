import glob
import subprocess

for path in sorted(glob.glob("**/*.luau", recursive=True)):
    result = subprocess.run(["luau_bin/luau-compile.exe", path], capture_output=True)
    if result.returncode == 0:
        print(f"{path}: {len(result.stdout):,} bytes bytecode")
    else:
        print(f"{path}: COMPILE ERROR")
        print(result.stderr.decode("utf-8", errors="replace"))
