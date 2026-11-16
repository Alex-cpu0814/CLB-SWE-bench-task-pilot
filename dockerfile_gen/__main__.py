"""Generate or verify CLB's checked-in Dockerfile and eval.sh files."""

import argparse
import json
from pathlib import Path

from yaml import YAMLError
from swebench.task.repo import load_yaml, task_dirs

from . import render_files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("task_repo", nargs="?", default=Path.cwd(), type=Path)
    parser.add_argument("-i", "--instance", action="append", help="Select tasks by instance ID (repeatable)")
    parser.add_argument("--check", action="store_true", help="Report missing or stale generated files")
    args = parser.parse_args()

    updates = {}
    try:
        tasks = {path.name: path for path in task_dirs(args.task_repo)}
        references = json.loads((args.task_repo / "base-images.json").read_bytes())
        if not tasks or tasks.keys() != references.keys():
            raise ValueError("Task directories and the Base image manifest must cover the same instances")
        selected = sorted(set(args.instance or tasks))
        if unknown := set(selected) - tasks.keys():
            raise ValueError(f"Unknown instances: {', '.join(sorted(unknown))}")
        for name in selected:
            directory = tasks[name]
            metadata = load_yaml(directory / "task.yaml")
            if metadata["instance_id"] != name:
                raise ValueError(f"Task metadata does not match directory name: {name}")
            patch = (directory / "test.patch").read_bytes().decode("utf-8")
            generated = render_files(name, metadata["cohort"], metadata["base_commit"], references[name], patch)
            for filename, content in generated.items():
                path = directory / filename
                if not path.is_file() or path.read_bytes() != content:
                    updates[path] = content
    except (OSError, KeyError, ValueError, YAMLError) as exc:
        parser.error(str(exc))

    if args.check:
        for path in updates:
            print(f"Missing or stale: {path.relative_to(args.task_repo)}")
        print(f"Checked {len(selected)} tasks, {len(updates)} files differ.")
        return int(bool(updates))

    for path, content in updates.items():
        path.write_bytes(content)
    print(f"Generated files for {len(selected)} tasks, wrote {len(updates)} files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
