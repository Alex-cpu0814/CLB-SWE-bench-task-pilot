---
pretty_name: SWE-bench CLB
language:
  - en
tags:
  - benchmark
  - software-engineering
  - swe-bench
configs:
  - config_name: default
    data_files:
      - split: test
        path: test.parquet
---

# SWE-bench CLB

[简体中文使用说明](https://github.com/Alex-cpu0814/swe-bench-clb-tasks/blob/main/docs/README.zh-CN.md)

SWE-bench CLB is a cross-language software repair benchmark for Python–C and Java–C projects. Its `default` configuration has one `test` split containing 72 tasks.

| Task group | Instances |
| --- | ---: |
| Python–C | 50 |
| Java–C with CLB-authored tests | 11 |
| Java–C with upstream tests | 11 |

The split contains 64 problem statements drawn from archived upstream issues and eight retained from the frozen CLB release. The [task index](https://github.com/Alex-cpu0814/swe-bench-clb-tasks/blob/main/tasks/README.md) identifies the language combination and test source for each instance.

The source review documents the upstream records checked for the eight retained statements. [Archived source review](https://github.com/Alex-cpu0814/swe-bench-clb-tasks/blob/98b99d2d976f8368788d8613ff2710f5b54a655d/docs/pilot-task-review.md#source-review-for-eight-frozen-statements)

## Dataset Structure

The `test` split contains one row per repair task. Each row has these fields.

```text
instance_id       (str)        Task ID in the form owner__repo-clb-NNN.
repo              (str)        Upstream GitHub repository in owner/repo form.
base_commit       (str)        Commit SHA at which the repair starts.
version           (str)        CLB release identifier.
cohort            (str)        Task group by language pair and test source.
image             (str)        Published CLB image on Docker Hub.
log_parser        (str)        Parser used to extract test results from logs.
eval_type         (str)        Grading mode, set to pass_and_fail.
patch             (str)        Reference repair (Gold patch).
test_patch        (str)        Patch that adds or updates evaluation tests.
eval_script       (str)        Shell script that prepares and runs the tests.
problem_statement (str)        Bug report or task description given to the model.
hints_text        (str)        Additional issue context, when available.
FAIL_TO_PASS      (list[str])  Tests expected to fail on Base and pass after repair.
PASS_TO_PASS      (list[str])  Tests expected to pass on Base and after repair.
```

The `cohort` values `python50`, `java_author11`, and `java_upstream11` correspond to the three groups above, in that order. Images are published under `yutu0814/sweb.eval.x86_64.*:latest`.

## Install

Use Linux or WSL 2 with Python 3.10+, Git, and Docker with Linux amd64 support.
Installing the CLB task repository installs the pinned SWE-bench 5.0.2 and its dependencies.

```bash
git clone https://github.com/Alex-cpu0814/swe-bench-clb-tasks.git
cd swe-bench-clb-tasks
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -e .
```

## Prepare local images

Before running inference, run the preparation command on the same Docker host that will run mini-SWE-agent. The command pulls missing CLB images from `yutu0814/` and gives the same images the local `swebench/` tags that mini-SWE-agent derives from task IDs.

```bash
python prepare_dataset.py -o scratch/local-swebench
```

To check the generated task repository, run `swebench dataset check scratch/local-swebench/task-repo`. For inference and evaluation, you can also pass `scratch/local-swebench/dataset/SWE-bench_CLB` as the dataset.

## Validate the reference patch

Run `--gold` on Fast Histogram 159 to check the image, tests, and scoring.

```bash
swebench eval Alex-cpu0814/SWE-bench_CLB --gold \
    -i astrofrog__fast-histogram-clb-159 \
    --run-id clb-159-gold \
    --task-repo scratch/local-swebench/task-repo
```

Validation covers reference patches and unrelated control patches for all 72 tasks. [Validation results](https://github.com/Alex-cpu0814/swe-bench-clb-tasks/blob/main/docs/validation.md)

## Generate predictions

Install mini-SWE-agent in the same environment, configure your model provider, and set `MODEL` to your model ID. Mini-SWE-agent starts from the local image tag prepared above.
Follow the official guide to configure your provider and API credentials. [Model setup](https://mini-swe-agent.com/latest/models/quickstart/)

```bash
python -m pip install mini-swe-agent
swebench infer Alex-cpu0814/SWE-bench_CLB \
    -m "$MODEL" \
    --run-id clb-159 \
    -w 1 \
    -- --filter '^astrofrog__fast-histogram-clb-159$'
```

The runner writes `logs/inference/clb-159/preds.json` and the task trajectory.

## Evaluation

With `--task-repo`, SWE-bench reads the tasks from the prepared local checkout, validates it, and checks or builds the required images from its Dockerfiles. The evaluator then starts a fresh container and applies the candidate patch. The evaluation script applies the test patch, writes the evaluation fixtures, and runs the tests.

Evaluate the prediction for Fast Histogram 159 generated above.

```bash
swebench eval Alex-cpu0814/SWE-bench_CLB \
    -p logs/inference/clb-159/preds.json \
    -i astrofrog__fast-histogram-clb-159 \
    --run-id clb-159 \
    --task-repo scratch/local-swebench/task-repo
```

For a batch of predictions, pass the batch file to `-p` and omit `-i` to evaluate the instances in that file. SWE-bench writes the summary to `logs/evaluation/<run_id>/results.json`. A task is resolved when all `FAIL_TO_PASS` and `PASS_TO_PASS` tests pass. Use a fresh run ID when grading a new patch. [SWE-bench CLI reference](https://github.com/SWE-bench/SWE-bench/blob/main/docs/reference/cli.md#swebench-eval-dataset)
