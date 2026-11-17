"""Prepare CLB for local SWE-bench runs or export a release."""

import argparse
import shutil
from contextlib import closing
from pathlib import Path
from tempfile import TemporaryDirectory

import docker
import pyarrow as pa
import pyarrow.parquet as pq
from docker.errors import DockerException
from swebench.task.checks import expected_image
from swebench.task.publish import write_parquets
from swebench.task.repo import dump_yaml, load_yaml, task_dirs

from dockerfile_gen.utils import task_image


DATASET_NAME = "SWE-bench_CLB"


def copy_tasks(repo: Path, checkout: Path) -> dict[str, str]:
    """Copy task files with the image names required by the official checker."""
    shutil.copy2(repo / "sweb.yaml", checkout)
    shutil.copytree(repo / "eval", checkout / "eval")
    images = {}
    for task in task_dirs(repo):
        metadata = load_yaml(task / "task.yaml")
        images[task.name] = task_image(task.name, metadata)
        metadata["image"] = expected_image(task.name)
        metadata.pop("image_name", None)
        target = checkout / "tasks" / task.name
        shutil.copytree(task, target)
        (target / "task.yaml").write_text(dump_yaml(metadata), encoding="utf-8")
    return images


def tag_images(images: dict[str, str]) -> None:
    with closing(docker.from_env(timeout=180)) as client:
        cached = {
            tag: image["Id"]
            for image in client.api.images()
            for tag in image.get("RepoTags") or []
        }
        for index, (instance_id, source) in enumerate(images.items(), start=1):
            alias = expected_image(instance_id)
            print(f"[{index}/{len(images)}] {source} -> {alias}", flush=True)
            image_id = cached.get(source)
            if image_id is None:
                image_id = client.images.pull(source, platform="linux/amd64").id
            if cached.get(alias) != image_id:
                image = client.images.get(image_id)
                if not image.tag(alias) or client.images.get(alias).id != image_id:
                    raise RuntimeError(f"Alias does not refer to the source image: {alias}")


def export_for_publish(
    repo: Path, checkout: Path, output: Path, images: dict[str, str]
) -> None:
    for path in write_parquets(checkout, output).values():
        if path.suffix != ".parquet":
            continue
        table = pq.read_table(path)
        index = table.schema.get_field_index("image")
        published = pa.array([images[iid] for iid in table["instance_id"].to_pylist()])
        pq.write_table(table.set_column(index, table.schema.field(index), published), path)
        print(f"Wrote {path}")
    shutil.copy2(repo / "docs" / "dataset-card.md", output / DATASET_NAME / "README.md")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-o", "--output", type=Path, required=True)
    parser.add_argument(
        "--for-publish", action="store_true",
        help="Export data with the public Docker Hub image addresses",
    )
    options = parser.parse_args()
    repo = Path(__file__).resolve().parent
    output = options.output.resolve()
    if not options.for_publish and output.exists():
        parser.error(f"Output directory already exists: {output}")

    try:
        output.parent.mkdir(parents=True, exist_ok=True)
        with TemporaryDirectory(prefix=".clb-prepare-", dir=output.parent) as directory:
            staging = Path(directory) / "output"
            checkout = staging / "task-repo"
            checkout.mkdir(parents=True)
            images = copy_tasks(repo, checkout)
            if options.for_publish:
                export_for_publish(repo, checkout, output, images)
            else:
                write_parquets(checkout, staging / "dataset")
                tag_images(images)
                staging.rename(output)
                print(f"Task repository: {output / 'task-repo'}")
                print(f"Dataset: {output / 'dataset' / DATASET_NAME}")
    except (DockerException, OSError, RuntimeError, ValueError) as error:
        parser.exit(1, f"{parser.prog}: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
