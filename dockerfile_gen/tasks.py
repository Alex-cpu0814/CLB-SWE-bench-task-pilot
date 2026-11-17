"""Read CLB tasks and update their generated files."""

import json
from pathlib import Path

from swebench.task.repo import load_yaml, task_dirs

from . import render_files


def published_base_image(instance_id: str) -> str:
    repository = instance_id.replace("__", "_1776_").lower()
    return f"yutu0814/sweb.eval.x86_64.{repository}:latest"


def load_base_images(task_repo: Path) -> dict[str, str]:
    manifest = task_repo / "dockerfile_gen" / "data" / "base-images.json"
    try:
        contents = manifest.read_bytes()
    except FileNotFoundError:
        # Older task checkouts put the manifest at the repository root.
        contents = (task_repo / "base-images.json").read_bytes()
    return json.loads(contents)


def plan_updates(task_repo: Path, instance_ids: list[str] | None) -> tuple[int, dict[Path, bytes]]:
    """Return the number of selected tasks and the files that need to be written."""
    tasks = {path.name: path for path in task_dirs(task_repo)}
    references = load_base_images(task_repo)
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
        if metadata["image"] != published_base_image(name):
            raise ValueError(f"Unexpected published Base image: {name}")
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
