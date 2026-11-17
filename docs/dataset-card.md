---
pretty_name: CLB SWE-bench
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

# CLB SWE-bench

CLB SWE-bench is a cross-language software repair benchmark for Python–C and Java–C projects. Its `default` configuration has one `test` split containing 72 tasks.

| Task group | Instances |
| --- | ---: |
| Python–C | 50 |
| Java–C with CLB-authored tests | 11 |
| Java–C with upstream tests | 11 |

The split contains 64 problem statements drawn from archived upstream issues and eight retained from the frozen CLB release. The [task index](https://github.com/Alex-cpu0814/swe-bench-clb-tasks/blob/main/tasks/README.md) identifies the language combination and test source for each instance.

## Dataset Structure

The `test` split contains one row per repair task. Each row has these fields.

```text
instance_id       (str)        Task ID in the form owner__repo-clb-NNN.
repo              (str)        Upstream GitHub repository in owner/repo form.
base_commit       (str)        Commit SHA at which the repair starts.
version           (str)        CLB release identifier.
cohort            (str)        Task group by language pair and test source.
image             (str)        Public CLB Base image on Docker Hub.
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

The `cohort` values `python50`, `java_author11`, and `java_upstream11` correspond to the three groups above, in that order. Base image names use the `yutu0814/sweb.eval.x86_64.*:latest` convention. SWE-bench builds separate evaluation images from the task checkout.

## Install

Use Linux or WSL 2 with Python 3.10+, Git, and Docker with Linux amd64 support and Buildx. The CLB task repository installs its `clb` command and pins SWE-bench 5.0.2.

```bash
git clone https://github.com/Alex-cpu0814/swe-bench-clb-tasks.git
cd swe-bench-clb-tasks
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -e .
```

## Generate predictions

Install mini-SWE-agent in the same environment, configure your model provider, and set `MODEL` to your model ID. Run from the root of the CLB task checkout. `clb infer` passes the task statement and digest-pinned Base image to the official inference command.

```bash
python -m pip install mini-swe-agent
clb infer \
    -m "$MODEL" \
    --run-id clb-159 \
    -w 1 \
    -- --filter '^astrofrog__fast-histogram-clb-159$'
```

The runner writes `logs/inference/clb-159/preds.json` and the task trajectory.

## Evaluation

Run from the CLB task checkout. `clb eval` gives the official SWE-bench evaluator the task files so it can build the selected evaluation images locally. [CLB task repository](https://github.com/Alex-cpu0814/swe-bench-clb-tasks)

Evaluate the prediction for Fast Histogram 159 generated above.

```bash
clb eval \
    -p logs/inference/clb-159/preds.json \
    -i astrofrog__fast-histogram-clb-159 \
    --run-id clb-159 \
    -j 1
```

For a batch of predictions, pass the batch file to `-p` and omit `-i` to evaluate the instances in that file. SWE-bench writes the summary to `logs/evaluation/<run_id>/results.json`. A task is resolved when all `FAIL_TO_PASS` and `PASS_TO_PASS` tests pass. Use a fresh run ID when grading a new patch. [SWE-bench CLI reference](https://github.com/SWE-bench/SWE-bench/blob/main/docs/reference/cli.md#swebench-eval-dataset)

Use the reference patch to check that the task builds and scores successfully.

```bash
clb eval --gold \
    -i astrofrog__fast-histogram-clb-159 \
    --run-id clb-159-gold \
    -j 1
```

The published validation covers Base and Gold checks for all 72 tasks. [Validation record](https://github.com/Alex-cpu0814/swe-bench-clb-tasks/blob/main/docs/validation.md)
