"""Adapt CLB's published Base image field to the upstream CLI's two image inputs."""

import argparse
import shutil
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory

from swebench.task.checks import expected_image
from swebench.task.repo import dump_yaml, load_yaml, task_dirs

from .tasks import load_base_images, published_base_image


DATASET = "Alex-cpu0814/CLB-SWE-bench"


def swebench(*arguments):
    return subprocess.call(["swebench", *map(str, arguments)])


def evaluation_checkout(repo: Path, destination: Path) -> dict[str, str]:
    """Give SWE-bench task files with a separate, locally built Eval image tag."""
    shutil.copy2(repo / "sweb.yaml", destination)
    shutil.copytree(repo / "eval", destination / "eval")
    images = {}
    for task in task_dirs(repo):
        metadata = load_yaml(task / "task.yaml")
        images[task.name] = metadata["image"]
        if images[task.name] != published_base_image(task.name):
            raise ValueError(f"Unexpected published Base image: {task.name}")
        metadata["image"] = expected_image(task.name)
        target = destination / "tasks" / task.name
        shutil.copytree(task, target)
        (target / "task.yaml").write_text(dump_yaml(metadata), encoding="utf-8")
    return images


def infer(repo: Path, arguments: list[str]) -> int:
    import pyarrow as pa
    import pyarrow.parquet as pq

    references = load_base_images(repo)
    splits = {}
    for task in task_dirs(repo):
        metadata = load_yaml(task / "task.yaml")
        image = metadata["image"]
        if image != published_base_image(task.name):
            raise ValueError(f"Unexpected published Base image: {task.name}")
        digest = references[task.name].split("@", 1)[1]
        splits.setdefault(metadata["split"], []).append({
            "instance_id": task.name,
            "problem_statement": (task / "problem_statement.md").read_bytes().decode("utf-8"),
            "image_name": f"{image}@{digest}",
        })
    with TemporaryDirectory(prefix="clb-inference-") as directory:
        for split, rows in splits.items():
            pq.write_table(pa.Table.from_pylist(rows), Path(directory) / f"{split}.parquet")
        return swebench("infer", directory, *arguments)


def evaluate(repo: Path, arguments: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="clb eval", add_help=False, allow_abbrev=False)
    parser.add_argument("-r", "--run-id", required=True)
    options, forwarded = parser.parse_known_args(arguments)
    run_id = options.run_id
    if run_id in {".", ".."} or any(separator in run_id for separator in ("/", "\\")) or not run_id:
        parser.error("--run-id must be a single directory name")
    if any(arg.split("=", 1)[0] == "--task-repo" for arg in forwarded):
        parser.error("run clb eval from the CLB task repository")

    # Keep the same evaluation inputs for re-grading with swebench report.
    snapshot = repo / "logs" / "evaluation" / run_id / "task-repo"
    if not snapshot.exists():
        snapshot.parent.mkdir(parents=True, exist_ok=True)
        with TemporaryDirectory(dir=snapshot.parent) as directory:
            checkout = Path(directory) / "checkout"
            checkout.mkdir()
            evaluation_checkout(repo, checkout)
            checkout.rename(snapshot)
    return swebench("eval", DATASET, "--task-repo", snapshot, "--run-id", run_id, *forwarded)


def export(repo: Path, command: str, arguments: list[str]) -> int:
    import pyarrow as pa
    import pyarrow.parquet as pq
    from swebench.task.publish import guard, write_parquets

    parser = argparse.ArgumentParser(prog=f"clb {command}")
    if command == "build":
        parser.add_argument("-o", "--output", type=Path, required=True)
    options = parser.parse_args(arguments)
    with TemporaryDirectory(prefix="clb-export-") as directory:
        checkout = Path(directory)
        images = evaluation_checkout(repo, checkout)
        if command == "check":
            guard(checkout)
            print(f"Checked {len(images)} CLB tasks")
            return 0

        files = write_parquets(checkout, options.output)
        for path in files.values():
            if path.suffix != ".parquet":
                continue
            table = pq.read_table(path)
            index = table.schema.get_field_index("image")
            bases = pa.array([images[iid] for iid in table["instance_id"].to_pylist()])
            pq.write_table(table.set_column(index, table.schema.field(index), bases), path)
            print(f"Wrote {path}")
        shutil.copy2(repo / "docs" / "dataset-card.md", options.output / "CLB-SWE-bench" / "README.md")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Run official SWE-bench tools on CLB's task repository.")
    parser.add_argument("command", choices=("infer", "eval", "check", "build"))
    parser.add_argument("arguments", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    repo = Path.cwd()
    if args.command in {"infer", "eval"} and any(arg in {"-h", "--help"} for arg in args.arguments):
        return swebench(args.command, "--help")
    if args.command == "infer":
        return infer(repo, args.arguments)
    if args.command == "eval":
        return evaluate(repo, args.arguments)
    return export(repo, args.command, args.arguments)
