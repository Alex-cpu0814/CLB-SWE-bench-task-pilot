# CLB SWE-bench 任务仓库

本仓库迁移冻结版 CLB 的 72 个跨语言任务，包含 50 个 Python–C、
11 个 Java–C 作者测试和 11 个 Java–C 上游测试任务。评测使用 SWE-bench 5.0.2，
固定上游提交 `02e7a74ffd0b707aab73d203fe87bdc7c76afc8e`。
64 个题面逐字取自归档的 issue 标题和正文，另外 8 个沿用冻结版题面。
来源核查见 [审核记录](pilot-task-review.md#source-review-for-eight-frozen-statements)。
按语言组合和测试来源浏览，可查看 [72 题任务索引](tasks/README.md)。

## 任务格式

`instance_id` 使用 `<仓库所有者>__<仓库名>-clb-<原案例号>`，仓库名前缀转为小写。
例如 Jep 的原案例 `093` 对应 `ninia__jep-clb-093`。迁移历史预测或对照历史结果时，
可使用 [新旧 ID 对照表](instance-id-map.tsv)。评测镜像名按 SWE-bench 的规则将 `__` 编码为 `_1776_`。

`tasks/<instance_id>/` 中的 `task.yaml` 记录实例、仓库和 Base commit，
`problem_statement.md`、`gold.patch`、`test.patch`、`tests.json` 直接对应冻结版数据。
`Dockerfile` 从 [Base 镜像清单](base-images.json) 引用 `yutu0814/clb.base.x86_64.*:latest`，
并同时锁定 `sha256`。镜像用于提供各题的原始代码和依赖，Dockerfile 再添加评测所用的构建和测试脚本。
官方评测器应用候选补丁，调用 `eval.sh` 加载测试补丁、运行测试并判分。
迁移后的日志转换沿用各题原有的测试状态解析逻辑。生成模型补丁时用冻结版题面和
原 Base 镜像，评测运行所需的脚本及补丁由评测侧读取。

`import_frozen_tasks.py` 从冻结发布目录导入三题试点之外的任务。维护者可在仓库根目录运行
`python import_frozen_tasks.py ../CLB-SWE-bench-v1 --check` 核对导入文件。

## 72 题迁移验证（原 Base 镜像）

官方 `swebench dataset check .` 和 `swebench dataset build .` 已通过。按新旧 ID 对照表核对后，
导出的 72 条记录与冻结数据的仓库、Base、题面、补丁和测试列表一致。回放了新导入任务的 131 份原始测试日志，
已有评分节点的状态逐项一致。另有七份对照日志未在本地任务目录中找到，未纳入本次回放。

在 WSL 2 中使用本机缓存的固定 Base 镜像构建评测包装镜像，再由固定版本的官方评测器复跑下列任务。
构建时用本地标签引用已核对的镜像 ID。任务目录里的 Dockerfile 继续引用原 digest。
16 次实际运行的各测试节点与冻结版归档状态一致。

| 任务 | Base F2P | Gold F2P | Base 和 Gold P2P |
|---|---:|---:|---:|
| `numpy__numpy-clb-007` | 0/1 | 1/1 | 1/1 |
| `python-pillow__pillow-clb-053` | 0/2 | 2/2 | 2/2 |
| `python-pillow__pillow-clb-057` | 0/1 | 1/1 | 2/2 |
| `python-pillow__pillow-clb-058` | 0/1 | 1/1 | 2/2 |
| `python-pillow__pillow-clb-060` | 0/2 | 2/2 | 2/2 |
| `lwjgl__lwjgl3-clb-068` | 0/1 | 1/1 | 1/1 |
| `ninia__jep-clb-100` | 0/5 | 5/5 | 69/69 |
| `kohlschutter__junixsocket-clb-170` | 0/2 | 2/2 | 41/41 |

全量对照完成后，72 条 Base 均未解决，72 条 Gold 均通过。结果包括 50 条 Python–C、
11 条 Java–C 作者测试及 11 条 Java–C 上游测试。其余 61 题的 Base／Gold 运行记录和全量汇总位于
本地 `scratch/qualification/`，其中的记录使用改名前的实例 ID。七次对照按冻结版归档计数核对，其他对照按测试 ID 核对。
八条发生预期崩溃的 Base，官方评测器判为未解决，已完成的回归测试状态从带标记的输出区间核对。
Jep `093` 的 Base 在测试日志出现前崩溃，见原三题试点记录。

`kohlschutter__junixsocket-clb-160` 的 Gold
在并行运行时达到原有的 Maven 超时，串行复跑通过。`mdsplus__mdsplus-clb-200` 的评测镜像为固定的
`/testbed` 配置了 Git 安全目录，使官方评测器使用 root 时能读取其 Base 提交。部分旧版
Python 镜像需要兼容 Python 2.7 的日志转换。`ultrajson__ultrajson-clb-071` 使用上游保留测试 ID 内部空格的解析器。

## 三题对照

| 实例 | 仓库 | 分组 |
|---|---|---|
| `scipy__scipy-clb-002` | SciPy | Python–C |
| `ninia__jep-clb-093` | Jep | Java–C 作者测试 |
| `kohlschutter__junixsocket-clb-175` | junixsocket | Java–C 上游测试 |

在此仓库根目录运行。需要 Linux、Python 3.10+、Git 和可运行 Linux amd64
镜像的 Docker。Windows 使用 WSL 2，避免上游在 Windows 写入 CRLF 脚本和补丁。

~~~bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
swebench dataset check .
swebench images build . --namespace swebench -j 1 \
  -i scipy__scipy-clb-002 -i ninia__jep-clb-093 -i kohlschutter__junixsocket-clb-175
python verify_pilot.py --output scratch --run-id clb-pilot
~~~

对照脚本调用上游评测器，分别运行仅应用 Test Patch、Gold＋Test Patch 和历史候选＋Test Patch。
对照汇总位于 `scratch/clb-pilot-comparison.json`。重复运行使用新的 `--run-id`。
同一轮中断后，可附加 `--resume` 复用该轮已完成的报告。
首次用新实例 ID 跑试点时，请使用新的 `--run-id`，便于区分改名前的报告。
同一套镜像的构建和对照评测应串行执行，因为上游构建会更新镜像标签。
每个测试 ID 的新旧状态差异也会写入汇总。Jep 的原 Base 对照因堆损坏在测试报告产生前退出。
汇总核查该退出码和日志特征。
也可直接用 CLI 单独评测 Gold 或已有候选。

~~~bash
swebench eval clb-local/CLB-SWE-bench-task-pilot --task-repo . --gold \
  -i scipy__scipy-clb-002 -i ninia__jep-clb-093 -i kohlschutter__junixsocket-clb-175 --run-id clb-pilot-gold -j 1
swebench eval clb-local/CLB-SWE-bench-task-pilot --task-repo . \
  -p fixtures/historical_predictions.jsonl --run-id clb-pilot-history -j 1
~~~

历史候选来自已完成的 CLB 实验，来源和 SHA-256 见
[provenance.json](fixtures/provenance.json)。试点用于验证评测迁移。

使用自己的模型补丁时，向 `swebench eval` 的 `-p` 传入 JSONL 文件。每行包含
`instance_id`、`model_name_or_path` 和 `model_patch`，其中 `model_patch` 是统一 diff 的文本。
实例 ID 使用本仓库的值，例如 `numpy__numpy-clb-010`。可通过 `-i` 指定要评测的实例。
若要导出全部 72 条记录，运行 `swebench dataset build . -o scratch/dataset`。

## 2026 年 11 月 13 日对照结果

在 WSL 2 上用固定的上游版本完成 9 项对照。最终判分与 CLB 原记录一致，
归档的逐项测试状态也全部一致。

| 实例 | Base＋Test Patch | Gold＋Test Patch | 历史候选＋Test Patch |
|---|---|---|---|
| `scipy__scipy-clb-002` | 未通过，F2P 0/42 | 通过 | 未通过，F2P 10/42 |
| `ninia__jep-clb-093` | 堆损坏，退出码 134 | 通过 | 通过 |
| `kohlschutter__junixsocket-clb-175` | 未通过，F2P 0/1 | 通过 | 未通过，F2P 0/1 |

另用官方 `swebench eval … --task-repo … --gold` 直接从试点仓库构建 Jep 镜像并完成评测。
本次对照覆盖这三个实例的测试行为和判分。

## 独立副本复现

在仅包含待发布文件的本地副本中，导出了 72 条任务，并用 digest 锁定的已有 Base
镜像为 NumPy `numpy__numpy-clb-010` 构建了新的评测镜像。官方 `swebench eval` 分别评测了
该题的 Gold 补丁和历史 GLM-5 候选补丁，两次均通过全部 6 项目标测试和 3 项回归测试。
这次验证在同一台机器上复用了 Docker 缓存。

## 新 Base 镜像验证

使用 SWE-bench 5.0.2 从新 Dockerfile 构建了 72 个评测镜像。构建复用了本机 Base 缓存。
72 个 Base 控制均未解决，72 个 Gold 控制均通过。导出的 72 条数据与前一版逐字段一致。

- `lwjgl__lwjgl3-clb-075` 的依赖移至 `/opt/clb-deps`。Dockerfile 将这个目录链接到构建器使用的原路径。复测 Base 和 Gold 后，目标与回归测试结果均与归档计数一致。
- `kohlschutter__junixsocket-clb-160` 的 Gold 在并行运行时触发 Maven 超时，串行复测通过。
- `pygobject__pycairo-clb-139` 的三项回归测试均通过，目标测试触发进程中止，退出码为 134。旧镜像有两次相同记录，冻结汇总采用的是目标测试报告 `FAILED`、退出码为 1 的一次运行。两种情况下 SWE-bench 对 Base 的判分均为未解决，Gold 通过全部四项测试。
