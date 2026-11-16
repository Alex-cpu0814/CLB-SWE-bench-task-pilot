# CLB SWE-bench 任务仓库

CLB 收录 72 个实际项目中的跨语言修复任务，包括 50 个 Python–C、11 个 Java–C 作者测试和
11 个 Java–C 上游测试任务。评测使用 SWE-bench 5.0.2，固定上游提交
`02e7a74ffd0b707aab73d203fe87bdc7c76afc8e`。

- [任务索引](tasks/README.md)可按语言组合与测试来源浏览。
- [题面来源及三题审核](docs/pilot-task-review.md)记录了 64 条归档 issue 题面及 8 条沿用的 CLB 题面。
- [验证记录](docs/validation.md)包含 72 题的 Base／Gold 对照和空构建缓存复现。
- [变更日志](CHANGELOG.md)记录数据、镜像与评测流程的版本变更。

## 快速开始

在仓库根目录运行。需要 Linux、Python 3.10+、Git 和支持 Linux amd64 镜像的 Docker。
Windows 上使用 WSL 2。

~~~bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -e .
clb-dockerfile-gen --check
swebench dataset check .
swebench dataset build . -o scratch/dataset
~~~

用官方评测器构建三道代表题并验证 Gold。三题分别来自 Python–C、Java–C 作者测试、Java–C 上游测试。

~~~bash
swebench eval Alex-cpu0814/CLB-SWE-bench --task-repo . --gold \
  -i scipy__scipy-clb-002 -i ninia__jep-clb-093 -i kohlschutter__junixsocket-clb-175 \
  --run-id clb-pilot-gold -j 1
~~~

评测自己的候选时，把 `--gold` 换成 `-p predictions.jsonl`。JSONL 每行包含
`instance_id`、`model_name_or_path` 和 `model_patch`，其中 `model_patch` 是统一 diff 文本。
删除示例中的三个 `-i` 可评测预测文件中提交的任务。用于生成模型补丁的容器只需题面和对应 Base，
测试资产由评测侧加载。

## 数据导出与评测配置

`swebench dataset build . -o scratch/dataset` 会生成 `test.parquet`，并将
[评测配置](eval/CLB-SWE-bench.yaml)复制为 `eval.yaml`。两个文件位于
`scratch/dataset/CLB-SWE-bench/`。如需准备 Hugging Face 数据集目录，可将
[数据集卡片](docs/dataset-card.md)放到同一目录。

~~~bash
cp docs/dataset-card.md scratch/dataset/CLB-SWE-bench/README.md
~~~

数据集 ID 为 `Alex-cpu0814/CLB-SWE-bench`。评测命令使用 `--task-repo .` 从任务仓库
读取测试并现场构建所选题目的评测镜像。

## 任务与生成器

`tasks/<instance_id>/` 包含题面、补丁、测试列表、构建和评测脚本。
实例 ID 使用 `<owner>__<repo>-clb-<原案例号>`，历史结果可通过[新旧 ID 对照表](instance-id-map.tsv)查找。

`dockerfile_gen/` 从任务元数据、测试补丁和 [Base 镜像清单](base-images.json) 生成
`Dockerfile` 与 `eval.sh`。每道题的原始 Base 镜像引用锁定 `sha256`，评测辅助脚本由各题的
`runtime/` 提供。

~~~bash
clb-dockerfile-gen -i scipy__scipy-clb-002
clb-dockerfile-gen
~~~

也可以用 `python -m dockerfile_gen` 调用同一入口。只安装官方评测依赖时可运行
`python -m pip install -r requirements.txt`。

## 维护与复测

`tools/` 存放旧数据导入和三题对照脚本。先构建三题评测镜像，再运行对照。验证器运行 Base、Gold
和 `tools/fixtures/` 中的历史候选，并比较逐项测试结果。

~~~bash
swebench images build . --namespace swebench -j 1 \
  -i scipy__scipy-clb-002 -i ninia__jep-clb-093 -i kohlschutter__junixsocket-clb-175
python tools/verify_pilot.py --output scratch --run-id clb-pilot
~~~

对照输出写入 `scratch/clb-pilot-comparison.json`。重跑时使用新的 `--run-id`。中断后可用原
`--run-id` 加 `--resume` 继续。同一组镜像的构建和对照依次执行，构建会更新标签。
历史候选的来源和补丁哈希见 [provenance.json](tools/fixtures/provenance.json)，其中的镜像字段记录当时实际使用的版本。
持有旧冻结发布仓库的维护者可用下面的命令核对导入文件。

~~~bash
python tools/import_frozen_tasks.py ../CLB-SWE-bench-v1 --check
~~~
