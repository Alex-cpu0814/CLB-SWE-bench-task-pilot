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

The split contains 64 problem statements drawn from archived upstream issues and eight retained from the frozen CLB release. The [task index](https://github.com/Alex-cpu0814/CLB-SWE-bench-task-pilot/blob/main/tasks/README.md) identifies the language combination and test source for each instance.

## Task fields

- `instance_id`, `repo`, and `base_commit` identify the task and its starting revision.
- `problem_statement` describes the repair task given to the model.
- `patch` is the reference repair. `test_patch`, `FAIL_TO_PASS`, `PASS_TO_PASS`, `eval_script`, `log_parser`, and `image` are used by the evaluation harness.

## Evaluation

Give the model the problem statement and the repository at its base revision. The evaluation harness applies the submitted patch and runs the task tests. A task is resolved when the `FAIL_TO_PASS` tests pass and the `PASS_TO_PASS` tests remain passing. The evaluation descriptor records the resolved rate over the `test` split.

To evaluate patches, use SWE-bench 5.0.2 with `--task-repo` pointing to a checkout of the task repository. SWE-bench reads the tasks and builds their evaluation images from the Dockerfiles in that checkout. The [task repository](https://github.com/Alex-cpu0814/CLB-SWE-bench-task-pilot) provides the commands, and the [validation record](https://github.com/Alex-cpu0814/CLB-SWE-bench-task-pilot/blob/main/docs/validation.md) documents Base and Gold checks for all 72 tasks.
