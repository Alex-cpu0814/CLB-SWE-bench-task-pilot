# CLB SWE-bench 三题试点

这个任务仓库试用 SWE-bench 5.0.2 的评测入口，固定上游提交
`02e7a74ffd0b707aab73d203fe87bdc7c76afc8e`。

| 实例 | 仓库 | 分组 |
|---|---|---|
| `clb-pyc-002` | SciPy | Python–C |
| `clb-javac-093` | Jep | Java–C 作者测试 |
| `clb-javac-175` | junixsocket | Java–C 上游测试 |

每个任务目录保留冻结题面、Base commit、Gold/Test Patch 和原测试 ID。
Dockerfile 基于原 CLB 镜像的 digest 构建，只添加构建与测试所需的运行脚本。
评测脚本应用测试补丁、执行原构建与测试命令，并将测试结果转换成上游
`parse_log_pytest_v2` 支持的逐行格式。上游负责候选补丁、容器调度和判分。
本地构建使用上游校验器要求的 `swebench/sweb.eval.*:latest` 标签。

## 复现

在此仓库根目录运行。需要 Linux、Python 3.10+、Git 和可运行 Linux amd64
镜像的 Docker。Windows 使用 WSL 2，避免上游在 Windows 写入 CRLF 脚本和补丁。

~~~bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
swebench dataset check .
swebench images build . -j 1
python verify_pilot.py --output scratch --run-id clb-pilot
~~~

对照脚本调用上游评测器，分别运行仅应用 Test Patch、Gold＋Test Patch 和历史候选＋Test Patch。
对照汇总位于 `scratch/clb-pilot-comparison.json`。重复运行使用新的 `--run-id`。
同一轮中断后，可附加 `--resume` 复用该轮已完成的报告。
同一套镜像的构建和对照评测应串行执行，因为上游构建会更新镜像标签。
每个测试 ID 的新旧状态差异也会写入汇总。Jep 的原 Base 对照因堆损坏在测试报告产生前退出。
汇总核查该退出码和日志特征。
也可直接用 CLI 单独评测 Gold 或已有候选。

~~~bash
swebench eval clb-local/CLB-SWE-bench-task-pilot --task-repo . --gold --run-id clb-pilot-gold -j 1
swebench eval clb-local/CLB-SWE-bench-task-pilot --task-repo . -p fixtures/historical_predictions.jsonl --run-id clb-pilot-history -j 1
~~~

历史候选来自已完成的 CLB 实验，来源和 SHA-256 见
[provenance.json](fixtures/provenance.json)。试点用于验证评测迁移。

## 2026 年 11 月 13 日对照结果

在 WSL 2 上用固定的上游版本完成 9 项对照。最终判分与 CLB 原记录一致，
归档的逐项测试状态也全部一致。

| 实例 | Base＋Test Patch | Gold＋Test Patch | 历史候选＋Test Patch |
|---|---|---|---|
| `clb-pyc-002` | 未通过，F2P 0/42 | 通过 | 未通过，F2P 10/42 |
| `clb-javac-093` | 堆损坏，退出码 134 | 通过 | 通过 |
| `clb-javac-175` | 未通过，F2P 0/1 | 通过 | 未通过，F2P 0/1 |

另用官方 `swebench eval … --task-repo … --gold` 直接从试点仓库构建 Jep 镜像并完成评测。
本次对照覆盖这三个实例的测试行为和判分。
