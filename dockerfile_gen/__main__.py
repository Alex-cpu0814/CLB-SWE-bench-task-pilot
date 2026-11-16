"""Generate or verify CLB's checked-in Dockerfile and eval.sh files."""

import argparse
from pathlib import Path

from yaml import YAMLError

from .tasks import plan_updates, write_generated


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("task_repo", nargs="?", default=Path.cwd(), type=Path)
    parser.add_argument("--instance_ids", nargs="+", default=[], help="Select tasks by instance ID")
    parser.add_argument("-i", "--instance", action="append", default=[], help="Select one instance (repeatable)")
    parser.add_argument("--check", action="store_true", help="Report missing or stale generated files")
    args = parser.parse_args()

    try:
        task_count, updates = plan_updates(args.task_repo, args.instance_ids + args.instance)
    except (OSError, KeyError, ValueError, YAMLError) as exc:
        parser.error(str(exc))

    if args.check:
        for path in updates:
            print(f"Missing or stale: {path.relative_to(args.task_repo)}")
        print(f"Checked {task_count} tasks, {len(updates)} files differ.")
        return int(bool(updates))

    write_generated(updates)
    print(f"Generated files for {task_count} tasks, wrote {len(updates)} files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
