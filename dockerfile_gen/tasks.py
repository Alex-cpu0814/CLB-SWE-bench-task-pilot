"""Read CLB tasks and update their generated files."""

import json
from pathlib import Path

from swebench.task.repo import load_yaml, task_dirs

from . import render_files


def plan_updates(task_repo: Path, instance_ids: list[str] | None) -> tuple[int, dict[Path, bytes]]:
    """Return the number of selected tasks and the files that need to be written."""
    tasks = {path.name: path for path in task_dirs(task_repo)}
    references = json.loads((task_repo / "base-images.json").read_bytes())
    if not tasks or tasks.keys() != references.keys():
        raise ValueError("Task directories and the Base image manifest must cover the same instances")
    selected = sorted(set(instance_ids or tasks))
    if unknown := set(selected) - tasks.keys():
        raise ValueError(f"Unknown instances: {', '.join(sorted(unknown))}")

    updates = {}
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
    return len(selected), updates


def write_generated(updates: dict[Path, bytes]) -> None:
    for path, content in updates.items():
        path.write_bytes(content)
