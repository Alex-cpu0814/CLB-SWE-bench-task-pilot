# SWE-bench CLB task repository

[简体中文](docs/README.zh-CN.md)

SWE-bench CLB is a cross-language software repair benchmark with 72 Python–C and Java–C tasks.
Models generate patches from task statements and fixed source revisions. The official SWE-bench evaluator runs the tests.
[Hugging Face dataset](https://huggingface.co/datasets/Alex-cpu0814/SWE-bench_CLB) · [Task index](tasks/README.md)

| Task group | Instances |
| --- | ---: |
| Python–C with upstream tests | 50 |
| Java–C with CLB-authored tests | 11 |
| Java–C with upstream tests | 11 |

## Install

Run the commands in Bash on Linux or WSL 2. You need Git, Python 3.10 or later (3.11 or later recommended), and Docker with Linux amd64 image support.

~~~bash
git clone https://github.com/Alex-cpu0814/swe-bench-clb-tasks.git
cd swe-bench-clb-tasks
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -e .
~~~

This installs the pinned SWE-bench 5.0.2 and its dependencies and registers the `dockerfile-gen` command.
The `-e` flag lets the generator use the code in your working tree. Run the remaining commands from the repository root in the same Python environment.

## Prepare local images

Run the preparation command on the same Docker host that will run inference. The `image` field records the published Docker Hub address.
The script pulls any missing CLB images from `yutu0814/` and adds the local `swebench/` tags that mini-SWE-agent derives from task IDs. Both tags refer to the same image.

~~~bash
python prepare_dataset.py -o scratch/local-swebench
~~~

To check the generated task repository, run `swebench dataset check scratch/local-swebench/swe-bench-clb-tasks`.
You can also use the exported Parquet for inference and evaluation by passing `scratch/local-swebench/dataset/SWE-bench_CLB` as the dataset.

## Validate the reference patch

Run `--gold` on Fast Histogram 159 to check that the image, tests, and scoring work.

~~~bash
swebench eval Alex-cpu0814/SWE-bench_CLB --gold \
    -i astrofrog__fast-histogram-clb-159 \
    --run-id clb-159-gold \
    --task-repo scratch/local-swebench/swe-bench-clb-tasks
~~~

## Generate model patches

Install `mini-swe-agent`, configure the API credentials and environment variables for your model provider, and set the Bash variable `MODEL` to your model ID.
For provider and key configuration, follow the mini-SWE-agent model setup guide. [Model setup](https://mini-swe-agent.com/latest/models/quickstart/)
This example uses Fast Histogram 159. Mini-SWE-agent starts a container from the local image prepared above and generates a patch.

~~~bash
python -m pip install mini-swe-agent
swebench infer Alex-cpu0814/SWE-bench_CLB \
    -m "$MODEL" \
    --run-id clb-159 \
    -w 1 \
    -- --filter '^astrofrog__fast-histogram-clb-159$'
~~~

The runner writes predictions to `logs/inference/clb-159/preds.json` and saves the trajectory in the same run directory.
To run the full `test` split, omit the filter line and the trailing backslash on the preceding line.
Use `-w` to set how many tasks run concurrently during inference.

## Evaluate model patches

With `--task-repo`, SWE-bench reads the tasks from the prepared local checkout, validates it, and checks or builds the required images from its Dockerfiles. The evaluator then starts a fresh container and applies the candidate patch. Next, `eval.sh` applies the test patch, writes the evaluation fixtures, and runs the tests.

~~~bash
swebench eval Alex-cpu0814/SWE-bench_CLB \
    -p logs/inference/clb-159/preds.json \
    -i astrofrog__fast-histogram-clb-159 \
    --run-id clb-159 \
    --task-repo scratch/local-swebench/swe-bench-clb-tasks
~~~

Results go to `logs/evaluation/clb-159/results.json`. A task is resolved when all `FAIL_TO_PASS` and `PASS_TO_PASS` tests pass.
For a batch, pass the prediction file to `-p` and omit `-i`. Use a fresh `--run-id` when grading new predictions to avoid reusing an earlier report.

You can also supply your own `predictions.jsonl`. Each row contains `instance_id`, `model_name_or_path`, and `model_patch` in unified diff format.

## Repository layout

- `tasks/<instance_id>/` contains task metadata, the problem statement, reference and test patches, and generated evaluation files. [Task index](tasks/README.md) · [Instance ID mapping](docs/instance-id-map.tsv)
- `dockerfile_gen/` generates the `Dockerfile` and `eval.sh` for Python–C and Java–C tasks. Its `fixtures/environments/` contains source-build recipes; the remaining fixtures are embedded in the evaluation scripts. [Generator](dockerfile_gen/)
- `sweb.yaml` registers datasets and splits. `eval/` holds the evaluation configuration. [Dataset registration](sweb.yaml) · [Evaluation configuration](eval/SWE-bench_CLB.yaml)

## Maintain and export the dataset

Regenerate the task files after changing build or test configuration. Omit `--instance_ids` to regenerate all tasks. Use `--check` to verify that the checked-in files match the current configuration.

~~~bash
dockerfile-gen --instance_ids astrofrog__fast-histogram-clb-159
dockerfile-gen --check
~~~

All 72 tasks have source-build Dockerfiles. These start from public system or language images, install dependencies, and check out the task's Base commit. They do not inherit pre-built CLB images or require local source/dependency archives. Historical Java toolchains and JARs are downloaded from public URLs with SHA-256 checks; the legacy junixsocket toolchain is included as Docker build stages. Evaluation fixtures remain in `eval.sh`.

To build one task under a separate local tag:

~~~bash
docker build \
    --platform linux/amd64 \
    -t clb-local/fast-histogram-159:source \
    tasks/astrofrog__fast-histogram-clb-159
~~~

Builds require network access to the registries and dependency sources named in each Dockerfile, such as PyPI, GitHub, Maven Central, and OS package repositories. They do not call a model API. The 72 recipes have been migrated and statically checked; only Fast Histogram 159 has completed source-build qualification. The other 71 await individual build and evaluation checks. Published Docker Hub images have not been replaced. See [Validation results](docs/validation.md).

`--for-publish` runs the SWE-bench task check during export and writes the published `yutu0814/` addresses to `image`.

~~~bash
python prepare_dataset.py --for-publish -o scratch/dataset
~~~

The output directory `scratch/dataset/SWE-bench_CLB/` contains `test.parquet`, `eval.yaml`, and the dataset card.
To verify changes before publishing, use the exported dataset directory in the example commands.
[Validation results](docs/validation.md) · [Changelog](CHANGELOG.md)
